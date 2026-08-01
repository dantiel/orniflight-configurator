seek = (firmware, address) ->
    index = 0
    while index < firmware.data.length and address >= firmware.data[index].address + firmware.data[index].bytes
        index++
    result = lineIndex: index
    if firmware.data[index] and address >= firmware.data[index].address
        result.byteIndex = address - (firmware.data[index].address)
    result

readUint32 = (firmware, index) ->
    result = 0
    position = 0
    while position < 4
        result += firmware.data[index.lineIndex].data[index.byteIndex++] << 8 * position
        if index.byteIndex >= firmware.data[index.lineIndex].bytes
            index.lineIndex++
            index.byteIndex = 0
        position++
    result

getCustomDefaultsArea = (firmware) ->
    `var result`
    result = {}
    index = seek(firmware, CUSTOM_DEFAULTS_POINTER_ADDRESS)
    if index.byteIndex == undefined
        return
    result = {}
    result.startAddress = readUint32(firmware, index)
    result.endAddress = readUint32(firmware, index)
    result

generateData = (firmware, input, startAddress) ->
    address = startAddress
    index = seek(firmware, address)
    if index.byteIndex != undefined
        throw new Error('Configuration area in firmware not free.')
    # Add 0 terminator
    input = input + '\u0000'
    inputIndex = 0
    while inputIndex < input.length
        remaining = input.length - inputIndex
        line = 
            address: address
            bytes: if BLOCK_SIZE > remaining then remaining else BLOCK_SIZE
            data: []
        if firmware.data[index.lineIndex] and line.address + line.bytes > firmware.data[index.lineIndex].address
            throw new Error('Aborting data generation, free area too small.')
        i = 0
        while i < line.bytes
            line.data.push input.charCodeAt(inputIndex++)
            i++
        address = address + line.bytes
        firmware.data.splice index.lineIndex++, 0, line
    firmware.bytes_total += input.length
    return

microtime = ->
    now = (new Date).getTime() / 1000
    now

'use strict'

ConfigInserter = ->

CUSTOM_DEFAULTS_POINTER_ADDRESS = 0x08002800
BLOCK_SIZE = 16384

ConfigInserter::insertConfig = (firmware, input) ->
    time_parsing_start = microtime()
    # track time
    customDefaultsArea = getCustomDefaultsArea(firmware)
    if !customDefaultsArea or customDefaultsArea.endAddress - (customDefaultsArea.startAddress) == 0
        return false
    else if input.length >= customDefaultsArea.endAddress - (customDefaultsArea.startAddress)
        throw new Error('Custom defaults area too small (' + customDefaultsArea.endAddress - (customDefaultsArea.startAddress) + ' bytes), ' + input.length + 1 + ' bytes needed.')
    generateData firmware, input, customDefaultsArea.startAddress
    console.log 'Custom defaults inserted in: ' + (microtime() - time_parsing_start).toFixed(4) + ' seconds.'
    true

