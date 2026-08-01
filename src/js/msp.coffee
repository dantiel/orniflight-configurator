'use strict'
MSP = 
    state: 0
    message_direction: 1
    code: 0
    dataView: 0
    message_length_expected: 0
    message_length_received: 0
    message_buffer: null
    message_buffer_uint8_view: null
    message_checksum: 0
    messageIsJumboFrame: false
    crcError: false
    callbacks: []
    packet_error: 0
    unsupported: 0
    last_received_timestamp: null
    listeners: []
    JUMBO_FRAME_SIZE_LIMIT: 255
    read: (readInfo) ->
        data = new Uint8Array(readInfo.data)
        i = 0
        while i < data.length
            switch @state
                when 0
                    # sync char 1
                    if data[i] == 36
                        # $
                        @state++
                when 1
                    # sync char 2
                    if data[i] == 77
                        # M
                        @state++
                    else
                        # restart and try again
                        @state = 0
                when 2
                    # direction (should be >)
                    @unsupported = 0
                    if data[i] == 62
                        # >
                        @message_direction = 1
                    else if data[i] == 60
                        # <
                        @message_direction = 0
                    else if data[i] == 33
                        # !
                        # FC reports unsupported message error
                        @unsupported = 1
                    @state++
                when 3
                    @message_length_expected = data[i]
                    if @message_length_expected == @JUMBO_FRAME_SIZE_LIMIT
                        @messageIsJumboFrame = true
                    @message_checksum = data[i]
                    @state++
                when 4
                    @code = data[i]
                    @message_checksum ^= data[i]
                    if @message_length_expected > 0
                        # process payload
                        if @messageIsJumboFrame
                            @state++
                        else
                            @state = @state + 3
                    else
                        # no payload
                        @state += 5
                when 5
                    @message_length_expected = data[i]
                    @message_checksum ^= data[i]
                    @state++
                when 6
                    @message_length_expected = @message_length_expected + 256 * data[i]
                    @message_checksum ^= data[i]
                    @state++
                when 7
                    # setup arraybuffer
                    @message_buffer = new ArrayBuffer(@message_length_expected)
                    @message_buffer_uint8_view = new Uint8Array(@message_buffer)
                    @state++
                    @message_buffer_uint8_view[@message_length_received] = data[i]
                    @message_checksum ^= data[i]
                    @message_length_received++
                when 8
                    # payload
                    @message_buffer_uint8_view[@message_length_received] = data[i]
                    @message_checksum ^= data[i]
                    @message_length_received++
                    if @message_length_received >= @message_length_expected
                        @state++
                when 9
                    if @message_checksum == data[i]
                        # message received, store dataview
                        @dataView = new DataView(@message_buffer, 0, @message_length_expected)
                    else
                        console.log 'code: ' + @code + ' - crc failed'
                        @packet_error++
                        @crcError = true
                        @dataView = new DataView(new ArrayBuffer(0))
                    # Reset variables
                    @message_length_received = 0
                    @state = 0
                    @messageIsJumboFrame = false
                    @notify()
                    @crcError = false
                else
                    console.log 'Unknown state detected: ' + @state
            i++
        @last_received_timestamp = Date.now()
        return
    notify: ->
        self = this
        @listeners.forEach (listener) ->
            listener self
            return
        return
    listen: (listener) ->
        if @listeners.indexOf(listener) == -1
            @listeners.push listener
        return
    clearListeners: ->
        @listeners = []
        return
    send_message: (code, data, callback_sent, callback_msp, callback_onerror) ->
        `var callbackOnError`
        `var i`
        if code == undefined
            debugger
        bufferOut = undefined
        bufView = undefined
        if !callback_onerror
            callbackOnError = false
        else
            callbackOnError = true
        # always reserve 6 bytes for protocol overhead !
        if data
            size = data.length + 6
            checksum = 0
            bufferOut = new ArrayBuffer(size)
            bufView = new Uint8Array(bufferOut)
            bufView[0] = 36
            # $
            bufView[1] = 77
            # M
            bufView[2] = 60
            # <
            bufView[3] = data.length
            bufView[4] = code
            checksum = bufView[3] ^ bufView[4]
            i = 0
            while i < data.length
                bufView[i + 5] = data[i]
                checksum ^= bufView[i + 5]
                i++
            bufView[5 + data.length] = checksum
        else
            bufferOut = new ArrayBuffer(6)
            bufView = new Uint8Array(bufferOut)
            bufView[0] = 36
            # $
            bufView[1] = 77
            # M
            bufView[2] = 60
            # <
            bufView[3] = 0
            # data length
            bufView[4] = code
            # code
            bufView[5] = bufView[3] ^ bufView[4]
            # checksum
        obj = 
            'code': code
            'requestBuffer': bufferOut
            'callback': if callback_msp then callback_msp else false
            'timer': false
            'callbackOnError': callbackOnError
        requestExists = false
        i = 0
        while i < MSP.callbacks.length
            if MSP.callbacks[i].code == code
                # request already exist, we will just attach
                requestExists = true
                break
            i++
        if !requestExists
            obj.timer = setInterval((->
                console.log 'MSP data request timed-out: ' + code
                serial.send bufferOut, false
                return
            ), 1000)
            # we should be able to define timeout in the future
        MSP.callbacks.push obj
        # always send messages with data payload (even when there is a message already in the queue)
        if data or !requestExists
            serial.send bufferOut, (sendInfo) ->
                if sendInfo.bytesSent == bufferOut.byteLength
                    if callback_sent
                        callback_sent()
                return
        true
    promise: (code, data) ->
        self = this
        new Promise((resolve) ->
            self.send_message code, data, false, (data) ->
                resolve data
                return
            return
)
    callbacks_cleanup: ->
        i = 0
        while i < @callbacks.length
            clearInterval @callbacks[i].timer
            i++
        @callbacks = []
        return
    disconnect_cleanup: ->
        @state = 0
        # reset packet state for "clean" initial entry (this is only required if user hot-disconnects)
        @packet_error = 0
        # reset CRC packet error counter for next session
        @callbacks_cleanup()
        return

