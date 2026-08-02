_typeof = (o) ->
    '@babel/helpers - typeof'
    _typeof = if 'function' == typeof Symbol and 'symbol' == typeof Symbol.iterator then ((o) ->
        typeof o
    ) else ((o) ->
        if o and 'function' == typeof Symbol and o.constructor == Symbol and o != Symbol.prototype then 'symbol' else typeof o
    )
    _typeof(o)

checkSetupAnalytics = (callback) ->
    if !analytics
        setTimeout ->
            ConfigStorage.get [
                'userId'
                'analyticsOptOut'
                'checkForConfiguratorUnstableVersions'
            ], (result) ->
                if !analytics
                    setupAnalytics result
                callback analytics
                return
            return
    else if callback
        callback analytics
    return

getBuildType = ->
    GUI.Mode

setupAnalytics = (result) ->
    userId = undefined

    logException = (exception) ->
        analytics.sendException exception.stack
        return

    sendCloseEvent = ->
        analytics.sendEvent analytics.EVENT_CATEGORIES.APPLICATION, 'AppClose', sessionControl: 'end'
        return

    if result.userId
        userId = result.userId
    else
        uid = new ShortUniqueId
        userId = uid.randomUUID(13)
        ConfigStorage.set 'userId': userId
    optOut = ! !result.analyticsOptOut
    checkForDebugVersions = ! !result.checkForConfiguratorUnstableVersions
    debugMode = (if typeof process == 'undefined' then 'undefined' else _typeof(process)) == 'object' and process.versions['nw-flavor'] == 'sdk'
    analytics = new Analytics('UA-123002063-1', userId, 'OrniFlight Configurator', CONFIGURATOR.version, CONFIGURATOR.gitChangesetId, GUI.operating_system, checkForDebugVersions, optOut, debugMode, getBuildType())
    if (if typeof process == 'undefined' then 'undefined' else _typeof(process)) == 'object'
        process.on 'uncaughtException', logException
    analytics.sendEvent analytics.EVENT_CATEGORIES.APPLICATION, 'AppStart', sessionControl: 'start'
    if GUI.isNWJS()
        win = GUI.nwGui.Window.get()
        win.on 'close', ->
            sendCloseEvent()
            @close true
            return
        win.on 'new-win-policy', (frame, url, policy) ->
            # do not open the window
            policy.ignore()
            # and open it in external browser
            GUI.nwGui.Shell.openExternal url
            return
    else if !GUI.isOther()
        # Looks like we're in Chrome - but the event does not actually get fired
        chrome.runtime.onSuspend.addListener sendCloseEvent
    $('.connect_b a.connect').removeClass 'disabled'
    $('.firmware_b a.flash').removeClass 'disabled'
    return

#Process to execute to real start the app

