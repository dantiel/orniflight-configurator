MspHelper = ->
    self = this
    # 0 based index, must be identical to 'baudRates' in 'src/main/io/serial.c' in firmware
    self.BAUD_RATES = [
        'AUTO'
        '9600'
        '19200'
        '38400'
        '57600'
        '115200'
        '230400'
        '250000'
        '400000'
        '460800'
        '500000'
        '921600'
        '1000000'
        '1500000'
        '2000000'
        '2470000'
    ]
    # needs to be identical to 'serialPortFunction_e' in 'src/main/io/serial.h' in firmware
    self.SERIAL_PORT_FUNCTIONS =
        'MSP': 0
        'GPS': 1
        'TELEMETRY_FRSKY': 2
        'TELEMETRY_HOTT': 3
        'TELEMETRY_MSP': 4
        'TELEMETRY_LTM': 4
        'TELEMETRY_SMARTPORT': 5
        'RX_SERIAL': 6
        'BLACKBOX': 7
        'TELEMETRY_MAVLINK': 9
        'ESC_SENSOR': 10
        'TBS_SMARTAUDIO': 11
        'TELEMETRY_IBUS': 12
        'IRC_TRAMP': 13
        'RUNCAM_DEVICE_CONTROL': 14
        'LIDAR_TF': 15
    self.REBOOT_TYPES =
        FIRMWARE: 0
        BOOTLOADER: 1
        MSC: 2
        MSC_UTC: 3
    self.RESET_TYPES =
        BASE_DEFAULTS: 0
        CUSTOM_DEFAULTS: 1
    self.SIGNATURE_LENGTH = 32
    self.mspMultipleCache = []
    return

'use strict'

MspHelper::reorderPwmProtocols = (protocol) ->
    result = protocol
    if semver.lt(CONFIG.apiVersion, '1.26.0')
        switch protocol
            when 5
                result = 7
            when 7
                result = 5
            else
                break
    result

