'use strict'

###*
# Encapsulates the Clipboard logic, depending on web or nw
#
###

Clipboard = 
    _nwClipboard: null
    available: null
    readAvailable: null
    writeAvailable: null
    writeText: null
    readText: null

Clipboard._configureClipboardAsNwJs = (nwGui) ->
    console.log 'NW GUI Clipboard available'
    @available = true
    @readAvailable = true
    @writeAvailable = true
    @_nwClipboard = nwGui.Clipboard.get()

    @writeText = (text, onSuccess, onError) ->
        try
            @_nwClipboard.set text, 'text'
        catch err
            if onError
                onError err
        if onSuccess
            onSuccess text
        return

    @readText = (onSuccess, onError) ->
        text = ''
        try
            text = @_nwClipboard.get('text')
        catch err
            if onError
                onError err
        if onSuccess
            onSuccess text
        return

    return

Clipboard._configureClipboardAsChrome = ->
    console.log 'Chrome Clipboard available'
    @available = true
    @readAvailable = false
    # FIXME: for some reason the read is not working
    @writeAvailable = true

    @writeText = (text, onSuccess, onError) ->
        navigator.clipboard.writeText(text).then(onSuccess).catch onError
        return

    @readText = (onSuccess, onError) ->
        navigator.clipboard.readText().then(onSuccess).catch onError
        return

    return

Clipboard._configureClipboardAsOther = ->
    console.warn 'NO Clipboard available'
    @available = false
    @readAvailable = false
    @writeAvailable = false

    @writeText = (text, onSuccess, onError) ->
        onError 'Clipboard not available'
        return

    @readText = (onSuccess, onError) ->
        onError 'Clipboard not available'
        return

    return

switch GUI.Mode
    when GUI_Modes.NWJS
        Clipboard._configureClipboardAsNwJs GUI.nwGui
    when GUI_Modes.ChromeApp
        Clipboard._configureClipboardAsChrome()
    else
        Clipboard._configureClipboardAsOther()