startProcess = ->
    # translate to user-selected language
    i18n.localizePage()
    # alternative - window.navigator.appVersion.match(/Chrome\/([0-9.]*)/)[1];
    GUI.log i18n.getMessage('infoVersions',
        operatingSystem: GUI.operating_system
        chromeVersion: window.navigator.appVersion.replace(/.*Chrome\/([0-9.]*).*/, '$1')
        configuratorVersion: CONFIGURATOR.version)
    $('#logo .version').text CONFIGURATOR.version
    updateStatusBarVersion()
    updateTopBarVersion()
    # notification messages for various operating systems
    switch GUI.operating_system
        when 'Windows' then
        when 'MacOS' then
            # var main_chromium_version = window.navigator.appVersion.replace(/.*Chrome\/([0-9.]*).*/,"$1").split('.')[0];
        when 'ChromeOS' then
        when 'Linux' then
        when 'UNIX' then
    if !GUI.isOther() and GUI.operating_system != 'ChromeOS'
        #checkForConfiguratorUpdates();
    else
    # log webgl capability
    # it would seem the webgl "enabling" through advanced settings will be ignored in the future
    # and webgl will be supported if gpu supports it by default (canary 40.0.2175.0), keep an eye on this one
    canvas = document.createElement('canvas')
    # log library versions in console to make version tracking easier
    console.log 'Libraries: jQuery - ' + $.fn.jquery + ', d3 - ' + d3.version + ', three.js - ' + THREE.REVISION
    # Tabs
    $('#tabs ul.mode-connected li').click ->
        # store the first class of the current tab (omit things like ".active")
        ConfigStorage.set lastTab: $(this).attr('class').split(' ')[0]
        return
    ui_tabs = $('#tabs > ul')
    $('a', ui_tabs).click ->
        if $(this).parent().hasClass('active') == false and !GUI.tab_switch_in_progress
            # only initialize when the tab isn't already active
            self = this
            tabClass = $(self).parent().prop('class')
            tabRequiresConnection = $(self).parent().hasClass('mode-connected')
            tab = tabClass.substring(4)
            tabName = $(self).text()
            offlineCapableTabs = ['setup']
            if tabRequiresConnection and !CONFIGURATOR.connectionValid and offlineCapableTabs.indexOf(tab) < 0
                GUI.log i18n.getMessage('tabSwitchConnectionRequired')
                return
            if GUI.connect_lock
                # tab switching disabled while operation is in progress
                GUI.log i18n.getMessage('tabSwitchWaitForOperation')
                return
            if GUI.allowedTabs.indexOf(tab) < 0 and tabName == 'Firmware Flasher'
                if GUI.connected_to or GUI.connecting_to
                    $('a.connect').click()
                else
                    self.disconnect()
                $('div.open_firmware_flasher a.flash').click()
            else if GUI.allowedTabs.indexOf(tab) < 0
                GUI.log i18n.getMessage('tabSwitchUpgradeRequired', [ tabName ])
                return
            GUI.tab_switch_in_progress = true
            GUI.tab_switch_cleanup ->
                # disable active firmware flasher if it was active

                content_ready = ->
                    GUI.tab_switch_in_progress = false
                    return

                if $('div#flashbutton a.flash_state').hasClass('active') and $('div#flashbutton a.flash').hasClass('active')
                    $('div#flashbutton a.flash_state').removeClass 'active'
                    $('div#flashbutton a.flash').removeClass 'active'
                # disable previously active tab highlight
                $('li', ui_tabs).removeClass 'active'
                # Highlight selected tab
                $(self).parent().addClass 'active'
                # detach listeners and remove element data
                content = $('#content')
                content.empty()
                # display loading screen
                $('#cache .data-loading').clone().appendTo content
                checkSetupAnalytics (analytics) ->
                    analytics.sendAppView tab
                    return
                switch tab
                    when 'landing'
                        TABS.landing.initialize content_ready
                    when 'changelog'
                        TABS.staticTab.initialize 'changelog', content_ready
                    when 'privacy_policy'
                        TABS.staticTab.initialize 'privacy_policy', content_ready
                    when 'firmware_flasher'
                        TABS.firmware_flasher.initialize content_ready
                    when 'help'
                        TABS.help.initialize content_ready
                    when 'auxiliary'
                        TABS.auxiliary.initialize content_ready
                    when 'adjustments'
                        TABS.adjustments.initialize content_ready
                    when 'ports'
                        TABS.ports.initialize content_ready
                    when 'led_strip'
                        TABS.led_strip.initialize content_ready
                    when 'failsafe'
                        TABS.failsafe.initialize content_ready
                    when 'transponder'
                        TABS.transponder.initialize content_ready
                    when 'osd'
                        TABS.osd.initialize content_ready
                    when 'vtx'
                        TABS.vtx.initialize content_ready
                    when 'power'
                        TABS.power.initialize content_ready
                    when 'setup'
                        TABS.setup.initialize content_ready
                    when 'setup_osd'
                        TABS.setup_osd.initialize content_ready
                    when 'configuration'
                        TABS.configuration.initialize content_ready
                    when 'pid_tuning'
                        TABS.pid_tuning.initialize content_ready
                    when 'receiver'
                        TABS.receiver.initialize content_ready
                    when 'servos'
                        TABS.servos.initialize content_ready
                    when 'gps'
                        TABS.gps.initialize content_ready
                    when 'motors'
                        TABS.motors.initialize content_ready
                    when 'sensors'
                        TABS.sensors.initialize content_ready
                    when 'logging'
                        TABS.logging.initialize content_ready
                    when 'onboard_logging'
                        TABS.onboard_logging.initialize content_ready
                    when 'cli'
                        TABS.cli.initialize content_ready, GUI.nwGui
                    else
                        console.log 'Tab not found:' + tab
                return
        return
    $('#tabs ul.mode-disconnected li a:first').click()
    # options
    $('a#options').click ->
        if GUI.isNWJS()
            win = GUI.nwGui.Window.get()
            #win.showDevTools();
        el = $(this)
        if !el.hasClass('active')
            el.addClass 'active'
            el.after '<div id="options-window"></div>'
            $('div#options-window').load './tabs/options.html', ->
                # translate to user-selected language

                close_and_cleanup = (e) ->
                    if e.type == 'click' and !$.contains($('div#options-window')[0], e.target) or e.type == 'keyup' and e.keyCode == 27
                        $(document).unbind 'click keyup', close_and_cleanup
                        $('div#options-window').slideUp 250, ->
                            el.removeClass 'active'
                            $(this).empty().remove()
                            return
                    return

                i18n.localizePage()
                ConfigStorage.get 'permanentExpertMode', (result) ->
                    if result.permanentExpertMode
                        $('div.permanentExpertMode input').prop 'checked', true
                    $('div.permanentExpertMode input').change(->
                        checked = $(this).is(':checked')
                        ConfigStorage.set 'permanentExpertMode': checked
                        $('input[name="expertModeCheckbox"]').prop('checked', checked).change()
                        return
                    ).change()
                    return
                ConfigStorage.get 'rememberLastTab', (result) ->
                    $('div.rememberLastTab input').prop('checked', ! !result.rememberLastTab).change(->
                        ConfigStorage.set rememberLastTab: $(this).is(':checked')
                        return
                    ).change()
                    return
                if GUI.operating_system != 'ChromeOS'
                    ConfigStorage.get 'checkForConfiguratorUnstableVersions', (result) ->
                        if result.checkForConfiguratorUnstableVersions
                            $('div.checkForConfiguratorUnstableVersions input').prop 'checked', true
                        $('div.checkForConfiguratorUnstableVersions input').change ->
                            checked = $(this).is(':checked')
                            ConfigStorage.set 'checkForConfiguratorUnstableVersions': checked
                            #checkForConfiguratorUpdates();
                            return
                        return
                else
                    $('div.checkForConfiguratorUnstableVersions').hide()
                ConfigStorage.get 'analyticsOptOut', (result) ->
                    if result.analyticsOptOut
                        $('div.analyticsOptOut input').prop 'checked', true
                    $('div.analyticsOptOut input').change(->
                        checked = $(this).is(':checked')
                        ConfigStorage.set 'analyticsOptOut': checked
                        checkSetupAnalytics (analytics) ->
                            if checked
                                analytics.sendEvent analytics.EVENT_CATEGORIES.APPLICATION, 'OptOut'
                            analytics.setOptOut checked
                            if !checked
                                analytics.sendEvent analytics.EVENT_CATEGORIES.APPLICATION, 'OptIn'
                            return
                        return
                    ).change()
                    return
                $('div.cliAutoComplete input').prop('checked', CliAutoComplete.configEnabled).change(->
                    checked = $(this).is(':checked')
                    ConfigStorage.set 'cliAutoComplete': checked
                    CliAutoComplete.setEnabled checked
                    return
                ).change()
                $('#darkThemeSelect').val(DarkTheme.configEnabled).change(->
                    value = parseInt($(this).val())
                    ConfigStorage.set 'darkTheme': value
                    setDarkTheme value
                    return
                ).change()
                $(document).bind 'click keyup', close_and_cleanup
                $(this).slideDown 250
                return
        return
    # listen to all input change events and adjust the value within limits if necessary
    $('#content').on 'focus', 'input[type="number"]', ->
        element = $(this)
        val = element.val()
        if !isNaN(val)
            element.data 'previousValue', parseFloat(val)
        return
    $('#content').on 'keydown', 'input[type="number"]', (e) ->
        # whitelist all that we need for numeric control
        whitelist = [
            96
            97
            98
            99
            100
            101
            102
            103
            104
            105
            48
            49
            50
            51
            52
            53
            54
            55
            56
            57
            109
            189
            8
            46
            9
            190
            110
            37
            38
            39
            40
            13
        ]
        if whitelist.indexOf(e.keyCode) == -1
            e.preventDefault()
        return
    $('#content').on 'change', 'input[type="number"]', ->
        element = $(this)
        min = parseFloat(element.prop('min'))
        max = parseFloat(element.prop('max'))
        step = parseFloat(element.prop('step'))
        val = parseFloat(element.val())
        decimal_places = undefined
        # only adjust minimal end if bound is set
        if element.prop('min')
            if val < min
                element.val min
                val = min
        # only adjust maximal end if bound is set
        if element.prop('max')
            if val > max
                element.val max
                val = max
        # if entered value is illegal use previous value instead
        if isNaN(val)
            element.val element.data('previousValue')
            val = element.data('previousValue')
        # if step is not set or step is int and value is float use previous value instead
        if isNaN(step) or step % 1 == 0
            if val % 1 != 0
                element.val element.data('previousValue')
                val = element.data('previousValue')
        # if step is set and is float and value is int, convert to float, keep decimal places in float according to step *experimental*
        if !isNaN(step) and step % 1 != 0
            decimal_places = String(step).split('.')[1].length
            if val % 1 == 0
                element.val val.toFixed(decimal_places)
            else if String(val).split('.')[1].length != decimal_places
                element.val val.toFixed(decimal_places)
        return
    $('#showlog').on 'click', ->
        state = $(this).data('state')
        if state
            $('#log').animate { height: 27 }, 200, ->
                command_log = $('div#log')
                command_log.scrollTop $('div.wrapper', command_log).height()
                return
            $('#log').removeClass 'active'
            $('#content').removeClass 'logopen'
            $('.tab_container').removeClass 'logopen'
            $('#scrollicon').removeClass 'active'
            ConfigStorage.set 'logopen': false
            state = false
        else
            $('#log').animate { height: 111 }, 200
            $('#log').addClass 'active'
            $('#content').addClass 'logopen'
            $('.tab_container').addClass 'logopen'
            $('#scrollicon').addClass 'active'
            ConfigStorage.set 'logopen': true
            state = true
        $(this).text if state then i18n.getMessage('logActionHide') else i18n.getMessage('logActionShow')
        $(this).data 'state', state
        return
    ConfigStorage.get 'logopen', (result) ->
        if result.logopen
            $('#showlog').trigger 'click'
        return
    ConfigStorage.get 'permanentExpertMode', (result) ->
        if result.permanentExpertMode
            $('input[name="expertModeCheckbox"]').prop 'checked', true
        $('input[name="expertModeCheckbox"]').change(->
            checked = $(this).is(':checked')
            checkSetupAnalytics (analytics) ->
                analytics.setDimension analytics.DIMENSIONS.CONFIGURATOR_EXPERT_MODE, if checked then 'On' else 'Off'
                return
            if FEATURE_CONFIG and FEATURE_CONFIG.features != 0
                updateTabList FEATURE_CONFIG.features
            return
        ).change()
        return
    ConfigStorage.get 'cliAutoComplete', (result) ->
        CliAutoComplete.setEnabled typeof result.cliAutoComplete == 'undefined' or result.cliAutoComplete
        # On by default
        return
    ConfigStorage.get 'darkTheme', (result) ->
        if result.darkTheme == undefined or typeof result.darkTheme != 'number'
            # sets dark theme to auto if not manually changed
            setDarkTheme 2
        else
            setDarkTheme result.darkTheme
        return
    return

