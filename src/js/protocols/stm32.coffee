###
    STM32 F103 serial bus seems to properly initialize with quite a huge auto-baud range
    From 921600 down to 1200, i don't recommend getting any lower then that
    Official "specs" are from 115200 to 1200

    popular choices - 921600, 460800, 256000, 230400, 153600, 128000, 115200, 57600, 38400, 28800, 19200
###

'use strict'

STM32_protocol = ->
    @baud
    @options = {}
    @callback
    # ref
    @hex
    # ref
    @verify_hex
    @receive_buffer
    @bytes_to_read = 0
    # ref
    @read_callback
    # ref
    @upload_time_start
    @upload_process_alive
    @msp_connector = new MSPConnectorImpl
    @status =
        ACK: 0x79
        NACK: 0x1F
    @command =
        get: 0x00
        get_ver_r_protect_s: 0x01
        get_ID: 0x02
        read_memory: 0x11
        go: 0x21
        write_memory: 0x31
        erase: 0x43
        extended_erase: 0x44
        write_protect: 0x63
        write_unprotect: 0x73
        readout_protect: 0x82
        readout_unprotect: 0x92
    # Erase (x043) and Extended Erase (0x44) are exclusive. A device may support either the Erase command or the Extended Erase command but not both.
    @available_flash_size = 0
    @page_size = 0
    @useExtendedErase = false
    return

# no input parameters

STM32_protocol::connect = (port, baud, hex, options, callback) ->
    self = this
    self.hex = hex
    self.port = port
    self.baud = baud
    self.callback = callback
    # we will crunch the options here since doing it inside initialization routine would be too late
    self.options =
        no_reboot: false
        reboot_baud: false
        erase_chip: false
    if options.no_reboot
        self.options.no_reboot = true
    else
        self.options.reboot_baud = options.reboot_baud
    if options.erase_chip
        self.options.erase_chip = true
    if self.options.no_reboot
        serial.connect port, {
            bitrate: self.baud
            parityBit: 'even'
            stopBits: 'one'
        }, (openInfo) ->
            if openInfo
                # we are connected, disabling connect button in the UI
                GUI.connect_lock = true
                self.initialize()
            else
                GUI.log i18n.getMessage('serialPortOpenFail')
            return
    else

        startFlashing = ->
            # refresh device list
            PortHandler.check_usb_devices (dfu_available) ->
                if dfu_available
                    STM32DFU.connect usbDevices, hex, options
                else
                    serial.connect self.port, {
                        bitrate: self.baud
                        parityBit: 'even'
                        stopBits: 'one'
                    }, (openInfo) ->
                        if openInfo
                            self.initialize()
                        else
                            GUI.connect_lock = false
                            GUI.log i18n.getMessage('serialPortOpenFail')
                        return
                return
            return

        legacyRebootAndFlash = ->
            serial.connect self.port, { bitrate: self.options.reboot_baud }, (openInfo) ->
                if !openInfo
                    GUI.connect_lock = false
                    GUI.log i18n.getMessage('serialPortOpenFail')
                    return
                console.log 'Using legacy reboot method'
                console.log 'Sending ascii "R" to reboot'
                bufferOut = new ArrayBuffer(1)
                bufferView = new Uint8Array(bufferOut)
                bufferView[0] = 0x52
                serial.send bufferOut, ->
                    serial.disconnect (disconnectionResult) ->
                        if disconnectionResult
                            # delay to allow board to boot in bootloader mode
                            # required to detect if a DFU device appears
                            setTimeout startFlashing, 1000
                        else
                            GUI.connect_lock = false
                        return
                    return
                return
            return

        onConnectHandler = ->
            GUI.log i18n.getMessage('apiVersionReceived', [ CONFIG.apiVersion ])
            if semver.lt(CONFIG.apiVersion, '1.42.0')
                self.msp_connector.disconnect (disconnectionResult) ->
                    # need some time for the port to be closed, serial port does not open if tried immediately
                    setTimeout legacyRebootAndFlash, 500
                    return
            else
                console.log 'Looking for capabilities via MSP'
                MSP.send_message MSPCodes.MSP_BOARD_INFO, false, false, ->
                    rebootMode = 0
                    # FIRMWARE
                    if bit_check(CONFIG.targetCapabilities, FC.TARGET_CAPABILITIES_FLAGS.HAS_FLASH_BOOTLOADER)
                        # Board has flash bootloader
                        GUI.log i18n.getMessage('deviceRebooting_flashBootloader')
                        console.log 'flash bootloader detected'
                        rebootMode = 4
                        # MSP_REBOOT_BOOTLOADER_FLASH
                    else
                        GUI.log i18n.getMessage('deviceRebooting_romBootloader')
                        console.log 'no flash bootloader detected'
                        rebootMode = 1
                        # MSP_REBOOT_BOOTLOADER_ROM;
                    buffer = []
                    buffer.push8 rebootMode
                    MSP.send_message MSPCodes.MSP_SET_REBOOT, buffer, (->
                        # if firmware doesn't flush MSP/serial send buffers and gracefully shutdown VCP connections we won't get a reply, so don't wait for it.
                        self.msp_connector.disconnect (disconnectionResult) ->
                            if disconnectionResult
                                # delay to allow board to boot in bootloader mode
                                # required to detect if a DFU device appears
                                setTimeout startFlashing, 1000
                            else
                                GUI.connect_lock = false
                            return
                        return
                    ), ->
                        console.log 'Reboot request recevied by device'
                        return
                    return
            return

        onTimeoutHandler = ->
            GUI.connect_lock = false
            console.log 'Looking for capabilities via MSP failed'
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32RebootingToBootloaderFailed'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
            return

        onFailureHandler = ->
            GUI.connect_lock = false
            return

        GUI.connect_lock = true
        TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32RebootingToBootloader'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
        self.msp_connector.connect self.port, self.options.reboot_baud, onConnectHandler, onTimeoutHandler, onFailureHandler
    return

