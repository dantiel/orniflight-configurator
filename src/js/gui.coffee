'use strict'
TABS = {}
# filled by individual tab js file

GUI_control = ->
    @auto_connect = false
    @connecting_to = false
    @connected_to = false
    @connect_lock = false
    @active_tab
    @tab_switch_in_progress = false
    @operating_system
    @interval_array = []
    @timeout_array = []
    @defaultAllowedTabsWhenDisconnected = [
        'landing'
        'setup'
        'changelog'
        'firmware_flasher'
        'privacy_policy'
        'help'
    ]
    @defaultAllowedFCTabsWhenConnected = [
        'setup'
        'failsafe'
        'transponder'
        'osd'
        'power'
        'adjustments'
        'auxiliary'
        'cli'
        'configuration'
        'gps'
        'led_strip'
        'logging'
        'onboard_logging'
        'modes'
        'motors'
        'pid_tuning'
        'ports'
        'receiver'
        'sensors'
        'servos'
        'vtx'
    ]
    @defaultAllowedOSDTabsWhenConnected = [
        'setup_osd'
        'osd'
        'power'
        'sensors'
        'transponder'
    ]
    @allowedTabs = @defaultAllowedTabsWhenDisconnected
    # check which operating system is user running
    if navigator.appVersion.indexOf('Win') != -1
        @operating_system = 'Windows'
    else if navigator.appVersion.indexOf('Mac') != -1
        @operating_system = 'MacOS'
    else if navigator.appVersion.indexOf('CrOS') != -1
        @operating_system = 'ChromeOS'
    else if navigator.appVersion.indexOf('Linux') != -1
        @operating_system = 'Linux'
    else if navigator.appVersion.indexOf('X11') != -1
        @operating_system = 'UNIX'
    else
        @operating_system = 'Unknown'
    # Check the method of execution
    @nwGui = null
    try
        @nwGui = require('nw.gui')
        @Mode = GUI_Modes.NWJS
    catch ex
        if window.chrome and chrome.storage and chrome.storage.local
            @Mode = GUI_Modes.ChromeApp
        else
            @Mode = GUI_Modes.Other
    return

GUI_Modes =
    NWJS: 'NW.js'
    ChromeApp: 'Chrome'
    Other: 'Other'

GUI_control::isNWJS = ->
    @Mode == GUI_Modes.NWJS

GUI_control::isBrowser = ->
    @Mode == GUI_Modes.Other

GUI_control::hasWebSerial = ->
    typeof navigator != 'undefined' and !!navigator.serial

# Timer managing methods
# name = string
# code = function reference (code to be executed)
# interval = time interval in miliseconds
# first = true/false if code should be ran initially before next timer interval hits

GUI_control::interval_add = (name, code, interval, first) ->
    data = 
        'name': name
        'timer': null
        'code': code
        'interval': interval
        'fired': 0
        'paused': false
    if first == true
        code()
        # execute code
        data.fired++
        # increment counter
    data.timer = setInterval((->
        code()
        # execute code
        data.fired++
        # increment counter
        return
    ), interval)
    @interval_array.push data
    # push to primary interval array
    data

# name = string

GUI_control::interval_remove = (name) ->
    i = 0
    while i < @interval_array.length
        if @interval_array[i].name == name
            clearInterval @interval_array[i].timer
            # stop timer
            @interval_array.splice i, 1
            # remove element/object from array
            return true
        i++
    false

# name = string

GUI_control::interval_pause = (name) ->
    i = 0
    while i < @interval_array.length
        if @interval_array[i].name == name
            clearInterval @interval_array[i].timer
            @interval_array[i].paused = true
            return true
        i++
    false

# name = string

GUI_control::interval_resume = (name) ->
    i = 0
    while i < @interval_array.length
        if @interval_array[i].name == name and @interval_array[i].paused
            obj = @interval_array[i]
            obj.timer = setInterval((->
                obj.code()
                # execute code
                obj.fired++
                # increment counter
                return
            ), obj.interval)
            obj.paused = false
            return true
        i++
    false

# input = array of timers thats meant to be kept, or nothing
# return = returns timers killed in last call

GUI_control::interval_kill_all = (keep_array) ->
    self = this
    timers_killed = 0
    i = @interval_array.length - 1
    while i >= 0
        # reverse iteration
        keep = false
        if keep_array
            # only run through the array if it exists
            keep_array.forEach (name) ->
                if self.interval_array[i].name == name
                    keep = true
                return
        if !keep
            clearInterval @interval_array[i].timer
            # stop timer
            @interval_array.splice i, 1
            # remove element/object from array
            timers_killed++
        i--
    timers_killed

# name = string
# code = function reference (code to be executed)
# timeout = timeout in miliseconds

GUI_control::timeout_add = (name, code, timeout) ->
    self = this
    data = 
        'name': name
        'timer': null
        'timeout': timeout
    # start timer with "cleaning" callback
    data.timer = setTimeout((->
        code()
        # execute code
        # remove object from array
        index = self.timeout_array.indexOf(data)
        if index > -1
            self.timeout_array.splice index, 1
        return
    ), timeout)
    @timeout_array.push data
    # push to primary timeout array
    data

# name = string

