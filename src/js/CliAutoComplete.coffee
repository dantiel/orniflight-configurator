'use strict'

###*
# Encapsulates the AutoComplete logic
#
# Uses: https://github.com/yuku/jquery-textcomplete
# Check out the docs at https://github.com/yuku/jquery-textcomplete/tree/v1/doc
###

CliAutoComplete = 
    configEnabled: false
    builder:
        state: 'reset'
        numFails: 0

CliAutoComplete.isEnabled = ->
    @isBuilding() or @configEnabled and CONFIG.flightControllerIdentifier == 'ORNI' and @builder.state != 'fail'

CliAutoComplete.isBuilding = ->
    @builder.state != 'reset' and @builder.state != 'done' and @builder.state != 'fail'

CliAutoComplete.isOpen = ->
    $('.cli-textcomplete-dropdown').is ':visible'

###*
# @param {boolean} force - Forces AutoComplete to be shown even if the matching strategy has less that minChars input
###

CliAutoComplete.openLater = (force) ->
    self = this
    setTimeout (->
        self.forceOpen = ! !force
        self.$textarea.textcomplete 'trigger'
        self.forceOpen = false
        return
    ), 0
    return

CliAutoComplete.setEnabled = (enable) ->
    if @configEnabled != enable
        @configEnabled = enable
        if CONFIGURATOR.cliActive and CONFIGURATOR.cliValid
            # cli is already open
            if @isEnabled()
                @builderStart()
            else if !@isEnabled() and !@isBuilding()
                @cleanup()
    return

CliAutoComplete.initialize = ($textarea, sendLine, writeToOutput) ->
    analytics.sendEvent analytics.EVENT_CATEGORIES.APPLICATION, 'CliAutoComplete', @configEnabled
    @$textarea = $textarea
    @forceOpen = false
    @sendLine = sendLine
    @writeToOutput = writeToOutput
    @cleanup()
    return

CliAutoComplete.cleanup = ->
    @$textarea.textcomplete 'destroy'
    @builder.state = 'reset'
    @builder.numFails = 0
    return

CliAutoComplete._builderWatchdogTouch = ->
    self = this
    @_builderWatchdogStop()
    GUI.timeout_add 'autocomplete_builder_watchdog', (->
        if self.builder.numFails++
            self.builder.state = 'fail'
            self.writeToOutput 'Failed!<br># '
            $(self).trigger 'build:stop'
        else
            # give it one more try
            self.builder.state = 'reset'
            self.builderStart()
        return
    ), 3000
    return

CliAutoComplete._builderWatchdogStop = ->
    GUI.timeout_remove 'autocomplete_builder_watchdog'
    return

CliAutoComplete.builderStart = ->
    if @builder.state == 'reset'
        @cache =
            commands: []
            resources: []
            resourcesCount: {}
            settings: []
            settingsAcceptedValues: {}
            feature: []
            beeper: [ 'ALL' ]
            mixers: []
        @builder.commandSequence = [
            'help'
            'dump'
            'get'
            'mixer list'
        ]
        @builder.currentSetting = null
        @builder.sentinel = '# ' + Math.random()
        @builder.state = 'init'
        @writeToOutput '<br># Building AutoComplete Cache ... '
        @sendLine @builder.sentinel
        $(this).trigger 'build:start'
    return

CliAutoComplete.builderParseLine = (line) ->
    cache = @cache
    builder = @builder
    m = undefined
    @_builderWatchdogTouch()
    if line.indexOf(builder.sentinel) != -1
        # got sentinel
        command = builder.commandSequence.shift()
        if command and @configEnabled
            # next state
            builder.state = 'parse-' + command
            @sendLine command
            @sendLine builder.sentinel
        else
            # done
            @_builderWatchdogStop()
            if !@configEnabled
                # disabled while we were building
                @writeToOutput 'Cancelled!<br># '
                @cleanup()
            else
                cache.settings.sort()
                cache.commands.sort()
                cache.feature.sort()
                cache.beeper.sort()
                cache.resources = Object.keys(cache.resourcesCount).sort()
                @_initTextcomplete()
                @writeToOutput 'Done!<br># '
                builder.state = 'done'
            $(this).trigger 'build:stop'
    else
        switch builder.state
            when 'parse-help'
                if m = line.match(/^(\w+)/)
                    cache.commands.push m[1]
            when 'parse-dump'
                if m = line.match(/^resource\s+(\w+)/i)
                    r = m[1].toUpperCase()
                    # should alread be upper, but to be sure, since we depend on that later
                    cache.resourcesCount[r] = (cache.resourcesCount[r] or 0) + 1
                else if m = line.match(/^(feature|beeper)\s+-?(\w+)/i)
                    cache[m[1].toLowerCase()].push m[2]
            when 'parse-get'
                if m = line.match(/^(\w+)\s*=/)
                    # setting name
                    cache.settings.push m[1]
                    builder.currentSetting = m[1].toLowerCase()
                else if builder.currentSetting and (m = line.match(/^(.*): (.*)/))
                    if m[1].match(/values/i)
                        # Allowed Values
                        cache.settingsAcceptedValues[builder.currentSetting] = m[2].split(/\s*,\s*/).sort()
                    else if m[1].match(/range|length/i)
                        # "Allowed range" or "Array length", store as string hint
                        cache.settingsAcceptedValues[builder.currentSetting] = m[0]
            when 'parse-mixer list'
                if m = line.match(/:(.+)/)
                    cache.mixers = [ 'list' ].concat(m[1].trim().split(/\s+/))
    return

