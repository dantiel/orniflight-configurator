###
    USB DFU uses:
    control transfers for communicating
    recipient is interface
    request type is class

    Descriptors seems to be broken in current chrome.usb API implementation (writing this while using canary 37.0.2040.0

    General rule to remember is that DFU doesn't like running specific operations while the device isn't in idle state
    that being said, it seems that certain level of CLRSTATUS is required before running another type of operation for
    example switching from DNLOAD to UPLOAD, etc, clearning the state so device is in dfuIDLE is highly recommended.
###

'use strict'

STM32DFU_protocol = ->
    @callback
    # ref
    @hex
    # ref
    @verify_hex
    @handle = null
    # connection handle
    @request =
        DETACH: 0x00
        DNLOAD: 0x01
        UPLOAD: 0x02
        GETSTATUS: 0x03
        CLRSTATUS: 0x04
        GETSTATE: 0x05
        ABORT: 0x06
    @status =
        OK: 0x00
        errTARGET: 0x01
        errFILE: 0x02
        errWRITE: 0x03
        errERASE: 0x04
        errCHECK_ERASED: 0x05
        errPROG: 0x06
        errVERIFY: 0x07
        errADDRESS: 0x08
        errNOTDONE: 0x09
        errFIRMWARE: 0x0A
        errVENDOR: 0x0B
        errUSBR: 0x0C
        errPOR: 0x0D
        errUNKNOWN: 0x0E
        errSTALLEDPKT: 0x0F
    @state =
        appIDLE: 0
        appDETACH: 1
        dfuIDLE: 2
        dfuDNLOAD_SYNC: 3
        dfuDNBUSY: 4
        dfuDNLOAD_IDLE: 5
        dfuMANIFEST_SYNC: 6
        dfuMANIFEST: 7
        dfuMANIFEST_WAIT_RESET: 8
        dfuUPLOAD_IDLE: 9
        dfuERROR: 10
    @chipInfo = null
    # information about chip's memory
    @flash_layout =
        'start_address': 0
        'total_size': 0
        'sectors': []
    @transferSize = 2048
    # Default USB DFU transfer size for F3,F4 and F7
    return

STM32DFU_protocol::connect = (device, hex, options, callback) ->
    self = this
    self.hex = hex
    self.callback = callback
    self.options = erase_chip: false
    if options.erase_chip
        self.options.erase_chip = true
    # reset and set some variables before we start
    self.upload_time_start = (new Date).getTime()
    self.verify_hex = []
    # reset progress bar to initial state
    TABS.firmware_flasher.flashingMessage(null, TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL).flashProgress 0
    chrome.usb.getDevices device, (result) ->
        if result.length
            console.log 'USB DFU detected with ID: ' + result[0].device
            self.openDevice result[0]
        else
            console.log 'USB DFU not found'
            GUI.log i18n.getMessage('stm32UsbDfuNotFound')
        return
    return

STM32DFU_protocol::checkChromeError = ->
    if chrome.runtime.lastError
        if chrome.runtime.lastError.message
            console.log 'reporting chrome error: ' + chrome.runtime.lastError.message
        else
            console.log 'reporting chrome error: ' + chrome.runtime.lastError
        return true
    false

STM32DFU_protocol::openDevice = (device) ->
    self = this
    chrome.usb.openDevice device, (handle) ->
        if self.checkChromeError()
            console.log 'Failed to open USB device!'
            GUI.log i18n.getMessage('usbDeviceOpenFail')
            if GUI.operating_system == 'Linux'
                GUI.log i18n.getMessage('usbDeviceUdevNotice')
            return
        self.handle = handle
        GUI.log i18n.getMessage('usbDeviceOpened', handle.handle.toString())
        console.log 'Device opened with Handle ID: ' + handle.handle
        self.claimInterface 0
        return
    return

STM32DFU_protocol::closeDevice = ->
    self = this
    chrome.usb.closeDevice @handle, ->
        if self.checkChromeError()
            console.log 'Failed to close USB device!'
            GUI.log i18n.getMessage('usbDeviceCloseFail')
        GUI.log i18n.getMessage('usbDeviceClosed')
        console.log 'Device closed with Handle ID: ' + self.handle.handle
        self.handle = null
        return
    return

STM32DFU_protocol::claimInterface = (interfaceNumber) ->
    self = this
    chrome.usb.claimInterface @handle, interfaceNumber, ->
        if self.checkChromeError()
            console.log 'Failed to claim USB device!'
            self.upload_procedure 99
        console.log 'Claimed interface: ' + interfaceNumber
        self.upload_procedure 0
        return
    return

STM32DFU_protocol::releaseInterface = (interfaceNumber) ->
    self = this
    chrome.usb.releaseInterface @handle, interfaceNumber, ->
        console.log 'Released interface: ' + interfaceNumber
        self.closeDevice()
        return
    return

STM32DFU_protocol::resetDevice = (callback) ->
    chrome.usb.resetDevice @handle, (result) ->
        console.log 'Reset Device: ' + result
        if callback
            callback()
        return
    return

STM32DFU_protocol::getString = (index, callback) ->
    self = this
    chrome.usb.controlTransfer self.handle, {
        'direction': 'in'
        'recipient': 'device'
        'requestType': 'standard'
        'request': 6
        'value': 0x300 | index
        'index': 0
        'length': 255
    }, (result) ->
        if self.checkChromeError()
            console.log 'USB getString failed! ' + result.resultCode
            callback '', result.resultCode
            return
        view = new DataView(result.data)
        length = view.getUint8(0)
        descriptor = ''
        i = 2
        while i < length
            charCode = view.getUint16(i, true)
            descriptor += String.fromCharCode(charCode)
            i += 2
        callback descriptor, result.resultCode
        return
    return

STM32DFU_protocol::getInterfaceDescriptors = (interfaceNum, callback) ->
    self = this
    chrome.usb.getConfiguration @handle, (config) ->
        if self.checkChromeError()
            console.log 'USB getConfiguration failed!'
            callback [], -200
            return
        interfaceID = 0
        descriptorStringArray = []

        _getDescriptorString = ->
            if interfaceID < config.interfaces.length
                self.getInterfaceDescriptor interfaceID, (descriptor, resultCode) ->
                    if resultCode
                        callback [], resultCode
                        return
                    interfaceID++
                    self.getString descriptor.iInterface, (descriptorString, resultCode) ->
                        if resultCode
                            callback [], resultCode
                            return
                        if descriptor.bInterfaceNumber == interfaceNum
                            descriptorStringArray.push descriptorString
                        _getDescriptorString()
                        return
                    return
            else
                #console.log(descriptorStringArray);
                callback descriptorStringArray, 0
                return
            return

        _getDescriptorString()
        return
    return

STM32DFU_protocol::getInterfaceDescriptor = (_interface, callback) ->
    self = this
    chrome.usb.controlTransfer @handle, {
        'direction': 'in'
        'recipient': 'device'
        'requestType': 'standard'
        'request': 6
        'value': 0x200
        'index': 0
        'length': 18 + _interface * 9
    }, (result) ->
        if self.checkChromeError()
            console.log 'USB getInterfaceDescriptor failed! ' + result.resultCode
            callback {}, result.resultCode
            return
        buf = new Uint8Array(result.data, 9 + _interface * 9)
        descriptor = 
            'bLength': buf[0]
            'bDescriptorType': buf[1]
            'bInterfaceNumber': buf[2]
            'bAlternateSetting': buf[3]
            'bNumEndpoints': buf[4]
            'bInterfaceClass': buf[5]
            'bInterfaceSubclass': buf[6]
            'bInterfaceProtocol': buf[7]
            'iInterface': buf[8]
        callback descriptor, result.resultCode
        return
    return

STM32DFU_protocol::getFunctionalDescriptor = (_interface, callback) ->
    self = this
    chrome.usb.controlTransfer @handle, {
        'direction': 'in'
        'recipient': 'interface'
        'requestType': 'standard'
        'request': 6
        'value': 0x2100
        'index': 0
        'length': 255
    }, (result) ->
        if self.checkChromeError()
            console.log 'USB getFunctionalDescriptor failed! ' + result.resultCode
            callback {}, result.resultCode
            return
        buf = new Uint8Array(result.data)
        descriptor = 
            'bLength': buf[0]
            'bDescriptorType': buf[1]
            'bmAttributes': buf[2]
            'wDetachTimeOut': buf[4] << 8 | buf[3]
            'wTransferSize': buf[6] << 8 | buf[5]
            'bcdDFUVersion': buf[7]
        callback descriptor, result.resultCode
        return
    return

STM32DFU_protocol::getChipInfo = (_interface, callback) ->
    self = this
    self.getInterfaceDescriptors 0, (descriptors, resultCode) ->
        if resultCode
            callback {}, resultCode
            return
        # Keep this for new MCU debugging
        # console.log('Descriptors: ' + descriptors);

        parseDescriptor = (str) ->
            # F303: "@Internal Flash  /0x08000000/128*0002Kg"
            # F40x: "@Internal Flash  /0x08000000/04*016Kg,01*064Kg,07*128Kg"
            # F72x: "@Internal Flash  /0x08000000/04*016Kg,01*64Kg,03*128Kg"
            # F74x: "@Internal Flash  /0x08000000/04*032Kg,01*128Kg,03*256Kg"
            # H750 SPRacing H7 EXST: "@External Flash /0x90000000/998*128Kg,1*128Kg,4*128Kg,21*128Ka"
            # H750 SPRacing H7 EXST: "@External Flash /0x90000000/1001*128Kg,3*128Kg,20*128Ka" - Early BL firmware with incorrect string, treat as above.
            # H750 Partitions: Flash, Config, Firmware, 1x BB Management block + x BB Replacement blocks)
            if str == '@External Flash /0x90000000/1001*128Kg,3*128Kg,20*128Ka'
                str = '@External Flash /0x90000000/998*128Kg,1*128Kg,4*128Kg,21*128Ka'
            # split main into [location, start_addr, sectors]
            tmp0 = str.replace(/[^\x20-\x7E]+/g, '')
            tmp1 = tmp0.split('/')
            # G474 (and may be other G4 variants) returns
            # "@Option Bytes   /0x1FFF7800/01*048 e/0x1FFFF800/01*048 e"
            # for two banks of options bytes which may be fine in terms of descriptor syntax,
            # but as this splits into an array of size 5 instead of 3, it induces an length error.
            # Here, we blindly trim the array length to 3. While doing so may fail to
            # capture errornous patterns, but it is good to avoid this known and immediate
            # error.
            # May need to preserve the second bank if the configurator starts to really
            # support option bytes.
            if tmp1.length > 3
                console.log 'parseDescriptor: shrinking long descriptor "' + str + '"'
                tmp1.length = 3
            if !tmp1[0].startsWith('@')
                return null
            type = tmp1[0].trim().replace('@', '')
            start_address = parseInt(tmp1[1])
            # split sectors into array
            sectors = []
            total_size = 0
            tmp2 = tmp1[2].split(',')
            if tmp2.length < 1
                return null
            i = 0
            while i < tmp2.length
                # split into [num_pages, page_size]
                tmp3 = tmp2[i].split('*')
                if tmp3.length != 2
                    return null
                num_pages = parseInt(tmp3[0])
                page_size = parseInt(tmp3[1])
                if !page_size
                    return null
                unit = tmp3[1].slice(-2, -1)
                switch unit
                    when 'M'
                        page_size *= 1024 * 1024
                    when 'K'
                        page_size *= 1024

                sectors.push
                    'num_pages': num_pages
                    'start_address': start_address + total_size
                    'page_size': page_size
                    'total_size': num_pages * page_size
                total_size += num_pages * page_size
                i++
            memory = 
                'type': type
                'start_address': start_address
                'sectors': sectors
                'total_size': total_size
            memory

        chipInfo = descriptors.map(parseDescriptor).reduce(((o, v, i) ->
            o[v.type.toLowerCase().replace(' ', '_')] = v
            o
        ), {})
        callback chipInfo, resultCode
        return
    return

STM32DFU_protocol::controlTransfer = (direction, request, value, _interface, length, data, callback, _timeout) ->
    `var arrayBuf`
    self = this
    # timeout support was added in chrome v43
    timeout = undefined
    if typeof _timeout == 'undefined'
        timeout = 0
        # default is 0 (according to chrome.usb API)
    else
        timeout = _timeout
    if direction == 'in'
        # data is ignored
        chrome.usb.controlTransfer @handle, {
            'direction': 'in'
            'recipient': 'interface'
            'requestType': 'class'
            'request': request
            'value': value
            'index': _interface
            'length': length
            'timeout': timeout
        }, (result) ->
            if self.checkChromeError()
                console.log 'USB controlTransfer IN failed for request ' + request + '!'
            if result.resultCode
                console.log 'USB transfer result code: ' + result.resultCode
            buf = new Uint8Array(result.data)
            callback buf, result.resultCode
            return
    else
        # length is ignored
        if data
            arrayBuf = new ArrayBuffer(data.length)
            arrayBufView = new Uint8Array(arrayBuf)
            arrayBufView.set data
        else
            arrayBuf = new ArrayBuffer(0)
        chrome.usb.controlTransfer @handle, {
            'direction': 'out'
            'recipient': 'interface'
            'requestType': 'class'
            'request': request
            'value': value
            'index': _interface
            'data': arrayBuf
            'timeout': timeout
        }, (result) ->
            if self.checkChromeError()
                console.log 'USB controlTransfer OUT failed for request ' + request + '!'
            if result.resultCode
                console.log 'USB transfer result code: ' + result.resultCode
            callback result
            return
    return

# routine calling DFU_CLRSTATUS until device is in dfuIDLE state

STM32DFU_protocol::clearStatus = (callback) ->
    self = this

    check_status = ->
        self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
            if data[4] == self.state.dfuIDLE
                callback data
            else
                delay = data[1] | data[2] << 8 | data[3] << 16
                setTimeout clear_status, delay
            return
        return

    clear_status = ->
        self.controlTransfer 'out', self.request.CLRSTATUS, 0, 0, 0, 0, check_status
        return

    check_status()
    return

STM32DFU_protocol::loadAddress = (address, callback, abort) ->
    self = this
    self.controlTransfer 'out', self.request.DNLOAD, 0, 0, 0, [
        0x21
        address & 0xff
        address >> 8 & 0xff
        address >> 16 & 0xff
        address >> 24 & 0xff
    ], ->
        self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
            if data[4] == self.state.dfuDNBUSY
                delay = data[1] | data[2] << 8 | data[3] << 16
                setTimeout (->
                    self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                        if data[4] == self.state.dfuDNLOAD_IDLE
                            callback data
                        else
                            console.log 'Failed to execute address load'
                            if typeof abort == 'undefined' or abort
                                self.upload_procedure 99
                            else
                                callback data
                        return
                    return
                ), delay
            else
                console.log 'Failed to request address load'
                self.upload_procedure 99
            return
        return
    return

# first_array = usually hex_to_flash array
# second_array = usually verify_hex array
# result = true/false

STM32DFU_protocol::verify_flash = (first_array, second_array) ->
    i = 0
    while i < first_array.length
        if first_array[i] != second_array[i]
            console.log 'Verification failed on byte: ' + i + ' expected: 0x' + first_array[i].toString(16) + ' received: 0x' + second_array[i].toString(16)
            return false
        i++
    console.log 'Verification successful, matching: ' + first_array.length + ' bytes'
    true

STM32DFU_protocol::upload_procedure = (step) ->
    `var blocks`
    `var address`
    `var wBlockNum`
    `var i`
    `var address`
    self = this
    switch step
        when 0
            self.getChipInfo 0, (chipInfo, resultCode) ->
                if resultCode != 0 or typeof chipInfo == 'undefined'
                    console.log 'Failed to detect chip info, resultCode: ' + resultCode
                    self.upload_procedure 99
                else
                    if typeof chipInfo.internal_flash != 'undefined'
                        # internal flash
                        self.chipInfo = chipInfo
                        self.flash_layout = chipInfo.internal_flash
                        self.available_flash_size = self.flash_layout.total_size - (self.hex.start_linear_address - (self.flash_layout.start_address))
                        GUI.log i18n.getMessage('dfu_device_flash_info', (self.flash_layout.total_size / 1024).toString())
                        if self.hex.bytes_total > self.available_flash_size
                            GUI.log i18n.getMessage('dfu_error_image_size', [
                                (self.hex.bytes_total / 1024.0).toFixed(1)
                                (self.available_flash_size / 1024.0).toFixed(1)
                            ])
                            self.upload_procedure 99
                        else
                            self.getFunctionalDescriptor 0, (descriptor, resultCode) ->
                                self.transferSize = if resultCode then 2048 else descriptor.wTransferSize
                                console.log 'Using transfer size: ' + self.transferSize
                                self.clearStatus ->
                                    self.upload_procedure 1
                                    return
                                return
                    else if typeof chipInfo.external_flash != 'undefined'
                        # external flash, flash to the 3rd partition.
                        self.chipInfo = chipInfo
                        self.flash_layout = chipInfo.external_flash
                        firmware_partition_index = 2
                        firmware_sectors = self.flash_layout.sectors[firmware_partition_index]
                        firmware_partition_size = firmware_sectors.total_size
                        self.available_flash_size = firmware_partition_size
                        GUI.log i18n.getMessage('dfu_device_flash_info', (self.flash_layout.total_size / 1024).toString())
                        if self.hex.bytes_total > self.available_flash_size
                            GUI.log i18n.getMessage('dfu_error_image_size', [
                                (self.hex.bytes_total / 1024.0).toFixed(1)
                                (self.available_flash_size / 1024.0).toFixed(1)
                            ])
                            self.upload_procedure 99
                        else
                            self.getFunctionalDescriptor 0, (descriptor, resultCode) ->
                                self.transferSize = if resultCode then 2048 else descriptor.wTransferSize
                                console.log 'Using transfer size: ' + self.transferSize
                                self.clearStatus ->
                                    self.upload_procedure 2
                                    # no option bytes to deal with
                                    return
                                return
                    else
                        console.log 'Failed to detect internal or external flash'
                        self.upload_procedure 99
                return
        when 1
            if typeof self.chipInfo.option_bytes == 'undefined'
                console.log 'Failed to detect option bytes'
                self.upload_procedure 99

            unprotect = ->
                console.log 'Initiate read unprotect'
                messageReadProtected = i18n.getMessage('stm32ReadProtected')
                GUI.log messageReadProtected
                TABS.firmware_flasher.flashingMessage messageReadProtected, TABS.firmware_flasher.FLASH_MESSAGE_TYPES.ACTION
                self.controlTransfer 'out', self.request.DNLOAD, 0, 0, 0, [ 0x92 ], ->
                    # 0x92 initiates read unprotect
                    self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                        if data[4] == self.state.dfuDNBUSY
                            # completely normal
                            delay = data[1] | data[2] << 8 | data[3] << 16
                            total_delay = delay + 20000
                            # wait at least 20 seconds to make sure the user does not disconnect the board while erasing the memory
                            timeSpentWaiting = 0
                            incr = 1000
                            # one sec increments
                            waitForErase = setInterval((->
                                TABS.firmware_flasher.flashProgress Math.min(timeSpentWaiting / total_delay, 1) * 100
                                if timeSpentWaiting < total_delay
                                    timeSpentWaiting += incr
                                    return
                                clearInterval waitForErase
                                self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, ((data, error) ->
                                    # should stall/disconnect
                                    if error
                                        # we encounter an error, but this is expected. should be a stall.
                                        console.log 'Unprotect memory command ran successfully. Unplug flight controller. Connect again in DFU mode and try flashing again.'
                                        GUI.log i18n.getMessage('stm32UnprotectSuccessful')
                                        messageUnprotectUnplug = i18n.getMessage('stm32UnprotectUnplug')
                                        GUI.log messageUnprotectUnplug
                                        TABS.firmware_flasher.flashingMessage(messageUnprotectUnplug, TABS.firmware_flasher.FLASH_MESSAGE_TYPES.ACTION).flashProgress 0
                                    else
                                        # unprotecting the flight controller did not work. It did not reboot.
                                        console.log 'Failed to execute unprotect memory command'
                                        GUI.log i18n.getMessage('stm32UnprotectFailed')
                                        TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32UnprotectFailed'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
                                        console.log data
                                        self.upload_procedure 99
                                    return
                                ), 2000
                                # this should stall/disconnect anyways. so we only wait 2 sec max.
                                return
                            ), incr)
                        else
                            console.log 'Failed to initiate unprotect memory command'
                            messageUnprotectInitFailed = i18n.getMessage('stm32UnprotectInitFailed')
                            GUI.log messageUnprotectInitFailed
                            TABS.firmware_flasher.flashingMessage messageUnprotectInitFailed, TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
                            self.upload_procedure 99
                        return
                    return
                return

            tryReadOB = ->
                # the following should fail if read protection is active
                self.controlTransfer 'in', self.request.UPLOAD, 2, 0, self.chipInfo.option_bytes.total_size, 0, (ob_data, errcode) ->
                    if errcode
                        console.log 'USB transfer error while reading option bytes: ' + errcode1
                        self.upload_procedure 99
                        return
                    self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                        if data[4] == self.state.dfuUPLOAD_IDLE and ob_data.length == self.chipInfo.option_bytes.total_size
                            console.log 'Option bytes read successfully'
                            console.log 'Chip does not appear read protected'
                            GUI.log i18n.getMessage('stm32NotReadProtected')
                            # it is pretty safe to continue to erase flash
                            self.clearStatus ->
                                self.upload_procedure 2
                                return

                            ### // this snippet is to protect the flash memory (only for the brave)
                            ob_data[1] = 0x0;
                            var writeOB = function() {
                            	self.controlTransfer('out', self.request.DNLOAD, 2, 0, 0, ob_data, function () {
                            		self.controlTransfer('in', self.request.GETSTATUS, 0, 0, 6, 0, function (data) {
                            		    if (data[4] == self.state.dfuDNBUSY) {
                            			var delay = data[1] | (data[2] << 8) | (data[3] << 16);
                            				setTimeout(function () {
                            			    self.controlTransfer('in', self.request.GETSTATUS, 0, 0, 6, 0, function (data) {
                            				if (data[4] == self.state.dfuDNLOAD_IDLE) {
                            				    console.log('Failed to write ob');
                            				    self.upload_procedure(99);								    
                            				} else {
                            				    console.log('Success writing ob');
                            				    self.upload_procedure(99);
                            				}
                            			    });
                            			}, delay);
                            		    } else {
                            			console.log('Failed to initiate write ob');
                            			self.upload_procedure(99);
                            		    }
                            		});
                            	});
                            }
                            self.clearStatus(function () {
                            	self.loadAddress(self.chipInfo.option_bytes.start_address, function () {
                            	    self.clearStatus(writeOB);
                            	});
                            }); // 
                            ###

                        else
                            console.log 'Option bytes could not be read. Quite possibly read protected.'
                            self.clearStatus unprotect
                        return
                    return
                return

            initReadOB = (loadAddressResponse) ->
                # contrary to what is in the docs. Address load should in theory work even if read protection is active
                # if address load fails with this specific error though, it is very likely bc of read protection
                if loadAddressResponse[4] == self.state.dfuERROR and loadAddressResponse[0] == self.status.errVENDOR
                    # read protected
                    GUI.log i18n.getMessage('stm32AddressLoadFailed')
                    self.clearStatus unprotect
                    return
                else if loadAddressResponse[4] == self.state.dfuDNLOAD_IDLE
                    console.log 'Address load for option bytes sector succeeded.'
                    self.clearStatus tryReadOB
                else
                    GUI.log i18n.getMessage('stm32AddressLoadUnknown')
                    self.upload_procedure 99
                return

            self.clearStatus ->
                # load address fails if read protection is active unlike as stated in the docs
                self.loadAddress self.chipInfo.option_bytes.start_address, initReadOB, false
                return
        when 2
            # erase
            # find out which pages to erase
            erase_pages = []
            i = 0
            while i < self.flash_layout.sectors.length
                j = 0
                while j < self.flash_layout.sectors[i].num_pages
                    if self.options.erase_chip
                        # full chip erase
                        erase_pages.push
                            'sector': i
                            'page': j
                    else
                        # local erase
                        page_start = self.flash_layout.sectors[i].start_address + j * self.flash_layout.sectors[i].page_size
                        page_end = page_start + self.flash_layout.sectors[i].page_size - 1
                        k = 0
                        while k < self.hex.data.length
                            starts_in_page = self.hex.data[k].address >= page_start and self.hex.data[k].address <= page_end
                            end_address = self.hex.data[k].address + self.hex.data[k].bytes - 1
                            ends_in_page = end_address >= page_start and end_address <= page_end
                            spans_page = self.hex.data[k].address < page_start and end_address > page_end
                            if starts_in_page or ends_in_page or spans_page
                                idx = erase_pages.findIndex((element, index, array) ->
                                    element.sector == i and element.page == j
                                )
                                if idx == -1
                                    erase_pages.push
                                        'sector': i
                                        'page': j
                            k++
                    j++
                i++
            if erase_pages.length == 0
                console.log 'Aborting, No flash pages to erase'
                TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32InvalidHex'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
                self.upload_procedure 99
                break
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32Erase'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
            console.log 'Executing local chip erase', erase_pages
            page = 0
            total_erased = 0
            # bytes

            _erase_page = ->
                page_addr = erase_pages[page].page * self.flash_layout.sectors[erase_pages[page].sector].page_size + self.flash_layout.sectors[erase_pages[page].sector].start_address
                cmd = [
                    0x41
                    page_addr & 0xff
                    page_addr >> 8 & 0xff
                    page_addr >> 16 & 0xff
                    page_addr >> 24 & 0xff
                ]
                total_erased += self.flash_layout.sectors[erase_pages[page].sector].page_size
                console.log 'Erasing. sector ' + erase_pages[page].sector + ', page ' + erase_pages[page].page + ' @ 0x' + page_addr.toString(16)
                self.controlTransfer 'out', self.request.DNLOAD, 0, 0, 0, cmd, ->
                    self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                        if data[4] == self.state.dfuDNBUSY
                            # completely normal
                            delay = data[1] | data[2] << 8 | data[3] << 16
                            setTimeout (->
                                self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                                    if data[4] == self.state.dfuDNLOAD_IDLE
                                        # update progress bar
                                        TABS.firmware_flasher.flashProgress (page + 1) / erase_pages.length * 100
                                        page++
                                        if page == erase_pages.length
                                            console.log 'Erase: complete'
                                            GUI.log i18n.getMessage('dfu_erased_kilobytes', (total_erased / 1024).toString())
                                            self.upload_procedure 4
                                        else
                                            _erase_page()
                                    else
                                        console.log 'Failed to erase page 0x' + page_addr.toString(16)
                                        self.upload_procedure 99
                                    return
                                return
                            ), delay
                        else
                            console.log 'Failed to initiate page erase, page 0x' + page_addr.toString(16)
                            self.upload_procedure 99
                        return
                    return
                return

            # start
            _erase_page()
        when 4
            # upload
            # we dont need to clear the state as we are already using DFU_DNLOAD
            console.log 'Writing data ...'
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32Flashing'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
            blocks = self.hex.data.length - 1
            flashing_block = 0
            address = self.hex.data[flashing_block].address
            bytes_flashed = 0
            bytes_flashed_total = 0
            # used for progress bar
            wBlockNum = 2
            # required by DFU

            _write = ->
                if bytes_flashed < self.hex.data[flashing_block].bytes
                    bytes_to_write = if bytes_flashed + self.transferSize <= self.hex.data[flashing_block].bytes then self.transferSize else self.hex.data[flashing_block].bytes - bytes_flashed
                    data_to_flash = self.hex.data[flashing_block].data.slice(bytes_flashed, bytes_flashed + bytes_to_write)
                    address += bytes_to_write
                    bytes_flashed += bytes_to_write
                    bytes_flashed_total += bytes_to_write
                    self.controlTransfer 'out', self.request.DNLOAD, wBlockNum++, 0, 0, data_to_flash, ->
                        self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                            if data[4] == self.state.dfuDNBUSY
                                delay = data[1] | data[2] << 8 | data[3] << 16
                                setTimeout (->
                                    self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                                        if data[4] == self.state.dfuDNLOAD_IDLE
                                            # update progress bar
                                            TABS.firmware_flasher.flashProgress bytes_flashed_total / (self.hex.bytes_total * 2) * 100
                                            # flash another page
                                            _write()
                                        else
                                            console.log 'Failed to write ' + bytes_to_write + 'bytes to 0x' + address.toString(16)
                                            self.upload_procedure 99
                                        return
                                    return
                                ), delay
                            else
                                console.log 'Failed to initiate write ' + bytes_to_write + 'bytes to 0x' + address.toString(16)
                                self.upload_procedure 99
                            return
                        return
                else
                    if flashing_block < blocks
                        # move to another block
                        flashing_block++
                        address = self.hex.data[flashing_block].address
                        bytes_flashed = 0
                        wBlockNum = 2
                        self.loadAddress address, _write
                    else
                        # all blocks flashed
                        console.log 'Writing: done'
                        # proceed to next step
                        self.upload_procedure 5
                return

            # start
            self.loadAddress address, _write
        when 5
            # verify
            console.log 'Verifying data ...'
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32Verifying'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
            blocks = self.hex.data.length - 1
            reading_block = 0
            address = self.hex.data[reading_block].address
            bytes_verified = 0
            bytes_verified_total = 0
            # used for progress bar
            wBlockNum = 2
            # required by DFU
            # initialize arrays
            i = 0
            while i <= blocks
                self.verify_hex.push []
                i++
            # start
            self.clearStatus ->
                self.loadAddress address, ->
                    self.clearStatus _read
                    return
                return

            _read = ->
                `var i`
                if bytes_verified < self.hex.data[reading_block].bytes
                    bytes_to_read = if bytes_verified + self.transferSize <= self.hex.data[reading_block].bytes then self.transferSize else self.hex.data[reading_block].bytes - bytes_verified
                    self.controlTransfer 'in', self.request.UPLOAD, wBlockNum++, 0, bytes_to_read, 0, (data, code) ->
                        `var i`
                        i = 0
                        while i < data.length
                            self.verify_hex[reading_block].push data[i]
                            i++
                        address += bytes_to_read
                        bytes_verified += bytes_to_read
                        bytes_verified_total += bytes_to_read
                        # update progress bar
                        TABS.firmware_flasher.flashProgress (self.hex.bytes_total + bytes_verified_total) / (self.hex.bytes_total * 2) * 100
                        # verify another page
                        _read()
                        return
                else
                    if reading_block < blocks
                        # move to another block
                        reading_block++
                        address = self.hex.data[reading_block].address
                        bytes_verified = 0
                        wBlockNum = 2
                        self.clearStatus ->
                            self.loadAddress address, ->
                                self.clearStatus _read
                                return
                            return
                    else
                        # all blocks read, verify
                        verify = true
                        i = 0
                        while i <= blocks
                            verify = self.verify_flash(self.hex.data[i].data, self.verify_hex[i])
                            if !verify
                                break
                            i++
                        if verify
                            console.log 'Programming: SUCCESSFUL'
                            # update progress bar
                            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32ProgrammingSuccessful'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.VALID
                            # proceed to next step
                            self.upload_procedure 6
                        else
                            console.log 'Programming: FAILED'
                            # update progress bar
                            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32ProgrammingFailed'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
                            # disconnect
                            self.upload_procedure 99
                return

        when 6
            # jump to application code
            address = self.hex.data[0].address
            self.clearStatus ->
                self.loadAddress address, leave
                return

            leave = ->
                self.controlTransfer 'out', self.request.DNLOAD, 0, 0, 0, 0, ->
                    self.controlTransfer 'in', self.request.GETSTATUS, 0, 0, 6, 0, (data) ->
                        self.upload_procedure 99
                        return
                    return
                return

        when 99
            # cleanup
            self.releaseInterface 0
            GUI.connect_lock = false
            timeSpent = (new Date).getTime() - (self.upload_time_start)
            console.log 'Script finished after: ' + timeSpent / 1000 + ' seconds'
            if self.callback
                self.callback()
    return

# initialize object
STM32DFU = new STM32DFU_protocol