# initialize certain variables and start timers that oversee the communication

STM32_protocol::initialize = ->
    self = this
    # reset and set some variables before we start
    self.receive_buffer = []
    self.verify_hex = []
    self.upload_time_start = (new Date).getTime()
    self.upload_process_alive = false
    # reset progress bar to initial state
    TABS.firmware_flasher.flashingMessage(null, TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL).flashProgress 0
    # lock some UI elements TODO needs rework
    $('select[name="release"]').prop 'disabled', true
    serial.onReceive.addListener (info) ->
        self.read info
        return
    GUI.interval_add 'STM32_timeout', (->
        if self.upload_process_alive
            # process is running
            self.upload_process_alive = false
        else
            console.log 'STM32 - timed out, programming failed ...'
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32TimedOut'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
            # protocol got stuck, clear timer and disconnect
            GUI.interval_remove 'STM32_timeout'
            # exit
            self.upload_procedure 99
        return
    ), 2000
    self.upload_procedure 1
    return

# no input parameters
# this method should be executed every 1 ms via interval timer

STM32_protocol::read = (readInfo) ->
    `var data`
    # routine that fills the buffer
    data = new Uint8Array(readInfo.data)
    i = 0
    while i < data.length
        @receive_buffer.push data[i]
        i++
    # routine that fetches data from buffer if statement is true
    if @receive_buffer.length >= @bytes_to_read and @bytes_to_read != 0
        data = @receive_buffer.slice(0, @bytes_to_read)
        # bytes requested
        @receive_buffer.splice 0, @bytes_to_read
        # remove read bytes
        @bytes_to_read = 0
        # reset trigger
        @read_callback data
    return

# we should always try to consume all "proper" available data while using retrieve

STM32_protocol::retrieve = (n_bytes, callback) ->
    if @receive_buffer.length >= n_bytes
        # data that we need are there, process immediately
        data = @receive_buffer.slice(0, n_bytes)
        @receive_buffer.splice 0, n_bytes
        # remove read bytes
        callback data
    else
        # still waiting for data, add callback
        @bytes_to_read = n_bytes
        @read_callback = callback
    return

# Array = array of bytes that will be send over serial
# bytes_to_read = received bytes necessary to trigger read_callback
# callback = function that will be executed after received bytes = bytes_to_read

STM32_protocol::send = (Array, bytes_to_read, callback) ->
    # flip flag
    @upload_process_alive = true
    bufferOut = new ArrayBuffer(Array.length)
    bufferView = new Uint8Array(bufferOut)
    # set Array values inside bufferView (alternative to for loop)
    bufferView.set Array
    # update references
    @bytes_to_read = bytes_to_read
    @read_callback = callback
    # empty receive buffer before next command is out
    @receive_buffer = []
    # send over the actual data
    serial.send bufferOut, (writeInfo) ->
    return

