'use strict'
sdcardTimer = undefined
TABS.onboard_logging =
    blockSize: 128
    writeError: false
    BLOCK_SIZE: 4096
    VCP_BLOCK_SIZE_3_0: 512
    VCP_BLOCK_SIZE: 4096

TABS.onboard_logging.initialize = (callback) ->
    self = this
    saveCancelled = undefined
    eraseCancelled = undefined

    gcd = (a, b) ->
        if b == 0
            return a
        gcd b, a % b

    save_to_eeprom = ->
        MSP.send_message MSPCodes.MSP_EEPROM_WRITE, false, false, reboot
        return

    reboot = ->
        GUI.log i18n.getMessage('configurationEepromSaved')
        GUI.tab_switch_cleanup ->
            MSP.send_message MSPCodes.MSP_SET_REBOOT, false, false
            reinitialiseConnection self
            return
        return

    load_html = ->
        $('#content').load './tabs/onboard_logging.html', ->
            # translate to user-selected language
            i18n.localizePage()
            dataflashPresent = DATAFLASH.totalSize > 0
            blackboxSupport = undefined

            ###
            # Pre-1.11.0 firmware supported DATAFLASH API (on targets with SPI flash) but not the BLACKBOX config API.
            # 
            # The best we can do on those targets is check the BLACKBOX feature bit to identify support for Blackbox instead.
            ###

            if (BLACKBOX.supported or DATAFLASH.supported) and (semver.gte(CONFIG.apiVersion, '1.33.0') or FEATURE_CONFIG.features.isEnabled('BLACKBOX'))
                blackboxSupport = 'yes'
            else
                blackboxSupport = 'no'
            $('.tab-onboard_logging').addClass('serial-supported').toggleClass('dataflash-supported', DATAFLASH.supported).toggleClass('dataflash-present', dataflashPresent).toggleClass('sdcard-supported', SDCARD.supported).toggleClass('blackbox-config-supported', BLACKBOX.supported).toggleClass('blackbox-supported', blackboxSupport == 'yes').toggleClass('blackbox-maybe-supported', blackboxSupport == 'maybe').toggleClass 'blackbox-unsupported', blackboxSupport == 'no'
            if dataflashPresent
                # UI hooks
                $('.tab-onboard_logging a.erase-flash').click ask_to_erase_flash
                $('.tab-onboard_logging a.erase-flash-confirm').click flash_erase
                $('.tab-onboard_logging a.erase-flash-cancel').click flash_erase_cancel
                $('.tab-onboard_logging a.save-flash').click flash_save_begin
                $('.tab-onboard_logging a.save-flash-cancel').click flash_save_cancel
                $('.tab-onboard_logging a.save-flash-dismiss').click dismiss_saving_dialog
            deviceSelect = $('.blackboxDevice select')
            loggingRatesSelect = $('.blackboxRate select')
            debugModeSelect = $('.blackboxDebugMode select')
            if BLACKBOX.supported
                $('.tab-onboard_logging a.save-settings').click ->
                    if semver.gte(CONFIG.apiVersion, '1.36.0')
                        BLACKBOX.blackboxPDenom = parseInt(loggingRatesSelect.val(), 10)
                    else
                        rate = loggingRatesSelect.val().split('/')
                        BLACKBOX.blackboxRateNum = parseInt(rate[0], 10)
                        BLACKBOX.blackboxRateDenom = parseInt(rate[1], 10)
                    BLACKBOX.blackboxDevice = parseInt(deviceSelect.val(), 10)
                    if semver.gte(CONFIG.apiVersion, '1.42.0')
                        PID_ADVANCED_CONFIG.debugMode = parseInt(debugModeSelect.val())
                        MSP.send_message MSPCodes.MSP_SET_ADVANCED_CONFIG, mspHelper.crunch(MSPCodes.MSP_SET_ADVANCED_CONFIG), false, save_to_eeprom
                    MSP.send_message MSPCodes.MSP_SET_BLACKBOX_CONFIG, mspHelper.crunch(MSPCodes.MSP_SET_BLACKBOX_CONFIG), false, save_to_eeprom
                    return
            populateLoggingRates loggingRatesSelect
            populateDevices deviceSelect
            populateDebugModes debugModeSelect
            deviceSelect.change(->
                if $(this).val() == '0'
                    $('div.blackboxRate').hide()
                else
                    $('div.blackboxRate').show()
                return
            ).change()
            if semver.gte(CONFIG.apiVersion, '1.40.0')
                if SDCARD.supported and deviceSelect.val() == 2 or DATAFLASH.supported and deviceSelect.val() == 1
                    $('.tab-onboard_logging').toggleClass 'msc-supported', true
                    $('a.onboardLoggingRebootMsc').click ->
                        analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'RebootMsc'
                        buffer = []
                        if semver.gte(CONFIG.apiVersion, '1.41.0')
                            if GUI.operating_system == 'Linux'
                                # Reboot into MSC using UTC time offset instead of user timezone
                                # Linux seems to expect that the FAT file system timestamps are UTC based
                                buffer.push mspHelper.REBOOT_TYPES.MSC_UTC
                            else
                                buffer.push mspHelper.REBOOT_TYPES.MSC
                        else
                            buffer.push mspHelper.REBOOT_TYPES.MSC
                        MSP.send_message MSPCodes.MSP_SET_REBOOT, buffer, false
                        return
            update_html()
            GUI.content_ready callback
            return
        return

    populateDevices = (deviceSelect) ->
        deviceSelect.empty()
        if semver.gte(CONFIG.apiVersion, '1.33.0')
            deviceSelect.append '<option value="0">' + i18n.getMessage('blackboxLoggingNone') + '</option>'
            if DATAFLASH.supported
                deviceSelect.append '<option value="1">' + i18n.getMessage('blackboxLoggingFlash') + '</option>'
            if SDCARD.supported
                deviceSelect.append '<option value="2">' + i18n.getMessage('blackboxLoggingSdCard') + '</option>'
            deviceSelect.append '<option value="3">' + i18n.getMessage('blackboxLoggingSerial') + '</option>'
        else
            deviceSelect.append '<option value="0">' + i18n.getMessage('blackboxLoggingSerial') + '</option>'
            if DATAFLASH.ready
                deviceSelect.append '<option value="1">' + i18n.getMessage('blackboxLoggingFlash') + '</option>'
            if SDCARD.supported
                deviceSelect.append '<option value="2">' + i18n.getMessage('blackboxLoggingSdCard') + '</option>'
        deviceSelect.val BLACKBOX.blackboxDevice
        return

    populateLoggingRates = (loggingRatesSelect) ->
        # Offer a reasonable choice of logging rates (if people want weird steps they can use CLI)
        loggingRates = []
        pidRateBase = 8000
        if semver.gte(CONFIG.apiVersion, '1.25.0') and semver.lt(CONFIG.apiVersion, '1.41.0') and PID_ADVANCED_CONFIG.gyroUse32kHz != 0
            pidRateBase = 32000
        pidRate = pidRateBase / PID_ADVANCED_CONFIG.gyro_sync_denom / PID_ADVANCED_CONFIG.pid_process_denom
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            loggingRates = [
                {
                    text: 'Disabled'
                    hz: 0
                    p_denom: 0
                }
                {
                    text: '500 Hz'
                    hz: 500
                    p_denom: 16
                }
                {
                    text: '1 kHz'
                    hz: 1000
                    p_denom: 32
                }
                {
                    text: '1.5 kHz'
                    hz: 1500
                    p_denom: 48
                }
                {
                    text: '2 kHz'
                    hz: 2000
                    p_denom: 64
                }
                {
                    text: '4 kHz'
                    hz: 4000
                    p_denom: 128
                }
                {
                    text: '8 kHz'
                    hz: 8000
                    p_denom: 256
                }
                {
                    text: '16 kHz'
                    hz: 16000
                    p_denom: 512
                }
                {
                    text: '32 kHz'
                    hz: 32000
                    p_denom: 1024
                }
            ]
            $.each loggingRates, (index, item) ->
                if pidRate >= item.hz or item.hz == 0
                    loggingRatesSelect.append new Option(item.text, item.p_denom)
                return
            loggingRatesSelect.val BLACKBOX.blackboxPDenom
        else
            loggingRates = [
                {
                    num: 1
                    denom: 1
                }
                {
                    num: 1
                    denom: 2
                }
                {
                    num: 1
                    denom: 3
                }
                {
                    num: 1
                    denom: 4
                }
                {
                    num: 1
                    denom: 5
                }
                {
                    num: 1
                    denom: 6
                }
                {
                    num: 1
                    denom: 7
                }
                {
                    num: 1
                    denom: 8
                }
                {
                    num: 1
                    denom: 16
                }
                {
                    num: 1
                    denom: 32
                }
            ]
            i = 0
            while i < loggingRates.length
                loggingRate = Math.round(pidRate / loggingRates[i].denom)
                loggingRateUnit = ' Hz'
                if loggingRate != Infinity
                    if gcd(loggingRate, 1000) == 1000
                        loggingRate /= 1000
                        loggingRateUnit = ' KHz'
                loggingRatesSelect.append '<option value="' + loggingRates[i].num + '/' + loggingRates[i].denom + '">' + loggingRate + loggingRateUnit + ' (' + Math.round(loggingRates[i].num / loggingRates[i].denom * 100) + '%)</option>'
                i++
            loggingRatesSelect.val BLACKBOX.blackboxRateNum + '/' + BLACKBOX.blackboxRateDenom
        return

    populateDebugModes = (debugModeSelect) ->
        debugModes = []
        if semver.gte(CONFIG.apiVersion, '1.42.0')
            $('.blackboxDebugMode').show()
            debugModes = [
                { text: 'NONE' }
                { text: 'CYCLETIME' }
                { text: 'BATTERY' }
                { text: 'GYRO_FILTERED' }
                { text: 'ACCELEROMETER' }
                { text: 'PIDLOOP' }
                { text: 'GYRO_SCALED' }
                { text: 'RC_INTERPOLATION' }
                { text: 'ANGLERATE' }
                { text: 'ESC_SENSOR' }
                { text: 'SCHEDULER' }
                { text: 'STACK' }
                { text: 'ESC_SENSOR_RPM' }
                { text: 'ESC_SENSOR_TMP' }
                { text: 'ALTITUDE' }
                { text: 'FFT' }
                { text: 'FFT_TIME' }
                { text: 'FFT_FREQ' }
                { text: 'RX_FRSKY_SPI' }
                { text: 'RX_SFHSS_SPI' }
                { text: 'GYRO_RAW' }
                { text: 'DUAL_GYRO_RAW' }
                { text: 'DUAL_GYRO_DIFF' }
                { text: 'MAX7456_SIGNAL' }
                { text: 'MAX7456_SPICLOCK' }
                { text: 'SBUS' }
                { text: 'FPORT' }
                { text: 'RANGEFINDER' }
                { text: 'RANGEFINDER_QUALITY' }
                { text: 'LIDAR_TF' }
                { text: 'ADC_INTERNAL' }
                { text: 'RUNAWAY_TAKEOFF' }
                { text: 'SDIO' }
                { text: 'CURRENT_SENSOR' }
                { text: 'USB' }
                { text: 'SMARTAUDIO' }
                { text: 'RTH' }
                { text: 'ITERM_RELAX' }
                { text: 'ACRO_TRAINER' }
                { text: 'RC_SMOOTHING' }
                { text: 'RX_SIGNAL_LOSS' }
                { text: 'RC_SMOOTHING_RATE' }
                { text: 'ANTI_GRAVITY' }
                { text: 'DYN_LPF' }
                { text: 'RX_SPEKTRUM_SPI' }
                { text: 'DSHOT_RPM_TELEMETRY' }
                { text: 'RPM_FILTER' }
                { text: 'D_MIN' }
                { text: 'AC_CORRECTION' }
                { text: 'AC_ERROR' }
                { text: 'DUAL_GYRO_SCALED' }
                { text: 'DSHOT_RPM_ERRORS' }
                { text: 'CRSF_LINK_STATISTICS_UPLINK' }
                { text: 'CRSF_LINK_STATISTICS_PWR' }
                { text: 'CRSF_LINK_STATISTICS_DOWN' }
                { text: 'BARO' }
                { text: 'GPS_RESCUE_THROTTLE_PID' }
                { text: 'DYN_IDLE' }
                { text: 'FF_LIMIT' }
                { text: 'FF_INTERPOLATED' }
            ]
            i = 0
            while i < PID_ADVANCED_CONFIG.debugModeCount
                if i < debugModes.length
                    debugModeSelect.append new Option(debugModes[i].text, i)
                else
                    debugModeSelect.append new Option(i18n.getMessage('onboardLoggingDebugModeUnknown'), i)
                i++
            debugModeSelect.val PID_ADVANCED_CONFIG.debugMode
        else
            $('.blackboxDebugMode').hide()
        return

    formatFilesizeKilobytes = (kilobytes) ->
        if kilobytes < 1024
            return Math.round(kilobytes) + 'kB'
        megabytes = kilobytes / 1024
        gigabytes = undefined
        if megabytes < 900
            megabytes.toFixed(1) + 'MB'
        else
            gigabytes = megabytes / 1024
            gigabytes.toFixed(1) + 'GB'

    formatFilesizeBytes = (bytes) ->
        if bytes < 1024
            return bytes + 'B'
        formatFilesizeKilobytes bytes / 1024

    update_bar_width = (bar, value, total, label, valuesAreKilobytes) ->
        if value > 0
            bar.css
                width: value / total * 100 + '%'
                display: 'block'
            $('div', bar).text (if label then label + ' ' else '') + (if valuesAreKilobytes then formatFilesizeKilobytes(value) else formatFilesizeBytes(value))
        else
            bar.css display: 'none'
        return

    update_html = ->
        dataflashPresent = DATAFLASH.totalSize > 0
        update_bar_width $('.tab-onboard_logging .dataflash-used'), DATAFLASH.usedSize, DATAFLASH.totalSize, i18n.getMessage('dataflashUsedSpace'), false
        update_bar_width $('.tab-onboard_logging .dataflash-free'), DATAFLASH.totalSize - (DATAFLASH.usedSize), DATAFLASH.totalSize, i18n.getMessage('dataflashFreeSpace'), false
        update_bar_width $('.tab-onboard_logging .sdcard-other'), SDCARD.totalSizeKB - (SDCARD.freeSizeKB), SDCARD.totalSizeKB, i18n.getMessage('dataflashUnavSpace'), true
        update_bar_width $('.tab-onboard_logging .sdcard-free'), SDCARD.freeSizeKB, SDCARD.totalSizeKB, i18n.getMessage('dataflashLogsSpace'), true
        $('.btn a.erase-flash, .btn a.save-flash').toggleClass 'disabled', DATAFLASH.usedSize == 0
        $('.tab-onboard_logging').toggleClass('sdcard-error', SDCARD.state == MSP.SDCARD_STATE_FATAL).toggleClass('sdcard-initializing', SDCARD.state == MSP.SDCARD_STATE_CARD_INIT or SDCARD.state == MSP.SDCARD_STATE_FS_INIT).toggleClass 'sdcard-ready', SDCARD.state == MSP.SDCARD_STATE_READY
        if semver.gte(CONFIG.apiVersion, '1.40.0')
            mscIsReady = dataflashPresent or SDCARD.state == MSP.SDCARD_STATE_READY
            $('.tab-onboard_logging').toggleClass 'msc-not-ready', !mscIsReady
            if !mscIsReady
                $('a.onboardLoggingRebootMsc').addClass 'disabled'
            else
                $('a.onboardLoggingRebootMsc').removeClass 'disabled'
        loggingStatus = undefined
        switch SDCARD.state
            when MSP.SDCARD_STATE_NOT_PRESENT
                $('.sdcard-status').text i18n.getMessage('sdcardStatusNoCard')
                loggingStatus = 'SdCard: NotPresent'
            when MSP.SDCARD_STATE_FATAL
                $('.sdcard-status').html i18n.getMessage('sdcardStatusReboot')
                loggingStatus = 'SdCard: Error'
            when MSP.SDCARD_STATE_READY
                $('.sdcard-status').text i18n.getMessage('sdcardStatusReady')
                loggingStatus = 'SdCard: Ready'
            when MSP.SDCARD_STATE_CARD_INIT
                $('.sdcard-status').text i18n.getMessage('sdcardStatusStarting')
                loggingStatus = 'SdCard: Init'
            when MSP.SDCARD_STATE_FS_INIT
                $('.sdcard-status').text i18n.getMessage('sdcardStatusFileSystem')
                loggingStatus = 'SdCard: FsInit'
            else
                $('.sdcard-status').text i18n.getMessage('sdcardStatusUnknown', [ SDCARD.state ])
        if dataflashPresent and SDCARD.state == MSP.SDCARD_STATE_NOT_PRESENT
            loggingStatus = 'Dataflash'
            analytics.setFlightControllerData analytics.DATA.LOG_SIZE, DATAFLASH.usedSize
        analytics.setFlightControllerData analytics.DATA.LOGGING_STATUS, loggingStatus
        if SDCARD.supported and !sdcardTimer
            # Poll for changes in SD card status
            sdcardTimer = setTimeout((->
                sdcardTimer = false
                if CONFIGURATOR.connectionValid
                    MSP.send_message MSPCodes.MSP_SDCARD_SUMMARY, false, false, ->
                        update_html()
                        return
                return
            ), 2000)
        return

    # IO related methods

    flash_save_cancel = ->
        saveCancelled = true
        return

    show_saving_dialog = ->
        $('.dataflash-saving progress').attr 'value', 0
        saveCancelled = false
        $('.dataflash-saving').removeClass 'done'
        $('.dataflash-saving')[0].showModal()
        return

    dismiss_saving_dialog = ->
        $('.dataflash-saving')[0].close()
        return

    mark_saving_dialog_done = (startTime, totalBytes, totalBytesCompressed) ->
        analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'SaveDataflash'
        totalTime = ((new Date).getTime() - startTime) / 1000
        console.log 'Received ' + totalBytes + ' bytes in ' + totalTime.toFixed(2) + 's (' + (totalBytes / totalTime / 1024).toFixed(2) + 'kB / s) with block size ' + self.blockSize + '.'
        if !isNaN(totalBytesCompressed)
            console.log 'Compressed into', totalBytesCompressed, 'bytes with mean compression factor of', totalBytes / totalBytesCompressed
        $('.dataflash-saving').addClass 'done'
        return

    flash_update_summary = (onDone) ->
        MSP.send_message MSPCodes.MSP_DATAFLASH_SUMMARY, false, false, ->
            update_html()
            if onDone
                onDone()
            return
        return

    flash_save_begin = ->
        if GUI.connected_to
            if FC.boardHasVcp()
                if semver.gte(CONFIG.apiVersion, '1.31.0')
                    self.blockSize = self.VCP_BLOCK_SIZE
                else
                    self.blockSize = self.VCP_BLOCK_SIZE_3_0
            else
                self.blockSize = self.BLOCK_SIZE
            # Begin by refreshing the occupied size in case it changed while the tab was open
            flash_update_summary ->
                maxBytes = DATAFLASH.usedSize
                prepare_file (fileWriter) ->
                    nextAddress = 0
                    totalBytesCompressed = 0

                    onChunkRead = (chunkAddress, chunkDataView, bytesCompressed) ->
                        if chunkDataView != null
                            # Did we receive any data?
                            if chunkDataView.byteLength > 0
                                nextAddress += chunkDataView.byteLength
                                if isNaN(bytesCompressed) or isNaN(totalBytesCompressed)
                                    totalBytesCompressed = null
                                else
                                    totalBytesCompressed += bytesCompressed
                                $('.dataflash-saving progress').attr 'value', nextAddress / maxBytes * 100
                                blob = new Blob([ chunkDataView ])

                                fileWriter.onwriteend = (e) ->
                                    if saveCancelled or nextAddress >= maxBytes
                                        if saveCancelled
                                            dismiss_saving_dialog()
                                        else
                                            mark_saving_dialog_done startTime, nextAddress, totalBytesCompressed
                                    else
                                        if !self.writeError
                                            mspHelper.dataflashRead nextAddress, self.blockSize, onChunkRead
                                        else
                                            dismiss_saving_dialog()
                                    return

                                fileWriter.write blob
                            else
                                # A zero-byte block indicates end-of-file, so we're done
                                mark_saving_dialog_done startTime, nextAddress, totalBytesCompressed
                        else
                            # There was an error with the received block (address didn't match the one we asked for), retry
                            mspHelper.dataflashRead nextAddress, self.blockSize, onChunkRead
                        return

                    show_saving_dialog()
                    startTime = (new Date).getTime()
                    # Fetch the initial block
                    mspHelper.dataflashRead nextAddress, self.blockSize, onChunkRead
                    return
                return
        return

    prepare_file = (onComplete) ->
        prefix = 'BLACKBOX_LOG'
        suffix = 'BBL'
        filename = generateFilename(prefix, suffix)
        chrome.fileSystem.chooseEntry {
            type: 'saveFile'
            suggestedName: filename
            accepts: [ {
                description: suffix.toUpperCase() + ' files'
                extensions: [ suffix ]
            } ]
        }, (fileEntry) ->
            error = chrome.runtime.lastError
            if error
                console.error error.message
                if error.message != 'User cancelled'
                    GUI.log i18n.getMessage('dataflashFileWriteFailed')
                return
            # echo/console log path specified
            chrome.fileSystem.getDisplayPath fileEntry, (path) ->
                console.log 'Dataflash dump file path: ' + path
                return
            fileEntry.createWriter ((fileWriter) ->

                fileWriter.onerror = (e) ->
                    GUI.log '<strong><span class="message-negative">' + i18n.getMessage('error', errorMessage: e.target.error.message) + '</span class="message-negative></strong>'
                    console.error e
                    # stop logging if the procedure was/is still running
                    self.writeError = true
                    return

                onComplete fileWriter
                return
            ), (e) ->
                # File is not readable or does not exist!
                console.error e
                GUI.log i18n.getMessage('dataflashFileWriteFailed')
                return
            return
        return

    ask_to_erase_flash = ->
        eraseCancelled = false
        $('.dataflash-confirm-erase').removeClass 'erasing'
        $('.dataflash-confirm-erase')[0].showModal()
        return

    poll_for_erase_completion = ->
        flash_update_summary ->
            if CONFIGURATOR.connectionValid and !eraseCancelled
                if DATAFLASH.ready
                    $('.dataflash-confirm-erase')[0].close()
                else
                    setTimeout poll_for_erase_completion, 500
            return
        return

    flash_erase = ->
        $('.dataflash-confirm-erase').addClass 'erasing'
        MSP.send_message MSPCodes.MSP_DATAFLASH_ERASE, false, false, poll_for_erase_completion
        return

    flash_erase_cancel = ->
        eraseCancelled = true
        $('.dataflash-confirm-erase')[0].close()
        return

    if GUI.active_tab != 'onboard_logging'
        GUI.active_tab = 'onboard_logging'
    if CONFIGURATOR.connectionValid
        MSP.send_message MSPCodes.MSP_FEATURE_CONFIG, false, false, ->
            MSP.send_message MSPCodes.MSP_DATAFLASH_SUMMARY, false, false, ->
                MSP.send_message MSPCodes.MSP_SDCARD_SUMMARY, false, false, ->
                    MSP.send_message MSPCodes.MSP_BLACKBOX_CONFIG, false, false, ->
                        MSP.send_message MSPCodes.MSP_ADVANCED_CONFIG, false, false, ->
                            MSP.send_message MSPCodes.MSP_NAME, false, false, load_html
                            return
                        return
                    return
                return
            return
    return

TABS.onboard_logging.cleanup = (callback) ->
    analytics.setFlightControllerData analytics.DATA.LOGGING_STATUS, undefined
    analytics.setFlightControllerData analytics.DATA.LOG_SIZE, undefined
    if sdcardTimer
        clearTimeout sdcardTimer
        sdcardTimer = false
    if callback
        callback()
    return

TABS.onboard_logging.mscRebootFailedCallback = ->
    $('.tab-onboard_logging').toggleClass 'msc-supported', false
    showErrorDialog i18n.getMessage('operationNotSupported')
    return

