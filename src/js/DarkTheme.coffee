'use strict'
css_dark = [
    './css/main-dark.css'
    './css/tabs-dark/landing-dark.css'
    './css/tabs-dark/setup-dark.css'
    './css/tabs-dark/help-dark.css'
    './css/tabs-dark/ports-dark.css'
    './css/tabs-dark/configuration-dark.css'
    './css/tabs-dark/pid_tuning-dark.css'
    './css/tabs-dark/receiver-dark.css'
    './css/tabs-dark/servos-dark.css'
    './css/tabs-dark/gps-dark.css'
    './css/tabs-dark/motors-dark.css'
    './css/tabs-dark/led_strip-dark.css'
    './css/tabs-dark/sensors-dark.css'
    './css/tabs-dark/cli-dark.css'
    './css/tabs-dark/logging-dark.css'
    './css/tabs-dark/onboard_logging-dark.css'
    './css/tabs-dark/firmware_flasher-dark.css'
    './css/tabs-dark/adjustments-dark.css'
    './css/tabs-dark/auxiliary-dark.css'
    './css/tabs-dark/failsafe-dark.css'
    './css/tabs-dark/osd-dark.css'
    './css/tabs-dark/power-dark.css'
    './css/tabs-dark/transponder-dark.css'
    './css/tabs-dark/static_tab-dark.css'
]
DarkTheme = configEnabled: undefined

DarkTheme.setConfig = (result) ->
    if @configEnabled != result
        @configEnabled = result
        if @configEnabled == 0 or @configEnabled == 2 and window.matchMedia and window.matchMedia('(prefers-color-scheme: dark)').matches
            @applyDark()
        else
            @applyNormal()
    return

DarkTheme.applyDark = ->
    i = 0
    while i < css_dark.length
        $('link[href="' + css_dark[i] + '"]').prop 'disabled', false
        i++
    return

DarkTheme.applyNormal = ->
    i = 0
    while i < css_dark.length
        $('link[href="' + css_dark[i] + '"]').prop 'disabled', true
        i++
    return

