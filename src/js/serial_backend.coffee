initializeSerialBackend = ->

    GUI.updateManualPortVisibility = ->
        selected_port = $('div#port-picker #port option:selected')
        if selected_port.data().isManual
            $('#port-override-option').show()
        else
            $('#port-override-option').hide()
        if selected_port.data().isDFU
            $('select#baud').hide()
        else
            $('select#baud').show()
        return

    GUI.updateManualPortVisibility()
    $('#port-override').change ->
        ConfigStorage.set 'portOverride': $('#port-override').val()
        return
    ConfigStorage.get 'portOverride', (data) ->
        $('#port-override').val data.portOverride
        return
    $('div#port-picker #port').change (target) ->
        GUI.updateManualPortVisibility()
        return
    $('div.connect_controls a.connect').click ->

        onFinishCallback = ->
            finishClose toggleStatus
            return

        if GUI.connect_lock != true
            # GUI control overrides the user control
            thisElement = $(this)
            clicks = thisElement.data('clicks')

            toggleStatus = ->
                thisElement.data 'clicks', !clicks
                return

            GUI.configuration_loaded = false
            selected_baud = parseInt($('div#port-picker #baud').val())
            selected_port = if $('div#port-picker #port option:selected').data().isManual then $('#port-override').val() else String($('div#port-picker #port').val())
            if selected_port == 'DFU'
                GUI.log i18n.getMessage('dfu_connect_message')
            else if selected_port != '0'
                if !clicks
                    console.log 'Connecting to: ' + selected_port
                    GUI.connecting_to = selected_port
                    # lock port select & baud while we are connecting / connected
                    $('div#port-picker #port, div#port-picker #baud, div#port-picker #delay').prop 'disabled', true
                    $('div.connect_controls a.connect_state').text i18n.getMessage('connecting')
                    serial.connect selected_port, { bitrate: selected_baud }, onOpen
                    toggleStatus()
                else
                    if $('div#flashbutton a.flash_state').hasClass('active') and $('div#flashbutton a.flash').hasClass('active')
                        $('div#flashbutton a.flash_state').removeClass 'active'
                        $('div#flashbutton a.flash').removeClass 'active'
                    GUI.timeout_kill_all()
                    GUI.interval_kill_all()
                    GUI.tab_switch_cleanup()
                    GUI.tab_switch_in_progress = false
                    mspHelper.setArmingEnabled true, false, onFinishCallback
        return
    $('div.open_firmware_flasher a.flash').click ->
        if $('div#flashbutton a.flash_state').hasClass('active') and $('div#flashbutton a.flash').hasClass('active')
            $('div#flashbutton a.flash_state').removeClass 'active'
            $('div#flashbutton a.flash').removeClass 'active'
            $('#tabs ul.mode-disconnected .tab_landing a').click()
        else
            $('#tabs ul.mode-disconnected .tab_firmware_flasher a').click()
            $('div#flashbutton a.flash_state').addClass 'active'
            $('div#flashbutton a.flash').addClass 'active'
        return
    # auto-connect
    ConfigStorage.get 'auto_connect', (result) ->
        if result.auto_connect == 'undefined' or result.auto_connect
            # default or enabled by user
            GUI.auto_connect = true
            $('input.auto_connect').prop 'checked', true
            $('input.auto_connect, span.auto_connect').prop 'title', i18n.getMessage('autoConnectEnabled')
            $('select#baud').val(115200).prop 'disabled', true
        else
            # disabled by user
            GUI.auto_connect = false
            $('input.auto_connect').prop 'checked', false
            $('input.auto_connect, span.auto_connect').prop 'title', i18n.getMessage('autoConnectDisabled')
        # bind UI hook to auto-connect checkbos
        $('input.auto_connect').change ->
            GUI.auto_connect = $(this).is(':checked')
            # update title/tooltip
            if GUI.auto_connect
                $('input.auto_connect, span.auto_connect').prop 'title', i18n.getMessage('autoConnectEnabled')
                $('select#baud').val(115200).prop 'disabled', true
            else
                $('input.auto_connect, span.auto_connect').prop 'title', i18n.getMessage('autoConnectDisabled')
                if !GUI.connected_to and !GUI.connecting_to
                    $('select#baud').prop 'disabled', false
            ConfigStorage.set 'auto_connect': GUI.auto_connect
            return
        return
    PortHandler.initialize()
    PortUsage.initialize()
    return

