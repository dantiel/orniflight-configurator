'use strict'
TABS.setup = yaw_fix: 0.0

TABS.setup.initialize = (callback) ->
    self = this

    load_status = ->
        MSP.send_message MSPCodes.MSP_STATUS, false, false, load_mixer_config
        return

    load_mixer_config = ->
        MSP.send_message MSPCodes.MSP_MIXER_CONFIG, false, false, load_html
        return

    load_html = ->
        $('#content').load './tabs/setup.html', process_html
        return

    process_html = ->
        # translate to user-selected language

        get_slow_data = ->
            MSP.send_message MSPCodes.MSP_STATUS, false, false, ->
                $('#initialSetupArmingAllowed').toggle CONFIG.armingDisableFlags == 0
                i = 0
                while i < CONFIG.armingDisableCount
                    $('#initialSetupArmingDisableFlags' + i).css 'display', if (CONFIG.armingDisableFlags & 1 << i) == 0 then 'none' else 'inline-block'
                    i++
                return
            MSP.send_message MSPCodes.MSP_ANALOG, false, false, ->
                bat_voltage_e.text i18n.getMessage('initialSetupBatteryValue', [ ANALOG.voltage ])
                bat_mah_drawn_e.text i18n.getMessage('initialSetupBatteryMahValue', [ ANALOG.mAhdrawn ])
                bat_mah_drawing_e.text i18n.getMessage('initialSetupBatteryAValue', [ ANALOG.amperage.toFixed(2) ])
                rssi_e.text i18n.getMessage('initialSetupRSSIValue', [ (ANALOG.rssi / 1023 * 100).toFixed(0) ])
                return
            if have_sensor(CONFIG.activeSensors, 'gps')
                MSP.send_message MSPCodes.MSP_RAW_GPS, false, false, ->
                    gpsFix_e.html if GPS_DATA.fix then i18n.getMessage('gpsFixTrue') else i18n.getMessage('gpsFixFalse')
                    gpsSats_e.text GPS_DATA.numSat
                    gpsLat_e.text (GPS_DATA.lat / 10000000).toFixed(4) + ' deg'
                    gpsLon_e.text (GPS_DATA.lon / 10000000).toFixed(4) + ' deg'
                    return
            return

        get_fast_data = ->
            MSP.send_message MSPCodes.MSP_RC, false, false, ->
                MSP.send_message MSPCodes.MSP_ATTITUDE, false, false, ->
                    roll_e.text i18n.getMessage('initialSetupAttitude', [ SENSOR_DATA.kinematics[0] ])
                    pitch_e.text i18n.getMessage('initialSetupAttitude', [ SENSOR_DATA.kinematics[1] ])
                    heading_e.text i18n.getMessage('initialSetupAttitude', [ SENSOR_DATA.kinematics[2] ])
                    self.renderModel()
                    self.updateInstruments()
                    return
                # Poll live servo positions for 3D model + waveform debugging
                MSP.send_message MSPCodes.MSP_SERVO, false, false, ->
                    if self.model and typeof SERVO_DATA != 'undefined'
                        self.model.setServoPositions SERVO_DATA
                    return
                return
            return

        # 4 fps
        # Model animation loop — always runs, uses demo defaults when no FC

        animate_model = ->
            self.renderModel()
            return

        i18n.localizePage()
        if semver.lt(CONFIG.apiVersion, CONFIGURATOR.backupRestoreMinApiVersionAccepted)
            $('#content .backup').addClass 'disabled'
            $('#content .restore').addClass 'disabled'
            GUI.log i18n.getMessage('initialSetupBackupAndRestoreApiVersion', [
                CONFIG.apiVersion
                CONFIGURATOR.backupRestoreMinApiVersionAccepted
            ])
        # initialize 3D Model
        self.initModel()
        # set roll in interactive block
        $('span.roll').text i18n.getMessage('initialSetupAttitude', [ 0 ])
        # set pitch in interactive block
        $('span.pitch').text i18n.getMessage('initialSetupAttitude', [ 0 ])
        # set heading in interactive block
        $('span.heading').text i18n.getMessage('initialSetupAttitude', [ 0 ])
        # check if we have accelerometer and magnetometer
        if !have_sensor(CONFIG.activeSensors, 'acc')
            $('a.calibrateAccel').addClass 'disabled'
            $('default_btn').addClass 'disabled'
        if !have_sensor(CONFIG.activeSensors, 'mag')
            $('a.calibrateMag').addClass 'disabled'
            $('default_btn').addClass 'disabled'
        self.initializeInstruments()
        $('#arming-disable-flag').attr 'title', i18n.getMessage('initialSetupArmingDisableFlagsTooltip')
        if semver.gte(CONFIG.apiVersion, '1.40.0')
            if isExpertModeEnabled()
                $('.initialSetupRebootBootloader').show()
            else
                $('.initialSetupRebootBootloader').hide()
            $('a.rebootBootloader').click ->
                buffer = []
                buffer.push mspHelper.REBOOT_TYPES.BOOTLOADER
                MSP.send_message MSPCodes.MSP_SET_REBOOT, buffer, false
                return
        else
            $('.initialSetupRebootBootloader').hide()
        # UI Hooks
        $('a.calibrateAccel').click ->
            `var self`
            self = $(this)
            if !self.hasClass('calibrating')
                self.addClass 'calibrating'
                # During this period MCU won't be able to process any serial commands because its locked in a for/while loop
                # until this operation finishes, sending more commands through data_poll() will result in serial buffer overflow
                GUI.interval_pause 'setup_data_pull'
                MSP.send_message MSPCodes.MSP_ACC_CALIBRATION, false, false, ->
                    GUI.log i18n.getMessage('initialSetupAccelCalibStarted')
                    $('#accel_calib_running').show()
                    $('#accel_calib_rest').hide()
                    return
                GUI.timeout_add 'button_reset', (->
                    GUI.interval_resume 'setup_data_pull'
                    GUI.log i18n.getMessage('initialSetupAccelCalibEnded')
                    self.removeClass 'calibrating'
                    $('#accel_calib_running').hide()
                    $('#accel_calib_rest').show()
                    return
                ), 2000
            return
        $('a.calibrateMag').click ->
            `var self`
            self = $(this)
            if !self.hasClass('calibrating') and !self.hasClass('disabled')
                self.addClass 'calibrating'
                MSP.send_message MSPCodes.MSP_MAG_CALIBRATION, false, false, ->
                    GUI.log i18n.getMessage('initialSetupMagCalibStarted')
                    $('#mag_calib_running').show()
                    $('#mag_calib_rest').hide()
                    return
                GUI.timeout_add 'button_reset', (->
                    GUI.log i18n.getMessage('initialSetupMagCalibEnded')
                    self.removeClass 'calibrating'
                    $('#mag_calib_running').hide()
                    $('#mag_calib_rest').show()
                    return
                ), 30000
            return
        dialogConfirmReset = $('.dialogConfirmReset')[0]
        $('a.resetSettings').click ->
            dialogConfirmReset.showModal()
            return
        $('.dialogConfirmReset-cancelbtn').click ->
            dialogConfirmReset.close()
            return
        $('.dialogConfirmReset-confirmbtn').click ->
            dialogConfirmReset.close()
            MSP.send_message MSPCodes.MSP_RESET_CONF, false, false, ->
                GUI.log i18n.getMessage('initialSetupSettingsRestored')
                GUI.tab_switch_cleanup ->
                    TABS.setup.initialize()
                    return
                return
            return
        # display current yaw fix value (important during tab re-initialization)
        $('div#interactive_block > a.reset').text i18n.getMessage('initialSetupButtonResetZaxisValue', [ self.yaw_fix ])
        # reset yaw button hook
        $('div#interactive_block > a.reset').click ->
            self.yaw_fix = SENSOR_DATA.kinematics[2] * -1.0
            $(this).text i18n.getMessage('initialSetupButtonResetZaxisValue', [ self.yaw_fix ])
            console.log 'YAW reset to 0 deg, fix: ' + self.yaw_fix + ' deg'
            return
        $('#content .backup').click ->
            if $(this).hasClass('disabled')
                return
            configuration_backup ->
                GUI.log i18n.getMessage('initialSetupBackupSuccess')
                return
            return
        $('#content .restore').click ->
            if $(this).hasClass('disabled')
                return
            configuration_restore ->
                # get latest settings
                TABS.setup.initialize()
                GUI.log i18n.getMessage('initialSetupRestoreSuccess')
                return
            return
        # cached elements
        bat_voltage_e = $('.bat-voltage')
        bat_mah_drawn_e = $('.bat-mah-drawn')
        bat_mah_drawing_e = $('.bat-mah-drawing')
        rssi_e = $('.rssi')
        arming_disable_flags_e = $('.arming-disable-flags')
        gpsFix_e = $('.gpsFix')
        gpsSats_e = $('.gpsSats')
        gpsLat_e = $('.gpsLat')
        gpsLon_e = $('.gpsLon')
        roll_e = $('dd.roll')
        pitch_e = $('dd.pitch')
        heading_e = $('dd.heading')
        if semver.lt(CONFIG.apiVersion, '1.36.0')
            arming_disable_flags_e.hide()
        # DISARM FLAGS
        # We add all the arming/disarming flags available, and show/hide them if needed.

        prepareDisarmFlags = ->
            disarmFlagElements = [
                'NO_GYRO'
                'FAILSAFE'
                'RX_FAILSAFE'
                'BAD_RX_RECOVERY'
                'BOXFAILSAFE'
                'THROTTLE'
                'ANGLE'
                'BOOT_GRACE_TIME'
                'NOPREARM'
                'LOAD'
                'CALIBRATING'
                'CLI'
                'CMS_MENU'
                'OSD_MENU'
                'BST'
                'MSP'
            ]
            if semver.gte(CONFIG.apiVersion, '1.38.0')
                disarmFlagElements.splice disarmFlagElements.indexOf('THROTTLE'), 0, 'RUNAWAY_TAKEOFF'
            if semver.gte(CONFIG.apiVersion, '1.39.0')
                disarmFlagElements = disarmFlagElements.concat([
                    'PARALYZE'
                    'GPS'
                ])
            if semver.gte(CONFIG.apiVersion, '1.41.0')
                disarmFlagElements.splice disarmFlagElements.indexOf('OSD_MENU'), 1
                disarmFlagElements = disarmFlagElements.concat([ 'RESC' ])
                disarmFlagElements = disarmFlagElements.concat([ 'RPMFILTER' ])
            if semver.gte(CONFIG.apiVersion, '1.42.0')
                disarmFlagElements.splice disarmFlagElements.indexOf('THROTTLE'), 0, 'CRASH'
                disarmFlagElements = disarmFlagElements.concat([
                    'REBOOT_REQD'
                    'DSHOT_BBANG'
                ])
            # Always the latest element
            disarmFlagElements = disarmFlagElements.concat([ 'ARM_SWITCH' ])
            # Arming allowed flag
            arming_disable_flags_e.append '<span id="initialSetupArmingAllowed" i18n="initialSetupArmingAllowed" style="display: none;"/>'
            # Arming disabled flags
            i = 0
            while i < CONFIG.armingDisableCount
                # All the known elements but the ARM_SWITCH (it must be always the last element)
                if i < disarmFlagElements.length - 1
                    arming_disable_flags_e.append '<span id="initialSetupArmingDisableFlags' + i + '" class="cf_tip disarm-flag" title="' + i18n.getMessage('initialSetupArmingDisableFlagsTooltip' + disarmFlagElements[i]) + '" style="display: none;">' + disarmFlagElements[i] + '</span>'
                    # The ARM_SWITCH, always the last element
                else if i == CONFIG.armingDisableCount - 1
                    arming_disable_flags_e.append '<span id="initialSetupArmingDisableFlags' + i + '" class="cf_tip disarm-flag" title="' + i18n.getMessage('initialSetupArmingDisableFlagsTooltipARM_SWITCH') + '" style="display: none;">ARM_SWITCH</span>'
                    # Unknown disarm flags
                else
                    arming_disable_flags_e.append '<span id="initialSetupArmingDisableFlags' + i + '" class="disarm-flag" style="display: none;">' + i + 1 + '</span>'
                i++
            return

        prepareDisarmFlags()
        GUI.interval_add 'setup_data_pull_fast', get_fast_data, 33, true
        # 30 fps
        GUI.interval_add 'setup_data_pull_slow', get_slow_data, 250, true
        GUI.interval_add 'setup_model_animate', animate_model, 33, true
        GUI.content_ready callback
        return

    if GUI.active_tab != 'setup'
        GUI.active_tab = 'setup'
    MSP.send_message MSPCodes.MSP_ACC_TRIM, false, false, load_status
    return

