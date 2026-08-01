'use strict'
serial = 
    connected: false
    connectionId: false
    openRequested: false
    openCanceled: false
    bitrate: 0
    bytesReceived: 0
    bytesSent: 0
    failed: 0
    connectionType: 'serial'
    connectionIP: '127.0.0.1'
    connectionPort: 2323
    transmitting: false
    outputBuffer: []
    logHead: 'SERIAL: '
    connect: (path, options, callback) ->
        self = this
        testUrl = path.match(/^tcp:\/\/([A-Za-z0-9\.-]+)(?:\:(\d+))?$/)
        if testUrl
            self.connectTcp testUrl[1], testUrl[2], options, callback
        else
            self.connectSerial path, options, callback
        return
    connectSerial: (path, options, callback) ->
        self = this
        self.openRequested = true
        self.connectionType = 'serial'
        self.logHead = 'SERIAL: '
        chrome.serial.connect path, options, (connectionInfo) ->
            if chrome.runtime.lastError
                console.error chrome.runtime.lastError.message
            if connectionInfo and !self.openCanceled
                self.connected = true
                self.connectionId = connectionInfo.connectionId
                self.bitrate = connectionInfo.bitrate
                self.bytesReceived = 0
                self.bytesSent = 0
                self.failed = 0
                self.openRequested = false
                self.onReceive.addListener (info) ->
                    self.bytesReceived += info.data.byteLength
                    return
                self.onReceiveError.addListener (info) ->
                    switch info.error
                        when 'system_error'
                            # we might be able to recover from this one
                            if !self.failed++
                                chrome.serial.setPaused self.connectionId, false, ->
                                    self.getInfo (info) ->
                                        if info
                                            if !info.paused
                                                console.log 'SERIAL: Connection recovered from last onReceiveError'
                                                self.failed = 0
                                            else
                                                console.log 'SERIAL: Connection did not recover from last onReceiveError, disconnecting'
                                                GUI.log i18n.getMessage('serialUnrecoverable')
                                                if GUI.connected_to or GUI.connecting_to
                                                    $('a.connect').click()
                                                else
                                                    self.disconnect()
                                        else
                                            if chrome.runtime.lastError
                                                console.error chrome.runtime.lastError.message
                                        return
                                    return
                        when 'overrun'
                            # wait 50 ms and attempt recovery
                            self.error = info.error
                            setTimeout (->
                                chrome.serial.setPaused info.connectionId, false, ->
                                    self.getInfo (info) ->
                                        if info
                                            if info.paused
                                                # assume unrecoverable, disconnect
                                                console.log 'SERIAL: Connection did not recover from ' + self.error + ' condition, disconnecting'
                                                GUI.log i18n.getMessage('serialUnrecoverable')
                                                if GUI.connected_to or GUI.connecting_to
                                                    $('a.connect').click()
                                                else
                                                    self.disconnect()
                                            else
                                                console.log 'SERIAL: Connection recovered from ' + self.error + ' condition'
                                        return
                                    return
                                return
                            ), 50
                        when 'timeout' then
                            # No data has been received for receiveTimeout milliseconds.
                            # We will do nothing.
                        when 'frame_error', 'parity_error'
                            GUI.log i18n.getMessage('serialError' + inflection.camelize(info.error))
                            console.log 'serial disconnecting: ' + info.error
                            CONFIG.armingDisabled = false
                            CONFIG.runawayTakeoffPreventionDisabled = false
                            if GUI.connected_to or GUI.connecting_to
                                $('a.connect').click()
                            else
                                self.disconnect()
                        else
                            console.log 'serial disconnecting: ' + info.error
                            CONFIG.armingDisabled = false
                            CONFIG.runawayTakeoffPreventionDisabled = false
                            if GUI.connected_to or GUI.connecting_to
                                $('a.connect').click()
                            else
                                self.disconnect()
                            break
                    return
                console.log 'SERIAL: Connection opened with ID: ' + connectionInfo.connectionId + ', Baud: ' + connectionInfo.bitrate
                if callback
                    callback connectionInfo
            else if connectionInfo and self.openCanceled
                # connection opened, but this connect sequence was canceled
                # we will disconnect without triggering any callbacks
                self.connectionId = connectionInfo.connectionId
                console.log 'SERIAL: Connection opened with ID: ' + connectionInfo.connectionId + ', but request was canceled, disconnecting'
                # some bluetooth dongles/dongle drivers really doesn't like to be closed instantly, adding a small delay
                setTimeout (->
                    self.openRequested = false
                    self.openCanceled = false
                    self.disconnect ->
                        if callback
                            callback false
                        return
                    return
                ), 150
            else if self.openCanceled
                # connection didn't open and sequence was canceled, so we will do nothing
                console.log 'SERIAL: Connection didn\'t open and request was canceled'
                self.openRequested = false
                self.openCanceled = false
                if callback
                    callback false
            else
                self.openRequested = false
                console.log 'SERIAL: Failed to open serial port'
                if callback
                    callback false
            return
        return
    connectTcp: (ip, port, options, callback) ->
        self = this
        self.openRequested = true
        self.connectionIP = ip
        self.connectionPort = port or 2323
        self.connectionPort = parseInt(self.connectionPort)
        self.connectionType = 'tcp'
        self.logHead = 'SERIAL-TCP: '
        console.log 'connect to raw tcp:', ip + ':' + port
        chrome.sockets.tcp.create {}, (createInfo) ->
            console.log 'chrome.sockets.tcp.create', createInfo
            if createInfo and !self.openCanceled
                self.connectionId = createInfo.socketId
                self.bitrate = 115200
                # fake
                self.bytesReceived = 0
                self.bytesSent = 0
                self.failed = 0
                self.openRequested = false
            chrome.sockets.tcp.connect createInfo.socketId, self.connectionIP, self.connectionPort, (result) ->
                if chrome.runtime.lastError
                    console.error 'onConnectedCallback', chrome.runtime.lastError.message
                console.log 'onConnectedCallback', result
                if result == 0
                    self.connected = true
                    chrome.sockets.tcp.setNoDelay createInfo.socketId, true, (noDelayResult) ->
                        if chrome.runtime.lastError
                            console.error 'setNoDelay', chrome.runtime.lastError.message
                        console.log 'setNoDelay', noDelayResult
                        if noDelayResult != 0
                            self.openRequested = false
                            console.log self.logHead + 'Failed to setNoDelay'
                        self.onReceive.addListener (info) ->
                            if info.socketId != self.connectionId
                                return
                            self.bytesReceived += info.data.byteLength
                            return
                        self.onReceiveError.addListener (info) ->
                            console.error info
                            if info.socketId != self.connectionId
                                return
                            # TODO: better error handle
                            # error code: https://cs.chromium.org/chromium/src/net/base/net_error_list.h?sq=package:chromium&l=124
                            switch info.resultCode
                                # CONNECTION_CLOSED
                                when -100, -102
                                    # CONNECTION_REFUSED
                                    if GUI.connected_to or GUI.connecting_to
                                        $('a.connect').click()
                                    else
                                        self.disconnect()
                            return
                        console.log self.logHead + 'Connection opened with ID: ' + createInfo.socketId + ', url: ' + self.connectionIP + ':' + self.connectionPort
                        if callback
                            callback createInfo
                        return
                else
                    self.openRequested = false
                    console.log self.logHead + 'Failed to connect'
                    if callback
                        callback false
                return
            return
        return
    disconnect: (callback) ->
        `var i`
        self = this
        self.connected = false
        if self.connectionId
            self.emptyOutputBuffer()
            # remove listeners
            i = self.onReceive.listeners.length - 1
            while i >= 0
                self.onReceive.removeListener self.onReceive.listeners[i]
                i--
            i = self.onReceiveError.listeners.length - 1
            while i >= 0
                self.onReceiveError.removeListener self.onReceiveError.listeners[i]
                i--
            disconnectFn = if self.connectionType == 'serial' then chrome.serial.disconnect else chrome.sockets.tcp.close
            disconnectFn @connectionId, (result) ->
                if chrome.runtime.lastError
                    console.error chrome.runtime.lastError.message
                result = result or self.connectionType == 'tcp'
                if result
                    console.log self.logHead + 'Connection with ID: ' + self.connectionId + ' closed, Sent: ' + self.bytesSent + ' bytes, Received: ' + self.bytesReceived + ' bytes'
                else
                    console.log self.logHead + 'Failed to close connection with ID: ' + self.connectionId + ' closed, Sent: ' + self.bytesSent + ' bytes, Received: ' + self.bytesReceived + ' bytes'
                self.connectionId = false
                self.bitrate = 0
                if callback
                    callback result
                return
        else
            # connection wasn't opened, so we won't try to close anything
            # instead we will rise canceled flag which will prevent connect from continueing further after being canceled
            self.openCanceled = true
        return
    getDevices: (callback) ->
        chrome.serial.getDevices (devices_array) ->
            devices = []
            devices_array.forEach (device) ->
                devices.push device.path
                return
            callback devices
            return
        return
    getInfo: (callback) ->
        chromeType = if @connectionType == 'serial' then chrome.serial else chrome.sockets.tcp
        chromeType.getInfo @connectionId, callback
        return
    getControlSignals: (callback) ->
        if @connectionType == 'serial'
            chrome.serial.getControlSignals @connectionId, callback
        return
    setControlSignals: (signals, callback) ->
        if @connectionType == 'serial'
            chrome.serial.setControlSignals @connectionId, signals, callback
        return
    send: (data, callback) ->
        self = this

        send = ->
            `var data`
            `var callback`
            # store inside separate variables in case array gets destroyed
            data = self.outputBuffer[0].data
            callback = self.outputBuffer[0].callback
            if !self.connected
                console.log 'attempting to send when disconnected'
                if callback
                    callback
                        bytesSent: 0
                        error: 'undefined'
                return
            sendFn = if self.connectionType == 'serial' then chrome.serial.send else chrome.sockets.tcp.send
            sendFn self.connectionId, data, (sendInfo) ->
                if sendInfo == undefined
                    console.log 'undefined send error'
                    if callback
                        callback
                            bytesSent: 0
                            error: 'undefined'
                    return
                # tcp send error
                if self.connectionType == 'tcp' and sendInfo.resultCode < 0
                    error = 'system_error'
                    # TODO: better error handle
                    # error code: https://cs.chromium.org/chromium/src/net/base/net_error_list.h?sq=package:chromium&l=124
                    switch sendInfo.resultCode
                        # CONNECTION_CLOSED
                        when -100, -102
                            # CONNECTION_REFUSED
                            error = 'disconnected'
                    if callback
                        callback
                            bytesSent: 0
                            error: error
                    return
                # track sent bytes for statistics
                self.bytesSent += sendInfo.bytesSent
                # fire callback
                if callback
                    callback sendInfo
                # remove data for current transmission form the buffer
                self.outputBuffer.shift()
                # if there is any data in the queue fire send immediately, otherwise stop trasmitting
                if self.outputBuffer.length
                    # keep the buffer withing reasonable limits
                    if self.outputBuffer.length > 100
                        counter = 0
                        while self.outputBuffer.length > 100
                            self.outputBuffer.pop()
                            counter++
                        console.log self.logHead + 'Send buffer overflowing, dropped: ' + counter + ' entries'
                    send()
                else
                    self.transmitting = false
                return
            return

        @outputBuffer.push
            'data': data
            'callback': callback
        if !@transmitting
            @transmitting = true
            send()
        return
    onReceive:
        listeners: []
        addListener: (function_reference) ->
            chromeType = if serial.connectionType == 'serial' then chrome.serial else chrome.sockets.tcp
            chromeType.onReceive.addListener function_reference
            @listeners.push function_reference
            return
        removeListener: (function_reference) ->
            chromeType = if serial.connectionType == 'serial' then chrome.serial else chrome.sockets.tcp
            i = @listeners.length - 1
            while i >= 0
                if @listeners[i] == function_reference
                    chromeType.onReceive.removeListener function_reference
                    @listeners.splice i, 1
                    break
                i--
            return
    onReceiveError:
        listeners: []
        addListener: (function_reference) ->
            chromeType = if serial.connectionType == 'serial' then chrome.serial else chrome.sockets.tcp
            chromeType.onReceiveError.addListener function_reference
            @listeners.push function_reference
            return
        removeListener: (function_reference) ->
            chromeType = if serial.connectionType == 'serial' then chrome.serial else chrome.sockets.tcp
            i = @listeners.length - 1
            while i >= 0
                if @listeners[i] == function_reference
                    chromeType.onReceiveError.removeListener function_reference
                    @listeners.splice i, 1
                    break
                i--
            return
    emptyOutputBuffer: ->
        @outputBuffer = []
        @transmitting = false
        return