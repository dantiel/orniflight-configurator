'use strict'
TABS.auxiliary = {}

TABS.auxiliary.initialize = (callback) ->

    get_mode_ranges = ->
        MSP.send_message MSPCodes.MSP_MODE_RANGES, false, false, if semver.gte(CONFIG.apiVersion, '1.41.0') then get_mode_ranges_extra else get_box_ids
        return

    get_mode_ranges_extra = ->
        MSP.send_message MSPCodes.MSP_MODE_RANGES_EXTRA, false, false, get_box_ids
        return

    get_box_ids = ->
        MSP.send_message MSPCodes.MSP_BOXIDS, false, false, get_rssi_config
        return

    get_rssi_config = ->
        MSP.send_message MSPCodes.MSP_RSSI_CONFIG, false, false, get_rc_data
        return

    get_rc_data = ->
        MSP.send_message MSPCodes.MSP_RC, false, false, get_serial_config
        return

    get_serial_config = ->
        MSP.send_message MSPCodes.MSP_CF_SERIAL_CONFIG, false, false, load_html
        return

    load_html = ->
        $('#content').load './tabs/auxiliary.html', process_html
        return

    createMode = (modeIndex, modeId) ->
        modeTemplate = $('#tab-auxiliary-templates .mode')
        newMode = modeTemplate.clone()
        modeName = AUX_CONFIG[modeIndex]
        # Adjust the name of the box if a peripheral is selected
        modeName = adjustBoxNameIfPeripheralWithModeID(modeId, modeName)
        $(newMode).attr 'id', 'mode-' + modeIndex
        $(newMode).find('.name').text modeName
        $(newMode).data 'index', modeIndex
        $(newMode).data 'id', modeId
        $(newMode).find('.name').data 'modeElement', newMode
        $(newMode).find('a.addRange').data 'modeElement', newMode
        $(newMode).find('a.addLink').data 'modeElement', newMode
        # hide link button for ARM
        if modeId == 0 or semver.lt(CONFIG.apiVersion, '1.41.0')
            $(newMode).find('.addLink').hide()
        newMode

    configureLogicList = (template) ->
        `var logicOption`
        logicList = $(template).find('.logic')
        logicOptionTemplate = $(logicList).find('option')
        logicOptionTemplate.remove()
        #add logic option(s)
        logicOption = logicOptionTemplate.clone()
        logicOption.text i18n.getMessage('auxiliaryModeLogicOR')
        logicOption.val 0
        logicList.append logicOption
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            logicOption = logicOptionTemplate.clone()
            logicOption.text i18n.getMessage('auxiliaryModeLogicAND')
            logicOption.val 1
            logicList.append logicOption
        logicOptionTemplate.val 0
        return

    configureRangeTemplate = (auxChannelCount) ->
        `var channelOption`
        rangeTemplate = $('#tab-auxiliary-templates .range')
        channelList = $(rangeTemplate).find('.channel')
        channelOptionTemplate = $(channelList).find('option')
        channelOptionTemplate.remove()
        #add value to autodetect channel
        channelOption = channelOptionTemplate.clone()
        channelOption.text i18n.getMessage('auxiliaryAutoChannelSelect')
        channelOption.val -1
        channelList.append channelOption
        channelIndex = 0
        while channelIndex < auxChannelCount
            channelOption = channelOptionTemplate.clone()
            channelOption.text 'AUX ' + channelIndex + 1
            channelOption.val channelIndex
            channelList.append channelOption
            channelIndex++
        channelOptionTemplate.val -1
        configureLogicList rangeTemplate
        return

    configureLinkTemplate = ->
        `var linkOption`
        linkTemplate = $('#tab-auxiliary-templates .link')
        linkList = $(linkTemplate).find('.linkedTo')
        linkOptionTemplate = $(linkList).find('option')
        linkOptionTemplate.remove()
        # set up a blank option in place of ARM
        linkOption = linkOptionTemplate.clone()
        linkOption.text ''
        linkOption.val 0
        linkList.append linkOption
        index = 1
        while index < AUX_CONFIG.length
            linkOption = linkOptionTemplate.clone()
            linkOption.text AUX_CONFIG[index]
            linkOption.val AUX_CONFIG_IDS[index]
            # set value to mode id
            linkList.append linkOption
            index++
        linkOptionTemplate.val 0
        configureLogicList linkTemplate
        return

    addRangeToMode = (modeElement, auxChannelIndex, modeLogic, range) ->
        modeIndex = $(modeElement).data('index')
        modeRanges = $(modeElement).find('.ranges')
        channel_range = 
            'min': [ 900 ]
            'max': [ 2100 ]
        rangeValues = [
            1300
            1700
        ]
        # matches MultiWii default values for the old checkbox MID range.
        if range != undefined
            rangeValues = [
                range.start
                range.end
            ]
        rangeIndex = modeRanges.children().length
        rangeElement = $('#tab-auxiliary-templates .range').clone()
        rangeElement.attr 'id', 'mode-' + modeIndex + '-range-' + rangeIndex
        modeRanges.append rangeElement
        if rangeIndex == 0
            $(rangeElement).find('.logic').hide()
        else if rangeIndex == 1
            modeRanges.children().eq(0).find('.logic').show()
        $(rangeElement).find('.channel-slider').noUiSlider
            start: rangeValues
            behaviour: 'snap-drag'
            margin: 50
            step: 25
            connect: true
            range: channel_range
            format: wNumb(decimals: 0)
        elementName = '#mode-' + modeIndex + '-range-' + rangeIndex
        $(elementName + ' .channel-slider').Link('lower').to $(elementName + ' .lowerLimitValue')
        $(elementName + ' .channel-slider').Link('upper').to $(elementName + ' .upperLimitValue')
        $(rangeElement).find('.pips-channel-range').noUiSlider_pips
            mode: 'values'
            values: [
                900
                1000
                1200
                1400
                1500
                1600
                1800
                2000
                2100
            ]
            density: 4
            stepped: true
        $(rangeElement).find('.deleteRange').data 'rangeElement', rangeElement
        $(rangeElement).find('.deleteRange').data 'modeElement', modeElement
        $(rangeElement).find('a.deleteRange').click ->
            `var modeElement`
            `var rangeElement`
            modeElement = $(this).data('modeElement')
            rangeElement = $(this).data('rangeElement')
            rangeElement.remove()
            siblings = $(modeElement).find('.ranges').children()
            if siblings.length == 1
                siblings.eq(0).find('.logic').hide()
            return
        $(rangeElement).find('.channel').val auxChannelIndex
        $(rangeElement).find('.logic').val modeLogic
        return

    addLinkedToMode = (modeElement, modeLogic, linkedTo) ->
        modeId = $(modeElement).data('id')
        modeIndex = $(modeElement).data('index')
        modeRanges = $(modeElement).find('.ranges')
        linkIndex = modeRanges.children().length
        linkElement = $('#tab-auxiliary-templates .link').clone()
        linkElement.attr 'id', 'mode-' + modeIndex + '-link-' + linkIndex
        modeRanges.append linkElement
        if linkIndex == 0
            $(linkElement).find('.logic').hide()
        else if linkIndex == 1
            modeRanges.children().eq(0).find('.logic').show()
        # disable the option associated with this mode
        linkSelect = $(linkElement).find('.linkedTo')
        $(linkSelect).find('option[value="' + modeId + '"]').prop 'disabled', true
        $(linkElement).find('.deleteLink').data 'linkElement', linkElement
        $(linkElement).find('.deleteLink').data 'modeElement', modeElement
        $(linkElement).find('a.deleteLink').click ->
            `var modeElement`
            `var linkElement`
            modeElement = $(this).data('modeElement')
            linkElement = $(this).data('linkElement')
            linkElement.remove()
            siblings = $(modeElement).find('.ranges').children()
            if siblings.length == 1
                siblings.eq(0).find('.logic').hide()
            return
        $(linkElement).find('.linkedTo').val linkedTo
        $(linkElement).find('.logic').val modeLogic
        return

    process_html = ->
        `var get_rc_data`
        auxChannelCount = RC.active_channels - 4

        box_highlight = (auxChannelIndex, channelPosition) ->
            if channelPosition < 900
                channelPosition = 900
            else if channelPosition > 2100
                channelPosition = 2100
            return

        update_marker = (auxChannelIndex, channelPosition) ->
            percentage = (channelPosition - 900) / (2100 - 900) * 100
            $('.modes .ranges .range').each ->
                auxChannelCandidateIndex = $(this).find('.channel').val()
                if auxChannelCandidateIndex != auxChannelIndex
                    return
                $(this).find('.marker').css 'left', percentage + '%'
                return
            return

        # data pulling functions used inside interval timer

        get_rc_data = ->
            MSP.send_message MSPCodes.MSP_RC, false, false, update_ui
            return

        update_ui = ->
            `var auxChannelCount`
            hasUsedMode = false
            _i = 0
            while _i < AUX_CONFIG.length
                modeElement = $('#mode-' + _i)
                if modeElement.find(' .range').length == 0 and modeElement.find(' .link').length == 0
                    # if the mode is unused, skip it
                    modeElement.removeClass('off').removeClass('on').removeClass 'disabled'
                    _i++
                    continue
                if bit_check(CONFIG.mode, _i)
                    $('.mode .name').eq(_i).data('modeElement').addClass('on').removeClass('off').removeClass 'disabled'
                    # ARM mode is a special case
                    if _i == 0
                        $('.mode .name').eq(_i).html AUX_CONFIG[_i]
                else
                    #ARM mode is a special case
                    if _i == 0
                        armSwitchActive = false
                        if semver.gte(CONFIG.apiVersion, '1.36.0')
                            if CONFIG.armingDisableCount > 0
                                # check the highest bit of the armingDisableFlags. This will be the ARMING_DISABLED_ARMSWITCH flag.
                                armSwitchMask = 1 << CONFIG.armingDisableCount - 1
                                if (CONFIG.armingDisableFlags & armSwitchMask) > 0
                                    armSwitchActive = true
                        # If the ARMING_DISABLED_ARMSWITCH flag is set then that means that arming is disabled
                        # and the arm switch is in a valid arming range. Highlight the mode in red to indicate
                        # that arming is disabled.
                        if armSwitchActive
                            $('.mode .name').eq(_i).data('modeElement').removeClass('on').removeClass('off').addClass 'disabled'
                            $('.mode .name').eq(_i).html AUX_CONFIG[_i] + '<br>' + i18n.getMessage('auxiliaryDisabled')
                        else
                            $('.mode .name').eq(_i).data('modeElement').removeClass('on').removeClass('disabled').addClass 'off'
                            $('.mode .name').eq(_i).html AUX_CONFIG[_i]
                    else
                        $('.mode .name').eq(_i).data('modeElement').removeClass('on').removeClass('disabled').addClass 'off'
                hasUsedMode = true
                _i++
            hideUnused = hideUnusedModes and hasUsedMode
            _i2 = 0
            while _i2 < AUX_CONFIG.length
                _modeElement = $('#mode-' + _i2)
                if _modeElement.find(' .range').length == 0 and _modeElement.find(' .link').length == 0
                    _modeElement.toggle !hideUnused
                _i2++
            auto_select_channel RC.channels, RSSI_CONFIG.channel
            auxChannelCount = RC.active_channels - 4
            i = 0
            while i < auxChannelCount
                box_highlight i, RC.channels[i + 4]
                update_marker i, RC.channels[i + 4]
                i++
            return

        ###*
        # Autodetect channel based on maximum deference with previous value
        # minimum value to autodetect is 100
        # @param RC_channels
        # @param RC_channels
        ###

        auto_select_channel = (RC_channels, RSSI_channel) ->
            auto_option = $('.tab-auxiliary select.channel option[value="-1"]:selected')
            if auto_option.length == 0
                prevChannelsValues = null
                return

            fillPrevChannelsValues = ->
                prevChannelsValues = RC_channels.slice(0)
                #clone array
                return

            if !prevChannelsValues or RC_channels.length == 0
                return fillPrevChannelsValues()
            diff_array = RC_channels.map((currentValue, index) ->
                Math.abs prevChannelsValues[index] - currentValue
            )
            largest = diff_array.reduce(((x, y) ->
                if x > y then x else y
            ), 0)
            #minimum change to autoselect is 100
            if largest < 100
                return fillPrevChannelsValues()
            indexOfMaxValue = diff_array.indexOf(largest)
            if indexOfMaxValue >= 4 and indexOfMaxValue != RSSI_channel - 1
                #set channel
                auto_option.parent().val indexOfMaxValue - 4
            fillPrevChannelsValues()

        configureRangeTemplate auxChannelCount
        configureLinkTemplate()
        modeTableBodyElement = $('.tab-auxiliary .modes tbody')
        modeIndex = 0
        while modeIndex < AUX_CONFIG.length
            modeId = AUX_CONFIG_IDS[modeIndex]
            newMode = createMode(modeIndex, modeId)
            modeTableBodyElement.append newMode
            # generate ranges from the supplied AUX names and MODE_RANGES[_EXTRA] data
            # skip linked modes for now
            modeRangeIndex = 0
            while modeRangeIndex < MODE_RANGES.length
                modeRange = MODE_RANGES[modeRangeIndex]
                modeRangeExtra = 
                    id: modeRange.id
                    modeLogic: 0
                    linkedTo: 0
                if semver.gte(CONFIG.apiVersion, '1.41.0')
                    modeRangeExtra = MODE_RANGES_EXTRA[modeRangeIndex]
                if modeRange.id != modeId or modeRangeExtra.id != modeId
                    modeRangeIndex++
                    continue
                if modeId == 0 or modeRangeExtra.linkedTo == 0
                    range = modeRange.range
                    if !(range.start < range.end)
                        modeRangeIndex++
                        continue
                        # invalid!
                    addRangeToMode newMode, modeRange.auxChannelIndex, modeRangeExtra.modeLogic, range
                else
                    addLinkedToMode newMode, modeRangeExtra.modeLogic, modeRangeExtra.linkedTo
                modeRangeIndex++
            modeIndex++
        $('a.addRange').click ->
            modeElement = $(this).data('modeElement')
            # auto select AUTO option; default to 'OR' logic
            addRangeToMode modeElement, -1, 0
            return
        $('a.addLink').click ->
            modeElement = $(this).data('modeElement')
            # default to 'OR' logic and no link selected
            addLinkedToMode modeElement, 0, 0
            return
        # translate to user-selected language
        i18n.localizePage()
        # UI Hooks
        $('a.save').click ->
            `var modeRangeIndex`
            # update internal data structures based on current UI elements
            # we must send this many back to the FC - overwrite all of the old ones to be sure.
            requiredModesRangeCount = MODE_RANGES.length

            save_to_eeprom = ->
                MSP.send_message MSPCodes.MSP_EEPROM_WRITE, false, false, ->
                    GUI.log i18n.getMessage('auxiliaryEepromSaved')
                    return
                return

            MODE_RANGES = []
            MODE_RANGES_EXTRA = []
            $('.tab-auxiliary .modes .mode').each ->
                `var modeId`
                modeElement = $(this)
                modeId = modeElement.data('id')
                $(modeElement).find('.range').each ->
                    `var modeRange`
                    `var modeRangeExtra`
                    rangeValues = $(this).find('.channel-slider').val()
                    modeRange = 
                        id: modeId
                        auxChannelIndex: parseInt($(this).find('.channel').val())
                        range:
                            start: rangeValues[0]
                            end: rangeValues[1]
                    MODE_RANGES.push modeRange
                    modeRangeExtra = 
                        id: modeId
                        modeLogic: parseInt($(this).find('.logic').val())
                        linkedTo: 0
                    MODE_RANGES_EXTRA.push modeRangeExtra
                    return
                $(modeElement).find('.link').each ->
                    `var modeRange`
                    `var modeRangeExtra`
                    linkedToSelection = parseInt($(this).find('.linkedTo').val())
                    if linkedToSelection == 0
                        $(this).remove()
                    else
                        modeRange = 
                            id: modeId
                            auxChannelIndex: 0
                            range:
                                start: 900
                                end: 900
                        MODE_RANGES.push modeRange
                        modeRangeExtra = 
                            id: modeId
                            modeLogic: parseInt($(this).find('.logic').val())
                            linkedTo: linkedToSelection
                        MODE_RANGES_EXTRA.push modeRangeExtra
                    return
                return
            modeRangeIndex = MODE_RANGES.length
            while modeRangeIndex < requiredModesRangeCount
                defaultModeRange = 
                    id: 0
                    auxChannelIndex: 0
                    range:
                        start: 900
                        end: 900
                MODE_RANGES.push defaultModeRange
                defaultModeRangeExtra = 
                    id: 0
                    modeLogic: 0
                    linkedTo: 0
                MODE_RANGES_EXTRA.push defaultModeRangeExtra
                modeRangeIndex++
            #
            # send data to FC
            #
            mspHelper.sendModeRanges save_to_eeprom
            return
        hideUnusedModes = false
        ConfigStorage.get 'hideUnusedModes', (result) ->
            $('input#switch-toggle-unused').change(->
                hideUnusedModes = $(this).prop('checked')
                ConfigStorage.set hideUnusedModes: hideUnusedModes
                update_ui()
                return
            ).prop('checked', ! !result.hideUnusedModes).change()
            return
        # update ui instantly on first load
        update_ui()
        # enable data pulling
        GUI.interval_add 'aux_data_pull', get_rc_data, 50
        # status data pulled via separate timer with static speed
        GUI.interval_add 'status_pull', (->
            MSP.send_message MSPCodes.MSP_STATUS
            return
        ), 250, true
        GUI.content_ready callback
        return

    GUI.active_tab_ref = this
    GUI.active_tab = 'auxiliary'
    prevChannelsValues = null
    MSP.send_message MSPCodes.MSP_BOXNAMES, false, false, get_mode_ranges
    return

TABS.auxiliary.cleanup = (callback) ->
    if callback
        callback()
    return

