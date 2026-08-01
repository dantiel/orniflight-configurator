'use strict'
TABS.led_strip =
    wireMode: false
    directions: [
        'n'
        'e'
        's'
        'w'
        'u'
        'd'
    ]

TABS.led_strip.initialize = (callback, scrollPosition) ->
    self = this
    selectedColorIndex = null
    selectedModeColor = null

    load_led_config = ->
        MSP.send_message MSPCodes.MSP_LED_STRIP_CONFIG, false, false, load_led_colors
        return

    load_led_colors = ->
        MSP.send_message MSPCodes.MSP_LED_COLORS, false, false, load_led_mode_colors
        return

    load_led_mode_colors = ->
        if semver.gte(CONFIG.apiVersion, '1.19.0')
            MSP.send_message MSPCodes.MSP_LED_STRIP_MODECOLOR, false, false, load_html
        else
            load_html()
        return

    load_html = ->
        $('#content').load './tabs/led_strip.html', process_html
        return

    buildUsedWireNumbers = ->
        usedWireNumbers = []
        $('.mainGrid .gPoint .wire').each ->
            wireNumber = parseInt($(this).html())
            if wireNumber >= 0
                usedWireNumbers.push wireNumber
            return
        usedWireNumbers.sort (a, b) ->
            a - b
        usedWireNumbers

    process_html = ->
        `var i`

        removeFunctionsAndDirections = (element) ->
            classesToRemove = []
            TABS.led_strip.baseFuncs.forEach (letter) ->
                classesToRemove.push 'function-' + letter
                return
            TABS.led_strip.overlays.forEach (letter) ->
                classesToRemove.push 'function-' + letter
                return
            TABS.led_strip.directions.forEach (letter) ->
                classesToRemove.push 'dir-' + letter
                return
            $(element).removeClass classesToRemove.join(' ')
            return

        toggleSwitch = (that, letter) ->
            if $(that).is(':checked')
                $('.ui-selected').find('.wire').each ->
                    if $(this).text() != ''
                        p = $(this).parent()
                        TABS.led_strip.functions.forEach (f) ->
                            if p.is('.function-' + f)
                                switch letter
                                    when 't', 'o', 's'
                                        if areModifiersActive('function-' + f)
                                            p.addClass 'function-' + letter
                                    when 'b', 'n'
                                        if areBlinkersActive('function-' + f)
                                            p.addClass 'function-' + letter
                                    when 'i'
                                        if areOverlaysActive('function-' + f)
                                            p.addClass 'function-' + letter
                                    when 'w'
                                        if areOverlaysActive('function-' + f)
                                            if isWarningActive('function-' + f)
                                                p.addClass 'function-' + letter
                                    when 'v'
                                        if areOverlaysActive('function-' + f)
                                            if isVtxActive('function-' + f)
                                                p.addClass 'function-' + letter
                            return
                    return
            else
                $('.ui-selected').removeClass 'function-' + letter
            $(that).is ':checked'

        i18n.localizePage()
        # Build Grid
        theHTML = []
        theHTMLlength = 0
        i = 0
        while i < 256
            if semver.lte(CONFIG.apiVersion, '1.19.0')
                theHTML[theHTMLlength++] = '<div class="gPoint"><div class="indicators"><span class="north"></span><span class="south"></span><span class="west"></span><span class="east"></span><span class="up">U</span><span class="down">D</span></div><span class="wire"></span><span class="overlay-t"> </span><span class="overlay-s"> </span><span class="overlay-w"> </span><span class="overlay-i"> </span><span class="overlay-color"> </span></div>'
            else if semver.lt(CONFIG.apiVersion, '1.36.0')
                theHTML[theHTMLlength++] = '<div class="gPoint"><div class="indicators"><span class="north"></span><span class="south"></span><span class="west"></span><span class="east"></span><span class="up">U</span><span class="down">D</span></div><span class="wire"></span><span class="overlay-t"> </span><span class="overlay-o"> </span><span class="overlay-b"> </span><span class="overlay-n"> </span><span class="overlay-i"> </span><span class="overlay-w"> </span><span class="overlay-color"> </span></div>'
            else
                theHTML[theHTMLlength++] = '<div class="gPoint"><div class="indicators"><span class="north"></span><span class="south"></span><span class="west"></span><span class="east"></span><span class="up">U</span><span class="down">D</span></div><span class="wire"></span><span class="overlay-t"> </span><span class="overlay-o"> </span><span class="overlay-b"> </span><span class="overlay-v"> </span><span class="overlay-i"> </span><span class="overlay-w"> </span><span class="overlay-color"> </span></div>'
            i++
        $('.mainGrid').html theHTML.join('')
        $('.tempOutput').click ->
            $(this).select()
            return
        # Aux channel drop-down
        if semver.lte(CONFIG.apiVersion, '1.20.0')
            $('.auxSelect').hide()
            $('.labelSelect').show()
        else
            $('.auxSelect').show()
            $('.labelSelect').hide()
            AuxMode = 7
            AuxDir = 0
            $('.auxSelect').val getModeColor(AuxMode, AuxDir)
            $('.auxSelect').on 'change', ->
                setModeColor AuxMode, AuxDir, $('.auxSelect').val()
                return
        if semver.lt(CONFIG.apiVersion, '1.36.0')
            $('.vtxOverlay').hide()
            $('.landingBlinkOverlay').show()
        else
            $('.landingBlinkOverlay').css 'visibility', 'hidden'
            $('.vtxOverlay').show()
        # Clear button
        $('.funcClear').click ->
            $('.gPoint').each ->
                if $(this).is('.ui-selected')
                    removeFunctionsAndDirections this
                    $(this).find('.wire').html ''
                return
            $('.controls button').removeClass 'btnOn'
            updateBulkCmd()
            return
        # Clear All button
        $('.funcClearAll').click ->
            $('.gPoint').each ->
                removeFunctionsAndDirections this
                return
            $('.gPoint .wire').html ''
            updateBulkCmd()
            $('.controls button').removeClass 'btnOn'
            return
        # Directional Buttons
        $('.directions').on 'click', 'button', ->
            that = this
            if $('.ui-selected').length > 0
                TABS.led_strip.directions.forEach (letter) ->
                    if $(that).is('.dir-' + letter)
                        if $(that).is('.btnOn')
                            $(that).removeClass 'btnOn'
                            $('.ui-selected').removeClass 'dir-' + letter
                        else
                            $(that).addClass 'btnOn'
                            $('.ui-selected').addClass 'dir-' + letter
                    return
                clearModeColorSelection()
                updateBulkCmd()
            return
        # Mode Color Buttons
        $('.mode_colors').on 'click', 'button', ->
            that = this
            LED_MODE_COLORS.forEach (mc) ->
                if $(that).is('.mode_color-' + mc.mode + '-' + mc.direction)
                    if $(that).is('.btnOn')
                        $(that).removeClass 'btnOn'
                        $('.ui-selected').removeClass 'mode_color-' + mc.mode + '-' + mc.direction
                        selectedModeColor = null
                    else
                        $(that).addClass 'btnOn'
                        selectedModeColor =
                            mode: mc.mode
                            direction: mc.direction
                        # select the color button
                        colorIndex = 0
                        while colorIndex < 16
                            className = '.color-' + colorIndex
                            if colorIndex == getModeColor(mc.mode, mc.direction)
                                $(className).addClass 'btnOn'
                                selectedColorIndex = colorIndex
                                setColorSliders colorIndex
                            else
                                $(className).removeClass 'btnOn'
                            colorIndex++
                return
            $('.mode_colors').each ->
                $(this).children().each ->
                    if !$(this).is($(that))
                        if $(this).is('.btnOn')
                            $(this).removeClass 'btnOn'
                    return
                return
            updateBulkCmd()
            return
        # Color sliders
        ip = $('div.colorDefineSliders input')
        ip.eq(0).on 'input change', ->
            updateColors $(this).val(), 0
            return
        ip.eq(1).on 'input change', ->
            updateColors $(this).val(), 1
            return
        ip.eq(2).on 'input change', ->
            updateColors $(this).val(), 2
            return
        i = 0
        while i < 3
            updateColors ip.eq(i).val(), i
            i++
        # Color Buttons
        $('.colors').on 'click', 'button', (e) ->
            that = this
            colorButtons = $(this).parent().find('button')
            colorIndex = 0
            while colorIndex < 16
                colorButtons.removeClass 'btnOn'
                if selectedModeColor == undefined
                    $('.ui-selected').removeClass 'color-' + colorIndex
                if $(that).is('.color-' + colorIndex)
                    selectedColorIndex = colorIndex
                    if selectedModeColor == undefined
                        $('.ui-selected').addClass 'color-' + colorIndex
                colorIndex++
            setColorSliders selectedColorIndex
            $(this).addClass 'btnOn'
            if selectedModeColor
                setModeColor selectedModeColor.mode, selectedModeColor.direction, selectedColorIndex
            drawColorBoxesInColorLedPoints()
            # refresh color buttons
            $('.colors').children().each ->
                setBackgroundColor $(this)
                return
            $('.overlay-color').each ->
                setBackgroundColor $(this)
                return
            $('.mode_colors').each ->
                setModeBackgroundColor $(this)
                return
            $('.special_colors').each ->
                setModeBackgroundColor $(this)
                return
            updateBulkCmd()
            return
        $('.colors').on 'dblclick', 'button', ->
            $('.colorDefineSliders').css 'left', $(this).position().left - ($('.colorDefineSliders').width() / 2) + $(this).width()
            $('.colorDefineSliders').css 'top', $(this).position().top + 26
            $('.colorDefineSliders').show()
            return
        $('.colors').children().on mouseleave: ->
            if !$('.colorDefineSliders').is(':hover')
                $('.colorDefineSliders').hide()
            return
        $('.funcWire').click ->
            $(this).toggleClass 'btnOn'
            TABS.led_strip.wireMode = $(this).hasClass('btnOn')
            $('.mainGrid').toggleClass 'gridWire'
            return
        $('.funcWireClearSelect').click ->
            $('.ui-selected').each ->
                thisWire = $(this).find('.wire')
                if thisWire.html() != ''
                    thisWire.html ''
                updateBulkCmd()
                return
            return
        $('.funcWireClear').click ->
            $('.gPoint .wire').html ''
            updateBulkCmd()
            return
        $('.mainGrid').selectable
            filter: ' > div'
            stop: ->
                functionsInSelection = []
                directionsInSelection = []
                clearModeColorSelection()
                that = undefined
                $('.ui-selected').each ->
                    `var nextWireNumber`
                    usedWireNumbers = buildUsedWireNumbers()
                    nextWireNumber = 0
                    nextWireNumber = 0
                    while nextWireNumber < usedWireNumbers.length
                        if usedWireNumbers[nextWireNumber] != nextWireNumber
                            break
                        nextWireNumber++
                    if TABS.led_strip.wireMode
                        if $(this).find('.wire').html() == '' and nextWireNumber < LED_STRIP.length
                            $(this).find('.wire').html nextWireNumber
                    if $(this).find('.wire').text() != ''
                        that = this
                        # Get function & overlays or current cell
                        TABS.led_strip.directions.forEach (letter) ->
                            className = '.dir-' + letter
                            if $(that).is(className)
                                directionsInSelection.push className
                            return
                        TABS.led_strip.baseFuncs.forEach (letter) ->
                            className = '.function-' + letter
                            if $(that).is(className)
                                functionsInSelection.push className
                            return
                        TABS.led_strip.overlays.forEach (letter) ->
                            className = '.function-' + letter
                            if $(that).is(className)
                                functionsInSelection.push className
                            return
                    return
                uiSelectedLast = that
                $('select.functionSelect').val ''
                TABS.led_strip.baseFuncs.forEach (letter) ->
                    className = 'function-' + letter
                    if $('select.functionSelect').is('.' + className)
                        $('select.functionSelect').removeClass className
                    return
                selectedColorIndex = 0
                if uiSelectedLast
                    # set active color
                    colorIndex = 0
                    while colorIndex < 16
                        className = '.color-' + colorIndex
                        if $(uiSelectedLast).is(className)
                            $(className).addClass 'btnOn'
                            selectedColorIndex = colorIndex
                        else
                            $(className).removeClass 'btnOn'
                        colorIndex++
                    # set checkbox values
                    TABS.led_strip.overlays.forEach (letter) ->
                        feature_o = $('.checkbox').find('input.function-' + letter)
                        newVal = $(uiSelectedLast).is('.function-' + letter)
                        if feature_o.is(':checked') != newVal
                            feature_o.prop 'checked', newVal
                            feature_o.change()
                        return
                    # Update active function in combobox
                    TABS.led_strip.baseFuncs.forEach (letter) ->
                        if $(uiSelectedLast).is('.function-' + letter)
                            $('select.functionSelect').val 'function-' + letter
                            $('select.functionSelect').addClass 'function-' + letter
                        return
                updateBulkCmd()
                setColorSliders selectedColorIndex
                setOptionalGroupsVisibility()
                $('.directions button').removeClass 'btnOn'
                directionsInSelection.forEach (direction_e) ->
                    $(direction_e).addClass 'btnOn'
                    return
                return
        # UI: select LED function from drop-down
        $('.functionSelect').on 'change', ->
            clearModeColorSelection()
            applyFunctionToSelectedLeds()
            drawColorBoxesInColorLedPoints()
            setOptionalGroupsVisibility()
            updateBulkCmd()
            return
        # UI: select mode from drop-down
        $('.modeSelect').on 'change', ->
            that = this
            mode = Number($(that).val())
            $('.mode_colors').find('button').each ->
                `var i`
                i = 0
                while i < 6
                    j = 0
                    while j < 6
                        if $(this).hasClass('mode_color-' + i + '-' + j)
                            $(this).removeClass 'mode_color-' + i + '-' + j
                            $(this).addClass 'mode_color-' + mode + '-' + j
                        j++
                    i++
                return
            $('.mode_colors').each ->
                setModeBackgroundColor $(this)
                return
            return
        # UI: check-box toggle
        $('.checkbox').change (e) ->
            if e.originalEvent
                # user-triggered event
                that = $(this).find('input')
                if $('.ui-selected').length > 0
                    TABS.led_strip.overlays.forEach (letter) ->
                        if $(that).is('.function-' + letter)
                            ret = toggleSwitch(that, letter)
                            cbn = $('.checkbox .function-n')
                            # blink on landing
                            cbb = $('.checkbox .function-b')
                            # blink
                            if ret
                                if letter == 'b' and cbn.is(':checked')
                                    cbn.prop 'checked', false
                                    cbn.change()
                                    toggleSwitch cbn, 'n'
                                else if letter == 'n' and cbb.is(':checked')
                                    cbb.prop 'checked', false
                                    cbb.change()
                                    toggleSwitch cbb, 'b'
                        return
                    clearModeColorSelection()
                    updateBulkCmd()
                    setOptionalGroupsVisibility()
            else
                # code-triggered event
            return
        $('.mainGrid').disableSelection()
        $('.gPoint').each ->
            gridNumber = $(this).index() + 1
            row = Math.ceil(gridNumber / 16) - 1
            col = gridNumber / 16 % 1 * 16 - 1
            if col < 0
                col = 15
            ledResult = findLed(col, row)
            if !ledResult
                return
            ledIndex = ledResult.index
            led = ledResult.led
            if led.functions[0] == 'c' and led.functions.length == 1 and led.directions.length == 0 and led.color == 0 and led.x == 0 and led.y == 0
                return
            $(this).find('.wire').html ledIndex
            modeIndex = 0
            while modeIndex < led.functions.length
                $(this).addClass 'function-' + led.functions[modeIndex]
                modeIndex++
            directionIndex = 0
            while directionIndex < led.directions.length
                $(this).addClass 'dir-' + led.directions[directionIndex]
                directionIndex++
            $(this).addClass 'color-' + led.color
            return
        $('a.save').click ->

            send_led_strip_colors = ->
                mspHelper.sendLedStripColors send_led_strip_mode_colors
                return

            send_led_strip_mode_colors = ->
                if semver.gte(CONFIG.apiVersion, '1.19.0')
                    mspHelper.sendLedStripModeColors save_to_eeprom
                else
                    save_to_eeprom()
                return

            save_to_eeprom = ->
                MSP.send_message MSPCodes.MSP_EEPROM_WRITE, false, false, ->
                    GUI.log i18n.getMessage('ledStripEepromSaved')
                    return
                return

            mspHelper.sendLedStripConfig send_led_strip_colors
            return
        $('.colorDefineSliders').hide()
        applyFunctionToSelectedLeds()
        drawColorBoxesInColorLedPoints()
        setOptionalGroupsVisibility()
        updateBulkCmd()
        GUI.content_ready callback
        return

    findLed = (x, y) ->
        ledIndex = 0
        while ledIndex < LED_STRIP.length
            led = LED_STRIP[ledIndex]
            if led.x == x and led.y == y
                return {
                    index: ledIndex
                    led: led
                }
            ledIndex++
        undefined

    updateBulkCmd = ->
        ledStripLength = LED_STRIP.length
        LED_STRIP = []
        $('.gPoint').each ->
            if $(this).is('[class*="function"]')
                gridNumber = $(this).index() + 1
                row = Math.ceil(gridNumber / 16) - 1
                col = gridNumber / 16 % 1 * 16 - 1
                if col < 0
                    col = 15
                wireNumber = $(this).find('.wire').html()
                functions = ''
                directions = ''
                colorIndex = 0
                that = this
                match = $(this).attr('class').match(/(^|\s)color-([0-9]+)(\s|$)/)
                if match
                    colorIndex = match[2]
                TABS.led_strip.baseFuncs.forEach (letter) ->
                    if $(that).is('.function-' + letter)
                        functions += letter
                    return
                TABS.led_strip.overlays.forEach (letter) ->
                    if $(that).is('.function-' + letter)
                        functions += letter
                    return
                TABS.led_strip.directions.forEach (letter) ->
                    if $(that).is('.dir-' + letter)
                        directions += letter
                    return
                if wireNumber != ''
                    led = 
                        x: col
                        y: row
                        directions: directions
                        functions: functions
                        color: colorIndex
                    LED_STRIP[wireNumber] = led
            return
        defaultLed = 
            x: 0
            y: 0
            directions: ''
            functions: ''
        i = 0
        while i < ledStripLength
            if LED_STRIP[i]
                i++
                continue
            LED_STRIP[i] = defaultLed
            i++
        usedWireNumbers = buildUsedWireNumbers()
        remaining = LED_STRIP.length - (usedWireNumbers.length)
        $('.wires-remaining div').html remaining
        return

    # refresh mode color buttons

    setModeBackgroundColor = (element) ->
        if semver.gte(CONFIG.apiVersion, '1.19.0')
            element.find('[class*="mode_color"]').each ->
                m = 0
                d = 0
                match = $(this).attr('class').match(/(^|\s)mode_color-([0-9]+)-([0-9]+)(\s|$)/)
                if match
                    m = Number(match[2])
                    d = Number(match[3])
                    $(this).css 'background-color', HsvToColor(LED_COLORS[getModeColor(m, d)])
                return
        return

    setBackgroundColor = (element) ->
        if element.is('[class*="color"]')
            colorIndex = 0
            match = element.attr('class').match(/(^|\s)color-([0-9]+)(\s|$)/)
            if match
                colorIndex = match[2]
                element.css 'background-color', HsvToColor(LED_COLORS[colorIndex])
        return

    areModifiersActive = (activeFunction) ->
        switch activeFunction
            when 'function-c', 'function-a', 'function-f'
                return true
        false

    areOverlaysActive = (activeFunction) ->
        if semver.lt(CONFIG.apiVersion, '1.20.0')
            switch activeFunction
                when 'function-c', 'function-a', 'function-f', 'function-g'
                    return true
        else
            switch activeFunction
                when '', 'function-c', 'function-a', 'function-f', 'function-s', 'function-l', 'function-r', 'function-o', 'function-g'
                    return true
        false

    areBlinkersActive = (activeFunction) ->
        if semver.gte(CONFIG.apiVersion, '1.20.0')
            switch activeFunction
                when 'function-c', 'function-a', 'function-f'
                    return true
        false

    isWarningActive = (activeFunction) ->
        switch activeFunction
            when 'function-l', 'function-s', 'function-g'
                return false
            when 'function-r', 'function-b'
                if semver.lt(CONFIG.apiVersion, '1.20.0')
                    return false
            else
                return true
                break
        return

    isVtxActive = (activeFunction) ->
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            switch activeFunction
                when 'function-v', 'function-c', 'function-a', 'function-f'
                    return true
                else
                    return false
                    break
        return

    setOptionalGroupsVisibility = ->
        activeFunction = $('select.functionSelect').val()
        $('select.functionSelect').addClass activeFunction
        if semver.lte(CONFIG.apiVersion, '1.18.0')
            # <= 18
            # Hide GPS (Func)
            # Hide RSSI (O/L), Blink (Func)
            # Hide Battery, RSSI (Func), Larson (O/L), Blink (O/L), Landing (O/L)
            $('.extra_functions20').hide()
            $('.mode_colors').hide()
        else
            # >= 20
            # Show GPS (Func)
            # Hide RSSI (O/L), Blink (Func)
            # Show Battery, RSSI (Func), Larson (O/L), Blink (O/L), Landing (O/L)
            $('.extra_functions20').show()
            $('.mode_colors').show()
        # set color modifiers (check-boxes) visibility
        $('.overlays').hide()
        $('.modifiers').hide()
        $('.blinkers').hide()
        $('.warningOverlay').hide()
        $('.vtxOverlay').hide()
        if areOverlaysActive(activeFunction)
            $('.overlays').show()
        if areModifiersActive(activeFunction)
            $('.modifiers').show()
        if areBlinkersActive(activeFunction)
            $('.blinkers').show()
        if isWarningActive(activeFunction)
            $('.warningOverlay').show()
        if isVtxActive(activeFunction)
            $('.vtxOverlay').show()
        # set directions visibility
        if semver.lt(CONFIG.apiVersion, '1.20.0')
            switch activeFunction
                when 'function-r'
                    $('.indicatorOverlay').hide()
                    $('.directions').hide()
                else
                    $('.indicatorOverlay').show()
                    $('.directions').show()
                    break
        $('.mode_colors').hide()
        if semver.gte(CONFIG.apiVersion, '1.19.0')
            # set mode colors visibility
            if semver.gte(CONFIG.apiVersion, '1.20.0')
                if activeFunction == 'function-f'
                    $('.mode_colors').show()
            # set special colors visibility
            $('.special_colors').show()
            $('.mode_color-6-0').hide()
            $('.mode_color-6-1').hide()
            $('.mode_color-6-2').hide()
            $('.mode_color-6-3').hide()
            $('.mode_color-6-4').hide()
            $('.mode_color-6-5').hide()
            $('.mode_color-6-6').hide()
            $('.mode_color-6-7').hide()
            switch activeFunction
                # none
                # Modes & Orientation
                when '', 'function-f', 'function-l'
                    # Battery
                    # $('.mode_color-6-3').show(); // background
                    $('.special_colors').hide()
                when 'function-g'
                    # GPS
                    $('.mode_color-6-5').show()
                    # no sats
                    $('.mode_color-6-6').show()
                    # no lock
                    $('.mode_color-6-7').show()
                    # locked
                    # $('.mode_color-6-3').show(); // background
                when 'function-b'
                    # Blink
                    $('.mode_color-6-4').show()
                    # blink background
                when 'function-a'
                    # Arm state
                    $('.mode_color-6-0').show()
                    # disarmed
                    $('.mode_color-6-1').show()
                    # armed
                # Ring
                else
                    $('.special_colors').hide()
                    break
        return

    applyFunctionToSelectedLeds = ->
        activeFunction = $('select.functionSelect').val()
        TABS.led_strip.baseFuncs.forEach (letter) ->
            if activeFunction == 'function-' + letter
                $('select.functionSelect').addClass 'function-' + letter
                $('.ui-selected').find('.wire').each ->
                    if $(this).text() != ''
                        $(this).parent().addClass 'function-' + letter
                    return
                unselectOverlays letter
            else
                $('select.functionSelect').removeClass 'function-' + letter
                $('.ui-selected').removeClass 'function-' + letter
            if activeFunction == ''
                unselectOverlays activeFunction
            return
        return

    unselectOverlays = (letter) ->
        if semver.lt(CONFIG.apiVersion, '1.20.0')
            if letter == 'b' or letter == 'r'
                unselectOverlay letter, 'i'
            if letter == 'b' or letter == 'r' or letter == 'l' or letter == 'g'
                unselectOverlay letter, 'w'
                unselectOverlay letter, 'v'
                unselectOverlay letter, 't'
                unselectOverlay letter, 's'
        else
            # MSP 1.20
            if letter == 'r' or letter == ''
                unselectOverlay letter, 'o'
                unselectOverlay letter, 'b'
                unselectOverlay letter, 'n'
                unselectOverlay letter, 't'
            if letter == 'l' or letter == 'g' or letter == 's'
                unselectOverlay letter, 'w'
                unselectOverlay letter, 'v'
                unselectOverlay letter, 't'
                unselectOverlay letter, 'o'
                unselectOverlay letter, 'b'
                unselectOverlay letter, 'n'
        return

    unselectOverlay = (func, overlay) ->
        $('input.function-' + overlay).prop 'checked', false
        $('input.function-' + overlay).change()
        $('.ui-selected').each ->
            if func == '' or $(this).is('.function-' + func)
                $(this).removeClass 'function-' + overlay
            return
        return

    updateColors = (value, hsvIndex) ->
        change = false
        value = Number(value)
        className = '.color-' + selectedColorIndex
        if $(className).hasClass('btnOn')
            switch hsvIndex
                when 0
                    if LED_COLORS[selectedColorIndex].h != value
                        LED_COLORS[selectedColorIndex].h = value
                        $('.colorDefineSliderValue.Hvalue').text LED_COLORS[selectedColorIndex].h
                        change = true
                when 1
                    if LED_COLORS[selectedColorIndex].s != value
                        LED_COLORS[selectedColorIndex].s = value
                        $('.colorDefineSliderValue.Svalue').text LED_COLORS[selectedColorIndex].s
                        change = true
                when 2
                    if LED_COLORS[selectedColorIndex].v != value
                        LED_COLORS[selectedColorIndex].v = value
                        $('.colorDefineSliderValue.Vvalue').text LED_COLORS[selectedColorIndex].v
                        change = true
        # refresh color buttons
        $('.colors').children().each ->
            setBackgroundColor $(this)
            return
        $('.overlay-color').each ->
            setBackgroundColor $(this)
            return
        $('.mode_colors').each ->
            setModeBackgroundColor $(this)
            return
        $('.special_colors').each ->
            setModeBackgroundColor $(this)
            return
        if change
            updateBulkCmd()
        return

    drawColorBoxesInColorLedPoints = ->
        $('.gPoint').each ->
            if $(this).is('.function-c') or $(this).is('.function-r') or $(this).is('.function-b')
                $(this).find('.overlay-color').show()
                colorIndex = 0
                while colorIndex < 16
                    className = 'color-' + colorIndex
                    if $(this).is('.' + className)
                        $(this).find('.overlay-color').addClass className
                        $(this).find('.overlay-color').css 'background-color', HsvToColor(LED_COLORS[colorIndex])
                    else
                        if $(this).find('.overlay-color').is('.' + className)
                            $(this).find('.overlay-color').removeClass className
                    colorIndex++
            else
                $(this).find('.overlay-color').hide()
            return
        return

    setColorSliders = (colorIndex) ->
        sliders = $('div.colorDefineSliders input')
        change = false
        if !LED_COLORS[colorIndex]
            return
        if LED_COLORS[colorIndex].h != Number(sliders.eq(0).val())
            sliders.eq(0).val LED_COLORS[colorIndex].h
            $('.colorDefineSliderValue.Hvalue').text LED_COLORS[colorIndex].h
            change = true
        if LED_COLORS[colorIndex].s != Number(sliders.eq(1).val())
            sliders.eq(1).val LED_COLORS[colorIndex].s
            $('.colorDefineSliderValue.Svalue').text LED_COLORS[colorIndex].s
            change = true
        if LED_COLORS[colorIndex].v != Number(sliders.eq(2).val())
            sliders.eq(2).val LED_COLORS[colorIndex].v
            $('.colorDefineSliderValue.Vvalue').text LED_COLORS[colorIndex].v
            change = true
        # only fire events when all values are set
        if change
            sliders.trigger 'input'
        return

    HsvToColor = (input) ->
        if input == undefined
            return ''
        HSV = 
            h: Number(input.h)
            s: Number(input.s)
            v: Number(input.v)
        if HSV.s == 0 and HSV.v == 0
            return ''
        HSV =
            h: HSV.h
            s: 1 - (HSV.s / 255)
            v: HSV.v / 255
        HSL = 
            h: 0
            s: 0
            v: 0
        HSL.h = HSV.h
        HSL.l = (2 - (HSV.s)) * HSV.v / 2
        HSL.s = if HSL.l and HSL.l < 1 then HSV.s * HSV.v / (if HSL.l < 0.5 then HSL.l * 2 else 2 - (HSL.l * 2)) else HSL.s
        ret = 'hsl(' + HSL.h + ', ' + HSL.s * 100 + '%, ' + HSL.l * 100 + '%)'
        ret

    getModeColor = (mode, dir) ->
        i = 0
        while i < LED_MODE_COLORS.length
            mc = LED_MODE_COLORS[i]
            if mc.mode == mode and mc.direction == dir
                return mc.color
            i++
        ''

    setModeColor = (mode, dir, color) ->
        i = 0
        while i < LED_MODE_COLORS.length
            mc = LED_MODE_COLORS[i]
            if mc.mode == mode and mc.direction == dir
                mc.color = color
                return 1
            i++
        0

    clearModeColorSelection = ->
        selectedModeColor = null
        $('.mode_colors').each ->
            $(this).children().each ->
                if $(this).is('.btnOn')
                    $(this).removeClass 'btnOn'
                return
            return
        return

    if semver.lt(CONFIG.apiVersion, '1.20.0')
        TABS.led_strip.functions = [
            'i'
            'w'
            'f'
            'a'
            't'
            'r'
            'c'
            'g'
            's'
            'b'
        ]
        TABS.led_strip.baseFuncs = [
            'c'
            'f'
            'a'
            'b'
            'g'
            'r'
        ]
        TABS.led_strip.overlays = [
            't'
            's'
            'i'
            'w'
        ]
    else
        TABS.led_strip.functions = [
            'i'
            'w'
            'f'
            'a'
            't'
            'r'
            'c'
            'g'
            's'
            'b'
            'l'
            'o'
            'n'
        ]
        TABS.led_strip.baseFuncs = [
            'c'
            'f'
            'a'
            'l'
            's'
            'g'
            'r'
        ]
        if semver.lt(CONFIG.apiVersion, '1.36.0')
            TABS.led_strip.overlays = [
                't'
                'o'
                'b'
                'n'
                'i'
                'w'
            ]
        else
            TABS.led_strip.overlays = [
                't'
                'o'
                'b'
                'v'
                'i'
                'w'
            ]
    TABS.led_strip.wireMode = false
    if GUI.active_tab != 'led_strip'
        GUI.active_tab = 'led_strip'
    load_led_config()
    return

TABS.led_strip.cleanup = (callback) ->
    if callback
        callback()
    return

