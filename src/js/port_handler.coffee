'use strict'
TIMEOUT_CHECK = 500
# With 250 it seems that it produces a memory leak and slowdown in some versions, reason unknown
usbDevices = filters: [
    {
        'vendorId': 1155
        'productId': 57105
    }
    {
        'vendorId': 10473
        'productId': 393
    }
]
PortHandler = new (->
    @initial_ports = false
    @port_detected_callbacks = []
    @port_removed_callbacks = []
    @dfu_available = false
    return
)

PortHandler.initialize = ->
    # start listening, check after TIMEOUT_CHECK ms
    @check()
    return

PortHandler.check = ->
    self = this
    serial.getDevices (current_ports) ->
        `var i`
        `var i`
        `var i`
        `var obj`
        `var index`
        # port got removed or initial_ports wasn't initialized yet
        if self.array_difference(self.initial_ports, current_ports).length > 0 or !self.initial_ports
            removed_ports = self.array_difference(self.initial_ports, current_ports)
            if self.initial_ports != false
                if removed_ports.length > 1
                    console.log 'PortHandler - Removed: ' + removed_ports
                else
                    console.log 'PortHandler - Removed: ' + removed_ports[0]
            # disconnect "UI" if necessary
            # Keep in mind that this routine can not fire during atmega32u4 reboot procedure !!!
            if GUI.connected_to
                i = 0
                while i < removed_ports.length
                    if removed_ports[i] == GUI.connected_to
                        $('div#port-picker a.connect').click()
                    i++
            self.update_port_select current_ports
            # trigger callbacks (only after initialization)
            if self.initial_ports
                i = self.port_removed_callbacks.length - 1
                while i >= 0
                    obj = self.port_removed_callbacks[i]
                    # remove timeout
                    clearTimeout obj.timer
                    # trigger callback
                    obj.code removed_ports
                    # remove object from array
                    index = self.port_removed_callbacks.indexOf(obj)
                    if index > -1
                        self.port_removed_callbacks.splice index, 1
                    i--
            # auto-select last used port (only during initialization)
            if !self.initial_ports
                ConfigStorage.get 'last_used_port', (result) ->
                    # if last_used_port was set, we try to select it
                    if result.last_used_port
                        current_ports.forEach (port) ->
                            if port == result.last_used_port
                                console.log 'Selecting last used port: ' + result.last_used_port
                                $('div#port-picker #port').val result.last_used_port
                            return
                    else
                        console.log 'Last used port wasn\'t saved "yet", auto-select disabled.'
                    return
            if !self.initial_ports
                # initialize
                self.initial_ports = current_ports
            else
                i = 0
                while i < removed_ports.length
                    self.initial_ports.splice self.initial_ports.indexOf(removed_ports[i]), 1
                    i++
        # new port detected
        new_ports = self.array_difference(current_ports, self.initial_ports)
        if new_ports.length
            if new_ports.length > 1
                console.log 'PortHandler - Found: ' + new_ports
            else
                console.log 'PortHandler - Found: ' + new_ports[0]
            self.update_port_select current_ports
            # select / highlight new port, if connected -> select connected port
            if !GUI.connected_to
                $('div#port-picker #port').val new_ports[0]
            else
                $('div#port-picker #port').val GUI.connected_to
            # start connect procedure (if statement is valid)
            if GUI.auto_connect and !GUI.connecting_to and !GUI.connected_to
                # we need firmware flasher protection over here
                if GUI.active_tab != 'firmware_flasher'
                    GUI.timeout_add 'auto-connect_timeout', (->
                        $('div#port-picker a.connect').click()
                        return
                    ), 100
                    # timeout so bus have time to initialize after being detected by the system
            # trigger callbacks
            i = self.port_detected_callbacks.length - 1
            while i >= 0
                obj = self.port_detected_callbacks[i]
                # remove timeout
                clearTimeout obj.timer
                # trigger callback
                obj.code new_ports
                # remove object from array
                index = self.port_detected_callbacks.indexOf(obj)
                if index > -1
                    self.port_detected_callbacks.splice index, 1
                i--
            self.initial_ports = current_ports
        self.check_usb_devices()
        GUI.updateManualPortVisibility()
        setTimeout (->
            self.check()
            return
        ), TIMEOUT_CHECK
        return
    return

PortHandler.check_usb_devices = (callback) ->
    chrome.usb.getDevices usbDevices, (result) ->
        if result.length
            if !$('div#port-picker #port [value=\'DFU\']').length
                $('div#port-picker #port').append $('<option/>',
                    value: 'DFU'
                    text: 'DFU'
                    data: isDFU: true)
                $('div#port-picker #port').val 'DFU'
            self.dfu_available = true
        else
            if $('div#port-picker #port [value=\'DFU\']').length
                $('div#port-picker #port [value=\'DFU\']').remove()
            self.dfu_available = false
        if callback
            callback self.dfu_available
        return
    return

PortHandler.update_port_select = (ports) ->
    $('div#port-picker #port').html ''
    # drop previous one
    i = 0
    while i < ports.length
        $('div#port-picker #port').append $('<option/>',
            value: ports[i]
            text: ports[i]
            data: isManual: false)
        i++
    $('div#port-picker #port').append $('<option/>',
        value: 'manual'
        i18n: 'portsSelectManual'
        data: isManual: true)
    i18n.localizePage()
    return

PortHandler.port_detected = (name, code, timeout, ignore_timeout) ->
    self = this
    obj = 
        'name': name
        'code': code
        'timeout': if timeout then timeout else 10000
    if !ignore_timeout
        obj.timer = setTimeout((->
            console.log 'PortHandler - timeout - ' + obj.name
            # trigger callback
            code false
            # remove object from array
            index = self.port_detected_callbacks.indexOf(obj)
            if index > -1
                self.port_detected_callbacks.splice index, 1
            return
        ), if timeout then timeout else 10000)
    else
        obj.timer = false
        obj.timeout = false
    @port_detected_callbacks.push obj
    obj

PortHandler.port_removed = (name, code, timeout, ignore_timeout) ->
    self = this
    obj = 
        'name': name
        'code': code
        'timeout': if timeout then timeout else 10000
    if !ignore_timeout
        obj.timer = setTimeout((->
            console.log 'PortHandler - timeout - ' + obj.name
            # trigger callback
            code false
            # remove object from array
            index = self.port_removed_callbacks.indexOf(obj)
            if index > -1
                self.port_removed_callbacks.splice index, 1
            return
        ), if timeout then timeout else 10000)
    else
        obj.timer = false
        obj.timeout = false
    @port_removed_callbacks.push obj
    obj

# accepting single level array with "value" as key

PortHandler.array_difference = (firstArray, secondArray) ->
    `var i`
    cloneArray = []
    # create hardcopy
    i = 0
    while i < firstArray.length
        cloneArray.push firstArray[i]
        i++
    i = 0
    while i < secondArray.length
        if cloneArray.indexOf(secondArray[i]) != -1
            cloneArray.splice cloneArray.indexOf(secondArray[i]), 1
        i++
    cloneArray

PortHandler.flush_callbacks = ->
    `var i`
    killed = 0
    i = @port_detected_callbacks.length - 1
    while i >= 0
        if @port_detected_callbacks[i].timer
            clearTimeout @port_detected_callbacks[i].timer
        @port_detected_callbacks.splice i, 1
        killed++
        i--
    i = @port_removed_callbacks.length - 1
    while i >= 0
        if @port_removed_callbacks[i].timer
            clearTimeout @port_removed_callbacks[i].timer
        @port_removed_callbacks.splice i, 1
        killed++
        i--
    killed