setDarkTheme = (enabled) ->
    DarkTheme.setConfig enabled
    checkSetupAnalytics (analytics) ->
        analytics.sendEvent analytics.EVENT_CATEGORIES.APPLICATION, 'DarkTheme', enabled
        return
    return

checkForConfiguratorUpdates = ->
    releaseChecker = new ReleaseChecker('configurator', 'https://api.github.com/repos/dantiel/orniflight-configurator/releases')
    releaseChecker.loadReleaseData notifyOutdatedVersion
    return

notifyOutdatedVersion = (releaseData) ->
    ConfigStorage.get 'checkForConfiguratorUnstableVersions', (result) ->
        showUnstableReleases = false
        if result.checkForConfiguratorUnstableVersions
            showUnstableReleases = true
        versions = releaseData.filter((version) ->
            semVerVersion = semver.parse(version.tag_name)
            if semVerVersion and (showUnstableReleases or semVerVersion.prerelease.length == 0)
                return version
            return
        ).sort((v1, v2) ->
            try
                return semver.compare(v2.tag_name, v1.tag_name)
            catch e
                return false
            return
        )
        if versions.length > 0 and semver.lt(CONFIGURATOR.version, versions[0].tag_name)
            GUI.log i18n.getMessage('configuratorUpdateNotice', [
                versions[0].tag_name
                versions[0].html_url
            ])
            dialog = $('.dialogConfiguratorUpdate')[0]
            $('.dialogConfiguratorUpdate-content').html i18n.getMessage('configuratorUpdateNotice', [
                versions[0].tag_name
                versions[0].html_url
            ])
            $('.dialogConfiguratorUpdate-closebtn').click ->
                dialog.close()
                return
            $('.dialogConfiguratorUpdate-websitebtn').click ->
                dialog.close()
                window.open versions[0].html_url, '_blank'
                return
            dialog.showModal()
        return
    return

