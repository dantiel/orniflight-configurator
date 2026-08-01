'use strict'
TABS.motors =
    escProtocolIsDshot: false
    sensor: 'gyro'
    sensorGyroRate: 20
    sensorGyroScale: 2000
    sensorAccelRate: 20
    sensorAccelScale: 2
    sensorSelectValues:
        'gyroScale':
            '10': 10
            '25': 25
            '50': 50
            '100': 100
            '200': 200
            '300': 300
            '400': 400
            '500': 500
            '1000': 1000
            '2000': 2000
        'accelScale':
            '0.05': 0.05
            '0.1': 0.1
            '0.2': 0.2
            '0.3': 0.3
            '0.4': 0.4
            '0.5': 0.5
            '1': 1
            '2': 2
    DSHOT_DISARMED_VALUE: 1000
    DSHOT_MAX_VALUE: 2000

TABS.motors.initialize = (callback) ->
    self = this

    get_arm_status = ->
        MSP.send_message MSPCodes.MSP_STATUS, false, false, load_feature_config
        return

    load_feature_config = ->
        MSP.send_message MSPCodes.MSP_FEATURE_CONFIG, false, false, load_motor_3d_config
        return

    load_motor_3d_config = ->
        MSP.send_message MSPCodes.MSP_MOTOR_3D_CONFIG, false, false, load_esc_protocol
        return

    load_esc_protocol = ->
        MSP.send_message MSPCodes.MSP_ADVANCED_CONFIG, false, false, load_motor_data
        return

    load_motor_data = ->
        MSP.send_message MSPCodes.MSP_MOTOR, false, false, load_motor_telemetry_data
        return

    load_motor_telemetry_data = ->
        if MOTOR_CONFIG.use_dshot_telemetry or MOTOR_CONFIG.use_esc_sensor
            MSP.send_message MSPCodes.MSP_MOTOR_TELEMETRY, false, false, load_mixer_config
        else
            load_mixer_config()
        return

    load_mixer_config = ->
        MSP.send_message MSPCodes.MSP_MIXER_CONFIG, false, false, load_html
        return

    load_html = ->
        $('#content').load './tabs/motors.html', process_html
        return

    update_arm_status = ->
        self.armed = bit_check(CONFIG.mode, 0)
        return

    initSensorData = ->
        i = 0
        while i < 3
            SENSOR_DATA.accelerometer[i] = 0
            SENSOR_DATA.gyroscope[i] = 0
            i++
        return

    initDataArray = (length) ->
        data = new Array(length)
        i = 0
        while i < length
            data[i] = []
            data[i].min = -1
            data[i].max = 1
            i++
        data

    addSampleToData = (data, sampleNumber, sensorData) ->
        i = 0
        while i < data.length
            dataPoint = sensorData[i]
            data[i].push [
                sampleNumber
                dataPoint
            ]
            if dataPoint < data[i].min
                data[i].min = dataPoint
            if dataPoint > data[i].max
                data[i].max = dataPoint
            i++
        while data[0].length > 300
            i = 0
            while i < data.length
                data[i].shift()
                i++
        sampleNumber + 1

    updateGraphHelperSize = (helpers) ->
        helpers.width = helpers.targetElement.width() - (margin.left) - (margin.right)
        helpers.height = helpers.targetElement.height() - (margin.top) - (margin.bottom)
        helpers.widthScale.range [
            0
            helpers.width
        ]
        helpers.heightScale.range [
            helpers.height
            0
        ]
        helpers.xGrid.tickSize -helpers.height, 0, 0
        helpers.yGrid.tickSize -helpers.width, 0, 0
        return

    initGraphHelpers = (selector, sampleNumber, heightDomain) ->
        helpers = 
            selector: selector
            targetElement: $(selector)
            dynamicHeightDomain: !heightDomain
        helpers.widthScale = d3.scale.linear().clamp(true).domain([
            sampleNumber - 299
            sampleNumber
        ])
        helpers.heightScale = d3.scale.linear().clamp(true).domain(heightDomain or [
            1
            -1
        ])
        helpers.xGrid = d3.svg.axis()
        helpers.yGrid = d3.svg.axis()
        updateGraphHelperSize helpers
        helpers.xGrid.scale(helpers.widthScale).orient('bottom').ticks(5).tickFormat ''
        helpers.yGrid.scale(helpers.heightScale).orient('left').ticks(5).tickFormat ''
        helpers.xAxis = d3.svg.axis().scale(helpers.widthScale).ticks(5).orient('bottom').tickFormat((d) ->
            d
        )
        helpers.yAxis = d3.svg.axis().scale(helpers.heightScale).ticks(5).orient('left').tickFormat((d) ->
            d
        )
        helpers.line = d3.svg.line().x((d) ->
            helpers.widthScale d[0]
        ).y((d) ->
            helpers.heightScale d[1]
        )
        helpers

    drawGraph = (graphHelpers, data, sampleNumber) ->
        svg = d3.select(graphHelpers.selector)
        if graphHelpers.dynamicHeightDomain
            limits = []
            $.each data, (idx, datum) ->
                limits.push datum.min
                limits.push datum.max
                return
            graphHelpers.heightScale.domain d3.extent(limits)
        graphHelpers.widthScale.domain [
            sampleNumber - 299
            sampleNumber
        ]
        svg.select('.x.grid').call graphHelpers.xGrid
        svg.select('.y.grid').call graphHelpers.yGrid
        svg.select('.x.axis').call graphHelpers.xAxis
        svg.select('.y.axis').call graphHelpers.yAxis
        group = svg.select('g.data')
        lines = group.selectAll('path').data(data, (d, i) ->
            i
        )
        lines.enter().append('path').attr 'class', 'line'
        lines.attr 'd', graphHelpers.line
        return

    update_model = (mixer) ->
        reverse = ''
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            reverse = if MIXER_CONFIG.reverseMotorDir then '_reversed' else ''
        entry = mixerList[mixer] or mixerList[27] or image: 'ornithopter'
        $('.mixerPreview img').attr 'src', './resources/motor_order/' + entry.image + reverse + '.svg'
        return

    process_html = ->
        # translate to user-selected language

        loadScaleSelector = (selectorValues, selectedValue) ->
            $('.tab-motors select[name="scale"]').find('option').remove()
            $.each selectorValues, (key, val) ->
                $('.tab-motors select[name="scale"]').append new Option(key, val)
                return
            $('.tab-motors select[name="scale"]').val selectedValue
            return

        selectRefresh = (refreshValue) ->
            $('.tab-motors select[name="rate"]').val refreshValue
            return

        # Amperage

        power_data_pull = ->
            motor_voltage_e.text i18n.getMessage('motorsVoltageValue', [ ANALOG.voltage ])
            motor_mah_drawing_e.text i18n.getMessage('motorsADrawingValue', [ ANALOG.amperage.toFixed(2) ])
            motor_mah_drawn_e.text i18n.getMessage('motorsmAhDrawnValue', [ ANALOG.mAhdrawn ])
            return

        # data pulling functions used inside interval timer

        get_status = ->
            # status needed for arming flag
            MSP.send_message MSPCodes.MSP_STATUS, false, false, get_motor_data
            return

        get_motor_data = ->
            MSP.send_message MSPCodes.MSP_MOTOR, false, false, get_motor_telemetry_data
            return

        get_motor_telemetry_data = ->
            if MOTOR_CONFIG.use_dshot_telemetry or MOTOR_CONFIG.use_esc_sensor
                MSP.send_message MSPCodes.MSP_MOTOR_TELEMETRY, false, false, get_servo_data
            else
                get_servo_data()
            return

        get_servo_data = ->
            MSP.send_message MSPCodes.MSP_SERVO, false, false, update_ui
            return

        update_ui = ->
            `var i`
            `var margin_top`
            `var height`
            `var color`
            block_height = $('div.m-block:first').height()
            i = 0
            while i < MOTOR_DATA.length
                motorValue = MOTOR_DATA[i]
                barHeight = motorValue - rangeMin
                margin_top = block_height - (barHeight * block_height / full_block_scale).clamp(0, block_height)
                height = (barHeight * block_height / full_block_scale).clamp(0, block_height)
                color = parseInt(barHeight * 0.009)
                $('.motor-' + i + ' .label', motors_wrapper).text motorValue
                $('.motor-' + i + ' .indicator', motors_wrapper).css
                    'margin-top': margin_top + 'px'
                    'height': height + 'px'
                    'background-color': 'rgba(255,187,0,1.' + color + ')'
                if i < MOTOR_CONFIG.motor_count and (MOTOR_CONFIG.use_dshot_telemetry or MOTOR_CONFIG.use_esc_sensor)
                    MAX_INVALID_PERCENT = 100
                    MAX_VALUE_SIZE = 6
                    rpmMotorValue = MOTOR_TELEMETRY_DATA.rpm[i]
                    # Reduce the size of the value if too big
                    if rpmMotorValue > 999999
                        rpmMotorValue = (rpmMotorValue / 1000000).toFixed(5 - ((rpmMotorValue / 1000000).toFixed(0).toString().length)) + 'M'
                    rpmMotorValue = rpmMotorValue.toString().padStart(MAX_VALUE_SIZE)
                    telemetryText = i18n.getMessage('motorsRPM', motorsRpmValue: rpmMotorValue)
                    if MOTOR_CONFIG.use_dshot_telemetry
                        invalidPercent = MOTOR_TELEMETRY_DATA.invalidPercent[i]
                        classError = if invalidPercent > MAX_INVALID_PERCENT then 'warning' else ''
                        invalidPercent = (invalidPercent / 100).toFixed(2).toString().padStart(MAX_VALUE_SIZE)
                        telemetryText += '<br><span class=\'' + classError + '\'>'
                        telemetryText += i18n.getMessage('motorsRPMError', motorsErrorValue: invalidPercent)
                        telemetryText += '</span>'
                    if MOTOR_CONFIG.use_esc_sensor
                        escTemperature = MOTOR_TELEMETRY_DATA.temperature[i]
                        telemetryText += '<br>'
                        escTemperature = escTemperature.toString().padStart(MAX_VALUE_SIZE)
                        telemetryText += i18n.getMessage('motorsESCTemperature', motorsESCTempValue: escTemperature)
                i++
            # servo indicators are still using old (not flexible block scale), it will be changed in the future accordingly
            i = 0
            while i < SERVO_DATA.length
                data = SERVO_DATA[i] - 1000
                margin_top = block_height - (data * block_height / 1000).clamp(0, block_height)
                height = (data * block_height / 1000).clamp(0, block_height)
                color = parseInt(data * 0.009)
                $('.servo-' + i + ' .label', servos_wrapper).text SERVO_DATA[i]
                $('.servo-' + i + ' .indicator', servos_wrapper).css
                    'margin-top': margin_top + 'px'
                    'height': height + 'px'
                    'background-color': 'rgba(255,187,0,1' + color + ')'
                i++
            #keep the following here so at least we get a visual cue of our motor setup
            update_arm_status()
            return

        i18n.localizePage()
        update_arm_status()
        if PID_ADVANCED_CONFIG.fast_pwm_protocol >= TABS.configuration.DSHOT_PROTOCOL_MIN_VALUE
            self.escProtocolIsDshot = true
        else
            self.escProtocolIsDshot = false
        update_model MIXER_CONFIG.mixer
        # Always start with default/empty sensor data array, clean slate all
        initSensorData()
        # Setup variables
        samples_gyro_i = 0
        gyro_data = initDataArray(3)
        gyro_helpers = initGraphHelpers('#graph', samples_gyro_i, [
            -2
            2
        ])
        gyro_max_read = [
            0
            0
            0
        ]
        samples_accel_i = 0
        accel_data = initDataArray(3)
        accel_helpers = initGraphHelpers('#graph', samples_accel_i, [
            -2
            2
        ])
        accel_max_read = [
            0
            0
            0
        ]
        accel_offset = [
            0
            0
            0
        ]
        accel_offset_established = false
        # cached elements
        motor_voltage_e = $('.motors-bat-voltage')
        motor_mah_drawing_e = $('.motors-bat-mah-drawing')
        motor_mah_drawn_e = $('.motors-bat-mah-drawn')
        raw_data_text_ements = 
            x: []
            y: []
            z: []
            rms: []
        $('.plot_control .x, .plot_control .y, .plot_control .z, .plot_control .rms').each ->
            el = $(this)
            if el.hasClass('x')
                raw_data_text_ements.x.push el
            else if el.hasClass('y')
                raw_data_text_ements.y.push el
            else if el.hasClass('z')
                raw_data_text_ements.z.push el
            else if el.hasClass('rms')
                raw_data_text_ements.rms.push el
            return
        $('.tab-motors .sensor select').change ->
            TABS.motors.sensor = $('.tab-motors select[name="sensor_choice"]').val()
            ConfigStorage.set 'motors_tab_sensor_settings': 'sensor': TABS.motors.sensor
            switch TABS.motors.sensor
                when 'gyro'
                    loadScaleSelector TABS.motors.sensorSelectValues.gyroScale, TABS.motors.sensorGyroScale
                    selectRefresh TABS.motors.sensorGyroRate
                when 'accel'
                    loadScaleSelector TABS.motors.sensorSelectValues.accelScale, TABS.motors.sensorAccelScale
                    selectRefresh TABS.motors.sensorAccelRate
            $('.tab-motors .rate select:first').change()
            return
        $('.tab-motors .rate select, .tab-motors .scale select').change ->
            rate = parseInt($('.tab-motors select[name="rate"]').val(), 10)
            scale = parseFloat($('.tab-motors select[name="scale"]').val())

            update_accel_graph = ->
                `var i`
                if !accel_offset_established
                    i = 0
                    while i < 3
                        accel_offset[i] = SENSOR_DATA.accelerometer[i] * -1
                        i++
                    accel_offset_established = true
                accel_with_offset = [
                    accel_offset[0] + SENSOR_DATA.accelerometer[0]
                    accel_offset[1] + SENSOR_DATA.accelerometer[1]
                    accel_offset[2] + SENSOR_DATA.accelerometer[2]
                ]
                updateGraphHelperSize accel_helpers
                samples_accel_i = addSampleToData(accel_data, samples_accel_i, accel_with_offset)
                drawGraph accel_helpers, accel_data, samples_accel_i
                i = 0
                while i < 3
                    if Math.abs(accel_with_offset[i]) > Math.abs(accel_max_read[i])
                        accel_max_read[i] = accel_with_offset[i]
                    i++
                computeAndUpdate accel_with_offset, accel_data, accel_max_read
                return

            update_gyro_graph = ->
                gyro = [
                    SENSOR_DATA.gyroscope[0]
                    SENSOR_DATA.gyroscope[1]
                    SENSOR_DATA.gyroscope[2]
                ]
                updateGraphHelperSize gyro_helpers
                samples_gyro_i = addSampleToData(gyro_data, samples_gyro_i, gyro)
                drawGraph gyro_helpers, gyro_data, samples_gyro_i
                i = 0
                while i < 3
                    if Math.abs(gyro[i]) > Math.abs(gyro_max_read[i])
                        gyro_max_read[i] = gyro[i]
                    i++
                computeAndUpdate gyro, gyro_data, gyro_max_read
                return

            computeAndUpdate = (sensor_data, data, max_read) ->
                sum = 0.0
                j = 0
                jlength = data.length
                while j < jlength
                    k = 0
                    klength = data[j].length
                    while k < klength
                        sum += data[j][k][1] * data[j][k][1]
                        k++
                    j++
                rms = Math.sqrt(sum / (data[0].length + data[1].length + data[2].length))
                raw_data_text_ements.x[0].text sensor_data[0].toFixed(2) + ' (' + max_read[0].toFixed(2) + ')'
                raw_data_text_ements.y[0].text sensor_data[1].toFixed(2) + ' (' + max_read[1].toFixed(2) + ')'
                raw_data_text_ements.z[0].text sensor_data[2].toFixed(2) + ' (' + max_read[2].toFixed(2) + ')'
                raw_data_text_ements.rms[0].text rms.toFixed(4)
                return

            GUI.interval_kill_all [
                'motor_and_status_pull'
                'motors_power_data_pull_slow'
            ]
            switch TABS.motors.sensor
                when 'gyro'
                    ConfigStorage.set 'motors_tab_gyro_settings':
                        'rate': rate
                        'scale': scale
                    TABS.motors.sensorGyroRate = rate
                    TABS.motors.sensorGyroScale = scale
                    gyro_helpers = initGraphHelpers('#graph', samples_gyro_i, [
                        -scale
                        scale
                    ])
                    GUI.interval_add 'IMU_pull', (->
                        MSP.send_message MSPCodes.MSP_RAW_IMU, false, false, update_gyro_graph
                        return
                    ), rate, true
                when 'accel'
                    ConfigStorage.set 'motors_tab_accel_settings':
                        'rate': rate
                        'scale': scale
                    TABS.motors.sensorAccelRate = rate
                    TABS.motors.sensorAccelScale = scale
                    accel_helpers = initGraphHelpers('#graph', samples_accel_i, [
                        -scale
                        scale
                    ])
                    GUI.interval_add 'IMU_pull', (->
                        MSP.send_message MSPCodes.MSP_RAW_IMU, false, false, update_accel_graph
                        return
                    ), rate, true
            return
        # set refresh speeds according to configuration saved in storage
        ConfigStorage.get [
            'motors_tab_sensor_settings'
            'motors_tab_gyro_settings'
            'motors_tab_accel_settings'
        ], (result) ->
            if result.motors_tab_sensor_settings
                sensor = result.motors_tab_sensor_settings.sensor
                $('.tab-motors select[name="sensor_choice"]').val result.motors_tab_sensor_settings.sensor
            if result.motors_tab_gyro_settings
                TABS.motors.sensorGyroRate = result.motors_tab_gyro_settings.rate
                TABS.motors.sensorGyroScale = result.motors_tab_gyro_settings.scale
            if result.motors_tab_accel_settings
                TABS.motors.sensorAccelRate = result.motors_tab_accel_settings.rate
                TABS.motors.sensorAccelScale = result.motors_tab_accel_settings.scale
            $('.tab-motors .sensor select:first').change()
            return
        GUI.interval_add 'motors_power_data_pull_slow', power_data_pull, 250, true
        # 4 fps
        $('a.reset_max').click ->
            gyro_max_read = [
                0
                0
                0
            ]
            accel_max_read = [
                0
                0
                0
            ]
            accel_offset_established = false
            return
        rangeMin = undefined
        rangeMax = undefined
        if self.escProtocolIsDshot
            rangeMin = self.DSHOT_DISARMED_VALUE
            rangeMax = self.DSHOT_MAX_VALUE
        else
            rangeMin = MOTOR_CONFIG.mincommand
            rangeMax = MOTOR_CONFIG.maxthrottle
        motors_wrapper = $('.motors .bar-wrapper')
        servos_wrapper = $('.servos .bar-wrapper')
        i = 0
        while i < 8
            motors_wrapper.append '                    <div class="m-block motor-' + i + '">                    <div class="meter-bar">                    <div class="label"></div>                    <div class="indicator">                    <div class="label">                    <div class="label"></div>                    </div>                    </div>                    </div>                    </div>            '
            servos_wrapper.append '                    <div class="m-block servo-' + 7 - i + '">                    <div class="meter-bar">                    <div class="label"></div>                    <div class="indicator">                    <div class="label">                    <div class="label"></div>                    </div>                    </div>                    </div>                    </div>            '
            i++
        $('div.sliders input').prop('min', rangeMin).prop 'max', rangeMax
        $('div.values li:not(:last)').text rangeMin
        full_block_scale = rangeMax - rangeMin
        # enable Status and Motor data pulling
        GUI.interval_add 'motor_and_status_pull', get_status, 50, true
        GUI.content_ready callback
        return

    self.armed = false
    self.escProtocolIsDshot = false
    if GUI.active_tab != 'motors'
        GUI.active_tab = 'motors'
    # Get information from FC
    if semver.gte(CONFIG.apiVersion, '1.36.0')
        # BF 3.2.0+
        MSP.send_message MSPCodes.MSP_MOTOR_CONFIG, false, false, get_arm_status
    else
        # BF 3.1.x or older
        MSP.send_message MSPCodes.MSP_MISC, false, false, get_arm_status
    margin = 
        top: 20
        right: 30
        bottom: 10
        left: 20
    return

TABS.motors.cleanup = (callback) ->
    if callback
        callback()
    return