finishClose = (finishedCallback) ->
    wasConnected = CONFIGURATOR.connectionValid
    analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'Disconnected'
    if connectionTimestamp
        connectedTime = Date.now() - connectionTimestamp
        analytics.sendTiming analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'Connected', connectedTime
        connectedTime = undefined
    analytics.resetFlightControllerData()
    serial.disconnect onClosed
    MSP.disconnect_cleanup()
    PortUsage.reset()
    GUI.connected_to = false
    GUI.allowedTabs = GUI.defaultAllowedTabsWhenDisconnected.slice()
    # Reset various UI elements
    $('span.i2c-error').text 0
    $('span.cycle-time').text 0
    if semver.gte(CONFIG.apiVersion, '1.20.0')
        $('span.cpu-load').text ''
    # unlock port select & baud
    $('div#port-picker #port').prop 'disabled', false
    if !GUI.auto_connect
        $('div#port-picker #baud').prop 'disabled', false
    # reset connect / disconnect button
    $('div.connect_controls a.connect').removeClass 'active'
    $('div.connect_controls a.connect_state').text i18n.getMessage('connect')
    # reset active sensor indicators
    sensor_status 0
    if wasConnected
        # detach listeners and remove element data
        $('#content').empty()
    $('#tabs .tab_landing a').click()
    finishedCallback()
    return