MspHelper::process_data = (dataHandler) ->
    `var i`
    `var i`
    `var i`
    `var i`
    `var i`
    `var i`
    `var i`
    `var subframe_length`
    `var j`
    `var i`
    `var j`
    `var i`
    `var buff`
    `var i`
    `var char`
    `var i`
    `var i`
    `var i`
    `var arr`
    `var i`
    `var arr`
    `var i`
    `var i`
    `var i`
    `var i`
    `var i`
    `var buff`
    `var i`
    `var i`
    `var identifier`
    `var i`
    `var char`
    `var i`
    `var serialPortCount`
    `var i`
    `var serialPort`
    `var i`
    `var i`
    `var i`
    `var i`
    `var ledOverlayLetters`
    `var i`
    `var functions`
    `var directionMask`
    `var directions`
    `var directionLetterIndex`
    `var led`
    `var i`
    `var colorCount`
    `var i`
    `var flags`
    `var i`
    `var i`
    `var i`
    self = this
    data = dataHandler.dataView
    # DataView (allowing us to view arrayBuffer as struct/union)
    code = dataHandler.code
    if code == 0
        debugger
    crcError = dataHandler.crcError
    if !crcError
        if !dataHandler.unsupported
            switch code
                when MSPCodes.MSP_STATUS
                    CONFIG.cycleTime = data.readU16()
                    CONFIG.i2cError = data.readU16()
                    CONFIG.activeSensors = data.readU16()
                    CONFIG.mode = data.readU32()
                    CONFIG.profile = data.readU8()
                    TABS.pid_tuning.checkUpdateProfile false
                    sensor_status CONFIG.activeSensors
                    $('span.i2c-error').text CONFIG.i2cError
                    $('span.cycle-time').text CONFIG.cycleTime
                when MSPCodes.MSP_STATUS_EX
                    CONFIG.cycleTime = data.readU16()
                    CONFIG.i2cError = data.readU16()
                    CONFIG.activeSensors = data.readU16()
                    CONFIG.mode = data.readU32()
                    CONFIG.profile = data.readU8()
                    CONFIG.cpuload = data.readU16()
                    if semver.gte(CONFIG.apiVersion, '1.16.0')
                        CONFIG.numProfiles = data.readU8()
                        CONFIG.rateProfile = data.readU8()
                        if semver.gte(CONFIG.apiVersion, '1.36.0')
                            # Read flight mode flags
                            byteCount = data.readU8()
                            i = 0
                            while i < byteCount
                                data.readU8()
                                i++
                            # Read arming disable flags
                            CONFIG.armingDisableCount = data.readU8()
                            # Flag count
                            CONFIG.armingDisableFlags = data.readU32()
                        TABS.pid_tuning.checkUpdateProfile true
                    sensor_status CONFIG.activeSensors
                    $('span.i2c-error').text CONFIG.i2cError
                    $('span.cycle-time').text CONFIG.cycleTime
                    $('span.cpu-load').text i18n.getMessage('statusbar_cpu_load', [ CONFIG.cpuload ])
                when MSPCodes.MSP_RAW_IMU
                    # 512 for mpu6050, 256 for mma
                    # currently we are unable to differentiate between the sensor types, so we are goign with 512
                    SENSOR_DATA.accelerometer[0] = data.read16() / 512
                    SENSOR_DATA.accelerometer[1] = data.read16() / 512
                    SENSOR_DATA.accelerometer[2] = data.read16() / 512
                    # properly scaled
                    SENSOR_DATA.gyroscope[0] = data.read16() * 4 / 16.4
                    SENSOR_DATA.gyroscope[1] = data.read16() * 4 / 16.4
                    SENSOR_DATA.gyroscope[2] = data.read16() * 4 / 16.4
                    # no clue about scaling factor
                    SENSOR_DATA.magnetometer[0] = data.read16() / 1090
                    SENSOR_DATA.magnetometer[1] = data.read16() / 1090
                    SENSOR_DATA.magnetometer[2] = data.read16() / 1090
                when MSPCodes.MSP_SERVO
                    servoCount = data.byteLength / 2
                    i = 0
                    while i < servoCount
                        SERVO_DATA[i] = data.readU16()
                        i++
                when MSPCodes.MSP_MOTOR
                    motorCount = data.byteLength / 2
                    i = 0
                    while i < motorCount
                        MOTOR_DATA[i] = data.readU16()
                        i++
                when MSPCodes.MSP_MOTOR_TELEMETRY
                    telemMotorCount = data.readU8()
                    _i = 0
                    while _i < telemMotorCount
                        MOTOR_TELEMETRY_DATA.rpm[_i] = data.readU32()
                        # RPM
                        MOTOR_TELEMETRY_DATA.invalidPercent[_i] = data.readU16()
                        # 10000 = 100.00%
                        MOTOR_TELEMETRY_DATA.temperature[_i] = data.readU8()
                        # degrees celsius
                        MOTOR_TELEMETRY_DATA.voltage[_i] = data.readU16()
                        # 0.01V per unit
                        MOTOR_TELEMETRY_DATA.current[_i] = data.readU16()
                        # 0.01A per unit
                        MOTOR_TELEMETRY_DATA.consumption[_i] = data.readU16()
                        # mAh
                        _i++
                when MSPCodes.MSP_RC
                    RC.active_channels = data.byteLength / 2
                    i = 0
                    while i < RC.active_channels
                        RC.channels[i] = data.readU16()
                        i++
                when MSPCodes.MSP_RAW_GPS
                    GPS_DATA.fix = data.readU8()
                    GPS_DATA.numSat = data.readU8()
                    GPS_DATA.lat = data.read32()
                    GPS_DATA.lon = data.read32()
                    GPS_DATA.alt = data.readU16()
                    GPS_DATA.speed = data.readU16()
                    GPS_DATA.ground_course = data.readU16()
                when MSPCodes.MSP_COMP_GPS
                    GPS_DATA.distanceToHome = data.readU16()
                    GPS_DATA.directionToHome = data.readU16()
                    GPS_DATA.update = data.readU8()
                when MSPCodes.MSP_ATTITUDE
                    SENSOR_DATA.kinematics[0] = data.read16() / 10.0
                    # x
                    SENSOR_DATA.kinematics[1] = data.read16() / 10.0
                    # y
                    SENSOR_DATA.kinematics[2] = data.read16()
                    # z
                when MSPCodes.MSP_ALTITUDE
                    SENSOR_DATA.altitude = parseFloat((data.read32() / 100.0).toFixed(2))
                    # correct scale factor
                when MSPCodes.MSP_SONAR
                    SENSOR_DATA.sonar = data.read32()
                when MSPCodes.MSP_ANALOG
                    ANALOG.voltage = data.readU8() / 10.0
                    ANALOG.mAhdrawn = data.readU16()
                    ANALOG.rssi = data.readU16()
                    # 0-1023
                    ANALOG.amperage = data.read16() / 100
                    # A
                    ANALOG.last_received_timestamp = Date.now()
                    if semver.gte(CONFIG.apiVersion, '1.41.0')
                        ANALOG.voltage = data.readU16() / 100
                when MSPCodes.MSP_VOLTAGE_METERS
                    VOLTAGE_METERS = []
                    voltageMeterLength = 2
                    i = 0
                    while i < data.byteLength / voltageMeterLength
                        voltageMeter = {}
                        voltageMeter.id = data.readU8()
                        voltageMeter.voltage = data.readU8() / 10.0
                        VOLTAGE_METERS.push voltageMeter
                        i++
                when MSPCodes.MSP_CURRENT_METERS
                    CURRENT_METERS = []
                    currentMeterLength = 5
                    i = 0
                    while i < data.byteLength / currentMeterLength
                        currentMeter = {}
                        currentMeter.id = data.readU8()
                        currentMeter.mAhDrawn = data.readU16()
                        # mAh
                        currentMeter.amperage = data.readU16() / 1000
                        # A
                        CURRENT_METERS.push currentMeter
                        i++
                when MSPCodes.MSP_BATTERY_STATE
                    BATTERY_STATE.cellCount = data.readU8()
                    BATTERY_STATE.capacity = data.readU16()
                    # mAh
                    BATTERY_STATE.voltage = data.readU8() / 10.0
                    # V
                    BATTERY_STATE.mAhDrawn = data.readU16()
                    # mAh
                    BATTERY_STATE.amperage = data.readU16() / 100
                    # A
                    if semver.gte(CONFIG.apiVersion, '1.41.0')
                        BATTERY_STATE.batteryState = data.readU8()
                        BATTERY_STATE.voltage = data.readU16() / 100
                when MSPCodes.MSP_VOLTAGE_METER_CONFIG
                    if semver.lt(CONFIG.apiVersion, '1.36.0')
                        MISC.vbatscale = data.readU8()
                        # 10-200
                        MISC.vbatmincellvoltage = data.readU8() / 10
                        # 10-50
                        MISC.vbatmaxcellvoltage = data.readU8() / 10
                        # 10-50
                        MISC.vbatwarningcellvoltage = data.readU8() / 10
                        # 10-50
                        if semver.gte(CONFIG.apiVersion, '1.23.0')
                            MISC.batterymetertype = data.readU8()
                    else
                        VOLTAGE_METER_CONFIGS = []
                        voltage_meter_count = data.readU8()
                        i = 0
                        while i < voltage_meter_count
                            subframe_length = data.readU8()
                            if subframe_length != 5
                                j = 0
                                while j < subframe_length
                                    data.readU8()
                                    j++
                            else
                                voltageMeterConfig = {}
                                voltageMeterConfig.id = data.readU8()
                                voltageMeterConfig.sensorType = data.readU8()
                                voltageMeterConfig.vbatscale = data.readU8()
                                voltageMeterConfig.vbatresdivval = data.readU8()
                                voltageMeterConfig.vbatresdivmultiplier = data.readU8()
                                VOLTAGE_METER_CONFIGS.push voltageMeterConfig
                            i++
                when MSPCodes.MSP_CURRENT_METER_CONFIG
                    if semver.lt(CONFIG.apiVersion, '1.36.0')
                        BF_CONFIG.currentscale = data.read16()
                        BF_CONFIG.currentoffset = data.read16()
                        BF_CONFIG.currentmetertype = data.readU8()
                        BF_CONFIG.batterycapacity = data.readU16()
                    else
                        offset = 0
                        CURRENT_METER_CONFIGS = []
                        current_meter_count = data.readU8()
                        i = 0
                        while i < current_meter_count
                            currentMeterConfig = {}
                            subframe_length = data.readU8()
                            if subframe_length != 6
                                j = 0
                                while j < subframe_length
                                    data.readU8()
                                    j++
                            else
                                currentMeterConfig.id = data.readU8()
                                currentMeterConfig.sensorType = data.readU8()
                                currentMeterConfig.scale = data.read16()
                                currentMeterConfig.offset = data.read16()
                                CURRENT_METER_CONFIGS.push currentMeterConfig
                            i++
                when MSPCodes.MSP_BATTERY_CONFIG
                    BATTERY_CONFIG.vbatmincellvoltage = data.readU8() / 10
                    # 10-50
                    BATTERY_CONFIG.vbatmaxcellvoltage = data.readU8() / 10
                    # 10-50
                    BATTERY_CONFIG.vbatwarningcellvoltage = data.readU8() / 10
                    # 10-50
                    BATTERY_CONFIG.capacity = data.readU16()
                    BATTERY_CONFIG.voltageMeterSource = data.readU8()
                    BATTERY_CONFIG.currentMeterSource = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.41.0')
                        BATTERY_CONFIG.vbatmincellvoltage = data.readU16() / 100
                        BATTERY_CONFIG.vbatmaxcellvoltage = data.readU16() / 100
                        BATTERY_CONFIG.vbatwarningcellvoltage = data.readU16() / 100
                when MSPCodes.MSP_RC_TUNING
                    RC_tuning.RC_RATE = parseFloat((data.readU8() / 100).toFixed(2))
                    RC_tuning.RC_EXPO = parseFloat((data.readU8() / 100).toFixed(2))
                    if semver.lt(CONFIG.apiVersion, '1.7.0')
                        RC_tuning.roll_pitch_rate = parseFloat((data.readU8() / 100).toFixed(2))
                        RC_tuning.pitch_rate = 0
                        RC_tuning.roll_rate = 0
                    else
                        RC_tuning.roll_pitch_rate = 0
                        RC_tuning.roll_rate = parseFloat((data.readU8() / 100).toFixed(2))
                        RC_tuning.pitch_rate = parseFloat((data.readU8() / 100).toFixed(2))
                    RC_tuning.yaw_rate = parseFloat((data.readU8() / 100).toFixed(2))
                    RC_tuning.dynamic_THR_PID = parseFloat((data.readU8() / 100).toFixed(2))
                    RC_tuning.throttle_MID = parseFloat((data.readU8() / 100).toFixed(2))
                    RC_tuning.throttle_EXPO = parseFloat((data.readU8() / 100).toFixed(2))
                    if semver.gte(CONFIG.apiVersion, '1.7.0')
                        RC_tuning.dynamic_THR_breakpoint = data.readU16()
                    else
                        RC_tuning.dynamic_THR_breakpoint = 0
                    if semver.gte(CONFIG.apiVersion, '1.10.0')
                        RC_tuning.RC_YAW_EXPO = parseFloat((data.readU8() / 100).toFixed(2))
                        if semver.gte(CONFIG.apiVersion, '1.16.0')
                            RC_tuning.rcYawRate = parseFloat((data.readU8() / 100).toFixed(2))
                        else
                            RC_tuning.rcYawRate = 0
                    else
                        RC_tuning.RC_YAW_EXPO = 0
                    if semver.gte(CONFIG.apiVersion, '1.37.0')
                        RC_tuning.rcPitchRate = parseFloat((data.readU8() / 100).toFixed(2))
                        RC_tuning.RC_PITCH_EXPO = parseFloat((data.readU8() / 100).toFixed(2))
                    else
                        RC_tuning.rcPitchRate = 0
                        RC_tuning.RC_PITCH_EXPO = 0
                    if semver.gte(CONFIG.apiVersion, '1.41.0')
                        RC_tuning.throttleLimitType = data.readU8()
                        RC_tuning.throttleLimitPercent = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.42.0')
                        RC_tuning.roll_rate_limit = data.readU16()
                        RC_tuning.pitch_rate_limit = data.readU16()
                        RC_tuning.yaw_rate_limit = data.readU16()
                when MSPCodes.MSP_PID
                    # PID data arrived, we need to scale it and save to appropriate bank / array
                    i = 0
                    needle = 0
                    while i < data.byteLength / 3
                        # main for loop selecting the pid section
                        j = 0
                        while j < 3
                            PIDs[i][j] = data.readU8()
                            j++
                        i++
                        needle += 3
                when MSPCodes.MSP_ARMING_CONFIG
                    if semver.gte(CONFIG.apiVersion, '1.8.0')
                        ARMING_CONFIG.auto_disarm_delay = data.readU8()
                        ARMING_CONFIG.disarm_kill_switch = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.37.0')
                        ARMING_CONFIG.small_angle = data.readU8()
                when MSPCodes.MSP_LOOP_TIME
                    if semver.gte(CONFIG.apiVersion, '1.8.0')
                        FC_CONFIG.loopTime = data.readU16()
                when MSPCodes.MSP_MISC
                    # 22 bytes
                    RX_CONFIG.midrc = data.readU16()
                    MOTOR_CONFIG.minthrottle = data.readU16()
                    # 0-2000
                    MOTOR_CONFIG.maxthrottle = data.readU16()
                    # 0-2000
                    MOTOR_CONFIG.mincommand = data.readU16()
                    # 0-2000
                    MISC.failsafe_throttle = data.readU16()
                    # 1000-2000
                    GPS_CONFIG.provider = data.readU8()
                    MISC.gps_baudrate = data.readU8()
                    GPS_CONFIG.ublox_sbas = data.readU8()
                    MISC.multiwiicurrentoutput = data.readU8()
                    RSSI_CONFIG.channel = data.readU8()
                    MISC.placeholder2 = data.readU8()
                    if semver.lt(CONFIG.apiVersion, '1.18.0')
                        COMPASS_CONFIG.mag_declination = data.read16() / 10
                    else
                        COMPASS_CONFIG.mag_declination = data.read16() / 100
                    # -18000-18000
                    MISC.vbatscale = data.readU8()
                    # was MISC.vbatscale - 10-200
                    MISC.vbatmincellvoltage = data.readU8() / 10
                    # 10-50
                    MISC.vbatmaxcellvoltage = data.readU8() / 10
                    # 10-50
                    MISC.vbatwarningcellvoltage = data.readU8() / 10
                    # 10-50
                when MSPCodes.MSP_MOTOR_CONFIG
                    MOTOR_CONFIG.minthrottle = data.readU16()
                    # 0-2000
                    MOTOR_CONFIG.maxthrottle = data.readU16()
                    # 0-2000
                    MOTOR_CONFIG.mincommand = data.readU16()
                    # 0-2000
                    if semver.gte(CONFIG.apiVersion, '1.42.0')
                        MOTOR_CONFIG.motor_count = data.readU8()
                        MOTOR_CONFIG.motor_poles = data.readU8()
                        MOTOR_CONFIG.use_dshot_telemetry = data.readU8() != 0
                        MOTOR_CONFIG.use_esc_sensor = data.readU8() != 0
                when MSPCodes.MSP_COMPASS_CONFIG
                    COMPASS_CONFIG.mag_declination = data.read16() / 100
                    # -18000-18000
                when MSPCodes.MSP_GPS_CONFIG
                    GPS_CONFIG.provider = data.readU8()
                    GPS_CONFIG.ublox_sbas = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.34.0')
                        GPS_CONFIG.auto_config = data.readU8()
                        GPS_CONFIG.auto_baud = data.readU8()
                when MSPCodes.MSP_GPS_RESCUE
                    GPS_RESCUE.angle = data.readU16()
                    GPS_RESCUE.initialAltitudeM = data.readU16()
                    GPS_RESCUE.descentDistanceM = data.readU16()
                    GPS_RESCUE.rescueGroundspeed = data.readU16()
                    GPS_RESCUE.throttleMin = data.readU16()
                    GPS_RESCUE.throttleMax = data.readU16()
                    GPS_RESCUE.throttleHover = data.readU16()
                    GPS_RESCUE.sanityChecks = data.readU8()
                    GPS_RESCUE.minSats = data.readU8()
                when MSPCodes.MSP_RSSI_CONFIG
                    RSSI_CONFIG.channel = data.readU8()
                when MSPCodes.MSP_MOTOR_3D_CONFIG
                    MOTOR_3D_CONFIG.deadband3d_low = data.readU16()
                    MOTOR_3D_CONFIG.deadband3d_high = data.readU16()
                    MOTOR_3D_CONFIG.neutral = data.readU16()
                    if semver.lt(CONFIG.apiVersion, '1.17.0')
                        RC_DEADBAND_CONFIG.deadband3d_throttle = data.readU16()
                when MSPCodes.MSP_BOXNAMES
                    AUX_CONFIG = []
                    # empty the array as new data is coming in
                    buff = []
                    i = 0
                    while i < data.byteLength
                        char = data.readU8()
                        if char == 0x3B
                            # ; (delimeter char)
                            AUX_CONFIG.push String.fromCharCode.apply(null, buff)
                            # convert bytes into ASCII and save as strings
                            # empty buffer
                            buff = []
                        else
                            buff.push char
                        i++
                when MSPCodes.MSP_PIDNAMES
                    PID_names = []
                    # empty the array as new data is coming in
                    buff = []
                    i = 0
                    while i < data.byteLength
                        char = data.readU8()
                        if char == 0x3B
                            # ; (delimeter char)
                            PID_names.push String.fromCharCode.apply(null, buff)
                            # convert bytes into ASCII and save as strings
                            # empty buffer
                            buff = []
                        else
                            buff.push char
                        i++
                when MSPCodes.MSP_BOXIDS
                    AUX_CONFIG_IDS = []
                    # empty the array as new data is coming in
                    i = 0
                    while i < data.byteLength
                        AUX_CONFIG_IDS.push data.readU8()
                        i++
                when MSPCodes.MSP_SERVO_MIX_RULES then
                when MSPCodes.MSP_SERVO_CONFIGURATIONS
                    SERVO_CONFIG = []
                    # empty the array as new data is coming in
                    if semver.gte(CONFIG.apiVersion, '1.33.0')
                        # if (data.byteLength % 12 == 0) {
                        i = 0
                        while i < Math.floor(data.byteLength / 12) * 12
                            arr = 
                                'min': data.readU16()
                                'max': data.readU16()
                                'middle': data.readU16()
                                'rate': data.read8()
                                'indexOfChannelToForward': data.readU8()
                                'reversedInputSources': data.readU32()
                            SERVO_CONFIG.push arr
                            i += 12
                        SERVO_CONFIG.ornithopter_glide_deg = data.readU8() - 128
                        # Signed: firmware sends u8=val+128
                        SERVO_CONFIG.cadence_gain = data.readU8() - 128
                        SERVO_CONFIG.ferocity_d_gain = data.readU8() - 128
                        SERVO_CONFIG.balance_gain = data.readU8() - 128
                        # }
                    else if semver.gte(CONFIG.apiVersion, '1.12.0')
                        if data.byteLength % 14 == 0
                            i = 0
                            while i < data.byteLength
                                arr = 
                                    'min': data.readU16()
                                    'max': data.readU16()
                                    'middle': data.readU16()
                                    'rate': data.read8()
                                    'angleAtMin': data.readU8()
                                    'angleAtMax': data.readU8()
                                    'indexOfChannelToForward': data.readU8()
                                    'reversedInputSources': data.readU32()
                                SERVO_CONFIG.push arr
                                i += 14
                    else
                        if data.byteLength % 7 == 0
                            i = 0
                            while i < data.byteLength
                                arr = 
                                    'min': data.readU16()
                                    'max': data.readU16()
                                    'middle': data.readU16()
                                    'rate': data.read8()
                                    'angleAtMin': 45
                                    'angleAtMax': 45
                                    'indexOfChannelToForward': undefined
                                    'reversedInputSources': 0
                                SERVO_CONFIG.push arr
                                i += 7
                        if semver.eq(CONFIG.apiVersion, '1.10.0')
                            # drop two unused servo configurations due to MSP rx buffer to small)
                            while SERVO_CONFIG.length > 8
                                SERVO_CONFIG.pop()
                when MSPCodes.MSP_RC_DEADBAND
                    RC_DEADBAND_CONFIG.deadband = data.readU8()
                    RC_DEADBAND_CONFIG.yaw_deadband = data.readU8()
                    RC_DEADBAND_CONFIG.alt_hold_deadband = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.17.0')
                        RC_DEADBAND_CONFIG.deadband3d_throttle = data.readU16()
                when MSPCodes.MSP_SENSOR_ALIGNMENT
                    SENSOR_ALIGNMENT.align_gyro = data.readU8()
                    SENSOR_ALIGNMENT.align_acc = data.readU8()
                    SENSOR_ALIGNMENT.align_mag = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.41.0')
                        SENSOR_ALIGNMENT.gyro_detection_flags = data.readU8()
                        SENSOR_ALIGNMENT.gyro_to_use = data.readU8()
                        SENSOR_ALIGNMENT.gyro_1_align = data.readU8()
                        SENSOR_ALIGNMENT.gyro_2_align = data.readU8()
                when MSPCodes.MSP_DISPLAYPORT then
                when MSPCodes.MSP_SET_RAW_RC then
                when MSPCodes.MSP_SET_PID
                    console.log 'PID settings saved'
                when MSPCodes.MSP_SET_RC_TUNING
                    console.log 'RC Tuning saved'
                when MSPCodes.MSP_ACC_CALIBRATION
                    console.log 'Accel calibration executed'
                when MSPCodes.MSP_MAG_CALIBRATION
                    console.log 'Mag calibration executed'
                when MSPCodes.MSP_SET_MOTOR_CONFIG
                    console.log 'Motor Configuration saved'
                when MSPCodes.MSP_SET_GPS_CONFIG
                    console.log 'GPS Configuration saved'
                when MSPCodes.MSP_SET_RSSI_CONFIG
                    console.log 'RSSI Configuration saved'
                when MSPCodes.MSP_SET_FEATURE_CONFIG
                    console.log 'Features saved'
                when MSPCodes.MSP_SET_BEEPER_CONFIG
                    console.log 'Beeper Configuration saved'
                when MSPCodes.MSP_RESET_CONF
                    console.log 'Settings Reset'
                when MSPCodes.MSP_SELECT_SETTING
                    console.log 'Profile selected'
                when MSPCodes.MSP_SET_SERVO_CONFIGURATION
                    console.log 'Servo Configuration saved'
                when MSPCodes.MSP_EEPROM_WRITE
                    console.log 'Settings Saved in EEPROM'
                when MSPCodes.MSP_SET_CURRENT_METER_CONFIG
                    console.log 'Amperage Settings saved'
                when MSPCodes.MSP_SET_VOLTAGE_METER_CONFIG
                    console.log 'Voltage config saved'
                    i = 0
                    while i < 4
                        SENSOR_DATA.debug[i] = data.read16()
                        i++
                when MSPCodes.MSP_DEBUG
                    i = 0
                    while i < 4
                        SENSOR_DATA.debug[i] = data.read16()
                        i++
                when MSPCodes.MSP_SET_MOTOR
                    console.log 'Motor Speeds Updated'
                when MSPCodes.MSP_UID
                    CONFIG.uid[0] = data.readU32()
                    CONFIG.uid[1] = data.readU32()
                    CONFIG.uid[2] = data.readU32()
                when MSPCodes.MSP_ACC_TRIM
                    CONFIG.accelerometerTrims[0] = data.read16()
                    # pitch
                    CONFIG.accelerometerTrims[1] = data.read16()
                    # roll
                when MSPCodes.MSP_SET_ACC_TRIM
                    console.log 'Accelerometer trimms saved.'
                when MSPCodes.MSP_GPS_SV_INFO
                    if data.byteLength > 0
                        numCh = data.readU8()
                        i = 0
                        while i < numCh
                            GPS_DATA.chn[i] = data.readU8()
                            GPS_DATA.svid[i] = data.readU8()
                            GPS_DATA.quality[i] = data.readU8()
                            GPS_DATA.cno[i] = data.readU8()
                            i++
                when MSPCodes.MSP_RX_MAP
                    RC_MAP = []
                    # empty the array as new data is coming in
                    i = 0
                    while i < data.byteLength
                        RC_MAP.push data.readU8()
                        i++
                when MSPCodes.MSP_SET_RX_MAP
                    console.log 'RCMAP saved'
                when MSPCodes.MSP_MIXER_CONFIG
                    MIXER_CONFIG.mixer = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.36.0')
                        MIXER_CONFIG.reverseMotorDir = data.readU8()
                when MSPCodes.MSP_FEATURE_CONFIG
                    FEATURE_CONFIG.features.setMask data.readU32()
                    updateTabList FEATURE_CONFIG.features
                when MSPCodes.MSP_BEEPER_CONFIG
                    BEEPER_CONFIG.beepers.setMask data.readU32()
                    if semver.gte(CONFIG.apiVersion, '1.37.0')
                        BEEPER_CONFIG.dshotBeaconTone = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.39.0')
                        BEEPER_CONFIG.dshotBeaconConditions.setMask data.readU32()
                when MSPCodes.MSP_BOARD_ALIGNMENT_CONFIG
                    BOARD_ALIGNMENT_CONFIG.roll = data.read16()
                    # -180 - 360
                    BOARD_ALIGNMENT_CONFIG.pitch = data.read16()
                    # -180 - 360
                    BOARD_ALIGNMENT_CONFIG.yaw = data.read16()
                    # -180 - 360
                when MSPCodes.MSP_SET_REBOOT
                    if semver.gte(CONFIG.apiVersion, '1.40.0')
                        rebootType = data.read8()
                        if rebootType == self.REBOOT_TYPES.MSC or rebootType == self.REBOOT_TYPES.MSC_UTC
                            if data.read8() == 0
                                console.log 'Storage device not ready.'
                                showErrorDialog i18n.getMessage('storageDeviceNotReady')
                                break
                    console.log 'Reboot request accepted'
                when MSPCodes.MSP_API_VERSION
                    CONFIG.mspProtocolVersion = data.readU8()
                    CONFIG.apiVersion = data.readU8() + '.' + data.readU8() + '.0'
                when MSPCodes.MSP_FC_VARIANT
                    identifier = ''
                    i = 0
                    while i < 4
                        identifier += String.fromCharCode(data.readU8())
                        i++
                    CONFIG.flightControllerIdentifier = identifier
                when MSPCodes.MSP_FC_VERSION
                    CONFIG.flightControllerVersion = data.readU8() + '.' + data.readU8() + '.' + data.readU8()
                when MSPCodes.MSP_BUILD_INFO
                    dateLength = 11
                    buff = []
                    i = 0
                    while i < dateLength
                        buff.push data.readU8()
                        i++
                    buff.push 32
                    # ascii space
                    timeLength = 8
                    i = 0
                    while i < timeLength
                        buff.push data.readU8()
                        i++
                    CONFIG.buildInfo = String.fromCharCode.apply(null, buff)
                when MSPCodes.MSP_BOARD_INFO
                    identifier = ''
                    i = 0
                    while i < 4
                        identifier += String.fromCharCode(data.readU8())
                        i++
                    CONFIG.boardIdentifier = identifier
                    CONFIG.boardVersion = data.readU16()
                    if semver.gte(CONFIG.apiVersion, '1.35.0')
                        CONFIG.boardType = data.readU8()
                    else
                        CONFIG.boardType = 0
                    CONFIG.targetName = ''
                    if semver.gte(CONFIG.apiVersion, '1.37.0')
                        CONFIG.targetCapabilities = data.readU8()
                        length = data.readU8()
                        _i2 = 0
                        while _i2 < length
                            CONFIG.targetName += String.fromCharCode(data.readU8())
                            _i2++
                    else
                        CONFIG.targetCapabilities = 0
                    CONFIG.boardName = ''
                    CONFIG.manufacturerId = ''
                    CONFIG.signature = []
                    if semver.gte(CONFIG.apiVersion, '1.39.0')
                        _length = data.readU8()
                        _i3 = 0
                        while _i3 < _length
                            CONFIG.boardName += String.fromCharCode(data.readU8())
                            _i3++
                        _length = data.readU8()
                        _i4 = 0
                        while _i4 < _length
                            CONFIG.manufacturerId += String.fromCharCode(data.readU8())
                            _i4++
                        _i5 = 0
                        while _i5 < self.SIGNATURE_LENGTH
                            CONFIG.signature.push data.readU8()
                            _i5++
                    if semver.gte(CONFIG.apiVersion, '1.41.0')
                        CONFIG.mcuTypeId = data.readU8()
                        if semver.gte(CONFIG.apiVersion, '1.42.0')
                            CONFIG.configurationState = data.readU8()
                    else
                        CONFIG.mcuTypeId = 255
                when MSPCodes.MSP_NAME
                    CONFIG.name = ''
                    char = undefined
                    while (char = data.readU8()) != null
                        CONFIG.name += String.fromCharCode(char)
                when MSPCodes.MSP_SET_CHANNEL_FORWARDING
                    console.log 'Channel forwarding saved'
                when MSPCodes.MSP_CF_SERIAL_CONFIG
                    if semver.lt(CONFIG.apiVersion, '1.6.0')
                        SERIAL_CONFIG.ports = []
                        serialPortCount = (data.byteLength - (4 * 4)) / 2
                        i = 0
                        while i < serialPortCount
                            serialPort = 
                                identifier: data.readU8()
                                scenario: data.readU8()
                            SERIAL_CONFIG.ports.push serialPort
                            i++
                        SERIAL_CONFIG.mspBaudRate = data.readU32()
                        SERIAL_CONFIG.cliBaudRate = data.readU32()
                        SERIAL_CONFIG.gpsBaudRate = data.readU32()
                        SERIAL_CONFIG.gpsPassthroughBaudRate = data.readU32()
                    else
                        SERIAL_CONFIG.ports = []
                        bytesPerPort = 1 + 2 + 1 * 4
                        serialPortCount = data.byteLength / bytesPerPort
                        i = 0
                        while i < serialPortCount
                            serialPort = 
                                identifier: data.readU8()
                                functions: self.serialPortFunctionMaskToFunctions(data.readU16())
                                msp_baudrate: self.BAUD_RATES[data.readU8()]
                                gps_baudrate: self.BAUD_RATES[data.readU8()]
                                telemetry_baudrate: self.BAUD_RATES[data.readU8()]
                                blackbox_baudrate: self.BAUD_RATES[data.readU8()]
                            SERIAL_CONFIG.ports.push serialPort
                            i++
                when MSPCodes.MSP_SET_CF_SERIAL_CONFIG
                    console.log 'Serial config saved'
                when MSPCodes.MSP_MODE_RANGES
                    MODE_RANGES = []
                    # empty the array as new data is coming in
                    modeRangeCount = data.byteLength / 4
                    # 4 bytes per item.
                    i = 0
                    while i < modeRangeCount
                        modeRange = 
                            id: data.readU8()
                            auxChannelIndex: data.readU8()
                            range:
                                start: 900 + data.readU8() * 25
                                end: 900 + data.readU8() * 25
                        MODE_RANGES.push modeRange
                        i++
                when MSPCodes.MSP_MODE_RANGES_EXTRA
                    MODE_RANGES_EXTRA = []
                    # empty the array as new data is coming in
                    modeRangeExtraCount = data.readU8()
                    i = 0
                    while i < modeRangeExtraCount
                        modeRangeExtra = 
                            id: data.readU8()
                            modeLogic: data.readU8()
                            linkedTo: data.readU8()
                        MODE_RANGES_EXTRA.push modeRangeExtra
                        i++
                when MSPCodes.MSP_ADJUSTMENT_RANGES
                    ADJUSTMENT_RANGES = []
                    # empty the array as new data is coming in
                    adjustmentRangeCount = data.byteLength / 6
                    # 6 bytes per item.
                    i = 0
                    while i < adjustmentRangeCount
                        adjustmentRange = 
                            slotIndex: data.readU8()
                            auxChannelIndex: data.readU8()
                            range:
                                start: 900 + data.readU8() * 25
                                end: 900 + data.readU8() * 25
                            adjustmentFunction: data.readU8()
                            auxSwitchChannelIndex: data.readU8()
                        ADJUSTMENT_RANGES.push adjustmentRange
                        i++
                when MSPCodes.MSP_RX_CONFIG
                    RX_CONFIG.serialrx_provider = data.readU8()
                    RX_CONFIG.stick_max = data.readU16()
                    RX_CONFIG.stick_center = data.readU16()
                    RX_CONFIG.stick_min = data.readU16()
                    RX_CONFIG.spektrum_sat_bind = data.readU8()
                    RX_CONFIG.rx_min_usec = data.readU16()
                    RX_CONFIG.rx_max_usec = data.readU16()
                    if semver.gte(CONFIG.apiVersion, '1.20.0')
                        RX_CONFIG.rcInterpolation = data.readU8()
                        RX_CONFIG.rcInterpolationInterval = data.readU8()
                        RX_CONFIG.airModeActivateThreshold = data.readU16()
                        if semver.gte(CONFIG.apiVersion, '1.31.0')
                            RX_CONFIG.rxSpiProtocol = data.readU8()
                            RX_CONFIG.rxSpiId = data.readU32()
                            RX_CONFIG.rxSpiRfChannelCount = data.readU8()
                            RX_CONFIG.fpvCamAngleDegrees = data.readU8()
                            if semver.gte(CONFIG.apiVersion, '1.40.0')
                                RX_CONFIG.rcInterpolationChannels = data.readU8()
                                RX_CONFIG.rcSmoothingType = data.readU8()
                                RX_CONFIG.rcSmoothingInputCutoff = data.readU8()
                                RX_CONFIG.rcSmoothingDerivativeCutoff = data.readU8()
                                RX_CONFIG.rcSmoothingInputType = data.readU8()
                                RX_CONFIG.rcSmoothingDerivativeType = data.readU8()
                                if semver.gte(CONFIG.apiVersion, '1.42.0')
                                    RX_CONFIG.usbCdcHidType = data.readU8()
                                    RX_CONFIG.rcSmoothingAutoSmoothness = data.readU8()
                        else
                            RX_CONFIG.rxSpiProtocol = 0
                            RX_CONFIG.rxSpiId = 0
                            RX_CONFIG.rxSpiRfChannelCount = 0
                            RX_CONFIG.fpvCamAngleDegrees = 0
                    else
                        RX_CONFIG.rcInterpolation = 0
                        RX_CONFIG.rcInterpolationInterval = 0
                        RX_CONFIG.airModeActivateThreshold = 0
                when MSPCodes.MSP_FAILSAFE_CONFIG
                    FAILSAFE_CONFIG.failsafe_delay = data.readU8()
                    FAILSAFE_CONFIG.failsafe_off_delay = data.readU8()
                    FAILSAFE_CONFIG.failsafe_throttle = data.readU16()
                    if semver.gte(CONFIG.apiVersion, '1.15.0')
                        FAILSAFE_CONFIG.failsafe_switch_mode = data.readU8()
                        FAILSAFE_CONFIG.failsafe_throttle_low_delay = data.readU16()
                        FAILSAFE_CONFIG.failsafe_procedure = data.readU8()
                when MSPCodes.MSP_RXFAIL_CONFIG
                    RXFAIL_CONFIG = []
                    # empty the array as new data is coming in
                    channelCount = data.byteLength / 3
                    i = 0
                    while i < channelCount
                        rxfailChannel = 
                            mode: data.readU8()
                            value: data.readU16()
                        RXFAIL_CONFIG.push rxfailChannel
                        i++
                when MSPCodes.MSP_ADVANCED_CONFIG
                    PID_ADVANCED_CONFIG.gyro_sync_denom = data.readU8()
                    PID_ADVANCED_CONFIG.pid_process_denom = data.readU8()
                    PID_ADVANCED_CONFIG.use_unsyncedPwm = data.readU8()
                    PID_ADVANCED_CONFIG.fast_pwm_protocol = self.reorderPwmProtocols(data.readU8())
                    PID_ADVANCED_CONFIG.motor_pwm_rate = data.readU16()
                    if semver.gte(CONFIG.apiVersion, '1.24.0')
                        PID_ADVANCED_CONFIG.digitalIdlePercent = data.readU16() / 100
                        if semver.gte(CONFIG.apiVersion, '1.25.0')
                            gyroUse32kHz = data.readU8()
                            if semver.lt(CONFIG.apiVersion, '1.41.0')
                                PID_ADVANCED_CONFIG.gyroUse32kHz = gyroUse32kHz
                            if semver.gte(CONFIG.apiVersion, '1.42.0')
                                PID_ADVANCED_CONFIG.motorPwmInversion = data.readU8()
                                SENSOR_ALIGNMENT.gyro_to_use = data.readU8()
                                # We don't want to double up on storing this state
                                PID_ADVANCED_CONFIG.gyroHighFsr = data.readU8()
                                PID_ADVANCED_CONFIG.gyroMovementCalibThreshold = data.readU8()
                                PID_ADVANCED_CONFIG.gyroCalibDuration = data.readU16()
                                PID_ADVANCED_CONFIG.gyroOffsetYaw = data.readU16()
                                PID_ADVANCED_CONFIG.gyroCheckOverflow = data.readU8()
                                PID_ADVANCED_CONFIG.debugMode = data.readU8()
                                PID_ADVANCED_CONFIG.debugModeCount = data.readU8()
                when MSPCodes.MSP_FILTER_CONFIG
                    FILTER_CONFIG.gyro_lowpass_hz = data.readU8()
                    FILTER_CONFIG.dterm_lowpass_hz = data.readU16()
                    FILTER_CONFIG.yaw_lowpass_hz = data.readU16()
                    if semver.gte(CONFIG.apiVersion, '1.20.0')
                        FILTER_CONFIG.gyro_notch_hz = data.readU16()
                        FILTER_CONFIG.gyro_notch_cutoff = data.readU16()
                        FILTER_CONFIG.dterm_notch_hz = data.readU16()
                        FILTER_CONFIG.dterm_notch_cutoff = data.readU16()
                        if semver.gte(CONFIG.apiVersion, '1.21.0')
                            FILTER_CONFIG.gyro_notch2_hz = data.readU16()
                            FILTER_CONFIG.gyro_notch2_cutoff = data.readU16()
                        if semver.gte(CONFIG.apiVersion, '1.36.0')
                            FILTER_CONFIG.dterm_lowpass_type = data.readU8()
                        if semver.gte(CONFIG.apiVersion, '1.39.0')
                            FILTER_CONFIG.gyro_hardware_lpf = data.readU8()
                            gyro_32khz_hardware_lpf = data.readU8()
                            FILTER_CONFIG.gyro_lowpass_hz = data.readU16()
                            FILTER_CONFIG.gyro_lowpass2_hz = data.readU16()
                            FILTER_CONFIG.gyro_lowpass_type = data.readU8()
                            FILTER_CONFIG.gyro_lowpass2_type = data.readU8()
                            FILTER_CONFIG.dterm_lowpass2_hz = data.readU16()
                            if semver.lt(CONFIG.apiVersion, '1.41.0')
                                FILTER_CONFIG.gyro_32khz_hardware_lpf = gyro_32khz_hardware_lpf
                            else
                                FILTER_CONFIG.gyro_32khz_hardware_lpf = 0
                                FILTER_CONFIG.dterm_lowpass2_type = data.readU8()
                                FILTER_CONFIG.gyro_lowpass_dyn_min_hz = data.readU16()
                                FILTER_CONFIG.gyro_lowpass_dyn_max_hz = data.readU16()
                                FILTER_CONFIG.dterm_lowpass_dyn_min_hz = data.readU16()
                                FILTER_CONFIG.dterm_lowpass_dyn_max_hz = data.readU16()
                                FILTER_CONFIG.cadence_gain = data.readU8()
                                console.log 'FILTER_CONFIG', FILTER_CONFIG
                                if semver.gte(CONFIG.apiVersion, '1.42.0')
                                    FILTER_CONFIG.dyn_notch_range = data.readU8()
                                    FILTER_CONFIG.dyn_notch_width_percent = data.readU8()
                                    FILTER_CONFIG.dyn_notch_q = data.readU16()
                                    FILTER_CONFIG.dyn_notch_min_hz = data.readU16()
                                    FILTER_CONFIG.gyro_rpm_notch_harmonics = data.readU8()
                                    FILTER_CONFIG.gyro_rpm_notch_min_hz = data.readU8()
                when MSPCodes.MSP_SET_PID_ADVANCED
                    console.log 'Advanced PID settings saved'
                when MSPCodes.MSP_PID_ADVANCED
                    ADVANCED_TUNING.rollPitchItermIgnoreRate = data.readU16()
                    ADVANCED_TUNING.yawItermIgnoreRate = data.readU16()
                    ADVANCED_TUNING.yaw_p_limit = data.readU16()
                    ADVANCED_TUNING.deltaMethod = data.readU8()
                    ADVANCED_TUNING.vbatPidCompensation = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.20.0')
                        if semver.gte(CONFIG.apiVersion, '1.40.0')
                            ADVANCED_TUNING.feedforwardTransition = data.readU8()
                        else
                            ADVANCED_TUNING.dtermSetpointTransition = data.readU8()
                        ADVANCED_TUNING.dtermSetpointWeight = data.readU8()
                        ADVANCED_TUNING.toleranceBand = data.readU8()
                        ADVANCED_TUNING.toleranceBandReduction = data.readU8()
                        ADVANCED_TUNING.itermThrottleGain = data.readU8()
                        ADVANCED_TUNING.pidMaxVelocity = data.readU16()
                        ADVANCED_TUNING.pidMaxVelocityYaw = data.readU16()
                        if semver.gte(CONFIG.apiVersion, '1.24.0')
                            ADVANCED_TUNING.levelAngleLimit = data.readU8()
                            ADVANCED_TUNING.levelSensitivity = data.readU8()
                            if semver.gte(CONFIG.apiVersion, '1.36.0')
                                ADVANCED_TUNING.itermThrottleThreshold = data.readU16()
                                ADVANCED_TUNING.itermAcceleratorGain = data.readU16()
                                if semver.gte(CONFIG.apiVersion, '1.39.0')
                                    ADVANCED_TUNING.dtermSetpointWeight = data.readU16()
                                    if semver.gte(CONFIG.apiVersion, '1.40.0')
                                        ADVANCED_TUNING.itermRotation = data.readU8()
                                        ADVANCED_TUNING.smartFeedforward = data.readU8()
                                        ADVANCED_TUNING.itermRelax = data.readU8()
                                        ADVANCED_TUNING.itermRelaxType = data.readU8()
                                        ADVANCED_TUNING.absoluteControlGain = data.readU8()
                                        ADVANCED_TUNING.throttleBoost = data.readU8()
                                        ADVANCED_TUNING.acroTrainerAngleLimit = data.readU8()
                                        ADVANCED_TUNING.feedforwardRoll = data.readU16()
                                        ADVANCED_TUNING.feedforwardPitch = data.readU16()
                                        ADVANCED_TUNING.feedforwardYaw = data.readU16()
                                        ADVANCED_TUNING.antiGravityMode = data.readU8()
                                        if semver.gte(CONFIG.apiVersion, '1.41.0')
                                            ADVANCED_TUNING.dMinRoll = data.readU8()
                                            ADVANCED_TUNING.dMinPitch = data.readU8()
                                            ADVANCED_TUNING.dMinYaw = data.readU8()
                                            ADVANCED_TUNING.dMinGain = data.readU8()
                                            ADVANCED_TUNING.dMinAdvance = data.readU8()
                                            ADVANCED_TUNING.useIntegratedYaw = data.readU8()
                                            ADVANCED_TUNING.integratedYawRelax = data.readU8()
                                            ADVANCED_TUNING.flapBaseFrequency = data.readU8()
                                            ADVANCED_TUNING.flapBaseAmplitude = data.readU8() - 128
                                            console.log 'ADVANCED_TUNING', ADVANCED_TUNING
                                            if semver.gte(CONFIG.apiVersion, '1.42.0')
                                                ADVANCED_TUNING.itermRelaxCutoff = data.readU8()
                                                # Signed: firmware sends u8=val+128, wire byte → JS int
                                                ADVANCED_TUNING.cadence_gain = data.readU8() - 128
                                                ADVANCED_TUNING.ferocity_d_gain = data.readU8() - 128
                                                ADVANCED_TUNING.balance_gain = data.readU8() - 128
                                                # Unsigned 0–100: direct wire passthrough
                                                ADVANCED_TUNING.ferocity_p_gain = data.readU8()
                                                ADVANCED_TUNING.ferocity_roll_gain = data.readU8()
                                                ADVANCED_TUNING.ferocity_yaw_gain = data.readU8()
                                                # Signed: u8=val+128
                                                ADVANCED_TUNING.warp_gain = data.readU8() - 128
                                                ADVANCED_TUNING.warp_yaw_gain = data.readU8() - 128
                                                # Unsigned 0–100
                                                ADVANCED_TUNING.anchor_gain = data.readU8()
                                                ADVANCED_TUNING.resonance_gain = data.readU8()
                                                if semver.gte(CONFIG.apiVersion, '1.43.0')
                                                    # Phase 2 — Wing Pair Geometry (signed, wire=val+128)
                                                    ADVANCED_TUNING.servo_mount_angle_0 = data.readU8() - 128
                                                    ADVANCED_TUNING.servo_mount_angle_1 = data.readU8() - 128
                                                    ADVANCED_TUNING.servo_mount_angle_2 = data.readU8() - 128
                                                    ADVANCED_TUNING.servo_mount_angle_3 = data.readU8() - 128
                                                    ADVANCED_TUNING.flapping_phase_shift_0 = data.readU8() - 128
                                                    ADVANCED_TUNING.flapping_phase_shift_1 = data.readU8() - 128
                                                    ADVANCED_TUNING.flapping_phase_shift_2 = data.readU8() - 128
                                                    ADVANCED_TUNING.flapping_phase_shift_3 = data.readU8() - 128
                                                    # Phase 2 — Advanced ONDAS Gains (unsigned 0–100, direct wire)
                                                    ADVANCED_TUNING.prescience_gain = data.readU8()
                                                    ADVANCED_TUNING.espelho_gain = data.readU8()
                                                    ADVANCED_TUNING.saudade_gain = data.readU8()
                                                    ADVANCED_TUNING.ssff_gain = data.readU8()
                                                    if semver.gte(CONFIG.apiVersion, '1.44.0')
                                                        # Phase 4 — GralhaAzul: physical servo params + wing trim
                                                        ADVANCED_TUNING.servo_speed_deg_s = data.readU16()
                                                        ADVANCED_TUNING.servo_max_amplitude = data.readU8()
                                                        ADVANCED_TUNING.flap_magnitude = data.readU8()
                                                        ADVANCED_TUNING.wing_origin_offset_0 = data.readU8() - 128
                                                        ADVANCED_TUNING.wing_origin_offset_1 = data.readU8() - 128
                                                        ADVANCED_TUNING.wing_origin_offset_2 = data.readU8() - 128
                                                        ADVANCED_TUNING.wing_origin_offset_3 = data.readU8() - 128
                                                        if semver.gte(CONFIG.apiVersion, '1.45.0')
                                                            # Phase 5 — Independent flight mode: unified frequency channel
                                                            ADVANCED_TUNING.ornithopter_freq_channel = data.readU8()
                                                            ADVANCED_TUNING.ornithopter_freq_min = data.readU8()
                                                            ADVANCED_TUNING.ornithopter_freq_max = data.readU8()
                                                            if semver.gte(CONFIG.apiVersion, '1.46.0')
                                                                # Phase 6 — Ornithopter profile + aeroelastic params
                                                                ADVANCED_TUNING.ornithopter_profile_index = data.readU8()
                                                                ADVANCED_TUNING.ferocity_downstroke = data.readU8()
                                                                ADVANCED_TUNING.ferocity_upstroke = data.readU8()
                                                                # Signed: firmware sends u8=val+128, wire byte → JS int
                                                                ADVANCED_TUNING.aeroelastic_glide_coefficient = data.readU8() - 128
                                                                ADVANCED_TUNING.aeroelastic_flap_coefficient = data.readU8() - 128
                when MSPCodes.MSP_SENSOR_CONFIG
                    SENSOR_CONFIG.acc_hardware = data.readU8()
                    SENSOR_CONFIG.baro_hardware = data.readU8()
                    SENSOR_CONFIG.mag_hardware = data.readU8()
                when MSPCodes.MSP_LED_STRIP_CONFIG
                    LED_STRIP = []
                    ledDirectionLetters = [
                        'n'
                        'e'
                        's'
                        'w'
                        'u'
                        'd'
                    ]
                    # in LSB bit order
                    ledFunctionLetters = [
                        'i'
                        'w'
                        'f'
                        'a'
                        't'
                        'r'
                        'c'
                        'g'
                        's'
                        'b'
                        'l'
                    ]
                    # in LSB bit order
                    ledBaseFunctionLetters = [
                        'c'
                        'f'
                        'a'
                        'l'
                        's'
                        'g'
                        'r'
                    ]
                    # in LSB bit
                    if semver.lt(CONFIG.apiVersion, '1.36.0')
                        ledOverlayLetters = [
                            't'
                            'o'
                            'b'
                            'n'
                            'i'
                            'w'
                        ]
                        # in LSB bit
                    else
                        ledOverlayLetters = [
                            't'
                            'o'
                            'b'
                            'v'
                            'i'
                            'w'
                        ]
                        # in LSB bit
                    ledCount = data.byteLength / 7
                    # v1.4.0 and below incorrectly reported 4 bytes per led.
                    if semver.gte(CONFIG.apiVersion, '1.20.0')
                        ledCount = data.byteLength / 4
                    if semver.gte(CONFIG.apiVersion, '1.41.0')
                        # According to firmware's msp.c
                        # API 1.41 - add indicator for advanced profile support and the current profile selection
                        # 0 = basic ledstrip available
                        # 1 = advanced ledstrip available
                        # Following byte is the current LED profile
                        ledCount = (data.byteLength - 2) / 4
                    i = 0
                    while i < ledCount
                        if semver.lt(CONFIG.apiVersion, '1.20.0')
                            directionMask = data.readU16()
                            directions = []
                            directionLetterIndex = 0
                            while directionLetterIndex < ledDirectionLetters.length
                                if bit_check(directionMask, directionLetterIndex)
                                    directions.push ledDirectionLetters[directionLetterIndex]
                                directionLetterIndex++
                            functionMask = data.readU16()
                            functions = []
                            functionLetterIndex = 0
                            while functionLetterIndex < ledFunctionLetters.length
                                if bit_check(functionMask, functionLetterIndex)
                                    functions.push ledFunctionLetters[functionLetterIndex]
                                functionLetterIndex++
                            led = 
                                directions: directions
                                functions: functions
                                x: data.readU8()
                                y: data.readU8()
                                color: data.readU8()
                            LED_STRIP.push led
                        else
                            mask = data.readU32()
                            functionId = mask >> 8 & 0xF
                            functions = []
                            baseFunctionLetterIndex = 0
                            while baseFunctionLetterIndex < ledBaseFunctionLetters.length
                                if functionId == baseFunctionLetterIndex
                                    functions.push ledBaseFunctionLetters[baseFunctionLetterIndex]
                                    break
                                baseFunctionLetterIndex++
                            overlayMask = mask >> 12 & 0x3F
                            overlayLetterIndex = 0
                            while overlayLetterIndex < ledOverlayLetters.length
                                if bit_check(overlayMask, overlayLetterIndex)
                                    functions.push ledOverlayLetters[overlayLetterIndex]
                                overlayLetterIndex++
                            directionMask = mask >> 22 & 0x3F
                            directions = []
                            directionLetterIndex = 0
                            while directionLetterIndex < ledDirectionLetters.length
                                if bit_check(directionMask, directionLetterIndex)
                                    directions.push ledDirectionLetters[directionLetterIndex]
                                directionLetterIndex++
                            led = 
                                y: mask & 0xF
                                x: mask >> 4 & 0xF
                                functions: functions
                                color: mask >> 18 & 0xF
                                directions: directions
                                parameters: mask >> 28 & 0xF
                            LED_STRIP.push led
                        i++
                when MSPCodes.MSP_SET_LED_STRIP_CONFIG
                    console.log 'Led strip config saved'
                when MSPCodes.MSP_LED_COLORS
                    LED_COLORS = []
                    colorCount = data.byteLength / 4
                    i = 0
                    while i < colorCount
                        color = 
                            h: data.readU16()
                            s: data.readU8()
                            v: data.readU8()
                        LED_COLORS.push color
                        i++
                when MSPCodes.MSP_SET_LED_COLORS
                    console.log 'Led strip colors saved'
                when MSPCodes.MSP_LED_STRIP_MODECOLOR
                    if semver.gte(CONFIG.apiVersion, '1.19.0')
                        LED_MODE_COLORS = []
                        colorCount = data.byteLength / 3
                        i = 0
                        while i < colorCount
                            mode_color = 
                                mode: data.readU8()
                                direction: data.readU8()
                                color: data.readU8()
                            LED_MODE_COLORS.push mode_color
                            i++
                when MSPCodes.MSP_SET_LED_STRIP_MODECOLOR
                    console.log 'Led strip mode colors saved'
                when MSPCodes.MSP_DATAFLASH_SUMMARY
                    if data.byteLength >= 13
                        flags = data.readU8()
                        DATAFLASH.ready = (flags & 1) != 0
                        DATAFLASH.supported = (flags & 2) != 0
                        DATAFLASH.sectors = data.readU32()
                        DATAFLASH.totalSize = data.readU32()
                        DATAFLASH.usedSize = data.readU32()
                    else
                        # Firmware version too old to support MSP_DATAFLASH_SUMMARY
                        DATAFLASH.ready = false
                        DATAFLASH.supported = false
                        DATAFLASH.sectors = 0
                        DATAFLASH.totalSize = 0
                        DATAFLASH.usedSize = 0
                    update_dataflash_global()
                when MSPCodes.MSP_DATAFLASH_READ then
                    # No-op, let callback handle it
                when MSPCodes.MSP_DATAFLASH_ERASE
                    console.log 'Data flash erase begun...'
                when MSPCodes.MSP_SDCARD_SUMMARY
                    flags = data.readU8()
                    SDCARD.supported = (flags & 0x01) != 0
                    SDCARD.state = data.readU8()
                    SDCARD.filesystemLastError = data.readU8()
                    SDCARD.freeSizeKB = data.readU32()
                    SDCARD.totalSizeKB = data.readU32()
                when MSPCodes.MSP_BLACKBOX_CONFIG
                    BLACKBOX.supported = (data.readU8() & 1) != 0
                    BLACKBOX.blackboxDevice = data.readU8()
                    BLACKBOX.blackboxRateNum = data.readU8()
                    BLACKBOX.blackboxRateDenom = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.36.0')
                        BLACKBOX.blackboxPDenom = data.readU16()
                when MSPCodes.MSP_SET_BLACKBOX_CONFIG
                    console.log 'Blackbox config saved'
                when MSPCodes.MSP_TRANSPONDER_CONFIG
                    bytesRemaining = data.byteLength
                    if semver.gte(CONFIG.apiVersion, '1.33.0')
                        providerCount = data.readU8()
                        bytesRemaining--
                        TRANSPONDER.supported = providerCount > 0
                        TRANSPONDER.providers = []
                        i = 0
                        while i < providerCount
                            provider = 
                                id: data.readU8()
                                dataLength: data.readU8()
                            bytesRemaining -= 2
                            TRANSPONDER.providers.push provider
                            i++
                        TRANSPONDER.provider = data.readU8()
                        bytesRemaining--
                    else
                        TRANSPONDER.supported = (data.readU8() & 1) != 0
                        bytesRemaining--
                        # only ILAP was supported prior to 1.33.0
                        TRANSPONDER.providers = [ {
                            id: 1
                            dataLength: 6
                        } ]
                        TRANSPONDER.provider = TRANSPONDER.providers[0].id
                    TRANSPONDER.data = []
                    i = 0
                    while i < bytesRemaining
                        TRANSPONDER.data.push data.readU8()
                        i++
                when MSPCodes.MSP_SET_TRANSPONDER_CONFIG
                    console.log 'Transponder config saved'
                when MSPCodes.MSP_VTX_CONFIG
                    VTX_CONFIG.vtx_type = data.readU8()
                    VTX_CONFIG.vtx_band = data.readU8()
                    VTX_CONFIG.vtx_channel = data.readU8()
                    VTX_CONFIG.vtx_power = data.readU8()
                    VTX_CONFIG.vtx_pit_mode = data.readU8() != 0
                    VTX_CONFIG.vtx_frequency = data.readU16()
                    VTX_CONFIG.vtx_device_ready = data.readU8() != 0
                    VTX_CONFIG.vtx_low_power_disarm = data.readU8()
                    if semver.gte(CONFIG.apiVersion, '1.42.0')
                        VTX_CONFIG.vtx_pit_mode_frequency = data.readU16()
                        VTX_CONFIG.vtx_table_available = data.readU8() != 0
                        VTX_CONFIG.vtx_table_bands = data.readU8()
                        VTX_CONFIG.vtx_table_channels = data.readU8()
                        VTX_CONFIG.vtx_table_powerlevels = data.readU8()
                        VTX_CONFIG.vtx_table_clear = false
                when MSPCodes.MSP_SET_VTX_CONFIG
                    console.log 'VTX config sent'
                when MSPCodes.MSP_VTXTABLE_BAND
                    VTXTABLE_BAND.vtxtable_band_number = data.readU8()
                    bandNameLength = data.readU8()
                    VTXTABLE_BAND.vtxtable_band_name = ''
                    _i6 = 0
                    while _i6 < bandNameLength
                        VTXTABLE_BAND.vtxtable_band_name += String.fromCharCode(data.readU8())
                        _i6++
                    VTXTABLE_BAND.vtxtable_band_letter = String.fromCharCode(data.readU8())
                    VTXTABLE_BAND.vtxtable_band_is_factory_band = data.readU8() != 0
                    bandFrequenciesLength = data.readU8()
                    VTXTABLE_BAND.vtxtable_band_frequencies = []
                    _i7 = 0
                    while _i7 < bandFrequenciesLength
                        VTXTABLE_BAND.vtxtable_band_frequencies.push data.readU16()
                        _i7++
                when MSPCodes.MSP_SET_VTXTABLE_BAND
                    console.log 'VTX band sent'
                when MSPCodes.MSP_VTXTABLE_POWERLEVEL
                    VTXTABLE_POWERLEVEL.vtxtable_powerlevel_number = data.readU8()
                    VTXTABLE_POWERLEVEL.vtxtable_powerlevel_value = data.readU16()
                    powerLabelLength = data.readU8()
                    VTXTABLE_POWERLEVEL.vtxtable_powerlevel_label = ''
                    _i8 = 0
                    while _i8 < powerLabelLength
                        VTXTABLE_POWERLEVEL.vtxtable_powerlevel_label += String.fromCharCode(data.readU8())
                        _i8++
                when MSPCodes.MSP_SET_VTXTABLE_POWERLEVEL
                    console.log 'VTX powerlevel sent'
                when MSPCodes.MSP_SET_MODE_RANGE
                    console.log 'Mode range saved'
                when MSPCodes.MSP_SET_ADJUSTMENT_RANGE
                    console.log 'Adjustment range saved'
                when MSPCodes.MSP_SET_BOARD_ALIGNMENT_CONFIG
                    console.log 'Board alignment saved'
                when MSPCodes.MSP_PID_CONTROLLER
                    PID.controller = data.readU8()
                when MSPCodes.MSP_SET_PID_CONTROLLER
                    console.log 'PID controller changed'
                when MSPCodes.MSP_SET_LOOP_TIME
                    console.log 'Looptime saved'
                when MSPCodes.MSP_SET_ARMING_CONFIG
                    console.log 'Arming config saved'
                when MSPCodes.MSP_SET_RESET_CURR_PID
                    console.log 'Current PID profile reset'
                when MSPCodes.MSP_SET_MOTOR_3D_CONFIG
                    console.log '3D settings saved'
                when MSPCodes.MSP_SET_MIXER_CONFIG
                    console.log 'Mixer config saved'
                when MSPCodes.MSP_SET_RC_DEADBAND
                    console.log 'Rc controls settings saved'
                when MSPCodes.MSP_SET_SENSOR_ALIGNMENT
                    console.log 'Sensor alignment saved'
                when MSPCodes.MSP_SET_RX_CONFIG
                    console.log 'Rx config saved'
                when MSPCodes.MSP_SET_RXFAIL_CONFIG
                    console.log 'Rxfail config saved'
                when MSPCodes.MSP_SET_FAILSAFE_CONFIG
                    console.log 'Failsafe config saved'
                when MSPCodes.MSP_OSD_CONFIG then
                when MSPCodes.MSP_SET_OSD_CONFIG
                    console.log 'OSD config set'
                when MSPCodes.MSP_OSD_CHAR_READ then
                when MSPCodes.MSP_OSD_CHAR_WRITE
                    console.log 'OSD char uploaded'
                when MSPCodes.MSP_SET_NAME
                    console.log 'Name set'
                when MSPCodes.MSP_SET_FILTER_CONFIG
                    console.log 'Filter config set'
                when MSPCodes.MSP_SET_ADVANCED_CONFIG
                    console.log 'Advanced config parameters set'
                when MSPCodes.MSP_SET_SENSOR_CONFIG
                    console.log 'Sensor config parameters set'
                when MSPCodes.MSP_COPY_PROFILE
                    console.log 'Copy profile'
                when MSPCodes.MSP_ARMING_DISABLE
                    console.log 'Arming disable'
                when MSPCodes.MSP_SET_RTC
                    console.log 'Real time clock set'
                when MSPCodes.MSP_MULTIPLE_MSP
                    hasReturnedSomeCommand = false
                    # To avoid infinite loops
                    while data.offset < data.byteLength
                        hasReturnedSomeCommand = true
                        command = self.mspMultipleCache.shift()
                        payloadSize = data.readU8()
                        if payloadSize != 0
                            currentDataHandler = 
                                code: command
                                dataView: new DataView(data.buffer, data.offset, payloadSize)
                                callbacks: []
                            self.process_data currentDataHandler
                            data.offset += payloadSize
                    if hasReturnedSomeCommand
                        # Send again MSP messages missing, the buffer in the FC was too small
                        if self.mspMultipleCache.length > 0
                            partialBuffer = []
                            _i9 = 0
                            while _i9 < self.mspMultipleCache.length
                                partialBuffer.push8 self.mspMultipleCache[_i9]
                                _i9++
                            MSP.send_message MSPCodes.MSP_MULTIPLE_MSP, partialBuffer, false, dataHandler.callbacks
                            dataHandler.callbacks = []
                    else
                        console.log 'MSP Multiple can\'t process the command'
                        self.mspMultipleCache = []
                else
                    console.log 'Unknown code detected: ' + code
        else
            console.log 'FC reports unsupported message error: ' + code
            switch code
                when MSPCodes.MSP_SET_REBOOT
                    TABS.onboard_logging.mscRebootFailedCallback()
    # trigger callbacks, cleanup/remove callback after trigger
    i = dataHandler.callbacks.length - 1
    while i >= 0
        # itterating in reverse because we use .splice which modifies array length
        if dataHandler.callbacks[i].code == code
            # save callback reference
            callback = dataHandler.callbacks[i].callback
            callbackOnError = dataHandler.callbacks[i].callbackOnError
            # remove timeout
            clearInterval dataHandler.callbacks[i].timer
            # remove object from array
            dataHandler.callbacks.splice i, 1
            if !crcError or callbackOnError
                # fire callback
                if callback
                    callback
                        'command': code
                        'data': data
                        'length': data.byteLength
                        'crcError': crcError
        i--
    return