###*
# Initializes textcomplete with all the autocomplete strategies
###

CliAutoComplete._initTextcomplete = ->
    sendOnEnter = false
    self = this
    $textarea = @$textarea
    cache = self.cache
    savedMouseoverItemHandler = null
    # helper functions

    highlighter = (anywhere) ->
        (value, term) ->
            if term then value.replace(new RegExp((if anywhere then '' else '^') + '(' + term + ')', 'gi'), '<b>$1</b>') else value

    highlighterAnywhere = highlighter(true)
    highlighterPrefix = highlighter(false)

    searcher = (term, callback, array, minChars, matchPrefix) ->
        res = []
        if minChars != false and term.length >= minChars or self.forceOpen or self.isOpen()
            term = term.toLowerCase()
            i = 0
            while i < array.length
                v = array[i].toLowerCase()
                if matchPrefix and v.startsWith(term) or !matchPrefix and v.indexOf(term) != -1
                    res.push array[i]
                i++
        callback res
        if self.forceOpen and res.length == 1
            # hacky: if we came here because of Tab and there's only one match
            # trigger Tab again, so that textcomplete should immediately select the only result
            # instead of showing the menu
            $textarea.trigger $.Event('keydown', keyCode: 9)
        return

    contexter = (text) ->
        val = $textarea.val()
        if val.length == text.length or val[text.length].match(/\s/)
            return true
        false
        # do not show autocomplete if in the middle of a word

    basicReplacer = (value) ->
        '$1' + value + ' '

    # end helper functions
    # init textcomplete
    $textarea.textcomplete([],
        maxCount: 10000
        debounce: 0
        className: 'cli-textcomplete-dropdown'
        placement: 'top'
        onKeydown: (e) ->
            # some strategies may set sendOnEnter only at the replace stage, thus we call with timeout
            # since this handler [onKeydown] is triggered before replace()
            if e.which == 13
                setTimeout (->
                    if sendOnEnter
                        # fake "enter" to run the textarea's handler
                        $textarea.trigger $.Event('keypress', which: 13)
                    return
                ), 0
            return
    ).on 'textComplete:show', (e) ->

        ###*
        # The purpose of this code is to disable initially the `mouseover` menu item handler.
        # Normally, when the menu pops up, if the mouse cursor is in the same area,
        # the `mouseover` event triggers immediately and activates the item under
        # the cursor. This might be undesirable when using the keyboard.
        #
        # Here we save the original `mouseover` handler and remove it on popup show.
        # Then add `mousemove` handler. If the mouse moves we consider that mouse interaction
        # is desired so we reenable the `mouseover` handler
        ###

        if !savedMouseoverItemHandler
            # save the original 'mouseover' handeler
            savedMouseoverItemHandler = $._data($('.textcomplete-dropdown')[0], 'events').mouseover[0].handler
        $('.textcomplete-dropdown').off('mouseover').off('mousemove').on 'mousemove', '.textcomplete-item', (e) ->
            # the mouse has moved so reenable `mouseover`
            $(this).parent().off('mousemove').on 'mouseover', '.textcomplete-item', savedMouseoverItemHandler
            # trigger the mouseover handler to select the item under the cursor
            savedMouseoverItemHandler e
            return
        return
    # textcomplete autocomplete strategies
    # strategy builder helper

    strategy = (s) ->
        $.extend {
            template: highlighterAnywhere
            replace: basicReplacer
            context: contexter
            index: 2
        }, s

    $textarea.textcomplete 'register', [
        strategy(
            match: /^(\s*)(\w*)$/
            search: (term, callback) ->
                sendOnEnter = false
                searcher term, callback, cache.commands, false, true
                return
            template: highlighterPrefix)
        strategy(
            match: /^(\s*get\s+)(\w*)$/i
            search: (term, callback) ->
                sendOnEnter = true
                searcher term, ((arr) ->
                    if term.length > 0 and arr.length > 1
                        # prepend the uncompleted term in the popup
                        arr = [ term ].concat(arr)
                    callback arr
                    return
                ), cache.settings, 3
                return
        )
        strategy(
            match: /^(\s*set\s+)(\w*)$/i
            search: (term, callback) ->
                sendOnEnter = false
                searcher term, callback, cache.settings, 3
                return
        )
        strategy(
            match: /^(\s*set\s+\w*\s*)$/i
            search: (term, callback) ->
                sendOnEnter = false
                searcher '', callback, [ '=' ], false
                return
            replace: (value) ->
                self.openLater()
                basicReplacer value
        )
        strategy(
            match: /^(\s*set\s+(\w+))\s*=\s*(.*)$/i
            search: (term, callback, match) ->
                arr = []
                settingName = match[2].toLowerCase()
                @isSettingValueArray = false
                @value = match[3]
                sendOnEnter = ! !term
                if settingName of cache.settingsAcceptedValues
                    val = cache.settingsAcceptedValues[settingName]
                    if Array.isArray(val)
                        # setting uses lookup strings
                        @isSettingValueArray = true
                        sendOnEnter = true
                        searcher term, callback, val, 0
                        return
                    # the settings uses a numeric value.
                    # Here we use a little trick - we use the autocomplete
                    # list as kind of a tooltip to display the Accepted Range hint
                    arr.push val
                callback arr
                return
            replace: (value) ->
                if !@isSettingValueArray
                    # `value` is the tooltip text, so use the saved match
                    value = @value
                '$1 = ' + value
                # cosmetic - make sure we have spaces around the `=`
            index: 3
            isSettingValueArray: false)
        strategy(
            match: /^(\s*resource\s+)(\w*)$/i
            search: (term, callback, match) ->
                sendOnEnter = false
                arr = cache.resources
                if semver.gte(CONFIG.flightControllerVersion, '4.0.0')
                    arr = [ 'show' ].concat(arr)
                else
                    arr = [ 'list' ].concat(arr)
                searcher term, callback, arr, 1
                return
            replace: (value) ->
                if value of cache.resourcesCount
                    self.openLater()
                else if value == 'list' or value == 'show'
                    sendOnEnter = true
                basicReplacer value
        )
        strategy(
            match: /^(\s*resource\s+(\w+)\s+)(\d*)$/i
            search: (term, callback, match) ->
                sendOnEnter = false
                @savedTerm = term
                callback [ '&lt;1-' + cache.resourcesCount[match[2].toUpperCase()] + '&gt;' ]
                return
            replace: (value) ->
                if @savedTerm
                    self.openLater()
                    return '$1$3 '
                return
            context: (text) ->
                m = undefined
                # use this strategy only for resources with more than one index
                if (m = text.match(/^\s*resource\s+(\w+)\s/i)) and (cache.resourcesCount[m[1].toUpperCase()] or 0) > 1
                    return contexter(text)
                false
            index: 3
            savedTerm: null)
        strategy(
            match: /^(\s*resource\s+\w+\s+(\d*\s+)?)(\w*)$/i
            search: (term, callback, match) ->
                sendOnEnter = ! !term
                if term
                    if 'none'.startsWith(term)
                        callback [ 'none' ]
                    else
                        callback [ '&lt;pin&gt;' ]
                else
                    callback [
                        '&lt;pin&gt'
                        'none'
                    ]
                return
            template: (value, term) ->
                if value == 'none'
                    return highlighterPrefix(value, term)
                value
            replace: (value) ->
                if value == 'none'
                    sendOnEnter = true
                    return '$1none '
                return
            context: (text) ->
                m = text.match(/^\s*resource\s+(\w+)\s+(\d+\s)?/i)
                if m
                    # show pin/none for resources having only one index (it's not needed at the commend line)
                    # OR having more than one index and the index is supplied at the command line
                    count = cache.resourcesCount[m[1].toUpperCase()] or 0
                    if count and (m[2] or count == 1)
                        return contexter(text)
                false
            index: 3)
        strategy(
            match: /^(\s*(feature|beeper)\s+(-?))(\w*)$/i
            search: (term, callback, match) ->
                sendOnEnter = ! !term
                arr = cache[match[2].toLowerCase()]
                if !match[3]
                    arr = [
                        '-'
                        'list'
                    ].concat(arr)
                searcher term, callback, arr, 1
                return
            replace: (value) ->
                if value == '-'
                    self.openLater true
                    return '$1-'
                basicReplacer value
            index: 4)
        strategy(
            match: /^(\s*mixer\s+)(\w*)$/i
            search: (term, callback, match) ->
                sendOnEnter = true
                searcher term, callback, cache.mixers, 1
                return
        )
    ]
    if semver.gte(CONFIG.flightControllerVersion, '4.0.0')
        $textarea.textcomplete 'register', [ strategy(
            match: /^(\s*resource\s+show\s+)(\w*)$/i
            search: (term, callback, matches) ->
                sendOnEnter = true
                searcher term, callback, [ 'all' ], 1, true
                return
            template: highlighterPrefix) ]
    return