onOpen = (openInfo) ->
    if openInfo
        # update connected_to
        GUI.connected_to = GUI.connecting_to
        # reset connecting_to
        GUI.connecting_to = false
        GUI.log i18n.getMessage('serialPortOpened', [ openInfo.connectionId ])
        # save selected port with chrome.storage if the port differs
        ConfigStorage.get 'last_used_port', (result) ->
            if result.last_used_port
                if result.last_used_port != GUI.connected_to
                    # last used port doesn't match the one found in local db, we will store the new one
                    ConfigStorage.set 'last_used_port': GUI.connected_to
            else
                # variable isn't stored yet, saving
                ConfigStorage.set 'last_used_port': GUI.connected_to
            return
        serial.onReceive.addListener read_serial
        # disconnect after 10 seconds with error if we don't get IDENT data
        GUI.timeout_add 'connecting', (->
            if !CONFIGURATOR.connectionValid
                GUI.log i18n.getMessage('noConfigurationReceived')
                $('div.connect_controls a.connect').click()
                # disconnect
            return
        ), 10000
        FC.resetState()
        MSP.listen update_packet_error
        mspHelper = new MspHelper
        MSP.listen mspHelper.process_data.bind(mspHelper)
        # request configuration data
        MSP.send_message MSPCodes.MSP_API_VERSION, false, false, ->
            analytics.setFlightControllerData analytics.DATA.API_VERSION, CONFIG.apiVersion
            GUI.log i18n.getMessage('apiVersionReceived', [ CONFIG.apiVersion ])
            if semver.gte(CONFIG.apiVersion, CONFIGURATOR.apiVersionAccepted)
                MSP.send_message MSPCodes.MSP_FC_VARIANT, false, false, ->
                    analytics.setFlightControllerData analytics.DATA.FIRMWARE_TYPE, CONFIG.flightControllerIdentifier
                    if CONFIG.flightControllerIdentifier == 'ORNI'
                        MSP.send_message MSPCodes.MSP_FC_VERSION, false, false, ->
                            analytics.setFlightControllerData analytics.DATA.FIRMWARE_VERSION, CONFIG.flightControllerVersion
                            GUI.log i18n.getMessage('fcInfoReceived', [
                                CONFIG.flightControllerIdentifier
                                CONFIG.flightControllerVersion
                            ])
                            updateStatusBarVersion CONFIG.flightControllerVersion, CONFIG.flightControllerIdentifier
                            updateTopBarVersion CONFIG.flightControllerVersion, CONFIG.flightControllerIdentifier
                            MSP.send_message MSPCodes.MSP_BUILD_INFO, false, false, ->
                                GUI.log i18n.getMessage('buildInfoReceived', [ CONFIG.buildInfo ])
                                MSP.send_message MSPCodes.MSP_BOARD_INFO, false, false, ->
                                    analytics.setFlightControllerData analytics.DATA.BOARD_TYPE, CONFIG.boardIdentifier
                                    analytics.setFlightControllerData analytics.DATA.TARGET_NAME, CONFIG.targetName
                                    analytics.setFlightControllerData analytics.DATA.BOARD_NAME, CONFIG.boardName
                                    analytics.setFlightControllerData analytics.DATA.MANUFACTURER_ID, CONFIG.manufacturerId
                                    analytics.setFlightControllerData analytics.DATA.MCU_TYPE, FC.getMcuType()
                                    GUI.log i18n.getMessage('boardInfoReceived', [
                                        FC.getHardwareName()
                                        CONFIG.boardVersion
                                    ])
                                    updateStatusBarVersion CONFIG.flightControllerVersion, CONFIG.flightControllerIdentifier, FC.getHardwareName()
                                    updateTopBarVersion CONFIG.flightControllerVersion, CONFIG.flightControllerIdentifier, FC.getHardwareName()
                                    if bit_check(CONFIG.targetCapabilities, FC.TARGET_CAPABILITIES_FLAGS.SUPPORTS_CUSTOM_DEFAULTS) and bit_check(CONFIG.targetCapabilities, FC.TARGET_CAPABILITIES_FLAGS.HAS_CUSTOM_DEFAULTS) and CONFIG.configurationState == FC.CONFIGURATION_STATES.DEFAULTS_BARE
                                        dialog = $('#dialogResetToCustomDefaults')[0]
                                        $('#dialogResetToCustomDefaults-content').html i18n.getMessage('resetToCustomDefaultsDialog')
                                        $('#dialogResetToCustomDefaults-acceptbtn').click ->
                                            analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'AcceptResetToCustomDefaults'
                                            buffer = []
                                            buffer.push mspHelper.RESET_TYPES.CUSTOM_DEFAULTS
                                            MSP.send_message MSPCodes.MSP_RESET_CONF, buffer, false
                                            dialog.close()
                                            return
                                        $('#dialogResetToCustomDefaults-cancelbtn').click ->
                                            analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'CancelResetToCustomDefaults'
                                            dialog.close()
                                            return
                                        dialog.showModal()
                                    MSP.send_message MSPCodes.MSP_UID, false, false, ->
                                        uniqueDeviceIdentifier = CONFIG.uid[0].toString(16) + CONFIG.uid[1].toString(16) + CONFIG.uid[2].toString(16)
                                        analytics.setFlightControllerData analytics.DATA.MCU_ID, objectHash.sha1(uniqueDeviceIdentifier)
                                        analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'Connected'
                                        connectionTimestamp = Date.now()
                                        GUI.log i18n.getMessage('uniqueDeviceIdReceived', [ uniqueDeviceIdentifier ])
                                        if semver.gte(CONFIG.apiVersion, '1.20.0')
                                            MSP.send_message MSPCodes.MSP_NAME, false, false, ->
                                                GUI.log i18n.getMessage('craftNameReceived', [ CONFIG.name ])
                                                CONFIG.armingDisabled = false
                                                mspHelper.setArmingEnabled false, false, setRtc
                                                return
                                        else
                                            setRtc()
                                        return
                                    return
                                return
                            return
                    else
                        analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'ConnectionRefusedFirmwareType'
                        dialog = $('.dialogConnectWarning')[0]
                        $('.dialogConnectWarning-content').html i18n.getMessage('firmwareTypeNotSupported')
                        $('.dialogConnectWarning-closebtn').click ->
                            dialog.close()
                            return
                        dialog.showModal()
                        connectCli()
                    return
            else
                analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'ConnectionRefusedFirmwareVersion'
                dialog = $('.dialogConnectWarning')[0]
                $('.dialogConnectWarning-content').html i18n.getMessage('firmwareVersionNotSupported', [ CONFIGURATOR.apiVersionAccepted ])
                $('.dialogConnectWarning-closebtn').click ->
                    dialog.close()
                    return
                dialog.showModal()
                connectCli()
            return
    else
        analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'SerialPortFailed'
        console.log 'Failed to open serial port'
        GUI.log i18n.getMessage('serialPortOpenFail')
        $('div#connectbutton a.connect_state').text i18n.getMessage('connect')
        $('div#connectbutton a.connect').removeClass 'active'
        # unlock port select & baud
        $('div#port-picker #port, div#port-picker #baud, div#port-picker #delay').prop 'disabled', false
        # reset data
        $('div#connectbutton a.connect').data 'clicks', false
    return