###*
# Encode the request body for the MSP request with the given code and return it as an array of bytes.
###

MspHelper::crunch = (code) ->
    `var i`
    `var i`
    `var i`
    `var i`
    `var i`
    `var i`
    buffer = []
    self = this
    switch code
        when MSPCodes.MSP_SET_FEATURE_CONFIG
            featureMask = FEATURE_CONFIG.features.getMask()
            buffer.push32 featureMask
        when MSPCodes.MSP_SET_BEEPER_CONFIG
            beeperMask = BEEPER_CONFIG.beepers.getMask()
            buffer.push32 beeperMask
            if semver.gte(CONFIG.apiVersion, '1.37.0')
                buffer.push8 BEEPER_CONFIG.dshotBeaconTone
            if semver.gte(CONFIG.apiVersion, '1.39.0')
                buffer.push32 BEEPER_CONFIG.dshotBeaconConditions.getMask()
        when MSPCodes.MSP_SET_MIXER_CONFIG
            buffer.push8 MIXER_CONFIG.mixer
            if semver.gte(CONFIG.apiVersion, '1.36.0')
                buffer.push8 MIXER_CONFIG.reverseMotorDir
        when MSPCodes.MSP_SET_BOARD_ALIGNMENT_CONFIG
            buffer.push16(BOARD_ALIGNMENT_CONFIG.roll).push16(BOARD_ALIGNMENT_CONFIG.pitch).push16 BOARD_ALIGNMENT_CONFIG.yaw
        when MSPCodes.MSP_SET_PID_CONTROLLER
            buffer.push8 PID.controller
        when MSPCodes.MSP_SET_PID
            i = 0
            while i < PIDs.length
                j = 0
                while j < 3
                    buffer.push8 parseInt(PIDs[i][j])
                    j++
                i++
        when MSPCodes.MSP_SET_RC_TUNING
            buffer.push8(Math.round(RC_tuning.RC_RATE * 100)).push8 Math.round(RC_tuning.RC_EXPO * 100)
            if semver.lt(CONFIG.apiVersion, '1.7.0')
                buffer.push8 Math.round(RC_tuning.roll_pitch_rate * 100)
            else
                buffer.push8(Math.round(RC_tuning.roll_rate * 100)).push8 Math.round(RC_tuning.pitch_rate * 100)
            buffer.push8(Math.round(RC_tuning.yaw_rate * 100)).push8(Math.round(RC_tuning.dynamic_THR_PID * 100)).push8(Math.round(RC_tuning.throttle_MID * 100)).push8 Math.round(RC_tuning.throttle_EXPO * 100)
            if semver.gte(CONFIG.apiVersion, '1.7.0')
                buffer.push16 RC_tuning.dynamic_THR_breakpoint
            if semver.gte(CONFIG.apiVersion, '1.10.0')
                buffer.push8 Math.round(RC_tuning.RC_YAW_EXPO * 100)
                if semver.gte(CONFIG.apiVersion, '1.16.0')
                    buffer.push8 Math.round(RC_tuning.rcYawRate * 100)
            if semver.gte(CONFIG.apiVersion, '1.37.0')
                buffer.push8 Math.round(RC_tuning.rcPitchRate * 100)
                buffer.push8 Math.round(RC_tuning.RC_PITCH_EXPO * 100)
            if semver.gte(CONFIG.apiVersion, '1.41.0')
                buffer.push8 RC_tuning.throttleLimitType
                buffer.push8 RC_tuning.throttleLimitPercent
            if semver.gte(CONFIG.apiVersion, '1.42.0')
                buffer.push16 RC_tuning.roll_rate_limit
                buffer.push16 RC_tuning.pitch_rate_limit
                buffer.push16 RC_tuning.yaw_rate_limit
        when MSPCodes.MSP_SET_RX_MAP
            i = 0
            while i < RC_MAP.length
                buffer.push8 RC_MAP[i]
                i++
        when MSPCodes.MSP_SET_ACC_TRIM
            buffer.push16(CONFIG.accelerometerTrims[0]).push16 CONFIG.accelerometerTrims[1]
        when MSPCodes.MSP_SET_ARMING_CONFIG
            buffer.push8(ARMING_CONFIG.auto_disarm_delay).push8 ARMING_CONFIG.disarm_kill_switch
            if semver.gte(CONFIG.apiVersion, '1.37.0')
                buffer.push8 ARMING_CONFIG.small_angle
        when MSPCodes.MSP_SET_LOOP_TIME
            buffer.push16 FC_CONFIG.loopTime
        when MSPCodes.MSP_SET_MISC
            buffer.push16(RX_CONFIG.midrc).push16(MOTOR_CONFIG.minthrottle).push16(MOTOR_CONFIG.maxthrottle).push16(MOTOR_CONFIG.mincommand).push16(MISC.failsafe_throttle).push8(GPS_CONFIG.provider).push8(MISC.gps_baudrate).push8(GPS_CONFIG.ublox_sbas).push8(MISC.multiwiicurrentoutput).push8(RSSI_CONFIG.channel).push8 MISC.placeholder2
            if semver.lt(CONFIG.apiVersion, '1.18.0')
                buffer.push16 Math.round(COMPASS_CONFIG.mag_declination * 10)
            else
                buffer.push16 Math.round(COMPASS_CONFIG.mag_declination * 100)
            buffer.push8(MISC.vbatscale).push8(Math.round(MISC.vbatmincellvoltage * 10)).push8(Math.round(MISC.vbatmaxcellvoltage * 10)).push8 Math.round(MISC.vbatwarningcellvoltage * 10)
        when MSPCodes.MSP_SET_MOTOR_CONFIG
            buffer.push16(MOTOR_CONFIG.minthrottle).push16(MOTOR_CONFIG.maxthrottle).push16 MOTOR_CONFIG.mincommand
            if semver.gte(CONFIG.apiVersion, '1.42.0')
                buffer.push8 MOTOR_CONFIG.motor_poles
                buffer.push8 if MOTOR_CONFIG.use_dshot_telemetry then 1 else 0
        when MSPCodes.MSP_SET_GPS_CONFIG
            buffer.push8(GPS_CONFIG.provider).push8 GPS_CONFIG.ublox_sbas
            if semver.gte(CONFIG.apiVersion, '1.34.0')
                buffer.push8(GPS_CONFIG.auto_config).push8 GPS_CONFIG.auto_baud
        when MSPCodes.MSP_SET_GPS_RESCUE
            buffer.push16(GPS_RESCUE.angle).push16(GPS_RESCUE.initialAltitudeM).push16(GPS_RESCUE.descentDistanceM).push16(GPS_RESCUE.rescueGroundspeed).push16(GPS_RESCUE.throttleMin).push16(GPS_RESCUE.throttleMax).push16(GPS_RESCUE.throttleHover).push8(GPS_RESCUE.sanityChecks).push8 GPS_RESCUE.minSats
        when MSPCodes.MSP_SET_COMPASS_CONFIG
            buffer.push16 Math.round(COMPASS_CONFIG.mag_declination * 100)
        when MSPCodes.MSP_SET_RSSI_CONFIG
            buffer.push8 RSSI_CONFIG.channel
        when MSPCodes.MSP_SET_BATTERY_CONFIG
            buffer.push8(Math.round(BATTERY_CONFIG.vbatmincellvoltage * 10)).push8(Math.round(BATTERY_CONFIG.vbatmaxcellvoltage * 10)).push8(Math.round(BATTERY_CONFIG.vbatwarningcellvoltage * 10)).push16(BATTERY_CONFIG.capacity).push8(BATTERY_CONFIG.voltageMeterSource).push8 BATTERY_CONFIG.currentMeterSource
            if semver.gte(CONFIG.apiVersion, '1.41.0')
                buffer.push16(Math.round(BATTERY_CONFIG.vbatmincellvoltage * 100)).push16(Math.round(BATTERY_CONFIG.vbatmaxcellvoltage * 100)).push16 Math.round(BATTERY_CONFIG.vbatwarningcellvoltage * 100)
        when MSPCodes.MSP_SET_VOLTAGE_METER_CONFIG
            if semver.lt(CONFIG.apiVersion, '1.36.0')
                buffer.push8(MISC.vbatscale).push8(Math.round(MISC.vbatmincellvoltage * 10)).push8(Math.round(MISC.vbatmaxcellvoltage * 10)).push8 Math.round(MISC.vbatwarningcellvoltage * 10)
                if semver.gte(CONFIG.apiVersion, '1.23.0')
                    buffer.push8 MISC.batterymetertype
        when MSPCodes.MSP_SET_CURRENT_METER_CONFIG
            if semver.lt(CONFIG.apiVersion, '1.36.0')
                buffer.push16(BF_CONFIG.currentscale).push16(BF_CONFIG.currentoffset).push8(BF_CONFIG.currentmetertype).push16 BF_CONFIG.batterycapacity
        when MSPCodes.MSP_SET_RX_CONFIG
            buffer.push8(RX_CONFIG.serialrx_provider).push16(RX_CONFIG.stick_max).push16(RX_CONFIG.stick_center).push16(RX_CONFIG.stick_min).push8(RX_CONFIG.spektrum_sat_bind).push16(RX_CONFIG.rx_min_usec).push16 RX_CONFIG.rx_max_usec
            if semver.gte(CONFIG.apiVersion, '1.20.0')
                buffer.push8(RX_CONFIG.rcInterpolation).push8(RX_CONFIG.rcInterpolationInterval).push16 RX_CONFIG.airModeActivateThreshold
                if semver.gte(CONFIG.apiVersion, '1.31.0')
                    buffer.push8(RX_CONFIG.rxSpiProtocol).push32(RX_CONFIG.rxSpiId).push8(RX_CONFIG.rxSpiRfChannelCount).push8 RX_CONFIG.fpvCamAngleDegrees
                    if semver.gte(CONFIG.apiVersion, '1.40.0')
                        buffer.push8(RX_CONFIG.rcInterpolationChannels).push8(RX_CONFIG.rcSmoothingType).push8(RX_CONFIG.rcSmoothingInputCutoff).push8(RX_CONFIG.rcSmoothingDerivativeCutoff).push8(RX_CONFIG.rcSmoothingInputType).push8 RX_CONFIG.rcSmoothingDerivativeType
                        if semver.gte(CONFIG.apiVersion, '1.42.0')
                            buffer.push8(RX_CONFIG.usbCdcHidType).push8 RX_CONFIG.rcSmoothingAutoSmoothness
        when MSPCodes.MSP_SET_FAILSAFE_CONFIG
            buffer.push8(FAILSAFE_CONFIG.failsafe_delay).push8(FAILSAFE_CONFIG.failsafe_off_delay).push16 FAILSAFE_CONFIG.failsafe_throttle
            if semver.gte(CONFIG.apiVersion, '1.15.0')
                buffer.push8(FAILSAFE_CONFIG.failsafe_switch_mode).push16(FAILSAFE_CONFIG.failsafe_throttle_low_delay).push8 FAILSAFE_CONFIG.failsafe_procedure
        when MSPCodes.MSP_SET_TRANSPONDER_CONFIG
            if semver.gte(CONFIG.apiVersion, '1.33.0')
                buffer.push8 TRANSPONDER.provider
                #
            i = 0
            while i < TRANSPONDER.data.length
                buffer.push8 TRANSPONDER.data[i]
                i++
        when MSPCodes.MSP_SET_CHANNEL_FORWARDING
            i = 0
            while i < SERVO_CONFIG.length
                out = SERVO_CONFIG[i].indexOfChannelToForward
                if out == undefined
                    out = 255
                    # Cleanflight defines "CHANNEL_FORWARDING_DISABLED" as "(uint8_t)0xFF"
                buffer.push8 out
                i++
        when MSPCodes.MSP_SET_CF_SERIAL_CONFIG
            if semver.lt(CONFIG.apiVersion, '1.6.0')
                i = 0
                while i < SERIAL_CONFIG.ports.length
                    buffer.push8 SERIAL_CONFIG.ports[i].scenario
                    i++
                buffer.push32(SERIAL_CONFIG.mspBaudRate).push32(SERIAL_CONFIG.cliBaudRate).push32(SERIAL_CONFIG.gpsBaudRate).push32 SERIAL_CONFIG.gpsPassthroughBaudRate
            else
                i = 0
                while i < SERIAL_CONFIG.ports.length
                    serialPort = SERIAL_CONFIG.ports[i]
                    buffer.push8 serialPort.identifier
                    functionMask = self.serialPortFunctionsToMask(serialPort.functions)
                    buffer.push16(functionMask).push8(self.BAUD_RATES.indexOf(serialPort.msp_baudrate)).push8(self.BAUD_RATES.indexOf(serialPort.gps_baudrate)).push8(self.BAUD_RATES.indexOf(serialPort.telemetry_baudrate)).push8 self.BAUD_RATES.indexOf(serialPort.blackbox_baudrate)
                    i++
        when MSPCodes.MSP_SET_MOTOR_3D_CONFIG
            buffer.push16(MOTOR_3D_CONFIG.deadband3d_low).push16(MOTOR_3D_CONFIG.deadband3d_high).push16 MOTOR_3D_CONFIG.neutral
            if semver.lt(CONFIG.apiVersion, '1.17.0')
                buffer.push16 RC_DEADBAND_CONFIG.deadband3d_throttle
        when MSPCodes.MSP_SET_RC_DEADBAND
            buffer.push8(RC_DEADBAND_CONFIG.deadband).push8(RC_DEADBAND_CONFIG.yaw_deadband).push8 RC_DEADBAND_CONFIG.alt_hold_deadband
            if semver.gte(CONFIG.apiVersion, '1.17.0')
                buffer.push16 RC_DEADBAND_CONFIG.deadband3d_throttle
        when MSPCodes.MSP_SET_SENSOR_ALIGNMENT
            buffer.push8(SENSOR_ALIGNMENT.align_gyro).push8(SENSOR_ALIGNMENT.align_acc).push8 SENSOR_ALIGNMENT.align_mag
            if semver.gte(CONFIG.apiVersion, '1.41.0')
                buffer.push8(SENSOR_ALIGNMENT.gyro_to_use).push8(SENSOR_ALIGNMENT.gyro_1_align).push8 SENSOR_ALIGNMENT.gyro_2_align
        when MSPCodes.MSP_SET_ADVANCED_CONFIG
            buffer.push8(PID_ADVANCED_CONFIG.gyro_sync_denom).push8(PID_ADVANCED_CONFIG.pid_process_denom).push8(PID_ADVANCED_CONFIG.use_unsyncedPwm).push8(self.reorderPwmProtocols(PID_ADVANCED_CONFIG.fast_pwm_protocol)).push16 PID_ADVANCED_CONFIG.motor_pwm_rate
            if semver.gte(CONFIG.apiVersion, '1.24.0')
                buffer.push16 PID_ADVANCED_CONFIG.digitalIdlePercent * 100
                if semver.gte(CONFIG.apiVersion, '1.25.0')
                    gyroUse32kHz = 0
                    if semver.lt(CONFIG.apiVersion, '1.41.0')
                        gyroUse32kHz = PID_ADVANCED_CONFIG.gyroUse32kHz
                    buffer.push8 gyroUse32kHz
                    if semver.gte(CONFIG.apiVersion, '1.42.0')
                        buffer.push8(PID_ADVANCED_CONFIG.motorPwmInversion).push8(SENSOR_ALIGNMENT.gyro_to_use).push8(PID_ADVANCED_CONFIG.gyroHighFsr).push8(PID_ADVANCED_CONFIG.gyroMovementCalibThreshold).push16(PID_ADVANCED_CONFIG.gyroCalibDuration).push16(PID_ADVANCED_CONFIG.gyroOffsetYaw).push8(PID_ADVANCED_CONFIG.gyroCheckOverflow).push8 PID_ADVANCED_CONFIG.debugMode
        when MSPCodes.MSP_SET_FILTER_CONFIG
            buffer.push8(FILTER_CONFIG.gyro_lowpass_hz).push16(FILTER_CONFIG.dterm_lowpass_hz).push16 FILTER_CONFIG.yaw_lowpass_hz
            if semver.gte(CONFIG.apiVersion, '1.20.0')
                buffer.push16(FILTER_CONFIG.gyro_notch_hz).push16(FILTER_CONFIG.gyro_notch_cutoff).push16(FILTER_CONFIG.dterm_notch_hz).push16 FILTER_CONFIG.dterm_notch_cutoff
                if semver.gte(CONFIG.apiVersion, '1.21.0')
                    buffer.push16(FILTER_CONFIG.gyro_notch2_hz).push16 FILTER_CONFIG.gyro_notch2_cutoff
                if semver.gte(CONFIG.apiVersion, '1.36.0')
                    buffer.push8 FILTER_CONFIG.dterm_lowpass_type
                if semver.gte(CONFIG.apiVersion, '1.39.0')
                    gyro_32khz_hardware_lpf = 0
                    if semver.lt(CONFIG.apiVersion, '1.41.0')
                        gyro_32khz_hardware_lpf = FILTER_CONFIG.gyro_32khz_hardware_lpf
                    buffer.push8(FILTER_CONFIG.gyro_hardware_lpf).push8(gyro_32khz_hardware_lpf).push16(FILTER_CONFIG.gyro_lowpass_hz).push16(FILTER_CONFIG.gyro_lowpass2_hz).push8(FILTER_CONFIG.gyro_lowpass_type).push8(FILTER_CONFIG.gyro_lowpass2_type).push16 FILTER_CONFIG.dterm_lowpass2_hz
                if semver.gte(CONFIG.apiVersion, '1.41.0')
                    buffer.push8(FILTER_CONFIG.dterm_lowpass2_type).push16(FILTER_CONFIG.gyro_lowpass_dyn_min_hz).push16(FILTER_CONFIG.gyro_lowpass_dyn_max_hz).push16(FILTER_CONFIG.dterm_lowpass_dyn_min_hz).push16 FILTER_CONFIG.dterm_lowpass_dyn_max_hz
                if semver.gte(CONFIG.apiVersion, '1.42.0')
                    buffer.push8(FILTER_CONFIG.dyn_notch_range).push8(FILTER_CONFIG.dyn_notch_width_percent).push16(FILTER_CONFIG.dyn_notch_q).push16(FILTER_CONFIG.dyn_notch_min_hz).push8(FILTER_CONFIG.gyro_rpm_notch_harmonics).push8 FILTER_CONFIG.gyro_rpm_notch_min_hz
                buffer.push8 FILTER_CONFIG.cadence_gain
        when MSPCodes.MSP_SET_PID_ADVANCED
            if semver.gte(CONFIG.apiVersion, '1.20.0')
                buffer.push16(ADVANCED_TUNING.rollPitchItermIgnoreRate).push16(ADVANCED_TUNING.yawItermIgnoreRate).push16(ADVANCED_TUNING.yaw_p_limit).push8(ADVANCED_TUNING.deltaMethod).push8 ADVANCED_TUNING.vbatPidCompensation
                if semver.gte(CONFIG.apiVersion, '1.40.0')
                    buffer.push8 ADVANCED_TUNING.feedforwardTransition
                else
                    buffer.push8 ADVANCED_TUNING.dtermSetpointTransition
                buffer.push8(Math.min(ADVANCED_TUNING.dtermSetpointWeight, 254)).push8(ADVANCED_TUNING.toleranceBand).push8(ADVANCED_TUNING.toleranceBandReduction).push8(ADVANCED_TUNING.itermThrottleGain).push16(ADVANCED_TUNING.pidMaxVelocity).push16 ADVANCED_TUNING.pidMaxVelocityYaw
                if semver.gte(CONFIG.apiVersion, '1.24.0')
                    buffer.push8(ADVANCED_TUNING.levelAngleLimit).push8 ADVANCED_TUNING.levelSensitivity
                    if semver.gte(CONFIG.apiVersion, '1.36.0')
                        buffer.push16(ADVANCED_TUNING.itermThrottleThreshold).push16 ADVANCED_TUNING.itermAcceleratorGain
                        if semver.gte(CONFIG.apiVersion, '1.39.0')
                            buffer.push16 ADVANCED_TUNING.dtermSetpointWeight
                            if semver.gte(CONFIG.apiVersion, '1.40.0')
                                buffer.push8(ADVANCED_TUNING.itermRotation).push8(ADVANCED_TUNING.smartFeedforward).push8(ADVANCED_TUNING.itermRelax).push8(ADVANCED_TUNING.itermRelaxType).push8(ADVANCED_TUNING.absoluteControlGain).push8(ADVANCED_TUNING.throttleBoost).push8(ADVANCED_TUNING.acroTrainerAngleLimit).push16(ADVANCED_TUNING.feedforwardRoll).push16(ADVANCED_TUNING.feedforwardPitch).push16(ADVANCED_TUNING.feedforwardYaw).push8 ADVANCED_TUNING.antiGravityMode
                                if semver.gte(CONFIG.apiVersion, '1.41.0')
                                    buffer.push8(ADVANCED_TUNING.dMinRoll).push8(ADVANCED_TUNING.dMinPitch).push8(ADVANCED_TUNING.dMinYaw).push8(ADVANCED_TUNING.dMinGain).push8(ADVANCED_TUNING.dMinAdvance).push8(ADVANCED_TUNING.useIntegratedYaw).push8(ADVANCED_TUNING.integratedYawRelax).push8(ADVANCED_TUNING.flapBaseFrequency).push8 ADVANCED_TUNING.flapBaseAmplitude + 128
                                    console.log 'ADVANCED_TUNING', ADVANCED_TUNING
                                    if semver.gte(CONFIG.apiVersion, '1.42.0')
                                        buffer.push8 ADVANCED_TUNING.itermRelaxCutoff
                                        # Signed → wire=val+128
                                        buffer.push8 ADVANCED_TUNING.cadence_gain + 128
                                        buffer.push8 ADVANCED_TUNING.ferocity_d_gain + 128
                                        buffer.push8 ADVANCED_TUNING.balance_gain + 128
                                        # Unsigned 0–100 → direct
                                        buffer.push8 ADVANCED_TUNING.ferocity_p_gain
                                        buffer.push8 ADVANCED_TUNING.ferocity_roll_gain
                                        buffer.push8 ADVANCED_TUNING.ferocity_yaw_gain
                                        # Signed → wire=val+128
                                        buffer.push8 ADVANCED_TUNING.warp_gain + 128
                                        buffer.push8 ADVANCED_TUNING.warp_yaw_gain + 128
                                        # Unsigned 0–100 → direct
                                        buffer.push8 ADVANCED_TUNING.anchor_gain
                                        buffer.push8 ADVANCED_TUNING.resonance_gain
                                        if semver.gte(CONFIG.apiVersion, '1.43.0')
                                            # Phase 2 — Wing Pair Geometry (signed → wire=val+128)
                                            buffer.push8 (ADVANCED_TUNING.servo_mount_angle_0 or 0) + 128
                                            buffer.push8 (ADVANCED_TUNING.servo_mount_angle_1 or 0) + 128
                                            buffer.push8 (ADVANCED_TUNING.servo_mount_angle_2 or 0) + 128
                                            buffer.push8 (ADVANCED_TUNING.servo_mount_angle_3 or 0) + 128
                                            buffer.push8 (ADVANCED_TUNING.flapping_phase_shift_0 or 0) + 128
                                            buffer.push8 (ADVANCED_TUNING.flapping_phase_shift_1 or 0) + 128
                                            buffer.push8 (ADVANCED_TUNING.flapping_phase_shift_2 or 0) + 128
                                            buffer.push8 (ADVANCED_TUNING.flapping_phase_shift_3 or 0) + 128
                                            # Phase 2 — Advanced ONDAS Gains (unsigned 0–100, direct wire)
                                            buffer.push8 ADVANCED_TUNING.prescience_gain or 0
                                            buffer.push8 ADVANCED_TUNING.espelho_gain or 0
                                            buffer.push8 ADVANCED_TUNING.saudade_gain or 0
                                            buffer.push8 ADVANCED_TUNING.ssff_gain or 0
                                            if semver.gte(CONFIG.apiVersion, '1.44.0')
                                                # Phase 4 — GralhaAzul: physical servo params + wing trim
                                                buffer.push16 ADVANCED_TUNING.servo_speed_deg_s or 0
                                                buffer.push8 ADVANCED_TUNING.servo_max_amplitude or 0
                                                buffer.push8 ADVANCED_TUNING.flap_magnitude or 0
                                                buffer.push8 (ADVANCED_TUNING.wing_origin_offset_0 or 0) + 128
                                                buffer.push8 (ADVANCED_TUNING.wing_origin_offset_1 or 0) + 128
                                                buffer.push8 (ADVANCED_TUNING.wing_origin_offset_2 or 0) + 128
                                                buffer.push8 (ADVANCED_TUNING.wing_origin_offset_3 or 0) + 128
                                                if semver.gte(CONFIG.apiVersion, '1.45.0')
                                                    # Phase 5 — Independent flight mode: unified frequency channel
                                                    buffer.push8 ADVANCED_TUNING.ornithopter_freq_channel or 0
                                                    buffer.push8 ADVANCED_TUNING.ornithopter_freq_min or 1
                                                    buffer.push8 ADVANCED_TUNING.ornithopter_freq_max or 25
                                                    if semver.gte(CONFIG.apiVersion, '1.46.0')
                                                        # Phase 6 — Ornithopter profile + aeroelastic params
                                                        buffer.push8 ADVANCED_TUNING.ornithopter_profile_index or 0
                                                        # Unsigned 0–100 → direct (0 is valid: no power / no twist)
                                                        buffer.push8 ADVANCED_TUNING.ferocity_downstroke
                                                        buffer.push8 ADVANCED_TUNING.ferocity_upstroke
                                                        # Signed → wire=val+128
                                                        buffer.push8 (ADVANCED_TUNING.aeroelastic_glide_coefficient or 0) + 128
                                                        buffer.push8 (ADVANCED_TUNING.aeroelastic_flap_coefficient or 0) + 128
            else
                buffer.push16(ADVANCED_TUNING.rollPitchItermIgnoreRate).push16(ADVANCED_TUNING.yawItermIgnoreRate).push16(ADVANCED_TUNING.yaw_p_limit).push8(ADVANCED_TUNING.deltaMethod).push8 ADVANCED_TUNING.vbatPidCompensation
        when MSPCodes.MSP_SET_SENSOR_CONFIG
            buffer.push8(SENSOR_CONFIG.acc_hardware).push8(SENSOR_CONFIG.baro_hardware).push8 SENSOR_CONFIG.mag_hardware
        when MSPCodes.MSP_SET_NAME
            MSP_BUFFER_SIZE = 64
            i = 0
            while i < CONFIG.name.length and i < MSP_BUFFER_SIZE
                buffer.push8 CONFIG.name.charCodeAt(i)
                i++
        when MSPCodes.MSP_SET_BLACKBOX_CONFIG
            buffer.push8(BLACKBOX.blackboxDevice).push8(BLACKBOX.blackboxRateNum).push8 BLACKBOX.blackboxRateDenom
            if semver.gte(CONFIG.apiVersion, '1.36.0')
                buffer.push16 BLACKBOX.blackboxPDenom
        when MSPCodes.MSP_COPY_PROFILE
            buffer.push8(COPY_PROFILE.type).push8(COPY_PROFILE.dstProfile).push8 COPY_PROFILE.srcProfile
        when MSPCodes.MSP_ARMING_DISABLE
            value = undefined
            if CONFIG.armingDisabled
                value = 1
            else
                value = 0
            buffer.push8 value
            if CONFIG.runawayTakeoffPreventionDisabled
                value = 1
            else
                value = 0
            # This will be ignored if `armingDisabled` is true
            buffer.push8 value
        when MSPCodes.MSP_SET_RTC
            now = new Date
            if semver.gte(CONFIG.apiVersion, '1.41.0')
                timestamp = now.getTime()
                secs = timestamp / 1000
                millis = timestamp % 1000
                buffer.push32 secs
                buffer.push16 millis
            else
                buffer.push16 now.getUTCFullYear()
                buffer.push8 now.getUTCMonth() + 1
                buffer.push8 now.getUTCDate()
                buffer.push8 now.getUTCHours()
                buffer.push8 now.getUTCMinutes()
                buffer.push8 now.getUTCSeconds()
        when MSPCodes.MSP_SET_VTX_CONFIG
            buffer.push16(VTX_CONFIG.vtx_frequency).push8(VTX_CONFIG.vtx_power).push8(if VTX_CONFIG.vtx_pit_mode then 1 else 0).push8 VTX_CONFIG.vtx_low_power_disarm
            if semver.gte(CONFIG.apiVersion, '1.42.0')
                buffer.push16(VTX_CONFIG.vtx_pit_mode_frequency).push8(VTX_CONFIG.vtx_band).push8(VTX_CONFIG.vtx_channel).push16(VTX_CONFIG.vtx_frequency).push8(VTX_CONFIG.vtx_table_bands).push8(VTX_CONFIG.vtx_table_channels).push8(VTX_CONFIG.vtx_table_powerlevels).push8 if VTX_CONFIG.vtx_table_clear then 1 else 0
        when MSPCodes.MSP_SET_VTXTABLE_POWERLEVEL
            buffer.push8(VTXTABLE_POWERLEVEL.vtxtable_powerlevel_number).push16 VTXTABLE_POWERLEVEL.vtxtable_powerlevel_value
            buffer.push8 VTXTABLE_POWERLEVEL.vtxtable_powerlevel_label.length
            _i0 = 0
            while _i0 < VTXTABLE_POWERLEVEL.vtxtable_powerlevel_label.length
                buffer.push8 VTXTABLE_POWERLEVEL.vtxtable_powerlevel_label.charCodeAt(_i0)
                _i0++
        when MSPCodes.MSP_SET_VTXTABLE_BAND
            buffer.push8 VTXTABLE_BAND.vtxtable_band_number
            buffer.push8 VTXTABLE_BAND.vtxtable_band_name.length
            _i1 = 0
            while _i1 < VTXTABLE_BAND.vtxtable_band_name.length
                buffer.push8 VTXTABLE_BAND.vtxtable_band_name.charCodeAt(_i1)
                _i1++
            if VTXTABLE_BAND.vtxtable_band_letter != ''
                buffer.push8 VTXTABLE_BAND.vtxtable_band_letter.charCodeAt(0)
            else
                buffer.push8 ' '.charCodeAt(0)
            buffer.push8 if VTXTABLE_BAND.vtxtable_band_is_factory_band then 1 else 0
            buffer.push8 VTXTABLE_BAND.vtxtable_band_frequencies.length
            _i10 = 0
            while _i10 < VTXTABLE_BAND.vtxtable_band_frequencies.length
                buffer.push16 VTXTABLE_BAND.vtxtable_band_frequencies[_i10]
                _i10++
        when MSPCodes.MSP_MULTIPLE_MSP
            while MULTIPLE_MSP.msp_commands.length > 0
                mspCommand = MULTIPLE_MSP.msp_commands.shift()
                self.mspMultipleCache.push mspCommand
                buffer.push8 mspCommand
        else
            return false
    buffer

