'use strict'
PortUsage = 
    previous_received: 0
    previous_sent: 0
    initialize: ->
        self = this
        self.main_timer_reference = setInterval((->
            self.update()
            return
        ), 1000)
        return
    update: ->
        if serial.bitrate
            port_usage_down = parseInt((serial.bytesReceived - (@previous_received)) * 10 / serial.bitrate * 100)
            port_usage_up = parseInt((serial.bytesSent - (@previous_sent)) * 10 / serial.bitrate * 100)
            @previous_received = serial.bytesReceived
            @previous_sent = serial.bytesSent
            # update UI
            $('span.port_usage_down').text i18n.getMessage('statusbar_usage_download', [ port_usage_down ])
            $('span.port_usage_up').text i18n.getMessage('statusbar_usage_upload', [ port_usage_up ])
        else
            $('span.port_usage_down').text i18n.getMessage('statusbar_usage_download', [ 0 ])
            $('span.port_usage_up').text i18n.getMessage('statusbar_usage_upload', [ 0 ])
        return
    reset: ->
        @previous_received = 0
        @previous_sent = 0
        return