setRtc = ->
    if semver.gte(CONFIG.apiVersion, '1.37.0')
        MSP.send_message MSPCodes.MSP_SET_RTC, mspHelper.crunch(MSPCodes.MSP_SET_RTC), false, finishOpen
    else
        finishOpen()
    return

finishOpen = ->
    CONFIGURATOR.connectionValid = true
    GUI.allowedTabs = GUI.defaultAllowedFCTabsWhenConnected.slice()
    if semver.lt(CONFIG.apiVersion, '1.4.0')
        GUI.allowedTabs.splice GUI.allowedTabs.indexOf('led_strip'), 1
    onConnect()
    GUI.selectDefaultTabWhenConnected()
    return

connectCli = ->
    CONFIGURATOR.connectionValid = true
    # making it possible to open the CLI tab
    GUI.allowedTabs = [ 'cli' ]
    onConnect()
    $('#tabs .tab_cli a').click()
    return

onConnect = ->
    if $('div#flashbutton a.flash_state').hasClass('active') and $('div#flashbutton a.flash').hasClass('active')
        $('div#flashbutton a.flash_state').removeClass 'active'
        $('div#flashbutton a.flash').removeClass 'active'
    GUI.timeout_remove 'connecting'
    # kill connecting timer
    $('div#connectbutton a.connect_state').text(i18n.getMessage('disconnect')).addClass 'active'
    $('div#connectbutton a.connect').addClass 'active'
    $('#tabs ul.mode-disconnected').hide()
    $('#tabs ul.mode-connected-cli').show()
    # show only appropriate tabs
    $('#tabs ul.mode-connected li').hide()
    $('#tabs ul.mode-connected li').filter((index) ->
        classes = $(this).attr('class').split(/\s+/)
        found = false
        $.each GUI.allowedTabs, (index, value) ->
            tabName = 'tab_' + value
            if $.inArray(tabName, classes) >= 0
                found = true
            return
        if CONFIG.boardType == 0
            if classes.indexOf('osd-required') >= 0
                found = false
        found
    ).show()
    if CONFIG.flightControllerVersion != ''
        FEATURE_CONFIG.features = new Features(CONFIG)
        BEEPER_CONFIG.beepers = new Beepers(CONFIG)
        BEEPER_CONFIG.dshotBeaconConditions = new Beepers(CONFIG, [
            'RX_LOST'
            'RX_SET'
        ])
        $('#tabs ul.mode-connected').show()
        MSP.send_message MSPCodes.MSP_FEATURE_CONFIG, false, false
        if semver.gte(CONFIG.apiVersion, '1.33.0')
            MSP.send_message MSPCodes.MSP_BATTERY_CONFIG, false, false
        MSP.send_message MSPCodes.MSP_STATUS_EX, false, false
        MSP.send_message MSPCodes.MSP_DATAFLASH_SUMMARY, false, false
        if CONFIG.boardType == 0 or CONFIG.boardType == 2
            startLiveDataRefreshTimer()
    sensor_state = $('#sensor-status')
    sensor_state.show()
    port_picker = $('#portsinput')
    port_picker.hide()
    dataflash = $('#dataflash_wrapper_global')
    dataflash.show()
    return

onClosed = (result) ->
    if result
        # All went as expected
        GUI.log i18n.getMessage('serialPortClosedOk')
    else
        # Something went wrong
        GUI.log i18n.getMessage('serialPortClosedFail')
    $('#tabs ul.mode-connected').hide()
    $('#tabs ul.mode-connected-cli').hide()
    $('#tabs ul.mode-disconnected').show()
    updateStatusBarVersion()
    updateTopBarVersion()
    sensor_state = $('#sensor-status')
    sensor_state.hide()
    port_picker = $('#portsinput')
    port_picker.show()
    dataflash = $('#dataflash_wrapper_global')
    dataflash.hide()
    battery = $('#quad-status_wrapper')
    battery.hide()
    MSP.clearListeners()
    CONFIGURATOR.connectionValid = false
    CONFIGURATOR.cliValid = false
    CONFIGURATOR.cliActive = false
    return