###*
# Set raw Rx values over MSP protocol.
#
# Channels is an array of 16-bit unsigned integer channel values to be sent. 8 channels is probably the maximum.
###

MspHelper::setRawRx = (channels) ->
    buffer = []
    i = 0
    while i < channels.length
        buffer.push16 channels[i]
        i++
    MSP.send_message MSPCodes.MSP_SET_RAW_RC, buffer, false
    return

###*
# Send a request to read a block of data from the dataflash at the given address and pass that address and a dataview
# of the returned data to the given callback (or null for the data if an error occured).
###

MspHelper::dataflashRead = (address, blockSize, onDataCallback) ->
    outData = [
        address & 0xFF
        address >> 8 & 0xFF
        address >> 16 & 0xFF
        address >> 24 & 0xFF
    ]
    if semver.gte(CONFIG.apiVersion, '1.31.0')
        outData = outData.concat([
            blockSize & 0xFF
            blockSize >> 8 & 0xFF
        ])
    if semver.gte(CONFIG.apiVersion, '1.36.0')
        # Allow compression
        outData = outData.concat([ 1 ])
    MSP.send_message MSPCodes.MSP_DATAFLASH_READ, outData, false, ((response) ->
        if !response.crcError
            chunkAddress = response.data.readU32()
            headerSize = 4
            dataSize = response.data.buffer.byteLength - headerSize
            dataCompressionType = 0
            if semver.gte(CONFIG.apiVersion, '1.31.0')
                headerSize = headerSize + 3
                dataSize = response.data.readU16()
                dataCompressionType = response.data.readU8()
            # Verify that the address of the memory returned matches what the caller asked for and there was not a CRC error
            if chunkAddress == address

                ### Strip that address off the front of the reply and deliver it separately so the caller doesn't have to
                # figure out the reply format:
                ###

                if dataCompressionType == 0
                    onDataCallback address, new DataView(response.data.buffer, response.data.byteOffset + headerSize, dataSize)
                else if dataCompressionType == 1
                    # Read compressed char count to avoid decoding stray bit sequences as bytes
                    compressedCharCount = response.data.readU16()
                    # Compressed format uses 2 additional bytes as a pseudo-header to denote the number of uncompressed bytes
                    compressedArray = new Uint8Array(response.data.buffer, response.data.byteOffset + headerSize + 2, dataSize - 2)
                    decompressedArray = huffmanDecodeBuf(compressedArray, compressedCharCount, defaultHuffmanTree, defaultHuffmanLenIndex)
                    onDataCallback address, new DataView(decompressedArray.buffer), dataSize
            else
                # Report address error
                console.log 'Expected address ' + address + ' but received ' + chunkAddress + ' - retrying'
                onDataCallback address, null
                # returning null to the callback forces a retry
        else
            # Report crc error
            console.log 'CRC error for address ' + address + ' - retrying'
            onDataCallback address, null
            # returning null to the callback forces a retry
        return
    ), true
    return

