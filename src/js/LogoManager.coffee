'use strict'
LogoManager = LogoManager or 
    font: null
    logoStartIndex: null
    elements:
        preview: '#font-logo-preview'
        uploadHint: '#font-logo-info-upload-hint'
    constants:
        TILES_NUM_HORIZ: 24
        TILES_NUM_VERT: 4
        MCM_COLORMAP:
            '0-255-0': '01'
            '0-0-0': '00'
            '255-255-255': '10'
            'default': '01'
    acceptFileTypes: [ {
        description: 'images'
        extensions: [
            'png'
            'bmp'
        ]
    } ]

###*
# Initialize Logo Manager UI with dependencies.
# 
# @param {FONT} font
# @param {number} logoStartIndex
###

LogoManager.init = (font, logoStartIndex) ->
    _this = this
    # custom logo image constraints
    @constraints =
        imageSize:
            el: '#font-logo-info-size'
            expectedWidth: font.constants.SIZES.CHAR_WIDTH * @constants.TILES_NUM_HORIZ
            expectedHeight: font.constants.SIZES.CHAR_HEIGHT * @constants.TILES_NUM_VERT
            test: (img) ->
                constraint = @constraints.imageSize
                if img.width != constraint.expectedWidth or img.height != constraint.expectedHeight
                    GUI.log i18n.getMessage('osdSetupCustomLogoImageSizeError',
                        width: img.width
                        height: img.height)
                    return false
                true
        colorMap:
            el: '#font-logo-info-colors'
            test: (img) ->
                canvas = document.createElement('canvas')
                ctx = canvas.getContext('2d')
                canvas.width = img.width
                canvas.height = img.height
                ctx.drawImage img, 0, 0
                y = 0
                Y = canvas.height
                while y < Y
                    x = 0
                    X = canvas.width
                    while x < X
                        rgbPixel = ctx.getImageData(x, y, 1, 1).data.slice(0, 3)
                        colorKey = rgbPixel.join('-')
                        if !@constants.MCM_COLORMAP[colorKey]
                            GUI.log i18n.getMessage('osdSetupCustomLogoColorMapError',
                                valueR: rgbPixel[0]
                                valueG: rgbPixel[1]
                                valueB: rgbPixel[2]
                                posX: x
                                posY: y)
                            return false
                        x++
                    y++
                true
    # deps from osd.js
    @font = font
    @logoStartIndex = logoStartIndex
    # inject logo size variables for dynamic translation strings
    i18n.addResources
        logoWidthPx: '' + @constraints.imageSize.expectedWidth
        logoHeightPx: '' + @constraints.imageSize.expectedHeight
    # find/cache DOM elements
    Object.keys(@elements).forEach (key) ->
        _this.elements['$' + key] = $(_this.elements[key])
        return
    Object.keys(@constraints).forEach (key) ->
        _this.constraints[key].$el = $(_this.constraints[key].el)
        return
    # resize logo preview area to match tile size
    @elements.$preview.width(@constraints.imageSize.expectedWidth).height @constraints.imageSize.expectedHeight
    @resetImageInfo()
    return

LogoManager.resetImageInfo = ->
    @hideUploadHint()
    Object.values(@constraints).forEach (constraint) ->
        $el = constraint.$el
        $el.toggleClass 'invalid', false
        $el.toggleClass 'valid', false
        return
    return

LogoManager.showConstraintNotSatisfied = (constraint) ->
    constraint.$el.toggleClass 'invalid', true
    return

LogoManager.showConstraintSatisfied = (constraint) ->
    constraint.$el.toggleClass 'valid', true
    return

LogoManager.showUploadHint = ->
    @elements.$uploadHint.show()
    return

LogoManager.hideUploadHint = ->
    @elements.$uploadHint.hide()
    return

###*
# Show a file open dialog and resolve to an Image object.
# 
# @returns {Promise}
###

