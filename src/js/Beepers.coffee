'use strict'

Beepers = (config, supportedConditions) ->
    self = this
    beepers = [
        {
            bit: 0
            name: 'GYRO_CALIBRATED'
            visible: true
        }
        {
            bit: 1
            name: 'RX_LOST'
            visible: true
        }
        {
            bit: 2
            name: 'RX_LOST_LANDING'
            visible: true
        }
        {
            bit: 3
            name: 'DISARMING'
            visible: true
        }
        {
            bit: 4
            name: 'ARMING'
            visible: true
        }
        {
            bit: 5
            name: 'ARMING_GPS_FIX'
            visible: true
        }
        {
            bit: 6
            name: 'BAT_CRIT_LOW'
            visible: true
        }
        {
            bit: 7
            name: 'BAT_LOW'
            visible: true
        }
        {
            bit: 8
            name: 'GPS_STATUS'
            visible: true
        }
        {
            bit: 9
            name: 'RX_SET'
            visible: true
        }
        {
            bit: 10
            name: 'ACC_CALIBRATION'
            visible: true
        }
        {
            bit: 11
            name: 'ACC_CALIBRATION_FAIL'
            visible: true
        }
        {
            bit: 12
            name: 'READY_BEEP'
            visible: true
        }
        {
            bit: 13
            name: 'MULTI_BEEPS'
            visible: false
        }
        {
            bit: 14
            name: 'DISARM_REPEAT'
            visible: true
        }
        {
            bit: 15
            name: 'ARMED'
            visible: true
        }
        {
            bit: 16
            name: 'SYSTEM_INIT'
            visible: true
        }
        {
            bit: 17
            name: 'USB'
            visible: true
        }
        {
            bit: 18
            name: 'BLACKBOX_ERASE'
            visible: true
        }
    ]
    if semver.gte(config.apiVersion, '1.37.0')
        beepers.push {
            bit: 19
            name: 'CRASH_FLIP'
            visible: true
        }, {
            bit: 20
            name: 'CAM_CONNECTION_OPEN'
            visible: true
        },
            bit: 21
            name: 'CAM_CONNECTION_CLOSE'
            visible: true
    if semver.gte(config.apiVersion, '1.39.0')
        beepers.push
            bit: 22
            name: 'RC_SMOOTHING_INIT_FAIL'
            visible: true
    if supportedConditions
        self._beepers = []
        beepers.forEach (beeper) ->
            if supportedConditions.some(((supportedCondition) ->
                    supportedCondition == beeper.name
                ))
                self._beepers.push beeper
            return
    else
        self._beepers = beepers.slice()
    self._beeperMask = 0
    return

Beepers::getMask = ->
    self = this
    self._beeperMask

Beepers::setMask = (beeperMask) ->
    self = this
    self._beeperMask = beeperMask
    return

Beepers::isEnabled = (beeperName) ->
    self = this
    i = 0
    while i < self._beepers.length
        if self._beepers[i].name == beeperName and bit_check(self._beeperOfMask, self._beepers[i].bit)
            return true
        i++
    false

Beepers::generateElements = (template, destination) ->
    self = this
    i = 0
    while i < self._beepers.length
        if self._beepers[i].visible
            element = template.clone()
            destination.append element
            input_e = $(element).find('input')
            label_e = $(element).find('div')
            span_e = $(element).find('span')
            input_e.attr 'id', 'beeper-' + i
            input_e.attr 'name', self._beepers[i].name
            input_e.attr 'title', self._beepers[i].name
            input_e.prop 'checked', bit_check(self._beeperMask, self._beepers[i].bit) == 0
            input_e.data 'bit', self._beepers[i].bit
            label_e.text self._beepers[i].name
            span_e.attr 'i18n', 'beeper' + self._beepers[i].name
            element.show()
        i++
    return

Beepers::updateData = (beeperElement) ->
    self = this
    if beeperElement.attr('type') == 'checkbox'
        bit = beeperElement.data('bit')
        if beeperElement.is(':checked')
            self._beeperMask = bit_clear(self._beeperMask, bit)
        else
            self._beeperMask = bit_set(self._beeperMask, bit)
    return