MspHelper::sendServoConfigurations = (onCompleteCallback) ->
    nextFunction = send_next_servo_configuration
    servoIndex = 0

    send_next_servo_configuration = ->
        buffer = []
        if semver.lt(CONFIG.apiVersion, '1.12.0')
            # send all in one go
            # 1.9.0 had a bug where the MSP input buffer was too small, limit to 8.
            i = 0
            while i < SERVO_CONFIG.length and i < 8
                buffer.push16(SERVO_CONFIG[i].min).push16(SERVO_CONFIG[i].max).push16(SERVO_CONFIG[i].middle).push8 SERVO_CONFIG[i].rate
                i++
            nextFunction = send_channel_forwarding
        else
            servoConfiguration = SERVO_CONFIG[servoIndex]
            # send other servo config as a smaller package
            if SERVO_CONFIG.ornithopter_glide_deg != null and !SERVO_CONFIG.ornithopter_glide_deg_sent
                buffer.push8 SERVO_CONFIG.ornithopter_glide_deg + 128
                # Signed → wire=val+128
                buffer.push8 SERVO_CONFIG.cadence_gain + 128
                buffer.push8 SERVO_CONFIG.ferocity_d_gain + 128
                buffer.push8 SERVO_CONFIG.balance_gain + 128
                SERVO_CONFIG.ornithopter_glide_deg_sent = true
            else
                # send one at a time, with index
                buffer.push8(servoIndex).push16(servoConfiguration.min).push16(servoConfiguration.max).push16(servoConfiguration.middle).push8 servoConfiguration.rate
                if semver.lt(CONFIG.apiVersion, '1.33.0')
                    buffer.push8(servoConfiguration.angleAtMin).push8 servoConfiguration.angleAtMax
                out = servoConfiguration.indexOfChannelToForward
                if out == undefined
                    out = 255
                    # Cleanflight defines "CHANNEL_FORWARDING_DISABLED" as "(uint8_t)0xFF"
                servoIndex++
                console.log 'added servo', servoIndex, buffer
                buffer.push8(out).push32 servoConfiguration.reversedInputSources
            # prepare for next iteration
            if servoIndex == SERVO_CONFIG.length + 1
                nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_SERVO_CONFIGURATION, buffer, false, nextFunction
        return

    send_channel_forwarding = ->
        buffer = []
        i = 0
        while i < SERVO_CONFIG.length
            out = SERVO_CONFIG[i].indexOfChannelToForward
            if out == undefined
                out = 255
                # Cleanflight defines "CHANNEL_FORWARDING_DISABLED" as "(uint8_t)0xFF"
            buffer.push8 out
            i++
        nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_CHANNEL_FORWARDING, buffer, false, nextFunction
        return

    if SERVO_CONFIG.length == 0
        onCompleteCallback()
    else
        nextFunction()
    return

