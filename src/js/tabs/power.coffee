'use strict'
TABS.power =
    supported: false
    analyticsChanges: {}

TABS.power.initialize = (callback) ->
    self = this

    load_status = ->
        MSP.send_message MSPCodes.MSP_STATUS, false, false, load_voltage_meters
        return

    load_voltage_meters = ->
        MSP.send_message MSPCodes.MSP_VOLTAGE_METERS, false, false, load_current_meters
        return

    load_current_meters = ->
        MSP.send_message MSPCodes.MSP_CURRENT_METERS, false, false, load_current_meter_configs
        return

    load_current_meter_configs = ->
        MSP.send_message MSPCodes.MSP_CURRENT_METER_CONFIG, false, false, load_voltage_meter_configs
        return

    load_voltage_meter_configs = ->
        MSP.send_message MSPCodes.MSP_VOLTAGE_METER_CONFIG, false, false, load_battery_state
        return

    load_battery_state = ->
        MSP.send_message MSPCodes.MSP_BATTERY_STATE, false, false, load_battery_config
        return

    load_battery_config = ->
        MSP.send_message MSPCodes.MSP_BATTERY_CONFIG, false, false, load_html
        return

    load_html = ->
        $('#content').load './tabs/power.html', process_html
        return

    updateDisplay = (voltageDataSource, currentDataSource) ->
        `var index`
        `var template`
        `var index`
        `var destination`
        `var index`
        `var template`
        `var destination`
        `var index`
        `var meterElement`
        `var message`
        `var template`
        `var index`
        `var destination`
        `var element`
        `var attributeNames`
        `var attributeName`
        # voltage meters
        if BATTERY_CONFIG.voltageMeterSource == 0
            $('.boxVoltageConfiguration').hide()
        else
            $('.boxVoltageConfiguration').show()
        if !voltageDataSource
            voltageDataSource = []
            index = 0
            while index < VOLTAGE_METER_CONFIGS.length
                voltageDataSource[index] =
                    vbatscale: parseInt($('input[name="vbatscale-' + index + '"]').val())
                    vbatresdivval: parseInt($('input[name="vbatresdivval-' + index + '"]').val())
                    vbatresdivmultiplier: parseInt($('input[name="vbatresdivmultiplier-' + index + '"]').val())
                index++
        template = $('#tab-power-templates .voltage-meters .voltage-meter')
        destination = $('.tab-power .voltage-meters')
        destination.empty()
        index = 0
        while index < VOLTAGE_METERS.length
            meterElement = template.clone()
            $(meterElement).attr 'id', 'voltage-meter-' + index
            message = i18n.getMessage('powerVoltageId' + VOLTAGE_METERS[index].id)
            $(meterElement).find('.label').text message
            destination.append meterElement
            meterElement.hide()
            if BATTERY_CONFIG.voltageMeterSource == 1 and VOLTAGE_METERS[index].id == 10 or BATTERY_CONFIG.voltageMeterSource == 2 and VOLTAGE_METERS[index].id >= 50
                meterElement.show()
            index++
        template = $('#tab-power-templates .voltage-configuration')
        index = 0
        while index < VOLTAGE_METER_CONFIGS.length
            destination = $('#voltage-meter-' + index + ' .configuration')
            element = template.clone()
            attributeNames = [
                'vbatscale'
                'vbatresdivval'
                'vbatresdivmultiplier'
            ]
            _i = 0
            while _i < attributeNames.length
                attributeName = attributeNames[_i]
                $(element).find('input[name="' + attributeName + '"]').attr 'name', attributeName + '-' + index
                _i++
            destination.append element
            $('input[name="vbatscale-' + index + '"]').val voltageDataSource[index].vbatscale
            $('input[name="vbatresdivval-' + index + '"]').val voltageDataSource[index].vbatresdivval
            $('input[name="vbatresdivmultiplier-' + index + '"]').val voltageDataSource[index].vbatresdivmultiplier
            index++
        $('input[name="vbatscale-0"]').change ->
            value = parseInt($(this).val())
            if value != voltageDataSource[0].vbatscale
                self.analyticsChanges['PowerVBatUpdated'] = value
            return
        # amperage meters
        if BATTERY_CONFIG.currentMeterSource == 0
            $('.boxAmperageConfiguration').hide()
        else
            $('.boxAmperageConfiguration').show()
        if !currentDataSource
            currentDataSource = []
            index = 0
            while index < CURRENT_METER_CONFIGS.length
                currentDataSource[index] =
                    scale: parseInt($('input[name="amperagescale-' + index + '"]').val())
                    offset: parseInt($('input[name="amperageoffset-' + index + '"]').val())
                index++
        template = $('#tab-power-templates .amperage-meters .amperage-meter')
        destination = $('.tab-power .amperage-meters')
        destination.empty()
        index = 0
        while index < CURRENT_METERS.length
            meterElement = template.clone()
            $(meterElement).attr 'id', 'amperage-meter-' + index
            message = i18n.getMessage('powerAmperageId' + CURRENT_METERS[index].id)
            $(meterElement).find('.label').text message
            destination.append meterElement
            meterElement.hide()
            if BATTERY_CONFIG.currentMeterSource == 1 and CURRENT_METERS[index].id == 10 or BATTERY_CONFIG.currentMeterSource == 2 and CURRENT_METERS[index].id == 80 or BATTERY_CONFIG.currentMeterSource == 3 and CURRENT_METERS[index].id >= 50 and CURRENT_METERS[index].id < 80
                meterElement.show()
            index++
        template = $('#tab-power-templates .amperage-configuration')
        index = 0
        while index < CURRENT_METER_CONFIGS.length
            destination = $('#amperage-meter-' + index + ' .configuration')
            element = template.clone()
            attributeNames = [
                'amperagescale'
                'amperageoffset'
            ]
            _j = 0
            while _j < attributeNames.length
                attributeName = attributeNames[_j]
                $(element).find('input[name="' + attributeName + '"]').attr 'name', attributeName + '-' + index
                _j++
            destination.append element
            $('input[name="amperagescale-' + index + '"]').val currentDataSource[index].scale
            $('input[name="amperageoffset-' + index + '"]').val currentDataSource[index].offset
            index++
        $('input[name="amperagescale-0"]').change ->
            if BATTERY_CONFIG.currentMeterSource == 1
                value = parseInt($(this).val())
                if value != currentDataSource[0].scale
                    self.analyticsChanges['PowerAmperageUpdated'] = value
            return
        $('input[name="amperagescale-1"]').change ->
            if BATTERY_CONFIG.currentMeterSource == 2
                value = parseInt($(this).val())
                if value != currentDataSource[1].scale
                    self.analyticsChanges['PowerAmperageUpdated'] = value
            return
        if BATTERY_CONFIG.voltageMeterSource == 1 or BATTERY_CONFIG.currentMeterSource == 1 or BATTERY_CONFIG.currentMeterSource == 2
            $('.calibration').show()
        else
            $('.calibration').hide()
        return

    initDisplay = ->
        `var template`
        `var destination`
        `var element`
        `var i`
        `var batteryMeterType_e`
        `var currentMeterType_e`

        get_slow_data = ->
            MSP.send_message MSPCodes.MSP_VOLTAGE_METERS, false, false, ->
                i = 0
                while i < VOLTAGE_METERS.length
                    elementName = '#voltage-meter-' + i + ' .value'
                    element = $(elementName)
                    element.text i18n.getMessage('powerVoltageValue', [ VOLTAGE_METERS[i].voltage ])
                    i++
                return
            MSP.send_message MSPCodes.MSP_CURRENT_METERS, false, false, ->
                i = 0
                while i < CURRENT_METERS.length
                    elementName = '#amperage-meter-' + i + ' .value'
                    element = $(elementName)
                    element.text i18n.getMessage('powerAmperageValue', [ CURRENT_METERS[i].amperage.toFixed(2) ])
                    i++
                return
            MSP.send_message MSPCodes.MSP_BATTERY_STATE, false, false, ->
                elementPrefix = '#battery'
                element = undefined
                element = $(elementPrefix + '-connection-state .value')
                element.text if BATTERY_STATE.cellCount > 0 then i18n.getMessage('powerBatteryConnectedValueYes', [ BATTERY_STATE.cellCount ]) else i18n.getMessage('powerBatteryConnectedValueNo')
                element = $(elementPrefix + '-voltage .value')
                element.text i18n.getMessage('powerVoltageValue', [ BATTERY_STATE.voltage ])
                element = $(elementPrefix + '-mah-drawn .value')
                element.text i18n.getMessage('powerMahValue', [ BATTERY_STATE.mAhDrawn ])
                element = $(elementPrefix + '-amperage .value')
                element.text i18n.getMessage('powerAmperageValue', [ BATTERY_STATE.amperage ])
                return
            return

        if !TABS.power.supported
            $('.tab-power').removeClass 'supported'
            return
        $('.tab-power').addClass 'supported'
        $('#calibrationmanagercontent').hide()
        $('#calibrationmanagerconfirmcontent').hide()
        # battery
        template = $('#tab-power-templates .battery-state .battery-state')
        destination = $('.tab-power .battery-state')
        element = template.clone()
        $(element).find('.connection-state').attr 'id', 'battery-connection-state'
        $(element).find('.voltage').attr 'id', 'battery-voltage'
        $(element).find('.mah-drawn').attr 'id', 'battery-mah-drawn'
        $(element).find('.amperage').attr 'id', 'battery-amperage'
        destination.append element.children()
        template = $('#tab-power-templates .battery-configuration')
        destination = $('.tab-power .battery .configuration')
        element = template.clone()
        destination.append element
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            $('input[name="mincellvoltage"]').prop 'step', '0.01'
            $('input[name="maxcellvoltage"]').prop 'step', '0.01'
            $('input[name="warningcellvoltage"]').prop 'step', '0.01'
        $('input[name="mincellvoltage"]').val BATTERY_CONFIG.vbatmincellvoltage
        $('input[name="maxcellvoltage"]').val BATTERY_CONFIG.vbatmaxcellvoltage
        $('input[name="warningcellvoltage"]').val BATTERY_CONFIG.vbatwarningcellvoltage
        $('input[name="capacity"]').val BATTERY_CONFIG.capacity
        haveFc = semver.lt(CONFIG.apiVersion, '1.35.0') or CONFIG.boardType == 0 or CONFIG.boardType == 2
        batteryMeterTypes = [
            i18n.getMessage('powerBatteryVoltageMeterTypeNone')
            i18n.getMessage('powerBatteryVoltageMeterTypeAdc')
        ]
        if haveFc
            batteryMeterTypes.push i18n.getMessage('powerBatteryVoltageMeterTypeEsc')
        batteryMeterType_e = $('select.batterymetersource')
        i = 0
        while i < batteryMeterTypes.length
            batteryMeterType_e.append '<option value="' + i + '">' + batteryMeterTypes[i] + '</option>'
            i++
        # fill current
        currentMeterTypes = [
            i18n.getMessage('powerBatteryCurrentMeterTypeNone')
            i18n.getMessage('powerBatteryCurrentMeterTypeAdc')
        ]
        if haveFc
            currentMeterTypes.push i18n.getMessage('powerBatteryCurrentMeterTypeVirtual')
            currentMeterTypes.push i18n.getMessage('powerBatteryCurrentMeterTypeEsc')
            if semver.gte(CONFIG.apiVersion, '1.36.0')
                currentMeterTypes.push i18n.getMessage('powerBatteryCurrentMeterTypeMsp')
        currentMeterType_e = $('select.currentmetersource')
        i = 0
        while i < currentMeterTypes.length
            currentMeterType_e.append '<option value="' + i + '">' + currentMeterTypes[i] + '</option>'
            i++
        updateDisplay VOLTAGE_METER_CONFIGS, CURRENT_METER_CONFIGS
        batteryMeterType_e = $('select.batterymetersource')
        sourceschanged = false
        batteryMeterType_e.val BATTERY_CONFIG.voltageMeterSource
        batteryMeterType_e.change ->
            BATTERY_CONFIG.voltageMeterSource = parseInt($(this).val())
            updateDisplay()
            sourceschanged = true
            return
        currentMeterType_e = $('select.currentmetersource')
        currentMeterType_e.val BATTERY_CONFIG.currentMeterSource
        currentMeterType_e.change ->
            BATTERY_CONFIG.currentMeterSource = parseInt($(this).val())
            updateDisplay()
            sourceschanged = true
            return
        #calibration manager
        calibrationconfirmed = false
        GUI.calibrationManager = new jBox('Modal',
            width: 400
            height: 230
            closeButton: 'title'
            animation: false
            attach: $('#calibrationmanager')
            title: i18n.getMessage('powerCalibrationManagerTitle')
            content: $('#calibrationmanagercontent')
            onCloseComplete: ->
                if !calibrationconfirmed
                    TABS.power.initialize()
                return
)
        GUI.calibrationManagerConfirmation = new jBox('Modal',
            width: 400
            height: 230
            closeButton: 'title'
            animation: false
            attach: $('#calibrate')
            title: i18n.getMessage('powerCalibrationManagerConfirmationTitle')
            content: $('#calibrationmanagerconfirmcontent')
            onCloseComplete: ->
                GUI.calibrationManager.close()
                return
)
        $('a.calibrationmanager').click ->
            if BATTERY_CONFIG.voltageMeterSource == 1 and BATTERY_STATE.voltage > 0.1
                $('.vbatcalibration').show()
            else
                $('.vbatcalibration').hide()
            if (BATTERY_CONFIG.currentMeterSource == 1 or BATTERY_CONFIG.currentMeterSource == 2) and BATTERY_STATE.amperage > 0.1
                $('.amperagecalibration').show()
            else
                $('.amperagecalibration').hide()
            if BATTERY_STATE.cellCount == 0
                $('.vbatcalibration').hide()
                $('.amperagecalibration').hide()
                $('.calibrate').hide()
                $('.nocalib').show()
            else
                $('.calibrate').show()
                $('.nocalib').hide()
            if sourceschanged
                $('.srcchange').show()
                $('.vbatcalibration').hide()
                $('.amperagecalibration').hide()
                $('.calibrate').hide()
                $('.nocalib').hide()
            else
                $('.srcchange').hide()
            return
        $('input[name="vbatcalibration"]').val 0
        $('input[name="amperagecalibration"]').val 0
        vbatscalechanged = false
        amperagescalechanged = false
        $('a.calibrate').click ->
            if BATTERY_CONFIG.voltageMeterSource == 1
                vbatcalibration = parseFloat($('input[name="vbatcalibration"]').val())
                if vbatcalibration != 0
                    vbatnewscale = Math.round(VOLTAGE_METER_CONFIGS[0].vbatscale * vbatcalibration / VOLTAGE_METERS[0].voltage)
                    if vbatnewscale >= 10 and vbatnewscale <= 255
                        VOLTAGE_METER_CONFIGS[0].vbatscale = vbatnewscale
                        vbatscalechanged = true
            ampsource = BATTERY_CONFIG.currentMeterSource
            if ampsource == 1 or ampsource == 2
                amperagecalibration = parseFloat($('input[name="amperagecalibration"]').val())
                amperageoffset = CURRENT_METER_CONFIGS[ampsource - 1].offset / 1000
                if amperagecalibration != 0
                    if CURRENT_METERS[ampsource - 1].amperage != amperageoffset and amperagecalibration != amperageoffset
                        amperagenewscale = Math.round(CURRENT_METER_CONFIGS[ampsource - 1].scale * (CURRENT_METERS[ampsource - 1].amperage - amperageoffset) / (amperagecalibration - amperageoffset))
                        if amperagenewscale > -16000 and amperagenewscale < 16000 and amperagenewscale != 0
                            CURRENT_METER_CONFIGS[ampsource - 1].scale = amperagenewscale
                            amperagescalechanged = true
            if vbatscalechanged or amperagescalechanged
                if vbatscalechanged
                    $('.vbatcalibration').show()
                else
                    $('.vbatcalibration').hide()
                if amperagescalechanged
                    $('.amperagecalibration').show()
                else
                    $('.amperagecalibration').hide()
                $('output[name="vbatnewscale"').val vbatnewscale
                $('output[name="amperagenewscale"').val amperagenewscale
                $('a.applycalibration').click ->
                    if vbatscalechanged
                        self.analyticsChanges['PowerVBatUpdated'] = 'Calibrated'
                    if amperagescalechanged
                        self.analyticsChanges['PowerAmperageUpdated'] = 'Calibrated'
                    calibrationconfirmed = true
                    GUI.calibrationManagerConfirmation.close()
                    updateDisplay VOLTAGE_METER_CONFIGS, CURRENT_METER_CONFIGS
                    $('.calibration').hide()
                    return
                $('a.discardcalibration').click ->
                    GUI.calibrationManagerConfirmation.close()
                    return
            else
                GUI.calibrationManagerConfirmation.close()
            return
        $('a.save').click ->
            `var index`
            index = 0
            while index < VOLTAGE_METER_CONFIGS.length
                VOLTAGE_METER_CONFIGS[index].vbatscale = parseInt($('input[name="vbatscale-' + index + '"]').val())
                VOLTAGE_METER_CONFIGS[index].vbatresdivval = parseInt($('input[name="vbatresdivval-' + index + '"]').val())
                VOLTAGE_METER_CONFIGS[index].vbatresdivmultiplier = parseInt($('input[name="vbatresdivmultiplier-' + index + '"]').val())
                index++
            index = 0
            while index < CURRENT_METER_CONFIGS.length
                CURRENT_METER_CONFIGS[index].scale = parseInt($('input[name="amperagescale-' + index + '"]').val())
                CURRENT_METER_CONFIGS[index].offset = parseInt($('input[name="amperageoffset-' + index + '"]').val())
                index++
            BATTERY_CONFIG.vbatmincellvoltage = parseFloat($('input[name="mincellvoltage"]').val())
            BATTERY_CONFIG.vbatmaxcellvoltage = parseFloat($('input[name="maxcellvoltage"]').val())
            BATTERY_CONFIG.vbatwarningcellvoltage = parseFloat($('input[name="warningcellvoltage"]').val())
            BATTERY_CONFIG.capacity = parseInt($('input[name="capacity"]').val())
            analytics.sendChangeEvents analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, self.analyticsChanges
            save_power_config()
            return
        GUI.interval_add 'setup_data_pull_slow', get_slow_data, 200, true
        # 5hz
        return

    save_power_config = ->

        save_battery_config = ->
            MSP.send_message MSPCodes.MSP_SET_BATTERY_CONFIG, mspHelper.crunch(MSPCodes.MSP_SET_BATTERY_CONFIG), false, save_voltage_config
            return

        save_voltage_config = ->
            if semver.gte(CONFIG.apiVersion, '1.36.0')
                mspHelper.sendVoltageConfig save_amperage_config
            else
                MSP.send_message MSPCodes.MSP_SET_VOLTAGE_METER_CONFIG, mspHelper.crunch(MSPCodes.MSP_SET_VOLTAGE_METER_CONFIG), false, save_amperage_config
            return

        save_amperage_config = ->
            if semver.gte(CONFIG.apiVersion, '1.36.0')
                mspHelper.sendCurrentConfig save_to_eeprom
            else
                MSP.send_message MSPCodes.MSP_SET_CURRENT_METER_CONFIG, mspHelper.crunch(MSPCodes.MSP_SET_CURRENT_METER_CONFIG), false, save_to_eeprom
            return

        save_to_eeprom = ->
            MSP.send_message MSPCodes.MSP_EEPROM_WRITE, false, false, save_completed
            return

        save_completed = ->
            GUI.log i18n.getMessage('configurationEepromSaved')
            TABS.power.initialize()
            return

        save_battery_config()
        return

    process_html = ->
        initDisplay()
        self.analyticsChanges = {}
        # translate to user-selected language
        i18n.localizePage()
        GUI.content_ready callback
        return

    if GUI.active_tab != 'power'
        GUI.active_tab = 'power'
        # Disabled on merge into configurator
        #googleAnalytics.sendAppView('Power');
    if GUI.calibrationManager
        GUI.calibrationManager.destroy()
    if GUI.calibrationManagerConfirmation
        GUI.calibrationManagerConfirmation.destroy()
    @supported = semver.gte(CONFIG.apiVersion, '1.33.0')
    if !@supported
        load_html()
    else
        load_status()
    return

TABS.power.cleanup = (callback) ->
    if callback
        callback()
    if GUI.calibrationManager
        GUI.calibrationManager.destroy()
    if GUI.calibrationManagerConfirmation
        GUI.calibrationManagerConfirmation.destroy()
    return