read_serial = (info) ->
    if !CONFIGURATOR.cliActive
        MSP.read info
    else if CONFIGURATOR.cliActive
        TABS.cli.read info
    return

sensor_status = (sensors_detected) ->
    # initialize variable (if it wasn't)
    if !sensor_status.previous_sensors_detected
        sensor_status.previous_sensors_detected = -1
        # Otherwise first iteration will not be run if sensors_detected == 0
    # update UI (if necessary)
    if sensor_status.previous_sensors_detected == sensors_detected
        return
    # set current value
    sensor_status.previous_sensors_detected = sensors_detected
    e_sensor_status = $('div#sensor-status')
    if have_sensor(sensors_detected, 'acc')
        $('.accel', e_sensor_status).addClass 'on'
        $('.accicon', e_sensor_status).addClass 'active'
    else
        $('.accel', e_sensor_status).removeClass 'on'
        $('.accicon', e_sensor_status).removeClass 'active'
    if (CONFIG.boardType == 0 or CONFIG.boardType == 2) and have_sensor(sensors_detected, 'gyro')
        $('.gyro', e_sensor_status).addClass 'on'
        $('.gyroicon', e_sensor_status).addClass 'active'
    else
        $('.gyro', e_sensor_status).removeClass 'on'
        $('.gyroicon', e_sensor_status).removeClass 'active'
    if have_sensor(sensors_detected, 'baro')
        $('.baro', e_sensor_status).addClass 'on'
        $('.baroicon', e_sensor_status).addClass 'active'
    else
        $('.baro', e_sensor_status).removeClass 'on'
        $('.baroicon', e_sensor_status).removeClass 'active'
    if have_sensor(sensors_detected, 'mag')
        $('.mag', e_sensor_status).addClass 'on'
        $('.magicon', e_sensor_status).addClass 'active'
    else
        $('.mag', e_sensor_status).removeClass 'on'
        $('.magicon', e_sensor_status).removeClass 'active'
    if have_sensor(sensors_detected, 'gps')
        $('.gps', e_sensor_status).addClass 'on'
        $('.gpsicon', e_sensor_status).addClass 'active'
    else
        $('.gps', e_sensor_status).removeClass 'on'
        $('.gpsicon', e_sensor_status).removeClass 'active'
    if have_sensor(sensors_detected, 'sonar')
        $('.sonar', e_sensor_status).addClass 'on'
        $('.sonaricon', e_sensor_status).addClass 'active'
    else
        $('.sonar', e_sensor_status).removeClass 'on'
        $('.sonaricon', e_sensor_status).removeClass 'active'
    return

have_sensor = (sensors_detected, sensor_code) ->
    if sensor_code == 'acc'
        return bit_check(sensors_detected, 0)
    else if sensor_code == 'baro'
        return bit_check(sensors_detected, 1)
    else if sensor_code == 'mag'
        return bit_check(sensors_detected, 2)
    else if sensor_code == 'gps'
        return bit_check(sensors_detected, 3)
    else if sensor_code == 'sonar'
        return bit_check(sensors_detected, 4)
    else if sensor_code == 'gyro'
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            return bit_check(sensors_detected, 5)
        else
            return true
    false

startLiveDataRefreshTimer = ->
    # live data refresh
    GUI.timeout_add 'data_refresh', (->
        update_live_status()
        return
    ), 100
    return