MspHelper::sendModeRanges = (onCompleteCallback) ->
    nextFunction = send_next_mode_range
    modeRangeIndex = 0

    send_next_mode_range = ->
        modeRange = MODE_RANGES[modeRangeIndex]
        buffer = []
        buffer.push8(modeRangeIndex).push8(modeRange.id).push8(modeRange.auxChannelIndex).push8((modeRange.range.start - 900) / 25).push8 (modeRange.range.end - 900) / 25
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            modeRangeExtra = MODE_RANGES_EXTRA[modeRangeIndex]
            buffer.push8(modeRangeExtra.modeLogic).push8 modeRangeExtra.linkedTo
        # prepare for next iteration
        modeRangeIndex++
        if modeRangeIndex == MODE_RANGES.length
            nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_MODE_RANGE, buffer, false, nextFunction
        return

    if MODE_RANGES.length == 0
        onCompleteCallback()
    else
        send_next_mode_range()
    return

MspHelper::sendAdjustmentRanges = (onCompleteCallback) ->
    nextFunction = send_next_adjustment_range
    adjustmentRangeIndex = 0

    send_next_adjustment_range = ->
        adjustmentRange = ADJUSTMENT_RANGES[adjustmentRangeIndex]
        buffer = []
        buffer.push8(adjustmentRangeIndex).push8(adjustmentRange.slotIndex).push8(adjustmentRange.auxChannelIndex).push8((adjustmentRange.range.start - 900) / 25).push8((adjustmentRange.range.end - 900) / 25).push8(adjustmentRange.adjustmentFunction).push8 adjustmentRange.auxSwitchChannelIndex
        # prepare for next iteration
        adjustmentRangeIndex++
        if adjustmentRangeIndex == ADJUSTMENT_RANGES.length
            nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_ADJUSTMENT_RANGE, buffer, false, nextFunction
        return

    if ADJUSTMENT_RANGES.length == 0
        onCompleteCallback()
    else
        send_next_adjustment_range()
    return

