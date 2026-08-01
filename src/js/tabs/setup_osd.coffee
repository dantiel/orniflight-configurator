'use strict'
TABS.setup_osd = {}

TABS.setup_osd.initialize = (callback) ->
    self = this

    load_status = ->
        MSP.send_message MSPCodes.MSP_STATUS, false, false, load_html
        return

    load_html = ->
        $('#content').load './tabs/setup_osd.html', process_html
        return

    process_html = ->

        get_slow_data = ->

            ### FIXME requires MSP update
            MSP.send_message(MSPCodes.MSP_OSD_VIDEO_STATUS, false, false, function () {
                var element;
                
                element = $('.video-mode');
                var osdVideoMode = osdVideoModes[OSD_VIDEO_STATE.video_mode];
                element.text(osdVideoMode);
                
                element = $('.camera-connected');
                element.text(OSD_VIDEO_STATE.camera_connected ? i18n.getMessage('yes') : i18n.getMessage('No'));
            });
            ###

            return

        $('.tab-setup-osd .info').hide()
        # requires an MSP update
        osdVideoModes = [
            'AUTO'
            'NTSC'
            'PAL'
        ]
        # translate to user-selected language
        i18n.localizePage()
        $('a.resetSettings').click ->
            MSP.send_message MSPCodes.MSP_RESET_CONF, false, false, ->
                GUI.log i18n.getMessage('initialSetupSettingsRestored')
                GUI.tab_switch_cleanup ->
                    TABS.setup_osd.initialize()
                    return
                return
            return
        GUI.interval_add 'setup_data_pull_slow', get_slow_data, 250, true
        # 4 fps
        GUI.content_ready callback
        return

    if GUI.active_tab != 'setup_osd'
        GUI.active_tab = 'setup_osd'
        # Disabled on merge into configurator
        #googleAnalytics.sendAppView('Setup OSD');
    load_status()
    return

TABS.setup_osd.cleanup = (callback) ->
    if callback
        callback()
    return