update_live_status = ->
    statuswrapper = $('#quad-status_wrapper')
    $('.quad-status-contents').css display: 'inline-block'
    if GUI.active_tab != 'cli'
        MSP.send_message MSPCodes.MSP_BOXNAMES, false, false
        if semver.gte(CONFIG.apiVersion, '1.32.0')
            MSP.send_message MSPCodes.MSP_STATUS_EX, false, false
        else
            MSP.send_message MSPCodes.MSP_STATUS, false, false
        MSP.send_message MSPCodes.MSP_ANALOG, false, false
    active = Date.now() - (ANALOG.last_received_timestamp) < 300
    i = 0
    while i < AUX_CONFIG.length
        if AUX_CONFIG[i] == 'ARM'
            if bit_check(CONFIG.mode, i)
                $('.armedicon').css 'background-image': 'url(images/icons/cf_icon_armed_active.svg)'
            else
                $('.armedicon').css 'background-image': 'url(images/icons/cf_icon_armed_grey.svg)'
        if AUX_CONFIG[i] == 'FAILSAFE'
            if bit_check(CONFIG.mode, i)
                $('.failsafeicon').css 'background-image': 'url(images/icons/cf_icon_failsafe_active.svg)'
            else
                $('.failsafeicon').css 'background-image': 'url(images/icons/cf_icon_failsafe_grey.svg)'
        i++
    if ANALOG != undefined
        nbCells = Math.floor(ANALOG.voltage / BATTERY_CONFIG.vbatmaxcellvoltage) + 1
        if ANALOG.voltage == 0
            nbCells = 1
        min = BATTERY_CONFIG.vbatmincellvoltage * nbCells
        max = BATTERY_CONFIG.vbatmaxcellvoltage * nbCells
        warn = BATTERY_CONFIG.vbatwarningcellvoltage * nbCells
        $('.battery-status').css
            width: (ANALOG.voltage - min) / (max - min) * 100 + '%'
            display: 'inline-block'
        if active
            $('.linkicon').css 'background-image': 'url(images/icons/cf_icon_link_active.svg)'
        else
            $('.linkicon').css 'background-image': 'url(images/icons/cf_icon_link_grey.svg)'
        if ANALOG.voltage < warn
            $('.battery-status').css 'background-color', '#D42133'
        else
            $('.battery-status').css 'background-color', '#59AA29'
        $('.battery-legend').text ANALOG.voltage + ' V'
    statuswrapper.show()
    GUI.timeout_remove 'data_refresh'
    startLiveDataRefreshTimer()
    return

specificByte = (num, pos) ->
    0x000000FF & num >> 8 * pos

bit_check = (num, bit) ->
    (num >> bit) % 2 != 0

bit_set = (num, bit) ->
    num | 1 << bit

bit_clear = (num, bit) ->
    num & ~(1 << bit)

update_dataflash_global = ->
    supportsDataflash = DATAFLASH.totalSize > 0

    formatFilesize = (bytes) ->
        if bytes < 1024
            return bytes + 'B'
        kilobytes = bytes / 1024
        if kilobytes < 1024
            return Math.round(kilobytes) + 'kB'
        megabytes = kilobytes / 1024
        megabytes.toFixed(1) + 'MB'

    if supportsDataflash
        $('.noflash_global').css display: 'none'
        $('.dataflash-contents_global').css display: 'block'
        $('.dataflash-free_global').css
            width: 100 - ((DATAFLASH.totalSize - (DATAFLASH.usedSize)) / DATAFLASH.totalSize * 100) + '%'
            display: 'block'
        $('.dataflash-free_global div').text 'Dataflash: free ' + formatFilesize(DATAFLASH.totalSize - (DATAFLASH.usedSize))
    else
        $('.noflash_global').css display: 'block'
        $('.dataflash-contents_global').css display: 'none'
    return

reinitialiseConnection = (originatorTab, callback) ->
    GUI.log i18n.getMessage('deviceRebooting')
    if FC.boardHasVcp()
        # VCP-based flight controls may crash old drivers, we catch and reconnect
        GUI.timeout_add 'waiting_for_disconnect', (->
            if callback
                callback()
            return
        ), 100
        #TODO: Need to work out how to do a proper reconnect here.
        # caveat: Timeouts set with `GUI.timeout_add()` are removed on disconnect.
    else
        GUI.timeout_add 'waiting_for_bootup', (->
            if callback
                callback()
            MSP.send_message MSPCodes.MSP_STATUS, false, false, ->
                GUI.log i18n.getMessage('deviceReady')
                originatorTab.initialize false, $('#content').scrollTop()
                return
            return
        ), 1500
        # 1500 ms seems to be just the right amount of delay to prevent data request timeouts
    return

'use strict'
mspHelper = undefined
connectionTimestamp = undefined