MspHelper::sendVoltageConfig = (onCompleteCallback) ->
    nextFunction = send_next_voltage_config
    configIndex = 0

    send_next_voltage_config = ->
        buffer = []
        buffer.push8(VOLTAGE_METER_CONFIGS[configIndex].id).push8(VOLTAGE_METER_CONFIGS[configIndex].vbatscale).push8(VOLTAGE_METER_CONFIGS[configIndex].vbatresdivval).push8 VOLTAGE_METER_CONFIGS[configIndex].vbatresdivmultiplier
        # prepare for next iteration
        configIndex++
        if configIndex == VOLTAGE_METER_CONFIGS.length
            nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_VOLTAGE_METER_CONFIG, buffer, false, nextFunction
        return

    if VOLTAGE_METER_CONFIGS.length == 0
        onCompleteCallback()
    else
        send_next_voltage_config()
    return

MspHelper::sendCurrentConfig = (onCompleteCallback) ->
    nextFunction = send_next_current_config
    configIndex = 0

    send_next_current_config = ->
        buffer = []
        buffer.push8(CURRENT_METER_CONFIGS[configIndex].id).push16(CURRENT_METER_CONFIGS[configIndex].scale).push16 CURRENT_METER_CONFIGS[configIndex].offset
        # prepare for next iteration
        configIndex++
        if configIndex == CURRENT_METER_CONFIGS.length
            nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_CURRENT_METER_CONFIG, buffer, false, nextFunction
        return

    if CURRENT_METER_CONFIGS.length == 0
        onCompleteCallback()
    else
        send_next_current_config()
    return