update_packet_error = (caller) ->
    $('span.packet-error').html caller.packet_error
    return

microtime = ->
    now = (new Date).getTime() / 1000
    now

millitime = ->
    now = (new Date).getTime()
    now

degToRad = (degrees) ->
    degrees * DEGREE_TO_RADIAN_RATIO

bytesToSize = (bytes) ->
    if bytes < 1024
        bytes = bytes + ' Bytes'
    else if bytes < 1048576
        bytes = (bytes / 1024).toFixed(3) + ' KB'
    else if bytes < 1073741824
        bytes = (bytes / 1048576).toFixed(3) + ' MB'
    else
        bytes = (bytes / 1073741824).toFixed(3) + ' GB'
    bytes

isExpertModeEnabled = ->
    $('input[name="expertModeCheckbox"]').is ':checked'

updateTabList = (features) ->
    if isExpertModeEnabled()
        $('#tabs ul.mode-connected li.tab_failsafe').show()
        $('#tabs ul.mode-connected li.tab_adjustments').show()
        $('#tabs ul.mode-connected li.tab_servos').show()
        $('#tabs ul.mode-connected li.tab_sensors').show()
        $('#tabs ul.mode-connected li.tab_logging').show()
    else
        $('#tabs ul.mode-connected li.tab_failsafe').hide()
        $('#tabs ul.mode-connected li.tab_adjustments').hide()
        $('#tabs ul.mode-connected li.tab_servos').hide()
        $('#tabs ul.mode-connected li.tab_sensors').hide()
        $('#tabs ul.mode-connected li.tab_logging').hide()
    if features.isEnabled('GPS') and isExpertModeEnabled()
        $('#tabs ul.mode-connected li.tab_gps').show()
    else
        $('#tabs ul.mode-connected li.tab_gps').hide()
    if features.isEnabled('LED_STRIP')
        $('#tabs ul.mode-connected li.tab_led_strip').show()
    else
        $('#tabs ul.mode-connected li.tab_led_strip').hide()
    if features.isEnabled('TRANSPONDER')
        $('#tabs ul.mode-connected li.tab_transponder').show()
    else
        $('#tabs ul.mode-connected li.tab_transponder').hide()
    if features.isEnabled('OSD')
        $('#tabs ul.mode-connected li.tab_osd').show()
    else
        $('#tabs ul.mode-connected li.tab_osd').hide()
    if semver.gte(CONFIG.apiVersion, '1.36.0')
        $('#tabs ul.mode-connected li.tab_power').show()
    else
        $('#tabs ul.mode-connected li.tab_power').hide()
    if semver.gte(CONFIG.apiVersion, '1.42.0')
        $('#tabs ul.mode-connected li.tab_vtx').show()
    else
        $('#tabs ul.mode-connected li.tab_vtx').hide()
    return