GUI_control::timeout_remove = (name) ->
    i = 0
    while i < @timeout_array.length
        if @timeout_array[i].name == name
            clearTimeout @timeout_array[i].timer
            # stop timer
            @timeout_array.splice i, 1
            # remove element/object from array
            return true
        i++
    false

# no input paremeters
# return = returns timers killed in last call

GUI_control::timeout_kill_all = ->
    timers_killed = 0
    i = 0
    while i < @timeout_array.length
        clearTimeout @timeout_array[i].timer
        # stop timer
        timers_killed++
        i++
    @timeout_array = []
    # drop objects
    timers_killed

# message = string

GUI_control::log = (message) ->
    command_log = $('div#log')
    d = new Date
    year = d.getFullYear()
    month = if d.getMonth() < 9 then '0' + d.getMonth() + 1 else d.getMonth() + 1
    date = if d.getDate() < 10 then '0' + d.getDate() else d.getDate()
    time = (if d.getHours() < 10 then '0' + d.getHours() else d.getHours()) + ':' + (if d.getMinutes() < 10 then '0' + d.getMinutes() else d.getMinutes()) + ':' + (if d.getSeconds() < 10 then '0' + d.getSeconds() else d.getSeconds())
    formattedDate = '{0}-{1}-{2} {3}'.format(year, month, date, ' @ ' + time)
    $('div.wrapper', command_log).append '<p>' + formattedDate + ' -- ' + message + '</p>'
    command_log.scrollTop $('div.wrapper', command_log).height()
    return

# Method is called every time a valid tab change event is received
# callback = code to run when cleanup is finished
# default switch doesn't require callback to be set

GUI_control::tab_switch_cleanup = (callback) ->
    MSP.callbacks_cleanup()
    # we don't care about any old data that might or might not arrive
    GUI.interval_kill_all()
    # all intervals (mostly data pulling) needs to be removed on tab switch
    if @active_tab and TABS[@active_tab]
        TABS[@active_tab].cleanup callback
    else
        callback()
    return

GUI_control::switchery = ->
    $('.togglesmall').each (index, elem) ->
        `var switchery`
        if DarkTheme.configEnabled
            switchery = new Switchery(elem,
                size: 'small'
                color: '#8998fe'
                secondaryColor: '#858585')
        else
            switchery = new Switchery(elem,
                size: 'small'
                color: '#8998fe'
                secondaryColor: '#c4c4c4')
        $(elem).on 'change', (evt) ->
            switchery.setPosition()
            return
        $(elem).removeClass 'togglesmall'
        return
    $('.toggle').each (index, elem) ->
        `var switchery`
        if DarkTheme.configEnabled
            switchery = new Switchery(elem,
                color: '#8998fe'
                secondaryColor: '#858585')
        else
            switchery = new Switchery(elem,
                color: '#8998fe'
                secondaryColor: '#c4c4c4')
        $(elem).on 'change', (evt) ->
            switchery.setPosition()
            return
        $(elem).removeClass 'toggle'
        return
    $('.togglemedium').each (index, elem) ->
        `var switchery`
        if DarkTheme.configEnabled
            switchery = new Switchery(elem,
                className: 'switcherymid'
                color: '#8998fe'
                secondaryColor: '#858585')
        else
            switchery = new Switchery(elem,
                className: 'switcherymid'
                color: '#8998fe'
                secondaryColor: '#c4c4c4')
        $(elem).on 'change', (evt) ->
            switchery.setPosition()
            return
        $(elem).removeClass 'togglemedium'
        return
    return

GUI_control::content_ready = (callback) ->
    @switchery()
    if CONFIGURATOR.connectionValid
        # Build link to in-use CF version documentation
        documentationButton = $('div#content #button-documentation')
        documentationButton.html 'Wiki'
        documentationButton.attr 'href', 'https://github.com/dantiel/orniflight/wiki'
    # loading tooltip
    jQuery(document).ready ($) ->
        new jBox('Tooltip',
            attach: '.cf_tip'
            trigger: 'mouseenter'
            closeOnMouseleave: true
            closeOnClick: 'body'
            delayOpen: 100
            delayClose: 100
            position:
                x: 'right'
                y: 'center'
            outside: 'x')
        new jBox('Tooltip',
            theme: 'Widetip'
            attach: '.cf_tip_wide'
            trigger: 'mouseenter'
            closeOnMouseleave: true
            closeOnClick: 'body'
            delayOpen: 100
            delayClose: 100
            position:
                x: 'right'
                y: 'center'
            outside: 'x')
        return
    if callback
        callback()
    return

GUI_control::selectDefaultTabWhenConnected = ->
    ConfigStorage.get [
        'rememberLastTab'
        'lastTab'
    ], (result) ->
        if !(result.rememberLastTab and ! !result.lastTab and result.lastTab.substring(4) != 'cli')
            $('#tabs ul.mode-connected .tab_setup a').click()
            return
        $('#tabs ul.mode-connected .' + result.lastTab + ' a').click()
        return
    return

GUI_control::isChromeApp = ->
    @Mode == GUI_Modes.ChromeApp

GUI_control::isNWJS = ->
    @Mode == GUI_Modes.NWJS

GUI_control::isOther = ->
    @Mode == GUI_Modes.Other

# initialize object into GUI variable
GUI = new GUI_control