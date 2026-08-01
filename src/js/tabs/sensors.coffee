'use strict'
TABS.sensors = {}

TABS.sensors.initialize = (callback) ->
    self = this

    initSensorData = ->
        i = 0
        while i < 3
            SENSOR_DATA.accelerometer[i] = 0
            SENSOR_DATA.gyroscope[i] = 0
            SENSOR_DATA.magnetometer[i] = 0
            SENSOR_DATA.sonar = 0
            SENSOR_DATA.altitude = 0
            SENSOR_DATA.debug[i] = 0
            i++
        return

    initDataArray = (length) ->
        data = new Array(length)
        i = 0
        while i < length
            data[i] = new Array
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
        newLines = lines.enter().append('path').attr('class', 'line')
        lines.attr 'd', graphHelpers.line
        return

    plot_gyro = (enable) ->
        if enable
            $('.wrapper.gyro').show()
        else
            $('.wrapper.gyro').hide()
        return

    plot_accel = (enable) ->
        if enable
            $('.wrapper.accel').show()
        else
            $('.wrapper.accel').hide()
        return

    plot_mag = (enable) ->
        if enable
            $('.wrapper.mag').show()
        else
            $('.wrapper.mag').hide()
        return

    plot_altitude = (enable) ->
        if enable
            $('.wrapper.altitude').show()
        else
            $('.wrapper.altitude').hide()
        return

    plot_sonar = (enable) ->
        if enable
            $('.wrapper.sonar').show()
        else
            $('.wrapper.sonar').hide()
        return

    plot_debug = (enable) ->
        if enable
            $('.wrapper.debug').show()
        else
            $('.wrapper.debug').hide()
        return

    if GUI.active_tab != 'sensors'
        GUI.active_tab = 'sensors'
    margin = 
        top: 20
        right: 10
        bottom: 10
        left: 40
    $('#content').load './tabs/sensors.html', ->
        # translate to user-selected language
        i18n.localizePage()
        # disable graphs for sensors that are missing
        checkboxes = $('.tab-sensors .info .checkboxes input')
        checkboxes.parent().show()
        if CONFIG.boardType == 0 or CONFIG.boardType == 2
            if !have_sensor(CONFIG.activeSensors, 'acc')
                checkboxes.eq(1).prop 'disabled', true
            if !have_sensor(CONFIG.activeSensors, 'mag')
                checkboxes.eq(2).prop 'disabled', true
            if !(have_sensor(CONFIG.activeSensors, 'baro') or semver.gte(CONFIG.apiVersion, '1.40.0') and have_sensor(CONFIG.activeSensors, 'gps'))
                checkboxes.eq(3).prop 'disabled', true
            if !have_sensor(CONFIG.activeSensors, 'sonar')
                checkboxes.eq(4).prop 'disabled', true
        else
            i = 0
            while i <= 4
                checkboxes.eq(i).prop 'disabled', true
                checkboxes.eq(i).parent().hide()
                i++
        $('.tab-sensors .info .checkboxes input').change ->
            `var checkboxes`
            enable = $(this).prop('checked')
            index = $(this).parent().index()
            switch index
                when 0
                    plot_gyro enable
                when 1
                    plot_accel enable
                when 2
                    plot_mag enable
                when 3
                    plot_altitude enable
                when 4
                    plot_sonar enable
                when 5
                    plot_debug enable
            checkboxes = []
            $('.tab-sensors .info .checkboxes input').each ->
                checkboxes.push $(this).prop('checked')
                return
            $('.tab-sensors .rate select:first').change()
            ConfigStorage.set 'graphs_enabled': checkboxes
            return
        altitudeHint_e = $('.tab-sensors #sensorsAltitudeHint')
        if semver.lt(CONFIG.apiVersion, '1.40.0')
            altitudeHint_e.hide()
        # Always start with default/empty sensor data array, clean slate all
        initSensorData()
        # Setup variables
        samples_gyro_i = 0
        samples_accel_i = 0
        samples_mag_i = 0
        samples_altitude_i = 0
        samples_sonar_i = 0
        samples_debug_i = 0
        gyro_data = initDataArray(3)
        accel_data = initDataArray(3)
        mag_data = initDataArray(3)
        altitude_data = initDataArray(1)
        sonar_data = initDataArray(1)
        debug_data = [
            initDataArray(1)
            initDataArray(1)
            initDataArray(1)
            initDataArray(1)
        ]
        gyroHelpers = initGraphHelpers('#gyro', samples_gyro_i, [
            -2000
            2000
        ])
        accelHelpers = initGraphHelpers('#accel', samples_accel_i, [
            -2
            2
        ])
        magHelpers = initGraphHelpers('#mag', samples_mag_i, [
            -1
            1
        ])
        altitudeHelpers = initGraphHelpers('#altitude', samples_altitude_i)
        sonarHelpers = initGraphHelpers('#sonar', samples_sonar_i)
        debugHelpers = [
            initGraphHelpers('#debug1', samples_debug_i)
            initGraphHelpers('#debug2', samples_debug_i)
            initGraphHelpers('#debug3', samples_debug_i)
            initGraphHelpers('#debug4', samples_debug_i)
        ]
        raw_data_text_ements = 
            x: []
            y: []
            z: []
        $('.plot_control .x, .plot_control .y, .plot_control .z').each ->
            el = $(this)
            if el.hasClass('x')
                raw_data_text_ements.x.push el
            else if el.hasClass('y')
                raw_data_text_ements.y.push el
            else
                raw_data_text_ements.z.push el
            return
        $('.tab-sensors .rate select, .tab-sensors .scale select').change ->
            `var checkboxes`
            # if any of the select fields change value, all of the select values are grabbed
            # and timers are re-initialized with the new settings
            rates = 
                'gyro': parseInt($('.tab-sensors select[name="gyro_refresh_rate"]').val(), 10)
                'accel': parseInt($('.tab-sensors select[name="accel_refresh_rate"]').val(), 10)
                'mag': parseInt($('.tab-sensors select[name="mag_refresh_rate"]').val(), 10)
                'altitude': parseInt($('.tab-sensors select[name="altitude_refresh_rate"]').val(), 10)
                'sonar': parseInt($('.tab-sensors select[name="sonar_refresh_rate"]').val(), 10)
                'debug': parseInt($('.tab-sensors select[name="debug_refresh_rate"]').val(), 10)
            scales = 
                'gyro': parseFloat($('.tab-sensors select[name="gyro_scale"]').val())
                'accel': parseFloat($('.tab-sensors select[name="accel_scale"]').val())
                'mag': parseFloat($('.tab-sensors select[name="mag_scale"]').val())
            # handling of "data pulling" is a little bit funky here, as MSP_RAW_IMU contains values for gyro/accel/mag but not altitude
            # this means that setting a slower refresh rate on any of the attributes would have no effect
            # what we will do instead is = determinate the fastest refresh rate for those 3 attributes, use that as a "polling rate"
            # and use the "slower" refresh rates only for re-drawing the graphs (to save resources/computing power)
            fastest = d3.min([
                rates.gyro
                rates.accel
                rates.mag
            ])
            # store current/latest refresh rates in the storage

            update_imu_graphs = ->
                if checkboxes[0]
                    updateGraphHelperSize gyroHelpers
                    samples_gyro_i = addSampleToData(gyro_data, samples_gyro_i, SENSOR_DATA.gyroscope)
                    drawGraph gyroHelpers, gyro_data, samples_gyro_i
                    raw_data_text_ements.x[0].text SENSOR_DATA.gyroscope[0].toFixed(2)
                    raw_data_text_ements.y[0].text SENSOR_DATA.gyroscope[1].toFixed(2)
                    raw_data_text_ements.z[0].text SENSOR_DATA.gyroscope[2].toFixed(2)
                if checkboxes[1]
                    updateGraphHelperSize accelHelpers
                    samples_accel_i = addSampleToData(accel_data, samples_accel_i, SENSOR_DATA.accelerometer)
                    drawGraph accelHelpers, accel_data, samples_accel_i
                    raw_data_text_ements.x[1].text SENSOR_DATA.accelerometer[0].toFixed(2)
                    raw_data_text_ements.y[1].text SENSOR_DATA.accelerometer[1].toFixed(2)
                    raw_data_text_ements.z[1].text SENSOR_DATA.accelerometer[2].toFixed(2)
                if checkboxes[2]
                    updateGraphHelperSize magHelpers
                    samples_mag_i = addSampleToData(mag_data, samples_mag_i, SENSOR_DATA.magnetometer)
                    drawGraph magHelpers, mag_data, samples_mag_i
                    raw_data_text_ements.x[2].text SENSOR_DATA.magnetometer[0].toFixed(2)
                    raw_data_text_ements.y[2].text SENSOR_DATA.magnetometer[1].toFixed(2)
                    raw_data_text_ements.z[2].text SENSOR_DATA.magnetometer[2].toFixed(2)
                return

            update_altitude_graph = ->
                updateGraphHelperSize altitudeHelpers
                samples_altitude_i = addSampleToData(altitude_data, samples_altitude_i, [ SENSOR_DATA.altitude ])
                drawGraph altitudeHelpers, altitude_data, samples_altitude_i
                raw_data_text_ements.x[3].text SENSOR_DATA.altitude.toFixed(2)
                return

            update_sonar_graphs = ->
                updateGraphHelperSize sonarHelpers
                samples_sonar_i = addSampleToData(sonar_data, samples_sonar_i, [ SENSOR_DATA.sonar ])
                drawGraph sonarHelpers, sonar_data, samples_sonar_i
                raw_data_text_ements.x[4].text SENSOR_DATA.sonar.toFixed(2)
                return

            update_debug_graphs = ->
                `var i`
                i = 0
                while i < 4
                    updateGraphHelperSize debugHelpers[i]
                    addSampleToData debug_data[i], samples_debug_i, [ SENSOR_DATA.debug[i] ]
                    drawGraph debugHelpers[i], debug_data[i], samples_debug_i
                    raw_data_text_ements.x[5 + i].text SENSOR_DATA.debug[i]
                    i++
                samples_debug_i++
                return

            ConfigStorage.set 'sensor_settings':
                'rates': rates
                'scales': scales
            # re-initialize domains with new scales
            gyroHelpers = initGraphHelpers('#gyro', samples_gyro_i, [
                -scales.gyro
                scales.gyro
            ])
            accelHelpers = initGraphHelpers('#accel', samples_accel_i, [
                -scales.accel
                scales.accel
            ])
            magHelpers = initGraphHelpers('#mag', samples_mag_i, [
                -scales.mag
                scales.mag
            ])
            # fetch currently enabled plots
            checkboxes = []
            $('.tab-sensors .info .checkboxes input').each ->
                checkboxes.push $(this).prop('checked')
                return
            # timer initialization
            GUI.interval_kill_all [ 'status_pull' ]
            # data pulling timers
            if checkboxes[0] or checkboxes[1] or checkboxes[2]
                GUI.interval_add 'IMU_pull', (->
                    MSP.send_message MSPCodes.MSP_RAW_IMU, false, false, update_imu_graphs
                    return
                ), fastest, true
            if checkboxes[3]
                GUI.interval_add 'altitude_pull', (->
                    MSP.send_message MSPCodes.MSP_ALTITUDE, false, false, update_altitude_graph
                    return
                ), rates.altitude, true
            if checkboxes[4]
                GUI.interval_add 'sonar_pull', (->
                    MSP.send_message MSPCodes.MSP_SONAR, false, false, update_sonar_graphs
                    return
                ), rates.sonar, true
            if checkboxes[5]
                GUI.interval_add 'debug_pull', (->
                    MSP.send_message MSPCodes.MSP_DEBUG, false, false, update_debug_graphs
                    return
                ), rates.debug, true
            return
        ConfigStorage.get 'sensor_settings', (result) ->
            # set refresh speeds according to configuration saved in storage
            if result.sensor_settings
                $('.tab-sensors select[name="gyro_refresh_rate"]').val result.sensor_settings.rates.gyro
                $('.tab-sensors select[name="gyro_scale"]').val result.sensor_settings.scales.gyro
                $('.tab-sensors select[name="accel_refresh_rate"]').val result.sensor_settings.rates.accel
                $('.tab-sensors select[name="accel_scale"]').val result.sensor_settings.scales.accel
                $('.tab-sensors select[name="mag_refresh_rate"]').val result.sensor_settings.rates.mag
                $('.tab-sensors select[name="mag_scale"]').val result.sensor_settings.scales.mag
                $('.tab-sensors select[name="altitude_refresh_rate"]').val result.sensor_settings.rates.altitude
                $('.tab-sensors select[name="sonar_refresh_rate"]').val result.sensor_settings.rates.sonar
                $('.tab-sensors select[name="debug_refresh_rate"]').val result.sensor_settings.rates.debug
                # start polling data by triggering refresh rate change event
                $('.tab-sensors .rate select:first').change()
            else
                # start polling immediatly (as there is no configuration saved in the storage)
                $('.tab-sensors .rate select:first').change()
            ConfigStorage.get 'graphs_enabled', (resultGraphs) ->
                `var checkboxes`
                `var i`
                if resultGraphs.graphs_enabled
                    checkboxes = $('.tab-sensors .info .checkboxes input')
                    i = 0
                    while i < resultGraphs.graphs_enabled.length
                        checkboxes.eq(i).not(':disabled').prop('checked', resultGraphs.graphs_enabled[i]).change()
                        i++
                else
                    $('.tab-sensors .info input:lt(4):not(:disabled)').prop('checked', true).change()
                return
            return
        # status data pulled via separate timer with static speed
        GUI.interval_add 'status_pull', (->
            MSP.send_message MSPCodes.MSP_STATUS
            return
        ), 250, true
        GUI.content_ready callback
        return
    return

TABS.sensors.cleanup = (callback) ->
    serial.emptyOutputBuffer()
    if callback
        callback()
    return