zeroPad = (value, width) ->
    value = '' + value
    while value.length < width
        value = '0' + value
    value

generateFilename = (prefix, suffix) ->
    date = new Date
    filename = prefix
    if CONFIG
        if CONFIG.flightControllerIdentifier
            filename = CONFIG.flightControllerIdentifier + '_' + filename
        if CONFIG.name and CONFIG.name.trim() != ''
            filename = filename + '_' + CONFIG.name.trim().replace(' ', '_')
    filename = filename + '_' + date.getFullYear() + zeroPad(date.getMonth() + 1, 2) + zeroPad(date.getDate(), 2) + '_' + zeroPad(date.getHours(), 2) + zeroPad(date.getMinutes(), 2) + zeroPad(date.getSeconds(), 2)
    filename + '.' + suffix

getTargetVersion = (hardwareId) ->
    versionText = ''
    if hardwareId
        versionText += i18n.getMessage('versionLabelTarget') + ': ' + hardwareId
    versionText

getFirmwareVersion = (firmwareVersion, firmwareId) ->
    versionText = ''
    if firmwareVersion
        versionText += i18n.getMessage('versionLabelFirmware') + ': ' + firmwareId + ' ' + firmwareVersion
    versionText

getConfiguratorVersion = ->
    i18n.getMessage('versionLabelConfigurator') + ': ' + CONFIGURATOR.version