MspHelper::sendLedStripConfig = (onCompleteCallback) ->
    nextFunction = send_next_led_strip_config
    ledIndex = 0

    send_next_led_strip_config = ->
        `var ledOverlayLetters`
        `var bitIndex`
        `var functionLetterIndex`
        `var bitIndex`
        `var directionLetterIndex`
        `var bitIndex`
        led = LED_STRIP[ledIndex]
        ledDirectionLetters = [
            'n'
            'e'
            's'
            'w'
            'u'
            'd'
        ]
        # in LSB bit order
        ledFunctionLetters = [
            'i'
            'w'
            'f'
            'a'
            't'
            'r'
            'c'
            'g'
            's'
            'b'
            'l'
        ]
        # in LSB bit order
        ledBaseFunctionLetters = [
            'c'
            'f'
            'a'
            'l'
            's'
            'g'
            'r'
        ]
        # in LSB bit
        if semver.lt(CONFIG.apiVersion, '1.36.0')
            ledOverlayLetters = [
                't'
                'o'
                'b'
                'w'
                'i'
                'w'
            ]
            # in LSB bit
        else
            ledOverlayLetters = [
                't'
                'o'
                'b'
                'v'
                'i'
                'w'
            ]
            # in LSB bit
        buffer = []
        buffer.push ledIndex
        if semver.lt(CONFIG.apiVersion, '1.20.0')
            directionMask = 0
            directionLetterIndex = 0
            while directionLetterIndex < led.directions.length
                bitIndex = ledDirectionLetters.indexOf(led.directions[directionLetterIndex])
                if bitIndex >= 0
                    directionMask = bit_set(directionMask, bitIndex)
                directionLetterIndex++
            buffer.push16 directionMask
            functionMask = 0
            functionLetterIndex = 0
            while functionLetterIndex < led.functions.length
                bitIndex = ledFunctionLetters.indexOf(led.functions[functionLetterIndex])
                if bitIndex >= 0
                    functionMask = bit_set(functionMask, bitIndex)
                functionLetterIndex++
            buffer.push16(functionMask).push8(led.x).push8(led.y).push8 led.color
        else
            mask = 0
            mask |= led.y << 0
            mask |= led.x << 4
            functionLetterIndex = 0
            while functionLetterIndex < led.functions.length
                fnIndex = ledBaseFunctionLetters.indexOf(led.functions[functionLetterIndex])
                if fnIndex >= 0
                    mask |= fnIndex << 8
                    break
                functionLetterIndex++
            overlayLetterIndex = 0
            while overlayLetterIndex < led.functions.length
                bitIndex = ledOverlayLetters.indexOf(led.functions[overlayLetterIndex])
                if bitIndex >= 0
                    mask |= bit_set(mask, bitIndex + 12)
                overlayLetterIndex++
            mask |= led.color << 18
            directionLetterIndex = 0
            while directionLetterIndex < led.directions.length
                bitIndex = ledDirectionLetters.indexOf(led.directions[directionLetterIndex])
                if bitIndex >= 0
                    mask |= bit_set(mask, bitIndex + 22)
                directionLetterIndex++
            mask |= 0 << 28
            # parameters
            buffer.push32 mask
        # prepare for next iteration
        ledIndex++
        if ledIndex == LED_STRIP.length
            nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_LED_STRIP_CONFIG, buffer, false, nextFunction
        return

    if LED_STRIP.length == 0
        onCompleteCallback()
    else
        send_next_led_strip_config()
    return

MspHelper::sendLedStripColors = (onCompleteCallback) ->
    if LED_COLORS.length == 0
        onCompleteCallback()
    else
        buffer = []
        colorIndex = 0
        while colorIndex < LED_COLORS.length
            color = LED_COLORS[colorIndex]
            buffer.push16(color.h).push8(color.s).push8 color.v
            colorIndex++
        MSP.send_message MSPCodes.MSP_SET_LED_COLORS, buffer, false, onCompleteCallback
    return

MspHelper::sendLedStripModeColors = (onCompleteCallback) ->
    nextFunction = send_next_led_strip_mode_color
    index = 0

    send_next_led_strip_mode_color = ->
        buffer = []
        mode_color = LED_MODE_COLORS[index]
        buffer.push8(mode_color.mode).push8(mode_color.direction).push8 mode_color.color
        # prepare for next iteration
        index++
        if index == LED_MODE_COLORS.length
            nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_LED_STRIP_MODECOLOR, buffer, false, nextFunction
        return

    if LED_MODE_COLORS.length == 0
        onCompleteCallback()
    else
        send_next_led_strip_mode_color()
    return

MspHelper::serialPortFunctionMaskToFunctions = (functionMask) ->
    self = this
    functions = []
    keys = Object.keys(self.SERIAL_PORT_FUNCTIONS)
    index = 0
    while index < keys.length
        key = keys[index]
        bit = self.SERIAL_PORT_FUNCTIONS[key]
        if bit_check(functionMask, bit)
            functions.push key
        index++
    functions

MspHelper::serialPortFunctionsToMask = (functions) ->
    self = this
    mask = 0
    keys = Object.keys(self.SERIAL_PORT_FUNCTIONS)
    index = 0
    while index < functions.length
        key = functions[index]
        bitIndex = self.SERIAL_PORT_FUNCTIONS[key]
        if bitIndex >= 0
            mask = bit_set(mask, bitIndex)
        index++
    mask

MspHelper::sendRxFailConfig = (onCompleteCallback) ->
    nextFunction = send_next_rxfail_config
    rxFailIndex = 0

    send_next_rxfail_config = ->
        rxFail = RXFAIL_CONFIG[rxFailIndex]
        buffer = []
        buffer.push8(rxFailIndex).push8(rxFail.mode).push16 rxFail.value
        # prepare for next iteration
        rxFailIndex++
        if rxFailIndex == RXFAIL_CONFIG.length
            nextFunction = onCompleteCallback
        MSP.send_message MSPCodes.MSP_SET_RXFAIL_CONFIG, buffer, false, nextFunction
        return

    if RXFAIL_CONFIG.length == 0
        onCompleteCallback()
    else
        send_next_rxfail_config()
    return

MspHelper::setArmingEnabled = (doEnable, disableRunawayTakeoffPrevention, onCompleteCallback) ->
    if semver.gte(CONFIG.apiVersion, '1.37.0') and (CONFIG.armingDisabled == doEnable or CONFIG.runawayTakeoffPreventionDisabled != disableRunawayTakeoffPrevention)
        CONFIG.armingDisabled = !doEnable
        CONFIG.runawayTakeoffPreventionDisabled = disableRunawayTakeoffPrevention
        MSP.send_message MSPCodes.MSP_ARMING_DISABLE, mspHelper.crunch(MSPCodes.MSP_ARMING_DISABLE), false, ->
            if doEnable
                GUI.log i18n.getMessage('armingEnabled')
                if disableRunawayTakeoffPrevention
                    GUI.log i18n.getMessage('runawayTakeoffPreventionDisabled')
                else
                    GUI.log i18n.getMessage('runawayTakeoffPreventionEnabled')
            else
                GUI.log i18n.getMessage('armingDisabled')
            if onCompleteCallback
                onCompleteCallback()
            return
    else
        if onCompleteCallback
            onCompleteCallback()
    return

MSP.SDCARD_STATE_NOT_PRESENT = 0
#TODO, move these to better place
MSP.SDCARD_STATE_FATAL = 1
MSP.SDCARD_STATE_CARD_INIT = 2
MSP.SDCARD_STATE_FS_INIT = 3
MSP.SDCARD_STATE_READY = 4