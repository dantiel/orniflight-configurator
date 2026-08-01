'use strict'
TABS.gps = {}

TABS.gps.initialize = (callback) ->
    self = this

    load_html = ->
        $('#content').load './tabs/gps.html', process_html
        return

    set_online = ->
        $('#connect').hide()
        $('#waiting').show()
        $('#loadmap').hide()
        return

    set_offline = ->
        $('#connect').show()
        $('#waiting').hide()
        $('#loadmap').hide()
        return

    process_html = ->
        # translate to user-selected languageconsole.log('Online');

        get_raw_gps_data = ->
            MSP.send_message MSPCodes.MSP_RAW_GPS, false, false, get_comp_gps_data
            return

        get_comp_gps_data = ->
            MSP.send_message MSPCodes.MSP_COMP_GPS, false, false, get_gpsvinfo_data
            return

        get_gpsvinfo_data = ->
            MSP.send_message MSPCodes.MSP_GPS_SV_INFO, false, false, update_ui
            return

        update_ui = ->
            lat = GPS_DATA.lat / 10000000
            lon = GPS_DATA.lon / 10000000
            url = 'https://maps.google.com/?q=' + lat + ',' + lon
            alt = GPS_DATA.alt
            if semver.lt(CONFIG.apiVersion, '1.39.0')
                alt = alt / 10
            $('.GPS_info td.fix').html if GPS_DATA.fix then i18n.getMessage('gpsFixTrue') else i18n.getMessage('gpsFixFalse')
            $('.GPS_info td.alt').text alt + ' m'
            $('.GPS_info td.lat a').prop('href', url).text lat.toFixed(4) + ' deg'
            $('.GPS_info td.lon a').prop('href', url).text lon.toFixed(4) + ' deg'
            $('.GPS_info td.speed').text GPS_DATA.speed + ' cm/s'
            $('.GPS_info td.sats').text GPS_DATA.numSat
            $('.GPS_info td.distToHome').text GPS_DATA.distanceToHome + ' m'
            # Update GPS Signal Strengths
            e_ss_table = $('div.GPS_signal_strength table tr:not(.titles)')
            i = 0
            while i < GPS_DATA.chn.length
                row = e_ss_table.eq(i)
                $('td', row).eq(0).text GPS_DATA.svid[i]
                $('td', row).eq(1).text GPS_DATA.quality[i]
                $('td', row).eq(2).find('progress').val GPS_DATA.cno[i]
                i++
            message = 
                action: 'center'
                lat: lat
                lon: lon
            frame = document.getElementById('map')
            if navigator.onLine
                $('#connect').hide()
                if GPS_DATA.fix
                    gpsWasFixed = true
                    frame.contentWindow.postMessage message, '*'
                    $('#loadmap').show()
                    $('#waiting').hide()
                else if !gpsWasFixed
                    $('#loadmap').hide()
                    $('#waiting').show()
                else
                    message.action = 'nofix'
                    frame.contentWindow.postMessage message, '*'
            else
                gpsWasFixed = false
                $('#connect').show()
                $('#waiting').hide()
                $('#loadmap').hide()
            return

        i18n.localizePage()
        # To not flicker the divs while the fix is unstable
        gpsWasFixed = false
        # enable data pulling
        GUI.interval_add 'gps_pull', (->
            # avoid usage of the GPS commands until a GPS sensor is detected for targets that are compiled without GPS support.
            if !have_sensor(CONFIG.activeSensors, 'gps')
                #return;
            else
            get_raw_gps_data()
            return
        ), 75, true
        # status data pulled via separate timer with static speed
        GUI.interval_add 'status_pull', (->
            MSP.send_message MSPCodes.MSP_STATUS
            return
        ), 250, true
        #check for internet connection on load
        if navigator.onLine
            console.log 'Online'
            set_online()
        else
            console.log 'Offline'
            set_offline()
        $('#check').on 'click', ->
            if navigator.onLine
                console.log 'Online'
                set_online()
            else
                console.log 'Offline'
                set_offline()
            return
        frame = document.getElementById('map')
        $('#zoom_in').click ->
            console.log 'zoom in'
            message = action: 'zoom_in'
            frame.contentWindow.postMessage message, '*'
            return
        $('#zoom_out').click ->
            console.log 'zoom out'
            message = action: 'zoom_out'
            frame.contentWindow.postMessage message, '*'
            return
        GUI.content_ready callback
        return

    if GUI.active_tab != 'gps'
        GUI.active_tab = 'gps'
    MSP.send_message MSPCodes.MSP_STATUS, false, false, load_html
    return

TABS.gps.cleanup = (callback) ->
    if callback
        callback()
    return