updateTopBarVersion = (firmwareVersion, firmwareId, hardwareId) ->
    versionText = getConfiguratorVersion() + ' | '
    # + '<br />';
    versionText = versionText + getFirmwareVersion(firmwareVersion, firmwareId) + ' | '
    # + '<br />';
    versionText = versionText + getTargetVersion(hardwareId)
    $('#logo .logo_text').html versionText
    return

updateStatusBarVersion = (firmwareVersion, firmwareId, hardwareId) ->
    versionText = ''
    versionText = versionText + getFirmwareVersion(firmwareVersion, firmwareId)
    if versionText != ''
        versionText = versionText + ', '
    targetVersion = getTargetVersion(hardwareId)
    versionText = versionText + targetVersion
    if targetVersion != ''
        versionText = versionText + ', '
    versionText = versionText + getConfiguratorVersion() + ' (' + CONFIGURATOR.gitChangesetId + ')'
    $('#status-bar .version').text versionText
    return

showErrorDialog = (message) ->
    dialog = $('.dialogError')[0]
    $('.dialogError-content').html message
    $('.dialogError-closebtn').click ->
        dialog.close()
        return
    dialog.showModal()
    return

'use strict'
googleAnalytics = analytics
analytics = undefined
$(document).ready ->
    $.getJSON 'version.json', (data) ->
        CONFIGURATOR.version = data.version
        CONFIGURATOR.gitChangesetId = data.gitChangesetId
        # Version in the ChromeApp's manifest takes precedence.
        if typeof chrome != 'undefined' && chrome.runtime && chrome.runtime.getManifest
            manifest = chrome.runtime.getManifest()
            CONFIGURATOR.version = manifest.version
            # manifest.json for ChromeApp can't have a version
            # with a prerelease tag eg 10.0.0-RC4
            # Work around is to specify the prerelease version in version_name
            if manifest.version_name
                CONFIGURATOR.version = manifest.version_name
        i18n.init ->
            startProcess()
            checkSetupAnalytics (analytics) ->
                analytics.sendEvent analytics.EVENT_CATEGORIES.APPLICATION, 'SelectedLanguage', i18n.selectedLanguage
                return
            initializeSerialBackend()
            return
        return
    return
DEGREE_TO_RADIAN_RATIO = Math.PI / 180