transmitChannels = ->
    channelValues = [
        0
        0
        0
        0
        0
        0
        0
        0
    ]
    if !enableTX
        return
    for stickName of stickValues
        channelValues[channelMSPIndexes[stickName]] = stickValues[stickName]
    # Callback given to us by the window creator so we can have it send data over MSP for us:
    if !window.setRawRx(channelValues)
        # MSP connection has gone away
        chrome.app.window.current().close()
    return

stickPortionToChannelValue = (portion) ->
    portion = Math.min(Math.max(portion, 0.0), 1.0)
    Math.round portion * (CHANNEL_MAX_VALUE - CHANNEL_MIN_VALUE) + CHANNEL_MIN_VALUE

channelValueToStickPortion = (channel) ->
    (channel - CHANNEL_MIN_VALUE) / (CHANNEL_MAX_VALUE - CHANNEL_MIN_VALUE)

updateControlPositions = ->
    for stickName of stickValues
        stickValue = stickValues[stickName]
        # Look for the gimbal which corresponds to this stick name
        for gimbalIndex of gimbals
            gimbal = gimbals[gimbalIndex]
            gimbalElem = gimbalElems.get(gimbalIndex)
            gimbalSize = $(gimbalElem).width()
            stickElem = $('.control-stick', gimbalElem)
            if gimbal[0] == stickName
                stickElem.css 'top', (1.0 - channelValueToStickPortion(stickValue)) * gimbalSize + 'px'
                break
            else if gimbal[1] == stickName
                stickElem.css 'left', channelValueToStickPortion(stickValue) * gimbalSize + 'px'
                break
    return

handleGimbalMouseDrag = (e) ->
    gimbal = $(gimbalElems.get(e.data.gimbalIndex))
    gimbalOffset = gimbal.offset()
    gimbalSize = gimbal.width()
    stickValues[gimbals[e.data.gimbalIndex][0]] = stickPortionToChannelValue(1.0 - ((e.pageY - (gimbalOffset.top)) / gimbalSize))
    stickValues[gimbals[e.data.gimbalIndex][1]] = stickPortionToChannelValue((e.pageX - (gimbalOffset.left)) / gimbalSize)
    updateControlPositions()
    return

localizeAxisNames = ->
    for gimbalIndex of gimbals
        gimbal = gimbalElems.get(gimbalIndex)
        $('.gimbal-label-vert', gimbal).text i18n.getMessage('controlAxis' + gimbals[gimbalIndex][0])
        $('.gimbal-label-horz', gimbal).text i18n.getMessage('controlAxis' + gimbals[gimbalIndex][1])
    sliderIndex = 0
    while sliderIndex < 4
        $('.slider-label', sliderElems.get(sliderIndex)).text i18n.getMessage('controlAxisAux' + sliderIndex + 1)
        sliderIndex++
    return

'use strict'
CHANNEL_MIN_VALUE = 1000
CHANNEL_MID_VALUE = 1500
CHANNEL_MAX_VALUE = 2000
channelMSPIndexes = 
    Roll: 0
    Pitch: 1
    Throttle: 2
    Yaw: 3
    Aux1: 4
    Aux2: 5
    Aux3: 6
    Aux4: 7
stickValues = 
    Throttle: CHANNEL_MIN_VALUE
    Pitch: CHANNEL_MID_VALUE
    Roll: CHANNEL_MID_VALUE
    Yaw: CHANNEL_MID_VALUE
    Aux1: CHANNEL_MIN_VALUE
    Aux2: CHANNEL_MIN_VALUE
    Aux3: CHANNEL_MIN_VALUE
    Aux4: CHANNEL_MIN_VALUE
gimbals = [
    [
        'Throttle'
        'Yaw'
    ]
    [
        'Pitch'
        'Roll'
    ]
]
gimbalElems = undefined
sliderElems = undefined
enableTX = false
# This is a hack to get the i18n var of the parent, but the localizePage not works
i18n = opener.i18n
$(document).ready ->
    $('[i18n]:not(.i18n-replaced)').each ->
        element = $(this)
        element.html i18n.getMessage(element.attr('i18n'))
        element.addClass 'i18n-replaced'
        return
    return
$(document).ready ->
    $('.button-enable .btn').click ->
        shrinkHeight = $('.warning').height()
        $('.warning').slideUp 'short', ->
            chrome.app.window.current().innerBounds.minHeight -= shrinkHeight
            chrome.app.window.current().innerBounds.height -= shrinkHeight
            chrome.app.window.current().innerBounds.maxHeight -= shrinkHeight
            return
        enableTX = true
        return
    gimbalElems = $('.control-gimbal')
    sliderElems = $('.control-slider')
    gimbalElems.each (gimbalIndex) ->
        $(this).on 'mousedown', { gimbalIndex: gimbalIndex }, (e) ->
            if e.which == 1
                # Only move sticks on left mouse button
                handleGimbalMouseDrag e
                $(window).on 'mousemove', { gimbalIndex: gimbalIndex }, handleGimbalMouseDrag
            return
        return
    $('.slider', sliderElems).each (sliderIndex) ->
        initialValue = stickValues['Aux' + sliderIndex + 1]
        $(this).noUiSlider(
            start: initialValue
            range:
                min: CHANNEL_MIN_VALUE
                max: CHANNEL_MAX_VALUE).on 'slide change set', (e, value) ->
            value = Math.round(parseFloat(value))
            stickValues['Aux' + sliderIndex + 1] = value
            $('.tooltip', this).text value
            return
        $(this).append '<div class="tooltip"></div>'
        $('.tooltip', this).text initialValue
        return

    ###
    # Mouseup handler needs to be bound to the window in order to receive mouseup if mouse leaves window.
    ###

    $(window).mouseup (e) ->
        $(this).off 'mousemove', handleGimbalMouseDrag
        return
    localizeAxisNames()
    updateControlPositions()
    setInterval transmitChannels, 50
    return

