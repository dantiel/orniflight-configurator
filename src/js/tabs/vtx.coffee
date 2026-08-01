'use strict'
TABS.vtx =
    supported: false
    vtxTableSavePending: false
    MAX_POWERLEVEL_VALUES: 8
    MAX_BAND_VALUES: 8
    MAX_BAND_CHANNELS_VALUES: 8
    VTXTABLE_BAND_LIST: []
    VTXTABLE_POWERLEVEL_LIST: []
    analyticsChanges: {}
    updating: true

TABS.vtx.initialize = (callback) ->
    self = this

    load_html = ->
        $('#content').load './tabs/vtx.html', process_html
        return

    process_html = ->
        initDisplay()
        # translate to user-selected language
        i18n.localizePage()
        self.updating = false
        GUI.content_ready callback
        return

    # Read all the MSP data needed by the tab

    read_vtx_config = (callback_after_msp) ->

        vtx_config = ->
            MSP.send_message MSPCodes.MSP_VTX_CONFIG, false, false, vtxtable_bands
            return

        vtxtable_bands = ->
            # Simulation of static variable
            if typeof vtxtable_bands.counter == 'undefined'
                TABS.vtx.VTXTABLE_BAND_LIST = []
                vtxtable_bands.counter = 1
            else
                TABS.vtx.VTXTABLE_BAND_LIST.push Object.assign({}, VTXTABLE_BAND)
                vtxtable_bands.counter++
            buffer = []
            buffer.push8 vtxtable_bands.counter
            if vtxtable_bands.counter <= VTX_CONFIG.vtx_table_bands
                MSP.send_message MSPCodes.MSP_VTXTABLE_BAND, buffer, false, vtxtable_bands
            else
                vtxtable_bands.counter = undefined
                vtxtable_powerlevels()
            return

        vtxtable_powerlevels = ->
            # Simulation of static variable
            if typeof vtxtable_powerlevels.counter == 'undefined'
                TABS.vtx.VTXTABLE_POWERLEVEL_LIST = []
                vtxtable_powerlevels.counter = 1
            else
                TABS.vtx.VTXTABLE_POWERLEVEL_LIST.push Object.assign({}, VTXTABLE_POWERLEVEL)
                vtxtable_powerlevels.counter++
            buffer = []
            buffer.push8 vtxtable_powerlevels.counter
            if vtxtable_powerlevels.counter <= VTX_CONFIG.vtx_table_powerlevels
                MSP.send_message MSPCodes.MSP_VTXTABLE_POWERLEVEL, buffer, false, vtxtable_powerlevels
            else
                vtxtable_powerlevels.counter = undefined
                callback_after_msp()
            return

        vtx_config()
        return

    # Emulates the MSP read from a vtxConfig object (JSON)

    read_vtx_config_json = (vtxConfig, vtxcallback_after_read) ->
        # Bands and channels
        VTX_CONFIG.vtx_table_bands = vtxConfig.vtx_table.bands_list.length
        maxChannels = 0
        TABS.vtx.VTXTABLE_BAND_LIST = []
        i = 1
        while i <= VTX_CONFIG.vtx_table_bands
            TABS.vtx.VTXTABLE_BAND_LIST[i - 1] = {}
            TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_number = i
            TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_name = vtxConfig.vtx_table.bands_list[i - 1].name
            TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_letter = vtxConfig.vtx_table.bands_list[i - 1].letter
            TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_is_factory_band = vtxConfig.vtx_table.bands_list[i - 1].is_factory_band
            TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_frequencies = vtxConfig.vtx_table.bands_list[i - 1].frequencies
            maxChannels = Math.max(maxChannels, TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_frequencies.length)
            i++
        VTX_CONFIG.vtx_table_channels = maxChannels
        # Power levels
        VTX_CONFIG.vtx_table_powerlevels = vtxConfig.vtx_table.powerlevels_list.length
        TABS.vtx.VTXTABLE_POWERLEVEL_LIST = []
        _i = 1
        while _i <= VTX_CONFIG.vtx_table_powerlevels
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[_i - 1] = {}
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[_i - 1].vtxtable_powerlevel_number = _i
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[_i - 1].vtxtable_powerlevel_value = vtxConfig.vtx_table.powerlevels_list[_i - 1].value
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[_i - 1].vtxtable_powerlevel_label = vtxConfig.vtx_table.powerlevels_list[_i - 1].label
            _i++
        vtxcallback_after_read()
        return

    # Prepares all the UI elements, the MSP command has been executed before

    initDisplay = ->
        # Actions and other

        frequencyOrBandChannel = ->
            frequencyEnabled = $(this).prop('checked')
            if frequencyEnabled
                $('.field.vtx_channel').slideUp 100, ->
                    $('.field.vtx_band').slideUp 100, ->
                        $('.field.vtx_frequency').slideDown 100
                        return
                    return
            else
                $('.field.vtx_frequency').slideUp 100, ->
                    $('.field.vtx_band').slideDown 100, ->
                        $('.field.vtx_channel').slideDown 100
                        return
                    return
            return

        showHidePowerlevels = ->
            powerlevelsValue = $(this).val()
            _i3 = 1
            while _i3 <= TABS.vtx.MAX_POWERLEVEL_VALUES
                $('.vtx_table_powerlevels_table td:nth-child(' + _i3 + ')').toggle _i3 <= powerlevelsValue
                _i3++
            return

        showHideBands = ->
            bandsValue = $(this).val()
            _i4 = 1
            while _i4 <= TABS.vtx.MAX_BAND_VALUES
                $('.vtx_table_bands_table tr:nth-child(' + _i4 + 1 + ')').toggle _i4 <= bandsValue
                _i4++
            return

        showHideBandChannels = ->
            channelsValue = $(this).val()
            _i5 = 1
            while _i5 <= TABS.vtx.MAX_BAND_CHANNELS_VALUES
                $('.vtx_table_bands_table td:nth-child(' + _i5 + 3 + ')').toggle _i5 <= channelsValue
                _i5++
            return

        ###** Helper functions ###

        loadPowerLevelsTemplate = ->
            # Power levels title
            powerlevelstitle_e = $('.vtx_table_powerlevels_table .vtx_table_powerlevels_title')
            _i6 = 1
            while _i6 <= TABS.vtx.MAX_POWERLEVEL_VALUES
                powerlevelstitle_e.append '<td><span>' + _i6 + '</span></td>'
                _i6++
            # Power levels
            powerlevelsrow_e = $('.vtx_table_powerlevels_table .vtx_table_powerlevels_values')
            powervalues_e = $('#tab-vtx-templates #tab-vtx-powerlevel-values td')
            _i7 = 1
            while _i7 <= TABS.vtx.MAX_POWERLEVEL_VALUES
                newPowerValues_e = powervalues_e.clone()
                $(newPowerValues_e).find('input').attr 'id', 'vtx_table_powerlevels_' + _i7
                powerlevelsrow_e.append newPowerValues_e
                _i7++
            powerlevelsrow_e.append '<td><span>' + i18n.getMessage('vtxTablePowerLevelsValue') + '</span></td>'
            # Power labels
            powerlabelsrow_e = $('.vtx_table_powerlevels_table .vtx_table_powerlevels_labels')
            powerlabels_e = $('#tab-vtx-templates #tab-vtx-powerlevel-labels td')
            _i8 = 1
            while _i8 <= TABS.vtx.MAX_POWERLEVEL_VALUES
                newPowerLabels_e = powerlabels_e.clone()
                $(newPowerLabels_e).find('input').attr 'id', 'vtx_table_powerlabels_' + _i8
                powerlabelsrow_e.append newPowerLabels_e
                _i8++
            powerlabelsrow_e.append '<td><span>' + i18n.getMessage('vtxTablePowerLevelsLabel') + '</span></td>'
            return

        loadBandsChannelsTemplate = ->
            bandstable_e = $('.vtx_table_bands_table tbody')
            # Title
            title_e = $('#tab-vtx-templates #tab-vtx-bands-title tr')
            _i9 = 1
            while _i9 <= TABS.vtx.MAX_BAND_VALUES
                title_e.append '<td><span>' + _i9 + '</span></td>'
                _i9++
            bandstable_e.append title_e
            # Bands
            band_e = $('#tab-vtx-templates #tab-vtx-bands tr')
            channel_e = $('#tab-vtx-templates #tab-vtx-channels td')
            _i0 = 1
            while _i0 <= TABS.vtx.MAX_BAND_VALUES
                newBand_e = band_e.clone()
                $(newBand_e).find('#vtx_table_band_name').attr 'id', 'vtx_table_band_name_' + _i0
                $(newBand_e).find('#vtx_table_band_letter').attr 'id', 'vtx_table_band_letter_' + _i0
                $(newBand_e).find('#vtx_table_band_factory').attr 'id', 'vtx_table_band_factory_' + _i0
                # Channels
                newChannel_e = undefined
                _j = 1
                while _j <= TABS.vtx.MAX_BAND_CHANNELS_VALUES
                    newChannel_e = channel_e.clone()
                    $(newChannel_e).find('input').attr 'id', 'vtx_table_band_channel_' + _i0 + '_' + _j
                    newBand_e.append newChannel_e
                    _j++
                # Append to the end an index of the band
                newBand_e.append '<td><span>' + i18n.getMessage('vtxBand_X', bandName: _i0) + '</span></td>'
                bandstable_e.append newBand_e
                _i0++
            return

        populateBandSelect = ->
            selectBand = $('.field #vtx_band')
            selectBand.append new Option(i18n.getMessage('vtxBand_0'), 0)
            if VTX_CONFIG.vtx_table_available
                _i1 = 1
                while _i1 <= VTX_CONFIG.vtx_table_bands
                    _bandName = TABS.vtx.VTXTABLE_BAND_LIST[_i1 - 1].vtxtable_band_name
                    if _bandName.trim() == ''
                        _bandName = i18n.getMessage('vtxBand_X', bandName: _i1)
                    selectBand.append new Option(_bandName, _i1)
                    _i1++
            else
                _i10 = 1
                while _i10 <= TABS.vtx.MAX_BAND_VALUES
                    selectBand.append new Option(i18n.getMessage('vtxBand_X', bandName: _i10), _i10)
                    _i10++
            return

        populateChannelSelect = ->
            selectChannel = $('.field #vtx_channel')
            selectedBand = $('#vtx_band').val()
            selectChannel.empty()
            selectChannel.append new Option(i18n.getMessage('vtxChannel_0'), 0)
            if VTX_CONFIG.vtx_table_available
                if TABS.vtx.VTXTABLE_BAND_LIST[selectedBand - 1]
                    _i11 = 1
                    while _i11 <= TABS.vtx.VTXTABLE_BAND_LIST[selectedBand - 1].vtxtable_band_frequencies.length
                        channelName = TABS.vtx.VTXTABLE_BAND_LIST[selectedBand - 1].vtxtable_band_frequencies[_i11 - 1]
                        if channelName > 0
                            selectChannel.append new Option(i18n.getMessage('vtxChannel_X', channelName: _i11), _i11)
                        _i11++
            else
                _i12 = 1
                while _i12 <= TABS.vtx.MAX_BAND_CHANNELS_VALUES
                    selectBand.append new Option(i18n.getMessage('vtxChannel_X', channelName: _i12), _i12)
                    _i12++
            return

        populatePowerSelect = ->
            selectPower = $('.field #vtx_power')
            if VTX_CONFIG.vtx_table_available
                selectPower.append new Option(i18n.getMessage('vtxPower_0'), 0)
                _i13 = 1
                while _i13 <= VTX_CONFIG.vtx_table_powerlevels
                    _powerLevel = TABS.vtx.VTXTABLE_POWERLEVEL_LIST[_i13 - 1].vtxtable_powerlevel_label
                    if _powerLevel.trim() == ''
                        _powerLevel = i18n.getMessage('vtxPower_X', powerLevel: _i13)
                    selectPower.append new Option(_powerLevel, _i13)
                    _i13++
            else
                powerMaxMinValues = getPowerValues(VTX_CONFIG.vtx_type)
                _i14 = powerMaxMinValues.min
                while _i14 <= powerMaxMinValues.max
                    if _i14 == 0
                        selectPower.append new Option(i18n.getMessage('vtxPower_0'), 0)
                    else
                        selectPower.append new Option(i18n.getMessage('vtxPower_X', bandName: _i14), _i14)
                    _i14++
            return

        # Returns the power values min and max depending on the VTX Type

        getPowerValues = (vtxType) ->
            powerMinMax = {}
            if VTX_CONFIG.vtx_table_available
                powerMinMax =
                    min: 1
                    max: VTX_CONFIG.vtx_table_powerlevels
            else
                switch vtxType
                    when 0
                        # Unsupported
                        powerMinMax = {}
                    when 1
                        # RTC6705
                        powerMinMax =
                            min: 1
                            max: 3
                    when 3
                        # SmartAudio
                        powerMinMax =
                            min: 1
                            max: 4
                    when 4
                        # Tramp
                        powerMinMax =
                            min: 1
                            max: 5
                    # Unknown
                    else
                        powerMinMax =
                            min: 0
                            max: 7
            powerMinMax

        if !TABS.vtx.supported
            $('.tab-vtx').removeClass 'supported'
            return
        $('.tab-vtx').addClass 'supported'
        # Load all the dynamic elements
        loadPowerLevelsTemplate()
        loadBandsChannelsTemplate()
        populateBandSelect()
        populatePowerSelect()
        $('.uppercase').keyup ->
            @value = @value.toUpperCase().trim()
            return
        # Supported?
        vtxSupported = VTX_CONFIG.vtx_type != 0 and VTX_CONFIG.vtx_type != 255
        vtxTableNotConfigured = vtxSupported and VTX_CONFIG.vtx_table_available and (VTX_CONFIG.vtx_table_bands == 0 or VTX_CONFIG.vtx_table_channels == 0 or VTX_CONFIG.vtx_table_powerlevels == 0)
        $('.vtx_supported').toggle vtxSupported
        $('.vtx_not_supported').toggle !vtxSupported
        $('.vtx_table_available').toggle vtxSupported and VTX_CONFIG.vtx_table_available
        $('.vtx_table_not_configured').toggle vtxTableNotConfigured
        $('.vtx_table_save_pending').toggle TABS.vtx.vtxTableSavePending
        # Buttons
        $('.clipboard_available').toggle Clipboard.available and Clipboard.readAvailable
        # Insert actual values in the fields
        # Values of the selected mode
        $('#vtx_frequency').val VTX_CONFIG.vtx_frequency
        $('#vtx_band').val VTX_CONFIG.vtx_band
        $('#vtx_band').change(populateChannelSelect).change()
        $('#vtx_channel').val VTX_CONFIG.vtx_channel
        if VTX_CONFIG.vtx_table_available
            $('#vtx_channel').attr 'max', VTX_CONFIG.vtx_table_channels
        $('#vtx_power').val VTX_CONFIG.vtx_power
        $('#vtx_pit_mode').prop 'checked', VTX_CONFIG.vtx_pit_mode
        $('#vtx_pit_mode_frequency').val VTX_CONFIG.vtx_pit_mode_frequency
        $('#vtx_low_power_disarm').val VTX_CONFIG.vtx_low_power_disarm
        # Values of the current values
        yesMessage = i18n.getMessage('yes')
        noMessage = i18n.getMessage('no')
        $('#vtx_device_ready_description').text if VTX_CONFIG.vtx_device_ready then yesMessage else noMessage
        $('#vtx_type_description').text i18n.getMessage('vtxType_' + VTX_CONFIG.vtx_type)
        $('#vtx_channel_description').text VTX_CONFIG.vtx_channel
        $('#vtx_frequency_description').text VTX_CONFIG.vtx_frequency
        $('#vtx_pit_mode_description').text if VTX_CONFIG.vtx_pit_mode then yesMessage else noMessage
        $('#vtx_pit_mode_frequency_description').text VTX_CONFIG.vtx_pit_mode_frequency
        $('#vtx_low_power_disarm_description').text i18n.getMessage('vtxLowPowerDisarmOption_' + VTX_CONFIG.vtx_low_power_disarm)
        if VTX_CONFIG.vtx_band == 0
            $('#vtx_band_description').text i18n.getMessage('vtxBand_0')
        else
            if VTX_CONFIG.vtx_table_available and TABS.vtx.VTXTABLE_BAND_LIST[VTX_CONFIG.vtx_band - 1]
                bandName = TABS.vtx.VTXTABLE_BAND_LIST[VTX_CONFIG.vtx_band - 1].vtxtable_band_name
                if bandName.trim() == ''
                    bandName = VTX_CONFIG.vtx_band
                $('#vtx_band_description').text bandName
            else
                $('#vtx_band_description').text VTX_CONFIG.vtx_band
        if VTX_CONFIG.vtx_power == 0
            $('#vtx_power_description').text i18n.getMessage('vtxPower_0')
        else
            if VTX_CONFIG.vtx_table_available
                entry = TABS.vtx.VTXTABLE_POWERLEVEL_LIST[VTX_CONFIG.vtx_power - 1]
                powerLevel = if entry and entry.vtxtable_powerlevel_label then entry.vtxtable_powerlevel_label else String(VTX_CONFIG.vtx_power)
                if powerLevel.trim() == ''
                    powerLevel = String(VTX_CONFIG.vtx_power)
                $('#vtx_power_description').text powerLevel
            else
                levelText = i18n.getMessage('vtxPower_X', powerLevel: VTX_CONFIG.vtx_power)
                $('#vtx_power_description').text levelText
        $('#vtx_table_powerlevels').val VTX_CONFIG.vtx_table_powerlevels
        # Populate power levels
        i = 1
        while i <= TABS.vtx.VTXTABLE_POWERLEVEL_LIST.length
            $('#vtx_table_powerlevels_' + i).val TABS.vtx.VTXTABLE_POWERLEVEL_LIST[i - 1].vtxtable_powerlevel_value
            $('#vtx_table_powerlabels_' + i).val TABS.vtx.VTXTABLE_POWERLEVEL_LIST[i - 1].vtxtable_powerlevel_label
            i++
        $('#vtx_table_bands').val VTX_CONFIG.vtx_table_bands
        $('#vtx_table_channels').val VTX_CONFIG.vtx_table_channels
        # Populate VTX Table
        _i2 = 1
        while _i2 <= TABS.vtx.VTXTABLE_BAND_LIST.length
            $('#vtx_table_band_name_' + _i2).val TABS.vtx.VTXTABLE_BAND_LIST[_i2 - 1].vtxtable_band_name
            $('#vtx_table_band_letter_' + _i2).val TABS.vtx.VTXTABLE_BAND_LIST[_i2 - 1].vtxtable_band_letter
            $('#vtx_table_band_factory_' + _i2).prop 'checked', TABS.vtx.VTXTABLE_BAND_LIST[_i2 - 1].vtxtable_band_is_factory_band
            j = 1
            while j <= TABS.vtx.VTXTABLE_BAND_LIST[_i2 - 1].vtxtable_band_frequencies.length
                $('#vtx_table_band_channel_' + _i2 + '_' + j).val TABS.vtx.VTXTABLE_BAND_LIST[_i2 - 1].vtxtable_band_frequencies[j - 1]
                j++
            _i2++
        $('#vtx_frequency_channel').prop('checked', VTX_CONFIG.vtx_band == 0 and VTX_CONFIG.vtx_frequency > 0).change frequencyOrBandChannel
        if $('#vtx_frequency_channel').prop('checked')
            $('.field.vtx_channel').hide()
            $('.field.vtx_band').hide()
            $('.field.vtx_frequency').show()
        else
            $('.field.vtx_channel').show()
            $('.field.vtx_band').show()
            $('.field.vtx_frequency').hide()
        $('#vtx_table_powerlevels').on('input', showHidePowerlevels).trigger 'input'
        $('#vtx_table_bands').on('input', showHideBands).trigger 'input'
        $('#vtx_table_channels').on('input', showHideBandChannels).trigger 'input'
        $('#vtx_table').change ->
            fromScratch = true
            if self.analyticsChanges['VtxTableLoadFromClipboard'] != undefined or self.analyticsChanges['VtxTableLoadFromFile'] != undefined
                fromScratch = false
            self.analyticsChanges['VtxTableEdit'] = if fromScratch then 'modificationOnly' else 'fromTemplate'
            return
        # Save and other button functions
        $('a.save_file').click ->
            save_json()
            return
        $('a.load_file').click ->
            load_json()
            return
        $('a.load_clipboard').click ->
            load_clipboard_json()
            return
        $('a.save').click ->
            if !self.updating
                save_vtx()
            return
        return

    save_json = ->
        suggestedName = 'vtxtable'
        suffix = 'json'
        filename = generateFilename(suggestedName, suffix)
        accepts = [ {
            description: suffix.toUpperCase() + ' files'
            extensions: [ suffix ]
        } ]
        chrome.fileSystem.chooseEntry {
            type: 'saveFile'
            suggestedName: filename
            accepts: accepts
        }, (entry) ->
            if chrome.runtime.lastError
                console.error chrome.runtime.lastError.message
                return
            if !entry
                console.log 'No file selected'
                return
            entry.createWriter ((writer) ->

                writer.onerror = ->
                    console.error 'Failed to write VTX file'
                    GUI.log i18n.getMessage('vtxSavedFileKo')
                    return

                writer.onwriteend = ->
                    dump_html_to_msp()
                    vtxConfig = createVtxConfigInfo()
                    text = JSON.stringify(vtxConfig, null, 4)
                    data = new Blob([ text ], type: 'application/json')
                    # we get here at the end of the truncate method, change to the new end

                    writer.onwriteend = ->
                        analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'VtxTableSave', text.length
                        console.log 'Write VTX file end'
                        GUI.log i18n.getMessage('vtxSavedFileOk')
                        return

                    writer.write data
                    return

                writer.truncate 0
                return
            ), ->
                console.error 'Failed to get VTX file writer'
                GUI.log i18n.getMessage('vtxSavedFileKo')
                return
            return
        return

    load_json = ->
        suffix = 'json'
        accepts = [ {
            description: suffix.toUpperCase() + ' files'
            extensions: [ suffix ]
        } ]
        chrome.fileSystem.chooseEntry {
            type: 'openFile'
            accepts: accepts
        }, (entry) ->
            if chrome.runtime.lastError
                console.error chrome.runtime.lastError.message
                return
            if !entry
                console.log 'No file selected'
                return
            entry.file ((file) ->
                reader = new FileReader

                reader.onload = (e) ->
                    text = e.target.result
                    try
                        vtxConfig = JSON.parse(text)
                        read_vtx_config_json vtxConfig, load_html
                        TABS.vtx.vtxTableSavePending = true
                        self.analyticsChanges['VtxTableLoadFromClipboard'] = undefined
                        self.analyticsChanges['VtxTableLoadFromFile'] = file.name
                        console.log 'Load VTX file end'
                        GUI.log i18n.getMessage('vtxLoadFileOk')
                    catch err
                        console.error 'Failed loading VTX file config'
                        GUI.log i18n.getMessage('vtxLoadFileKo')
                    return

                reader.readAsText file
                return
            ), ->
                console.error 'Failed to get VTX file reader'
                GUI.log i18n.getMessage('vtxLoadFileKo')
                return
            return
        return

    load_clipboard_json = ->
        try
            Clipboard.readText ((text) ->
                console.log 'Pasted content: ', text
                vtxConfig = JSON.parse(text)
                read_vtx_config_json vtxConfig, load_html
                TABS.vtx.vtxTableSavePending = true
                self.analyticsChanges['VtxTableLoadFromFile'] = undefined
                self.analyticsChanges['VtxTableLoadFromClipboard'] = text.length
                console.log 'Load VTX clipboard end'
                GUI.log i18n.getMessage('vtxLoadClipboardOk')
                return
            ), (err) ->
                GUI.log i18n.getMessage('vtxLoadClipboardKo')
                console.error 'Failed to read clipboard contents: ', err
                return
        catch err
            console.error 'Failed loading VTX file config: ' + err
            GUI.log i18n.getMessage('vtxLoadClipboardKo')
        return

    # Save all the values from the tab to MSP

    save_vtx = ->

        save_vtx_config = ->
            MSP.send_message MSPCodes.MSP_SET_VTX_CONFIG, mspHelper.crunch(MSPCodes.MSP_SET_VTX_CONFIG), false, save_vtx_powerlevels
            return

        save_vtx_powerlevels = ->
            # Simulation of static variable
            if typeof save_vtx_powerlevels.counter == 'undefined'
                save_vtx_powerlevels.counter = 0
            else
                save_vtx_powerlevels.counter++
            if save_vtx_powerlevels.counter < VTX_CONFIG.vtx_table_powerlevels
                VTXTABLE_POWERLEVEL = Object.assign({}, TABS.vtx.VTXTABLE_POWERLEVEL_LIST[save_vtx_powerlevels.counter])
                MSP.send_message MSPCodes.MSP_SET_VTXTABLE_POWERLEVEL, mspHelper.crunch(MSPCodes.MSP_SET_VTXTABLE_POWERLEVEL), false, save_vtx_powerlevels
            else
                save_vtx_powerlevels.counter = undefined
                save_vtx_bands()
            return

        save_vtx_bands = ->
            # Simulation of static variable
            if typeof save_vtx_bands.counter == 'undefined'
                save_vtx_bands.counter = 0
            else
                save_vtx_bands.counter++
            if save_vtx_bands.counter < VTX_CONFIG.vtx_table_bands
                VTXTABLE_BAND = Object.assign({}, TABS.vtx.VTXTABLE_BAND_LIST[save_vtx_bands.counter])
                MSP.send_message MSPCodes.MSP_SET_VTXTABLE_BAND, mspHelper.crunch(MSPCodes.MSP_SET_VTXTABLE_BAND), false, save_vtx_bands
            else
                save_vtx_bands.counter = undefined
                save_to_eeprom()
            return

        save_to_eeprom = ->
            MSP.send_message MSPCodes.MSP_EEPROM_WRITE, false, false, save_completed
            return

        save_completed = ->
            GUI.log i18n.getMessage('configurationEepromSaved')
            TABS.vtx.vtxTableSavePending = false
            oldText = $('#save_button').text()
            $('#save_button').html i18n.getMessage('vtxButtonSaved')
            setTimeout (->
                $('#save_button').html oldText
                return
            ), 2000
            TABS.vtx.initialize()
            return

        self.updating = true
        dump_html_to_msp()
        # Start MSP saving
        save_vtx_config()
        analytics.sendChangeEvents analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, self.analyticsChanges
        return

    dump_html_to_msp = ->
        # General config
        frequencyEnabled = $('#vtx_frequency_channel').prop('checked')
        if frequencyEnabled
            VTX_CONFIG.vtx_frequency = parseInt($('#vtx_frequency').val())
            VTX_CONFIG.vtx_band = 0
            VTX_CONFIG.vtx_channel = 0
        else
            VTX_CONFIG.vtx_band = parseInt($('#vtx_band').val())
            VTX_CONFIG.vtx_channel = parseInt($('#vtx_channel').val())
            VTX_CONFIG.vtx_frequency = 0
            if semver.lt(CONFIG.apiVersion, '1.42.0')
                if VTX_CONFIG.vtx_band > 0 or VTX_CONFIG.vtx_channel > 0
                    VTX_CONFIG.vtx_frequency = (band - 1) * 8 + channel - 1
        VTX_CONFIG.vtx_power = parseInt($('#vtx_power').val())
        VTX_CONFIG.vtx_pit_mode = $('#vtx_pit_mode').prop('checked')
        VTX_CONFIG.vtx_low_power_disarm = parseInt($('#vtx_low_power_disarm').val())
        VTX_CONFIG.vtx_table_clear = true
        # Power levels
        VTX_CONFIG.vtx_table_powerlevels = parseInt($('#vtx_table_powerlevels').val())
        TABS.vtx.VTXTABLE_POWERLEVEL_LIST = []
        i = 1
        while i <= VTX_CONFIG.vtx_table_powerlevels
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[i - 1] = {}
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[i - 1].vtxtable_powerlevel_number = i
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[i - 1].vtxtable_powerlevel_value = parseInt($('#vtx_table_powerlevels_' + i).val())
            TABS.vtx.VTXTABLE_POWERLEVEL_LIST[i - 1].vtxtable_powerlevel_label = $('#vtx_table_powerlabels_' + i).val()
            i++
        # Bands and channels
        VTX_CONFIG.vtx_table_bands = parseInt($('#vtx_table_bands').val())
        VTX_CONFIG.vtx_table_channels = parseInt($('#vtx_table_channels').val())
        TABS.vtx.VTXTABLE_BAND_LIST = []
        _i15 = 1
        while _i15 <= VTX_CONFIG.vtx_table_bands
            TABS.vtx.VTXTABLE_BAND_LIST[_i15 - 1] = {}
            TABS.vtx.VTXTABLE_BAND_LIST[_i15 - 1].vtxtable_band_number = _i15
            TABS.vtx.VTXTABLE_BAND_LIST[_i15 - 1].vtxtable_band_name = $('#vtx_table_band_name_' + _i15).val()
            TABS.vtx.VTXTABLE_BAND_LIST[_i15 - 1].vtxtable_band_letter = $('#vtx_table_band_letter_' + _i15).val()
            TABS.vtx.VTXTABLE_BAND_LIST[_i15 - 1].vtxtable_band_is_factory_band = $('#vtx_table_band_factory_' + _i15).prop('checked')
            TABS.vtx.VTXTABLE_BAND_LIST[_i15 - 1].vtxtable_band_frequencies = []
            j = 1
            while j <= VTX_CONFIG.vtx_table_channels
                TABS.vtx.VTXTABLE_BAND_LIST[_i15 - 1].vtxtable_band_frequencies.push parseInt($('#vtx_table_band_channel_' + _i15 + '_' + j).val())
                j++
            _i15++
        return

    # Copies from the MSP data to the vtxInfo object (JSON)

    createVtxConfigInfo = ->
        vtxConfig = {}
        vtxConfig.description = 'OrniFlight VTX Config file'
        vtxConfig.version = '1.0'
        vtxConfig.vtx_table = {}
        vtxConfig.vtx_table.bands_list = []
        i = 1
        while i <= VTX_CONFIG.vtx_table_bands
            vtxConfig.vtx_table.bands_list[i - 1] = {}
            vtxConfig.vtx_table.bands_list[i - 1].name = TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_name
            vtxConfig.vtx_table.bands_list[i - 1].letter = TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_letter
            vtxConfig.vtx_table.bands_list[i - 1].is_factory_band = TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_is_factory_band
            vtxConfig.vtx_table.bands_list[i - 1].frequencies = TABS.vtx.VTXTABLE_BAND_LIST[i - 1].vtxtable_band_frequencies
            i++
        vtxConfig.vtx_table.powerlevels_list = []
        _i16 = 1
        while _i16 <= VTX_CONFIG.vtx_table_powerlevels
            vtxConfig.vtx_table.powerlevels_list[_i16 - 1] = {}
            vtxConfig.vtx_table.powerlevels_list[_i16 - 1].value = TABS.vtx.VTXTABLE_POWERLEVEL_LIST[_i16 - 1].vtxtable_powerlevel_value
            vtxConfig.vtx_table.powerlevels_list[_i16 - 1].label = TABS.vtx.VTXTABLE_POWERLEVEL_LIST[_i16 - 1].vtxtable_powerlevel_label
            _i16++
        vtxConfig

    if GUI.active_tab != 'vtx'
        GUI.active_tab = 'vtx'
    self.analyticsChanges = {}
    @supported = semver.gte(CONFIG.apiVersion, '1.42.0')
    if !@supported
        load_html()
    else
        read_vtx_config load_html
    return

TABS.vtx.cleanup = (callback) ->
    # Add here things that need to be cleaned or closed before leaving the tab
    @vtxTableSavePending = false
    @VTXTABLE_BAND_LIST = []
    @VTXTABLE_POWERLEVEL_LIST = []
    if callback
        callback()
    return

