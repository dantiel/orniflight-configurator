'use strict'
TABS.logging = {}

TABS.logging.initialize = (callback) ->
    self = this

    process_html = ->
        # translate to user-selected language
        i18n.localizePage()
        # UI hooks
        $('a.log_file').click prepare_file
        $('a.logging').click ->
            if GUI.connected_to
                if fileEntry != null
                    clicks = $(this).data('clicks')
                    if !clicks
                        # reset some variables before start
                        samples = 0
                        requests = 0
                        log_buffer = []
                        requested_properties = []
                        $('.properties input:checked').each ->
                            requested_properties.push $(this).prop('name')
                            return
                        if requested_properties.length
                            # print header for the csv file
                            print_head()

                            log_data_poll = ->
                                if requests
                                    # save current data (only after everything is initialized)
                                    crunch_data()
                                # request new
                                i = 0
                                while i < requested_properties.length
                                    MSP.send_message MSPCodes[requested_properties[i]]
                                    i++
                                    requests++
                                return

                            GUI.interval_add 'log_data_poll', log_data_poll, parseInt($('select.speed').val()), true
                            # refresh rate goes here
                            GUI.interval_add 'write_data', (->
                                if log_buffer.length
                                    # only execute when there is actual data to write
                                    if fileWriter.readyState == 0 or fileWriter.readyState == 2
                                        append_to_file log_buffer.join('\n')
                                        $('.samples').text samples += log_buffer.length
                                        log_buffer = []
                                    else
                                        console.log 'IO having trouble keeping up with the data flow'
                                return
                            ), 1000
                            $('.speed').prop 'disabled', true
                            $(this).text i18n.getMessage('loggingStop')
                            $(this).data 'clicks', !clicks
                        else
                            GUI.log i18n.getMessage('loggingErrorOneProperty')
                    else
                        GUI.interval_kill_all()
                        $('.speed').prop 'disabled', false
                        $(this).text i18n.getMessage('loggingStart')
                        $(this).data 'clicks', !clicks
                else
                    GUI.log i18n.getMessage('loggingErrorLogFile')
            else
                GUI.log i18n.getMessage('loggingErrorNotConnected')
            return
        ConfigStorage.get 'logging_file_entry', (result) ->
            if result.logging_file_entry
                chrome.fileSystem.restoreEntry result.logging_file_entry, (entry) ->
                    fileEntry = entry
                    prepare_writer true
                    return
            return
        GUI.content_ready callback
        return

    print_head = ->
        head = 'timestamp'
        i = 0
        while i < requested_properties.length
            switch requested_properties[i]
                when 'MSP_RAW_IMU'
                    head += ',' + 'gyroscopeX'
                    head += ',' + 'gyroscopeY'
                    head += ',' + 'gyroscopeZ'
                    head += ',' + 'accelerometerX'
                    head += ',' + 'accelerometerY'
                    head += ',' + 'accelerometerZ'
                    head += ',' + 'magnetometerX'
                    head += ',' + 'magnetometerY'
                    head += ',' + 'magnetometerZ'
                when 'MSP_ATTITUDE'
                    head += ',' + 'kinematicsX'
                    head += ',' + 'kinematicsY'
                    head += ',' + 'kinematicsZ'
                when 'MSP_ALTITUDE'
                    head += ',' + 'altitude'
                when 'MSP_RAW_GPS'
                    head += ',' + 'gpsFix'
                    head += ',' + 'gpsNumSat'
                    head += ',' + 'gpsLat'
                    head += ',' + 'gpsLon'
                    head += ',' + 'gpsAlt'
                    head += ',' + 'gpsSpeed'
                    head += ',' + 'gpsGroundCourse'
                when 'MSP_ANALOG'
                    head += ',' + 'voltage'
                    head += ',' + 'amperage'
                    head += ',' + 'mAhdrawn'
                    head += ',' + 'rssi'
                when 'MSP_RC'
                    chan = 0
                    while chan < RC.active_channels
                        head += ',' + 'RC' + chan
                        chan++
                when 'MSP_MOTOR'
                    motor = 0
                    while motor < MOTOR_DATA.length
                        head += ',' + 'Motor' + motor
                        motor++
                when 'MSP_DEBUG'
                    debug = 0
                    while debug < SENSOR_DATA.debug.length
                        head += ',' + 'Debug' + debug
                        debug++
            i++
        append_to_file head
        return

    crunch_data = ->
        sample = millitime()
        i = 0
        while i < requested_properties.length
            switch requested_properties[i]
                when 'MSP_RAW_IMU'
                    sample += ',' + SENSOR_DATA.gyroscope
                    sample += ',' + SENSOR_DATA.accelerometer
                    sample += ',' + SENSOR_DATA.magnetometer
                when 'MSP_ATTITUDE'
                    sample += ',' + SENSOR_DATA.kinematics[0]
                    sample += ',' + SENSOR_DATA.kinematics[1]
                    sample += ',' + SENSOR_DATA.kinematics[2]
                when 'MSP_ALTITUDE'
                    sample += ',' + SENSOR_DATA.altitude
                when 'MSP_RAW_GPS'
                    sample += ',' + GPS_DATA.fix
                    sample += ',' + GPS_DATA.numSat
                    sample += ',' + GPS_DATA.lat / 10000000
                    sample += ',' + GPS_DATA.lon / 10000000
                    sample += ',' + GPS_DATA.alt
                    sample += ',' + GPS_DATA.speed
                    sample += ',' + GPS_DATA.ground_course
                when 'MSP_ANALOG'
                    sample += ',' + ANALOG.voltage
                    sample += ',' + ANALOG.amperage
                    sample += ',' + ANALOG.mAhdrawn
                    sample += ',' + ANALOG.rssi
                when 'MSP_RC'
                    chan = 0
                    while chan < RC.active_channels
                        sample += ',' + RC.channels[chan]
                        chan++
                when 'MSP_MOTOR'
                    sample += ',' + MOTOR_DATA
                when 'MSP_DEBUG'
                    sample += ',' + SENSOR_DATA.debug
            i++
        log_buffer.push sample
        return

    prepare_file = ->
        prefix = 'log'
        suffix = 'csv'
        filename = generateFilename(prefix, suffix)
        accepts = [ {
            description: suffix.toUpperCase() + ' files'
            extensions: [ suffix ]
        } ]
        # create or load the file
        chrome.fileSystem.chooseEntry {
            type: 'saveFile'
            suggestedName: filename
            accepts: accepts
        }, (entry) ->
            if !entry
                console.log 'No file selected'
                return
            fileEntry = entry
            # echo/console log path specified
            chrome.fileSystem.getDisplayPath fileEntry, (path) ->
                console.log 'Log file path: ' + path
                return
            # change file entry from read only to read/write
            chrome.fileSystem.getWritableEntry fileEntry, (fileEntryWritable) ->
                # check if file is writable
                chrome.fileSystem.isWritableEntry fileEntryWritable, (isWritable) ->
                    if isWritable
                        fileEntry = fileEntryWritable
                        # save entry for next use
                        ConfigStorage.set 'logging_file_entry': chrome.fileSystem.retainEntry(fileEntry)
                        # reset sample counter in UI
                        $('.samples').text 0
                        prepare_writer()
                    else
                        console.log 'File appears to be read only, sorry.'
                    return
                return
            return
        return

    prepare_writer = (retaining) ->
        fileEntry.createWriter ((writer) ->
            fileWriter = writer

            fileWriter.onerror = (e) ->
                console.error e
                # stop logging if the procedure was/is still running
                if $('a.logging').data('clicks')
                    $('a.logging').click()
                return

            fileWriter.onwriteend = ->
                $('.size').text bytesToSize(fileWriter.length)
                return

            if retaining
                chrome.fileSystem.getDisplayPath fileEntry, (path) ->
                    GUI.log i18n.getMessage('loggingAutomaticallyRetained', [ path ])
                    return
            # update log size in UI on fileWriter creation
            $('.size').text bytesToSize(fileWriter.length)
            return
        ), (e) ->
            # File is not readable or does not exist!
            console.error e
            if retaining
                fileEntry = null
            return
        return

    append_to_file = (data) ->
        if fileWriter.position < fileWriter.length
            fileWriter.seek fileWriter.length
        fileWriter.write new Blob([ data + '\n' ], type: 'text/plain')
        return

    if GUI.active_tab != 'logging'
        GUI.active_tab = 'logging'
    requested_properties = []
    samples = 0
    requests = 0
    log_buffer = []
    if CONFIGURATOR.connectionValid

        get_motor_data = ->
            MSP.send_message MSPCodes.MSP_MOTOR, false, false, load_html
            return

        load_html = ->
            $('#content').load './tabs/logging.html', process_html
            return

        MSP.send_message MSPCodes.MSP_RC, false, false, get_motor_data
    # IO related methods
    fileEntry = null
    fileWriter = null
    return

TABS.logging.cleanup = (callback) ->
    if callback
        callback()
    return