# val = single byte to be verified
# data = response of n bytes from mcu (array)
# result = true/false

STM32_protocol::verify_response = (val, data) ->
    self = this
    if val != data[0]
        message = 'STM32 Communication failed, wrong response, expected: ' + val + ' (0x' + val.toString(16) + ') received: ' + data[0] + ' (0x' + data[0].toString(16) + ')'
        console.error message
        TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32WrongResponse', [
            val
            val.toString(16)
            data[0]
            data[0].toString(16)
        ]), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
        # disconnect
        @upload_procedure 99
        return false
    true

# input = 16 bit value
# result = true/false

STM32_protocol::verify_chip_signature = (signature) ->
    switch signature
        when 0x412
            # not tested
            console.log 'Chip recognized as F1 Low-density'
        when 0x410
            console.log 'Chip recognized as F1 Medium-density'
            @available_flash_size = 131072
            @page_size = 1024
        when 0x414
            @available_flash_size = 0x40000
            @page_size = 2048
            console.log 'Chip recognized as F1 High-density'
        when 0x418
            # not tested
            console.log 'Chip recognized as F1 Connectivity line'
        when 0x420
            # not tested
            console.log 'Chip recognized as F1 Medium-density value line'
        when 0x428
            # not tested
            console.log 'Chip recognized as F1 High-density value line'
        when 0x430
            # not tested
            console.log 'Chip recognized as F1 XL-density value line'
        when 0x416
            # not tested
            console.log 'Chip recognized as L1 Medium-density ultralow power'
        when 0x436
            # not tested
            console.log 'Chip recognized as L1 High-density ultralow power'
        when 0x427
            # not tested
            console.log 'Chip recognized as L1 Medium-density plus ultralow power'
        when 0x411
            # not tested
            console.log 'Chip recognized as F2 STM32F2xxxx'
        when 0x440
            # not tested
            console.log 'Chip recognized as F0 STM32F051xx'
        when 0x444
            # not tested
            console.log 'Chip recognized as F0 STM32F050xx'
        when 0x413
            # not tested
            console.log 'Chip recognized as F4 STM32F40xxx/41xxx'
        when 0x419
            # not tested
            console.log 'Chip recognized as F4 STM32F427xx/437xx, STM32F429xx/439xx'
        when 0x432
            # not tested
            console.log 'Chip recognized as F3 STM32F37xxx, STM32F38xxx'
        when 0x422
            console.log 'Chip recognized as F3 STM32F30xxx, STM32F31xxx'
            @available_flash_size = 0x40000
            @page_size = 2048
    if @available_flash_size > 0
        if @hex.bytes_total < @available_flash_size
            return true
        else
            console.log 'Supplied hex is bigger then flash available on the chip, HEX: ' + @hex.bytes_total + ' bytes, limit = ' + @available_flash_size + ' bytes'
            return false
    console.log 'Chip NOT recognized: ' + signature
    false

# first_array = usually hex_to_flash array
# second_array = usually verify_hex array
# result = true/false

STM32_protocol::verify_flash = (first_array, second_array) ->
    i = 0
    while i < first_array.length
        if first_array[i] != second_array[i]
            console.log 'Verification failed on byte: ' + i + ' expected: 0x' + first_array[i].toString(16) + ' received: 0x' + second_array[i].toString(16)
            return false
        i++
    console.log 'Verification successful, matching: ' + first_array.length + ' bytes'
    true

# step = value depending on current state of upload_procedure