TABS.setup.initializeInstruments = ->
    options = 
        size: 90
        showBox: false
        img_directory: 'images/flightindicators/'
    attitude = $.flightIndicator('#attitude', 'attitude', options)
    heading = $.flightIndicator('#heading', 'heading', options)

    @updateInstruments = ->
        attitude.setRoll SENSOR_DATA.kinematics[0]
        attitude.setPitch SENSOR_DATA.kinematics[1]
        heading.setHeading SENSOR_DATA.kinematics[2]
        return

    return

TABS.setup.initModel = ->
    @model = new Model($('.model-and-info #canvas_wrapper'), $('.model-and-info #canvas'), $('.model-and-info #wave-canvas'))
    $(window).on 'resize', $.proxy(@model.resize, @model)
    return

TABS.setup.renderModel = ->
    `var x`
    `var z`
    `var y`
    hasFC = typeof SENSOR_DATA != 'undefined' and SENSOR_DATA.kinematics
    now = performance.now()
    if hasFC
        x = SENSOR_DATA.kinematics[1] * -1.0 * 0.017453292519943295
        y = (SENSOR_DATA.kinematics[2] * -1.0 - (@yaw_fix)) * 0.017453292519943295
        z = SENSOR_DATA.kinematics[0] * -1.0 * 0.017453292519943295
    else
        # Demo mode: slow gyro sweep for visual testing without FC
        t = now * 0.001
        x = Math.sin(t * 0.7) * 0.25
        z = Math.cos(t * 0.5) * 0.2
        y = Math.sin(t * 0.3) * 0.4
    @model.rotateTo x, y, z
    # Pass flap state — use live FC data or sensible demo defaults
    throttle = undefined
    yaw = undefined
    freq = undefined
    amp = undefined
    ferocityD = undefined
    ferocityU = undefined
    phaseShifts = [
        0
        0
        0
        0
    ]
    mountAngles = [
        0
        0
        0
        0
    ]
    svCnt = undefined
    if hasFC and typeof ADVANCED_TUNING != 'undefined'
        throttle = if typeof RC != 'undefined' and RC.channels and RC.channels.length > 2 then RC.channels[2] else 1280
        yaw = if typeof RC != 'undefined' and RC.channels and RC.channels.length > 3 then RC.channels[3] else 1500
        freq = ADVANCED_TUNING.ornithopter_freq_min or 6
        amp = ADVANCED_TUNING.servo_max_amplitude or 55
        ferocityD = (ADVANCED_TUNING.ferocity_d_gain or 20) * 0.08
        ferocityU = (ADVANCED_TUNING.ferocity_p_gain or 10) * 0.08
        phaseShifts = [
            ADVANCED_TUNING.flapping_phase_shift_0 or 0
            ADVANCED_TUNING.flapping_phase_shift_1 or 0
            ADVANCED_TUNING.flapping_phase_shift_2 or 0
            ADVANCED_TUNING.flapping_phase_shift_3 or 0
        ]
        mountAngles = [
            ADVANCED_TUNING.servo_mount_angle_0 or 0
            ADVANCED_TUNING.servo_mount_angle_1 or 0
            ADVANCED_TUNING.servo_mount_angle_2 or 0
            ADVANCED_TUNING.servo_mount_angle_3 or 0
        ]
        svCnt = if typeof SERVO_CONFIG != 'undefined' and SERVO_CONFIG.length then SERVO_CONFIG.length else 4
    else
        # Demo defaults — enough to see flapping + wave plotter
        t2 = now * 0.001
        throttle = 1280 + Math.round(Math.sin(t2 * 0.4 + 0.6) * 400)
        # 880–1680, cyclic
        yaw = 1500 + Math.round(Math.cos(t2 * 0.25) * 300)
        # 1200–1800, cyclic
        freq = 6
        amp = 45
        ferocityD = 3.2
        ferocityU = 1.6
        svCnt = 2
        # default 1 wing pair for demo
    @model.setFlapState
        throttle: throttle
        yaw: yaw
        frequency: freq
        amplitude: amp
        ferocityDown: ferocityD
        ferocityUp: ferocityU
        phaseShifts: phaseShifts
        mountAngles: mountAngles
        servoCount: svCnt
    return

TABS.setup.cleanup = (callback) ->
    if @model
        $(window).off 'resize', $.proxy(@model.resize, @model)
        @model.dispose()
    if callback
        callback()
    return