LogoManager.openImage = ->
    _this2 = this
    new Promise((resolve, reject) ->

        ###*
        # Validate image using defined constraints and display results on the UI.
        # 
        # @param {HTMLImageElement} img
        ###

        validateImage = (img) ->
            new Promise((resolve, reject) ->
                _this2.resetImageInfo()
                for key of _this2.constraints
                    if !_this2.constraints.hasOwnProperty(key)
                        x++
                        continue
                    constraint = _this2.constraints[key]
                    satisfied = constraint.test(img)
                    if satisfied
                        _this2.showConstraintSatisfied constraint
                    else
                        _this2.showConstraintNotSatisfied constraint
                        reject 'Boot logo image constraint violation'
                        return
                resolve()
                return
)

        dialogOptions = 
            type: 'openFile'
            accepts: _this2.acceptFileTypes
        chrome.fileSystem.chooseEntry dialogOptions, (fileEntry) ->
            if chrome.runtime.lastError
                console.error chrome.runtime.lastError.message
                return
            # load and validate selected image
            img = new Image

            img.onload = ->
                validateImage(img).then(->
                    resolve img
                ).catch (error) ->
                    reject error
                return

            img.onerror = (error) ->
                reject error

            fileEntry.file (file) ->
                img.src = 'file://' + file.path
            return
        return
)

###*
# Replaces the logo in the loaded font based on an image.
# 
# @param {HTMLImageElement} img
###

LogoManager.replaceLogoInFont = (img) ->
    _this3 = this

    ###*
    # Takes an ImageData object and returns an MCM symbol as an array of strings.
    # 
    # @param {ImageData} data
    ###

    imageToCharacter = (data) ->
        `var i`
        `var I`
        char = []
        line = ''
        i = 0
        I = data.length
        while i < I
            rgbPixel = data.slice(i, i + 3)
            colorKey = rgbPixel.join('-')
            line += _this3.constants.MCM_COLORMAP[colorKey] or _this3.constants.MCM_COLORMAP['default']
            if line.length == 8
                char.push line
                line = ''
            i += 4
        fieldSize = _this3.font.constants.SIZES.MAX_NVM_FONT_CHAR_FIELD_SIZE
        if char.length < fieldSize
            pad = _this3.constants.MCM_COLORMAP['default'].repeat(4)
            i = 0
            I = fieldSize - (char.length)
            while i < I
                char.push pad
                i++
        char

    # takes an OSD symbol as an array of strings and replaces the in-memory character at charAddress with it

    replaceChar = (lines, charAddress) ->
        characterBits = []
        characterBytes = []
        n = 0
        N = lines.length
        while n < N
            line = lines[n]
            y = 0
            while y < 8
                v = parseInt(line.slice(y, y + 2), 2)
                characterBits.push v
                y = y + 2
            characterBytes.push parseInt(line, 2)
            n++
        _this3.font.data.characters[charAddress] = characterBits
        _this3.font.data.characters_bytes[charAddress] = characterBytes
        _this3.font.data.character_image_urls[charAddress] = null
        _this3.font.draw charAddress
        return

    # loop through an image and replace font symbols
    canvas = document.createElement('canvas')
    ctx = canvas.getContext('2d')
    charAddr = @logoStartIndex
    canvas.width = img.width
    canvas.height = img.height
    ctx.drawImage img, 0, 0
    y = 0
    while y < @constants.TILES_NUM_VERT
        x = 0
        while x < @constants.TILES_NUM_HORIZ
            imageData = ctx.getImageData(x * @font.constants.SIZES.CHAR_WIDTH, y * @font.constants.SIZES.CHAR_HEIGHT, @font.constants.SIZES.CHAR_WIDTH, @font.constants.SIZES.CHAR_HEIGHT)
            newChar = imageToCharacter(imageData.data)
            replaceChar newChar, charAddr
            charAddr++
            x++
        y++
    return

###*
# Draw the logo using the loaded font data.
###

LogoManager.drawPreview = ->
    $el = @elements.$preview.empty()
    i = @logoStartIndex
    I = @font.constants.MAX_CHAR_COUNT
    while i < I
        url = @font.data.character_image_urls[i]
        $el.append '<img src="' + url + '" title="0x' + i.toString(16) + '"></img>'
        i++
    return