STM32_protocol::upload_procedure = (step) ->
    `var message`
    `var message`
    `var message`
    `var blocks`
    `var address`
    self = this
    switch step
        when 1
            # initialize serial interface on the MCU side, auto baud rate settings
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32ContactingBootloader'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
            send_counter = 0
            GUI.interval_add 'stm32_initialize_mcu', (->
                # 200 ms interval (just in case mcu was already initialized), we need to break the 2 bytes command requirement
                self.send [ 0x7F ], 1, (reply) ->
                    if reply[0] == 0x7F or reply[0] == self.status.ACK or reply[0] == self.status.NACK
                        GUI.interval_remove 'stm32_initialize_mcu'
                        console.log 'STM32 - Serial interface initialized on the MCU side'
                        # proceed to next step
                        self.upload_procedure 2
                    else
                        TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32ContactingBootloaderFailed'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
                        GUI.interval_remove 'stm32_initialize_mcu'
                        # disconnect
                        self.upload_procedure 99
                    return
                if send_counter++ > 3
                    # stop retrying, its too late to get any response from MCU
                    console.log 'STM32 - no response from bootloader, disconnecting'
                    TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32ResponseBootloaderFailed'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
                    GUI.interval_remove 'stm32_initialize_mcu'
                    GUI.interval_remove 'STM32_timeout'
                    # exit
                    self.upload_procedure 99
                return
            ), 250, true
        when 2
            # get version of the bootloader and supported commands
            self.send [
                self.command.get
                0xFF
            ], 2, (data) ->
                # 0x00 ^ 0xFF
                if self.verify_response(self.status.ACK, data)
                    self.retrieve data[1] + 1 + 1, (data) ->
                        # data[1] = number of bytes that will follow [– 1 except current and ACKs]
                        console.log 'STM32 - Bootloader version: ' + (parseInt(data[0].toString(16)) / 10).toFixed(1)
                        # convert dec to hex, hex to dec and add floating point
                        self.useExtendedErase = data[7] == self.command.extended_erase
                        # proceed to next step
                        self.upload_procedure 3
                        return
                return
        when 3
            # get ID (device signature)
            self.send [
                self.command.get_ID
                0xFD
            ], 2, (data) ->
                # 0x01 ^ 0xFF
                if self.verify_response(self.status.ACK, data)
                    self.retrieve data[1] + 1 + 1, (data) ->
                        # data[1] = number of bytes that will follow [– 1 (N = 1 for STM32), except for current byte and ACKs]
                        signature = data[0] << 8 | data[1]
                        console.log 'STM32 - Signature: 0x' + signature.toString(16)
                        # signature in hex representation
                        if self.verify_chip_signature(signature)
                            # proceed to next step
                            self.upload_procedure 4
                        else
                            # disconnect
                            self.upload_procedure 99
                        return
                return
        when 4
            # erase memory
            if self.useExtendedErase
                if self.options.erase_chip
                    message = 'Executing global chip erase (via extended erase)'
                    console.log message
                    TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32GlobalEraseExtended'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
                    self.send [
                        self.command.extended_erase
                        0xBB
                    ], 1, (reply) ->
                        if self.verify_response(self.status.ACK, reply)
                            self.send [
                                0xFF
                                0xFF
                                0x00
                            ], 1, (reply) ->
                                if self.verify_response(self.status.ACK, reply)
                                    console.log 'Executing global chip extended erase: done'
                                    self.upload_procedure 5
                                return
                        return
                else
                    message = 'Executing local erase (via extended erase)'
                    console.log message
                    TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32LocalEraseExtended'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
                    self.send [
                        self.command.extended_erase
                        0xBB
                    ], 1, (reply) ->
                        if self.verify_response(self.status.ACK, reply)
                            # For reference: https://code.google.com/p/stm32flash/source/browse/stm32.c#723
                            max_address = self.hex.data[self.hex.data.length - 1].address + self.hex.data[self.hex.data.length - 1].bytes - 0x8000000
                            erase_pages_n = Math.ceil(max_address / self.page_size)
                            buff = []
                            checksum = 0
                            pg_byte = undefined
                            pg_byte = erase_pages_n - 1 >> 8
                            buff.push pg_byte
                            checksum ^= pg_byte
                            pg_byte = erase_pages_n - 1 & 0xFF
                            buff.push pg_byte
                            checksum ^= pg_byte
                            i = 0
                            while i < erase_pages_n
                                pg_byte = i >> 8
                                buff.push pg_byte
                                checksum ^= pg_byte
                                pg_byte = i & 0xFF
                                buff.push pg_byte
                                checksum ^= pg_byte
                                i++
                            buff.push checksum
                            console.log 'Erasing. pages: 0x00 - 0x' + erase_pages_n.toString(16) + ', checksum: 0x' + checksum.toString(16)
                            self.send buff, 1, (reply) ->
                                if self.verify_response(self.status.ACK, reply)
                                    console.log 'Erasing: done'
                                    # proceed to next step
                                    self.upload_procedure 5
                                return
                        return
                break
            if self.options.erase_chip
                message = 'Executing global chip erase'
                console.log message
                TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32GlobalErase'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
                self.send [
                    self.command.erase
                    0xBC
                ], 1, (reply) ->
                    # 0x43 ^ 0xFF
                    if self.verify_response(self.status.ACK, reply)
                        self.send [
                            0xFF
                            0x00
                        ], 1, (reply) ->
                            if self.verify_response(self.status.ACK, reply)
                                console.log 'Erasing: done'
                                # proceed to next step
                                self.upload_procedure 5
                            return
                    return
            else
                message = 'Executing local erase'
                console.log message
                TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32LocalErase'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
                self.send [
                    self.command.erase
                    0xBC
                ], 1, (reply) ->
                    # 0x43 ^ 0xFF
                    if self.verify_response(self.status.ACK, reply)
                        # the bootloader receives one byte that contains N, the number of pages to be erased – 1
                        max_address = self.hex.data[self.hex.data.length - 1].address + self.hex.data[self.hex.data.length - 1].bytes - 0x8000000
                        erase_pages_n = Math.ceil(max_address / self.page_size)
                        buff = []
                        checksum = erase_pages_n - 1
                        buff.push erase_pages_n - 1
                        i = 0
                        while i < erase_pages_n
                            buff.push i
                            checksum ^= i
                            i++
                        buff.push checksum
                        self.send buff, 1, (reply) ->
                            if self.verify_response(self.status.ACK, reply)
                                console.log 'Erasing: done'
                                # proceed to next step
                                self.upload_procedure 5
                            return
                    return
        when 5
            # upload
            console.log 'Writing data ...'
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32Flashing'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
            blocks = self.hex.data.length - 1
            flashing_block = 0
            address = self.hex.data[flashing_block].address
            bytes_flashed = 0
            bytes_flashed_total = 0
            # used for progress bar

            _write = ->
                if bytes_flashed < self.hex.data[flashing_block].bytes
                    bytes_to_write = if bytes_flashed + 256 <= self.hex.data[flashing_block].bytes then 256 else self.hex.data[flashing_block].bytes - bytes_flashed
                    # console.log('STM32 - Writing to: 0x' + address.toString(16) + ', ' + bytes_to_write + ' bytes');
                    self.send [
                        self.command.write_memory
                        0xCE
                    ], 1, (reply) ->
                        # 0x31 ^ 0xFF
                        if self.verify_response(self.status.ACK, reply)
                            # address needs to be transmitted as 32 bit integer, we need to bit shift each byte out and then calculate address checksum
                            address_arr = [
                                address >> 24
                                address >> 16
                                address >> 8
                                address
                            ]
                            address_checksum = address_arr[0] ^ address_arr[1] ^ address_arr[2] ^ address_arr[3]
                            self.send [
                                address_arr[0]
                                address_arr[1]
                                address_arr[2]
                                address_arr[3]
                                address_checksum
                            ], 1, (reply) ->
                                # write start address + checksum
                                if self.verify_response(self.status.ACK, reply)
                                    array_out = new Array(bytes_to_write + 2)
                                    # 2 byte overhead [N, ...., checksum]
                                    array_out[0] = bytes_to_write - 1
                                    # number of bytes to be written (to write 128 bytes, N must be 127, to write 256 bytes, N must be 255)
                                    checksum = array_out[0]
                                    i = 0
                                    while i < bytes_to_write
                                        array_out[i + 1] = self.hex.data[flashing_block].data[bytes_flashed]
                                        # + 1 because of the first byte offset
                                        checksum ^= self.hex.data[flashing_block].data[bytes_flashed]
                                        bytes_flashed++
                                        i++
                                    array_out[array_out.length - 1] = checksum
                                    # checksum (last byte in the array_out array)
                                    address += bytes_to_write
                                    bytes_flashed_total += bytes_to_write
                                    self.send array_out, 1, (reply) ->
                                        if self.verify_response(self.status.ACK, reply)
                                            # flash another page
                                            _write()
                                        return
                                    # update progress bar
                                    TABS.firmware_flasher.flashProgress Math.round(bytes_flashed_total / (self.hex.bytes_total * 2) * 100)
                                return
                        return
                else
                    # move to another block
                    if flashing_block < blocks
                        flashing_block++
                        address = self.hex.data[flashing_block].address
                        bytes_flashed = 0
                        _write()
                    else
                        # all blocks flashed
                        console.log 'Writing: done'
                        # proceed to next step
                        self.upload_procedure 6
                return

            # start writing
            _write()
        when 6
            # verify
            console.log 'Verifying data ...'
            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32Verifying'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.NEUTRAL
            blocks = self.hex.data.length - 1
            reading_block = 0
            address = self.hex.data[reading_block].address
            bytes_verified = 0
            bytes_verified_total = 0
            # used for progress bar
            # initialize arrays
            i = 0
            while i <= blocks
                self.verify_hex.push []
                i++

            _reading = ->
                `var i`
                if bytes_verified < self.hex.data[reading_block].bytes
                    bytes_to_read = if bytes_verified + 256 <= self.hex.data[reading_block].bytes then 256 else self.hex.data[reading_block].bytes - bytes_verified
                    # console.log('STM32 - Reading from: 0x' + address.toString(16) + ', ' + bytes_to_read + ' bytes');
                    self.send [
                        self.command.read_memory
                        0xEE
                    ], 1, (reply) ->
                        # 0x11 ^ 0xFF
                        if self.verify_response(self.status.ACK, reply)
                            address_arr = [
                                address >> 24
                                address >> 16
                                address >> 8
                                address
                            ]
                            address_checksum = address_arr[0] ^ address_arr[1] ^ address_arr[2] ^ address_arr[3]
                            self.send [
                                address_arr[0]
                                address_arr[1]
                                address_arr[2]
                                address_arr[3]
                                address_checksum
                            ], 1, (reply) ->
                                # read start address + checksum
                                if self.verify_response(self.status.ACK, reply)
                                    bytes_to_read_n = bytes_to_read - 1
                                    self.send [
                                        bytes_to_read_n
                                        ~bytes_to_read_n & 0xFF
                                    ], 1, (reply) ->
                                        # bytes to be read + checksum XOR(complement of bytes_to_read_n)
                                        if self.verify_response(self.status.ACK, reply)
                                            self.retrieve bytes_to_read, (data) ->
                                                `var i`
                                                i = 0
                                                while i < data.length
                                                    self.verify_hex[reading_block].push data[i]
                                                    i++
                                                address += bytes_to_read
                                                bytes_verified += bytes_to_read
                                                bytes_verified_total += bytes_to_read
                                                # verify another page
                                                _reading()
                                                return
                                        return
                                    # update progress bar
                                    TABS.firmware_flasher.flashProgress Math.round((self.hex.bytes_total + bytes_verified_total) / (self.hex.bytes_total * 2) * 100)
                                return
                        return
                else
                    # move to another block
                    if reading_block < blocks
                        reading_block++
                        address = self.hex.data[reading_block].address
                        bytes_verified = 0
                        _reading()
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
                            self.upload_procedure 7
                        else
                            console.log 'Programming: FAILED'
                            # update progress bar
                            TABS.firmware_flasher.flashingMessage i18n.getMessage('stm32ProgrammingFailed'), TABS.firmware_flasher.FLASH_MESSAGE_TYPES.INVALID
                            # disconnect
                            self.upload_procedure 99
                return

            # start reading
            _reading()
        when 7
            # go
            # memory address = 4 bytes, 1st high byte, 4th low byte, 5th byte = checksum XOR(byte 1, byte 2, byte 3, byte 4)
            console.log 'Sending GO command: 0x8000000'
            self.send [
                self.command.go
                0xDE
            ], 1, (reply) ->
                `var address`
                # 0x21 ^ 0xFF
                if self.verify_response(self.status.ACK, reply)
                    gt_address = 0x8000000
                    address = [
                        gt_address >> 24
                        gt_address >> 16
                        gt_address >> 8
                        gt_address
                    ]
                    address_checksum = address[0] ^ address[1] ^ address[2] ^ address[3]
                    self.send [
                        address[0]
                        address[1]
                        address[2]
                        address[3]
                        address_checksum
                    ], 1, (reply) ->
                        if self.verify_response(self.status.ACK, reply)
                            # disconnect
                            self.upload_procedure 99
                        return
                return
        when 99
            # disconnect
            GUI.interval_remove 'STM32_timeout'
            # stop STM32 timeout timer (everything is finished now)
            # close connection
            if serial.connectionId
                serial.disconnect self.cleanup
            else
                self.cleanup()
    return

STM32_protocol::cleanup = ->
    PortUsage.reset()
    # unlocking connect button
    GUI.connect_lock = false
    # unlock some UI elements TODO needs rework
    $('select[name="release"]').prop 'disabled', false
    # handle timing
    timeSpent = (new Date).getTime() - (self.upload_time_start)
    console.log 'Script finished after: ' + timeSpent / 1000 + ' seconds'
    if self.callback
        self.callback()
    return

# initialize object
STM32 = new STM32_protocol

