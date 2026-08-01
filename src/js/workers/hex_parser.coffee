# input = string
# result = if hex file is valid, result is an object
#          if hex file wasn't valid (crc check failed on any of the lines), result will be false

read_hex_file = (data) ->
    data = data.split('\n')
    # check if there is an empty line in the end of hex file, if there is, remove it
    if data[data.length - 1] == ''
        data.pop()
    hexfile_valid = true
    # if any of the crc checks failed, this variable flips to false
    result = 
        data: []
        end_of_file: false
        bytes_total: 0
        start_linear_address: 0
    extended_linear_address = 0
    next_address = 0
    i = 0
    while i < data.length and hexfile_valid
        # each byte is represnted by two chars
        byte_count = parseInt(data[i].substr(1, 2), 16)
        address = parseInt(data[i].substr(3, 4), 16)
        record_type = parseInt(data[i].substr(7, 2), 16)
        content = data[i].substr(9, byte_count * 2)
        # still in string format
        checksum = parseInt(data[i].substr(9 + byte_count * 2, 2), 16)
        # (this is a 2's complement value)
        switch record_type
            when 0x00
                # data record
                if address != next_address or next_address == 0
                    result.data.push
                        'address': extended_linear_address + address
                        'bytes': 0
                        'data': []
                # store address for next comparison
                next_address = address + byte_count
                # process data
                crc = byte_count + parseInt(data[i].substr(3, 2), 16) + parseInt(data[i].substr(5, 2), 16) + record_type
                needle = 0
                while needle < byte_count * 2
                    # * 2 because of 2 hex chars per 1 byte
                    num = parseInt(content.substr(needle, 2), 16)
                    # get one byte in hex and convert it to decimal
                    data_block = result.data.length - 1
                    result.data[data_block].data.push num
                    result.data[data_block].bytes++
                    crc += num
                    result.bytes_total++
                    needle += 2
                # change crc to 2's complement
                crc = ~crc + 1 & 0xFF
                # verify
                if crc != checksum
                    hexfile_valid = false
            when 0x01
                # end of file record
                result.end_of_file = true
            when 0x02
                # extended segment address record
                # not implemented
                if parseInt(content, 16) != 0
                    # ignore if segment is 0
                    console.log 'extended segment address record found - NOT IMPLEMENTED !!!'
            when 0x03
                # start segment address record
                # not implemented
                if parseInt(content, 16) != 0
                    # ignore if segment is 0
                    console.log 'start segment address record found - NOT IMPLEMENTED !!!'
            when 0x04
                # extended linear address record
                # input address is UNSIGNED
                extended_linear_address = (parseInt(content.substr(0, 2), 16) << 24 | parseInt(content.substr(2, 2), 16) << 16) >>> 0
            when 0x05
                # start linear address record
                result.start_linear_address = parseInt(content, 16)
        i++
    if result.end_of_file and hexfile_valid
        postMessage result
    else
        postMessage false
    return

microtime = ->
    now = (new Date).getTime() / 1000
    now

'use strict'

onmessage = (event) ->
    time_parsing_start = microtime()
    # track time
    read_hex_file event.data
    console.log 'HEX_PARSER - File parsed in: ' + (microtime() - time_parsing_start).toFixed(4) + ' seconds'
    # terminate worker
    close()
    return

