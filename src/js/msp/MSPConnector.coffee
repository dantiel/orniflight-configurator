'use strict'

MSPConnectorImpl = ->
    @baud = undefined
    @port = undefined
    @onConnectCallback = undefined
    @onTimeoutCallback = undefined
    @onDisconnectCallback = undefined
    return

MSPConnectorImpl::connect = (port, baud, onConnectCallback, onTimeoutCallback, onFailureCallback) ->
    self = this
    self.port = port
    self.baud = baud
    self.onConnectCallback = onConnectCallback
    self.onTimeoutCallback = onTimeoutCallback
    self.onFailureCallback = onFailureCallback
    serial.connect self.port, { bitrate: self.baud }, (openInfo) ->
        if openInfo

            disconnectAndCleanup = ->
                serial.disconnect (result) ->
                    console.log 'Disconnected'
                    MSP.clearListeners()
                    self.onTimeoutCallback()
                    return
                MSP.disconnect_cleanup()
                return

            FC.resetState()
            # disconnect after 10 seconds with error if we don't get IDENT data
            GUI.timeout_add 'msp_connector', (->
                if !CONFIGURATOR.connectionValid
                    GUI.log i18n.getMessage('noConfigurationReceived')
                    disconnectAndCleanup()
                return
            ), 10000
            serial.onReceive.addListener read_serial
            MSP.listen update_packet_error
            mspHelper = new MspHelper
            MSP.listen mspHelper.process_data.bind(mspHelper)
            MSP.send_message MSPCodes.MSP_API_VERSION, false, false, ->
                CONFIGURATOR.connectionValid = true
                GUI.timeout_remove 'msp_connector'
                console.log 'Connected'
                self.onConnectCallback()
                return
        else
            GUI.log i18n.getMessage('serialPortOpenFail')
            self.onFailureCallback()
        return
    return

MSPConnectorImpl::disconnect = (onDisconnectCallback) ->
    self.onDisconnectCallback = onDisconnectCallback
    serial.disconnect (result) ->
        MSP.clearListeners()
        console.log 'Disconnected'
        self.onDisconnectCallback result
        return
    MSP.disconnect_cleanup()
    return

