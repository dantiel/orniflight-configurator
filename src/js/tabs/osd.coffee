_typeof = (o) ->
    '@babel/helpers - typeof'
    _typeof = if 'function' == typeof Symbol and 'symbol' == typeof Symbol.iterator then ((o) ->
        typeof o
    ) else ((o) ->
        if o and 'function' == typeof Symbol and o.constructor == Symbol and o != Symbol.prototype then 'symbol' else typeof o
    )
    _typeof(o)

_createForOfIteratorHelper = (r, e) ->
    t = 'undefined' != typeof Symbol and r[Symbol.iterator] or r['@@iterator']
    if !t
        if Array.isArray(r) or (t = _unsupportedIterableToArray(r)) or e and r and 'number' == typeof r.length
            t and (r = t)
            _n = 0

            F = ->

            return {
                s: F
                n: ->
                    if _n >= r.length then done: !0 else
                        done: !1
                        value: r[_n++]
                e: (r) ->
                    throw r
                    return
                f: F
            }
        throw new TypeError('Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.')
    o = undefined
    a = !0
    u = !1
    {
        s: ->
            t = t.call(r)
            return
        n: ->
            `var r`
            r = t.next()
            a = r.done
            r
        e: (r) ->
            u = !0
            o = r
            return
        f: ->
            if a or null == t['return'] or t['return']()
                true
            if u
                throw o
            return

    }

_unsupportedIterableToArray = (r, a) ->
    if r
        if 'string' == typeof r
            return _arrayLikeToArray(r, a)
        t = {}.toString.call(r).slice(8, -1)
        return 'Object' == t and r.constructor and (t = r.constructor.name)
        if 'Map' == t or 'Set' == t then Array.from(r) else if 'Arguments' == t or /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) then _arrayLikeToArray(r, a) else undefined

    return

_arrayLikeToArray = (r, a) ->
    (null == a or a > r.length) and (a = r.length)
    e = 0
    n = Array(a)
    while e < a
        n[e] = r[e]
        e++
    n

'use strict'
SYM = SYM or {}

SYM.loadSymbols = ->
    SYM.BLANK = 0x20
    SYM.VOLT = 0x06
    SYM.RSSI = 0x01
    SYM.LINK_QUALITY = 0x7B
    SYM.AH_RIGHT = 0x02
    SYM.AH_LEFT = 0x03
    SYM.THR = 0x04
    SYM.FLY_M = 0x9C
    SYM.ON_M = 0x9B
    SYM.AH_CENTER_LINE = 0x72
    SYM.AH_CENTER = 0x73
    SYM.AH_CENTER_LINE_RIGHT = 0x74
    SYM.AH_BAR9_0 = 0x80
    SYM.AH_DECORATION = 0x13
    SYM.LOGO = 0xA0
    SYM.AMP = 0x9A
    SYM.MAH = 0x07
    SYM.METRE = 0xC
    SYM.FEET = 0xF
    SYM.KPH = 0x9E
    SYM.MPH = 0x9D
    SYM.MPS = 0x9F
    SYM.FTPS = 0x99
    SYM.SPEED = 0x70
    SYM.TOTAL_DIST = 0x71
    SYM.GPS_SAT_L = 0x1E
    SYM.GPS_SAT_R = 0x1F
    SYM.GPS_LAT = 0x89
    SYM.GPS_LON = 0x98
    SYM.HOMEFLAG = 0x11
    SYM.PB_START = 0x8A
    SYM.PB_FULL = 0x8B
    SYM.PB_EMPTY = 0x8D
    SYM.PB_END = 0x8E
    SYM.PB_CLOSE = 0x8F
    SYM.BATTERY = 0x96
    SYM.ARROW_NORTH = 0x68
    SYM.ARROW_SOUTH = 0x60
    SYM.ARROW_EAST = 0x64
    SYM.ARROW_SMALL_UP = 0x75
    SYM.HEADING_LINE = 0x1D
    SYM.HEADING_DIVIDED_LINE = 0x1C
    SYM.HEADING_N = 0x18
    SYM.HEADING_S = 0x19
    SYM.HEADING_E = 0x1A
    SYM.HEADING_W = 0x1B
    SYM.TEMPERATURE = 0x7A
    SYM.TEMP_F = 0x0D
    SYM.TEMP_C = 0x0E
    SYM.STICK_OVERLAY_SPRITE_HIGH = 0x08
    SYM.STICK_OVERLAY_SPRITE_MID = 0x09
    SYM.STICK_OVERLAY_SPRITE_LOW = 0x0A
    SYM.STICK_OVERLAY_CENTER = 0x0B
    SYM.STICK_OVERLAY_VERTICAL = 0x16
    SYM.STICK_OVERLAY_HORIZONTAL = 0x17
    SYM.BBLOG = 0x10
    SYM.ALTITUDE = 0x7F
    SYM.PITCH = 0x15
    SYM.ROLL = 0x14

    ### Versions before firmware 4.1 use font V1
    # To maintain this list at minimum, we only add here: 
    # - Symbols used in this versions
    # - That were moved or didn't exist in the font file
    ###

    if semver.lt(CONFIG.apiVersion, '1.42.0')
        SYM.AH_CENTER_LINE = 0x26
        SYM.AH_CENTER = 0x7E
        SYM.AH_CENTER_LINE_RIGHT = 0x27
        SYM.SPEED = null
        SYM.LINK_QUALITY = null
    return

STICK_OVERLAY_SPRITE = [
    SYM.STICK_OVERLAY_SPRITE_HIGH
    SYM.STICK_OVERLAY_SPRITE_MID
    SYM.STICK_OVERLAY_SPRITE_LOW
]
FONT = FONT or {}

FONT.initData = ->
    if FONT.data
        return
    FONT.data =
        loaded_font_file: 'default'
        characters_bytes: []
        characters: []
        character_image_urls: []
    return

FONT.constants =
    MAX_CHAR_COUNT: 256
    SIZES:
        MAX_NVM_FONT_CHAR_SIZE: 54
        MAX_NVM_FONT_CHAR_FIELD_SIZE: 64
        CHAR_HEIGHT: 18
        CHAR_WIDTH: 12
        LINE: 30
    COLORS:
        0: 'rgba(0, 0, 0, 1)'
        1: 'rgba(255, 255, 255, 0)'
        2: 'rgba(255,255,255, 1)'

###*
* Each line is composed of 8 asci 1 or 0, representing 1 bit each for a total of 1 byte per line
###

FONT.parseMCMFontFile = (data) ->
    `var data`
    data = data.trim().split('\n')
    # clear local data
    FONT.data.characters.length = 0
    FONT.data.characters_bytes.length = 0
    FONT.data.character_image_urls.length = 0
    # reset logo image info when font data is changed
    LogoManager.resetImageInfo()
    # make sure the font file is valid
    if data.shift().trim() != 'MAX7456'
        msg = 'that font file doesnt have the MAX7456 header, giving up'
        console.debug msg
        Promise.reject msg
    character_bits = []
    character_bytes = []
    # hexstring is for debugging
    FONT.data.hexstring = []

    pushChar = ->
        # Only push full characters onto the stack.
        if character_bytes.length != FONT.constants.SIZES.MAX_NVM_FONT_CHAR_FIELD_SIZE
            return
        FONT.data.characters_bytes.push character_bytes
        FONT.data.characters.push character_bits
        FONT.draw FONT.data.characters.length - 1
        character_bits = []
        character_bytes = []
        return

    i = 0
    while i < data.length
        line = data[i]
        # hexstring is for debugging
        FONT.data.hexstring.push '0x' + parseInt(line, 2).toString(16)
        # every 64 bytes (line) is a char, we're counting chars though, which are 2 bits
        if character_bits.length == FONT.constants.SIZES.MAX_NVM_FONT_CHAR_FIELD_SIZE * 8 / 2
            pushChar()
        y = 0
        while y < 8
            v = parseInt(line.slice(y, y + 2), 2)
            character_bits.push v
            y = y + 2
        character_bytes.push parseInt(line, 2)
        i++
    # push the last char
    pushChar()
    FONT.data.characters

FONT.openFontFile = (fontPreviewElement) ->
    new Promise((resolve) ->
        chrome.fileSystem.chooseEntry {
            type: 'openFile'
            accepts: [ {
                description: 'MCM files'
                extensions: [ 'mcm' ]
            } ]
        }, (fileEntry) ->
            FONT.data.loaded_font_file = fileEntry.name
            if chrome.runtime.lastError
                console.error chrome.runtime.lastError.message
                return
            fileEntry.file (file) ->
                reader = new FileReader

                reader.onloadend = (e) ->
                    if e.total != 0 and e.total == e.loaded
                        FONT.parseMCMFontFile e.target.result
                        resolve()
                    else
                        console.error 'could not load whole font file'
                    return

                reader.readAsText file
                return
            return
        return
)

###*
* returns a canvas image with the character on it
###

drawCanvas = (charAddress) ->
    canvas = document.createElement('canvas')
    ctx = canvas.getContext('2d')
    # TODO: do we want to be able to set pixel size? going to try letting the consumer scale the image.
    pixelSize = pixelSize or 1
    width = pixelSize * FONT.constants.SIZES.CHAR_WIDTH
    height = pixelSize * FONT.constants.SIZES.CHAR_HEIGHT
    canvas.width = width
    canvas.height = height
    y = 0
    while y < height
        x = 0
        while x < width
            if !(charAddress of FONT.data.characters)
                console.log 'charAddress', charAddress, ' is not in ', FONT.data.characters.length
            v = FONT.data.characters[charAddress][y * width + x]
            ctx.fillStyle = FONT.constants.COLORS[v]
            ctx.fillRect x, y, pixelSize, pixelSize
            x++
        y++
    canvas

FONT.draw = (charAddress) ->
    cached = FONT.data.character_image_urls[charAddress]
    if !cached
        cached = FONT.data.character_image_urls[charAddress] = drawCanvas(charAddress).toDataURL('image/png')
    cached

FONT.msp = encode: (charAddress) ->
    [ charAddress ].concat FONT.data.characters_bytes[charAddress].slice(0, FONT.constants.SIZES.MAX_NVM_FONT_CHAR_SIZE)

FONT.upload = ($progress) ->
    Promise.mapSeries(FONT.data.characters, (data, i) ->
        $progress.val i / FONT.data.characters.length * 100
        MSP.promise MSPCodes.MSP_OSD_CHAR_WRITE, FONT.msp.encode(i)
    ).then ->
        console.log 'Uploaded all ' + FONT.data.characters.length + ' characters'
        GUI.log i18n.getMessage('osdSetupUploadingFontEnd', length: FONT.data.characters.length)
        OSD.GUI.fontManager.close()
        MSP.promise MSPCodes.MSP_SET_REBOOT

FONT.preview = ($el) ->
    $el.empty()
    i = 0
    while i < SYM.LOGO
        url = FONT.data.character_image_urls[i]
        $el.append '<img src="' + url + '" title="0x' + i.toString(16) + '"></img>'
        i++
    return

FONT.symbol = (hexVal) ->
    if hexVal == '' or hexVal == null then '' else String.fromCharCode(hexVal)

OSD = OSD or {}

OSD.getNumberOfProfiles = ->
    OSD.data.osd_profiles.number

OSD.getCurrentPreviewProfile = ->
    osdprofile_e = $('.osdprofile-selector')
    if osdprofile_e
        osdprofile_e.val()
    else
        0

# parsed fc output and output to fc, used by to OSD.msp.encode

OSD.initData = ->
    OSD.data =
        video_system: null
        unit_mode: null
        alarms: []
        stat_items: []
        warnings: []
        display_items: []
        timers: []
        last_positions: {}
        preview: []
        tooltips: []
        osd_profiles: {}
    return

OSD.initData()

OSD.generateTimerPreview = (osd_data, timer_index) ->
    preview = ''
    switch osd_data.timers[timer_index].src
        when 0, 3
            preview += FONT.symbol(SYM.ON_M)
        when 1, 2
            preview += FONT.symbol(SYM.FLY_M)
    switch osd_data.timers[timer_index].precision
        when 0
            preview += '00:00'
        when 1
            preview += '00:00.00'
        when 2
            preview += '00:00.0'
    preview

OSD.generateTemperaturePreview = (osd_data, temperature) ->
    preview = FONT.symbol(SYM.TEMPERATURE)
    switch osd_data.unit_mode
        when 0
            temperature *= 9.0 / 5.0
            temperature += 32.0
            preview += Math.floor(temperature) + FONT.symbol(SYM.TEMP_F)
        when 1
            preview += temperature + FONT.symbol(SYM.TEMP_C)
    preview

OSD.generateCraftName = (osd_data) ->
    preview = 'CRAFT_NAME'
    if CONFIG.name != ''
        preview = CONFIG.name.toUpperCase()
    preview

OSD.generateDisplayName = (osd_data) ->
    preview = 'DISPLAY_NAME'
    if CONFIG.displayName != ''
        preview = CONFIG.displayName.toUpperCase()
    preview

OSD.drawStickOverlayPreview = ->
    OVERLAY_WIDTH = 7
    OVERLAY_HEIGHT = 5
    stickX = randomInt(OVERLAY_WIDTH)
    stickY = randomInt(OVERLAY_HEIGHT)
    stickSymbol = randomInt(3)
    # From 'osdDrawStickOverlayAxis' in 'src/main/io/osd.c'
    stickOverlay = new Array

    randomInt = (count) ->
        Math.floor Math.random() * Math.floor(count)

    x = 0
    while x < OVERLAY_WIDTH
        y = 0
        while y < OVERLAY_HEIGHT
            symbol = undefined
            if x == stickX and y == stickY
                symbol = STICK_OVERLAY_SPRITE[stickSymbol]
            else if x == (OVERLAY_WIDTH - 1) / 2 and y == (OVERLAY_HEIGHT - 1) / 2
                symbol = SYM.STICK_OVERLAY_CENTER
            else if x == (OVERLAY_WIDTH - 1) / 2
                symbol = SYM.STICK_OVERLAY_VERTICAL
            else if y == (OVERLAY_HEIGHT - 1) / 2
                symbol = SYM.STICK_OVERLAY_HORIZONTAL
            if symbol
                element = 
                    x: x
                    y: y
                    sym: symbol
                stickOverlay.push element
            y++
        x++
    stickOverlay

OSD.loadDisplayFields = ->
    # All display fields, from every version, do not remove elements, only add!
    OSD.ALL_DISPLAY_FIELDS =
        MAIN_BATT_VOLTAGE:
            name: 'MAIN_BATT_VOLTAGE'
            text: 'osdTextElementMainBattVoltage'
            desc: 'osdDescElementMainBattVoltage'
            default_position: -29
            draw_order: 20
            positionable: true
            preview: FONT.symbol(SYM.BATTERY) + '16.8' + FONT.symbol(SYM.VOLT)
        RSSI_VALUE:
            name: 'RSSI_VALUE'
            text: 'osdTextElementRssiValue'
            desc: 'osdDescElementRssiValue'
            default_position: -59
            draw_order: 30
            positionable: true
            preview: FONT.symbol(SYM.RSSI) + '99'
        TIMER:
            name: 'TIMER'
            text: 'osdTextElementTimer'
            desc: 'osdDescElementTimer'
            default_position: -39
            positionable: true
            preview: FONT.symbol(SYM.ON_M) + ' 11:11'
        THROTTLE_POSITION:
            name: 'THROTTLE_POSITION'
            text: 'osdTextElementThrottlePosition'
            desc: 'osdDescElementThrottlePosition'
            default_position: -9
            draw_order: 110
            positionable: true
            preview: FONT.symbol(SYM.THR) + ' 69'
        CPU_LOAD:
            name: 'CPU_LOAD'
            text: 'osdTextElementCpuLoad'
            desc: 'osdDescElementCpuLoad'
            default_position: 26
            positionable: true
            preview: '15'
        VTX_CHANNEL:
            name: 'VTX_CHANNEL'
            text: 'osdTextElementVtxChannel'
            desc: 'osdDescElementVtxChannel'
            default_position: 1
            draw_order: 120
            positionable: true
            preview: 'R:2:200:P'
        VOLTAGE_WARNING:
            name: 'VOLTAGE_WARNING'
            text: 'osdTextElementVoltageWarning'
            desc: 'osdDescElementVoltageWarning'
            default_position: -80
            positionable: true
            preview: 'LOW VOLTAGE'
        ARMED:
            name: 'ARMED'
            text: 'osdTextElementArmed'
            desc: 'osdDescElementArmed'
            default_position: -107
            positionable: true
            preview: 'ARMED'
        DISARMED:
            name: 'DISARMED'
            text: 'osdTextElementDisarmed'
            desc: 'osdDescElementDisarmed'
            default_position: -109
            draw_order: 280
            positionable: true
            preview: 'DISARMED'
        CROSSHAIRS:
            name: 'CROSSHAIRS'
            text: 'osdTextElementCrosshairs'
            desc: 'osdDescElementCrosshairs'
            default_position: ->
                position = 193
                if OSD.constants.VIDEO_TYPES[OSD.data.video_system] != 'NTSC'
                    position += FONT.constants.SIZES.LINE
                position
            draw_order: 40
            positionable: ->
                if semver.gte(CONFIG.apiVersion, '1.39.0') then true else false
            preview: ->
                FONT.symbol(SYM.AH_CENTER_LINE) + FONT.symbol(SYM.AH_CENTER) + FONT.symbol(SYM.AH_CENTER_LINE_RIGHT)
        ARTIFICIAL_HORIZON:
            name: 'ARTIFICIAL_HORIZON'
            text: 'osdTextElementArtificialHorizon'
            desc: 'osdDescElementArtificialHorizon'
            default_position: ->
                position = 74
                if OSD.constants.VIDEO_TYPES[OSD.data.video_system] != 'NTSC'
                    position += FONT.constants.SIZES.LINE
                position
            draw_order: 10
            positionable: ->
                if semver.gte(CONFIG.apiVersion, '1.39.0') then true else false
            preview: ->
                artificialHorizon = new Array
                j = 1
                while j < 8
                    i = -4
                    while i <= 4
                        element = undefined
                        # Blank char to mark the size of the element
                        if j != 4
                            element =
                                x: i
                                y: j
                                sym: SYM.BLANK
                            # Sample of horizon
                        else
                            element =
                                x: i
                                y: j
                                sym: SYM.AH_BAR9_0 + 4
                        artificialHorizon.push element
                        i++
                    j++
                artificialHorizon
        HORIZON_SIDEBARS:
            name: 'HORIZON_SIDEBARS'
            text: 'osdTextElementHorizonSidebars'
            desc: 'osdDescElementHorizonSidebars'
            default_position: ->
                position = 194
                if OSD.constants.VIDEO_TYPES[OSD.data.video_system] != 'NTSC'
                    position += FONT.constants.SIZES.LINE
                position
            draw_order: 50
            positionable: ->
                if semver.gte(CONFIG.apiVersion, '1.39.0') then true else false
            preview: (fieldPosition) ->
                `var element`
                horizonSidebar = new Array
                hudwidth = OSD.constants.AHISIDEBARWIDTHPOSITION
                hudheight = OSD.constants.AHISIDEBARHEIGHTPOSITION
                i = -hudheight
                while i <= hudheight
                    element = 
                        x: -hudwidth
                        y: i
                        sym: SYM.AH_DECORATION
                    horizonSidebar.push element
                    element =
                        x: hudwidth
                        y: i
                        sym: SYM.AH_DECORATION
                    horizonSidebar.push element
                    i++
                # AH level indicators
                element = 
                    x: -hudwidth + 1
                    y: 0
                    sym: SYM.AH_LEFT
                horizonSidebar.push element
                element =
                    x: hudwidth - 1
                    y: 0
                    sym: SYM.AH_RIGHT
                horizonSidebar.push element
                horizonSidebar
        CURRENT_DRAW:
            name: 'CURRENT_DRAW'
            text: 'osdTextElementCurrentDraw'
            desc: 'osdDescElementCurrentDraw'
            default_position: -23
            draw_order: 130
            positionable: true
            preview: ->
                if semver.gte(CONFIG.apiVersion, '1.36.0') then ' 42.00' + FONT.symbol(SYM.AMP) else FONT.symbol(SYM.AMP) + '42.0'
        MAH_DRAWN:
            name: 'MAH_DRAWN'
            text: 'osdTextElementMahDrawn'
            desc: 'osdDescElementMahDrawn'
            default_position: -18
            draw_order: 140
            positionable: true
            preview: ->
                if semver.gte(CONFIG.apiVersion, '1.36.0') then ' 690' + FONT.symbol(SYM.MAH) else FONT.symbol(SYM.MAH) + '690'
        CRAFT_NAME:
            name: 'CRAFT_NAME'
            text: 'osdTextElementCraftName'
            desc: 'osdDescElementCraftName'
            default_position: -77
            draw_order: 150
            positionable: true
            preview: OSD.generateCraftName
        ALTITUDE:
            name: 'ALTITUDE'
            text: 'osdTextElementAltitude'
            desc: 'osdDescElementAltitude'
            default_position: 62
            draw_order: 160
            positionable: true
            preview: (osd_data) ->
                FONT.symbol(SYM.ALTITUDE) + '399.7' + FONT.symbol(if osd_data.unit_mode == 0 then SYM.FEET else SYM.METRE)
        ONTIME:
            name: 'ONTIME'
            text: 'osdTextElementOnTime'
            desc: 'osdDescElementOnTime'
            default_position: -1
            positionable: true
            preview: FONT.symbol(SYM.ON_M) + '05:42'
        FLYTIME:
            name: 'FLYTIME'
            text: 'osdTextElementFlyTime'
            desc: 'osdDescElementFlyTime'
            default_position: -1
            positionable: true
            preview: FONT.symbol(SYM.FLY_M) + '04:11'
        FLYMODE:
            name: 'FLYMODE'
            text: 'osdTextElementFlyMode'
            desc: 'osdDescElementFlyMode'
            default_position: -1
            draw_order: 90
            positionable: true
            preview: 'STAB'
        GPS_SPEED:
            name: 'GPS_SPEED'
            text: 'osdTextElementGPSSpeed'
            desc: 'osdDescElementGPSSpeed'
            default_position: -1
            draw_order: 810
            positionable: true
            preview: (osd_data) ->
                FONT.symbol(SYM.SPEED) + ' 40' + (if osd_data.unit_mode == 0 then FONT.symbol(SYM.MPH) else FONT.symbol(SYM.KPH))
        GPS_SATS:
            name: 'GPS_SATS'
            text: 'osdTextElementGPSSats'
            desc: 'osdDescElementGPSSats'
            default_position: -1
            draw_order: 800
            positionable: true
            preview: FONT.symbol(SYM.GPS_SAT_L) + FONT.symbol(SYM.GPS_SAT_R) + '14'
        GPS_LON:
            name: 'GPS_LON'
            text: 'osdTextElementGPSLon'
            desc: 'osdDescElementGPSLon'
            default_position: -1
            draw_order: 830
            positionable: true
            preview: FONT.symbol(SYM.GPS_LON) + '-000.0000000'
        GPS_LAT:
            name: 'GPS_LAT'
            text: 'osdTextElementGPSLat'
            desc: 'osdDescElementGPSLat'
            default_position: -1
            draw_order: 820
            positionable: true
            preview: FONT.symbol(SYM.GPS_LAT) + '-00.0000000 '
        DEBUG:
            name: 'DEBUG'
            text: 'osdTextElementDebug'
            desc: 'osdDescElementDebug'
            default_position: -1
            draw_order: 240
            positionable: true
            preview: 'DBG     0     0     0     0'
        PID_ROLL:
            name: 'PID_ROLL'
            text: 'osdTextElementPIDRoll'
            desc: 'osdDescElementPIDRoll'
            default_position: 0x800 | 10 << 5 | 2
            draw_order: 170
            positionable: true
            preview: 'ROL  43  40  20'
        PID_PITCH:
            name: 'PID_PITCH'
            text: 'osdTextElementPIDPitch'
            desc: 'osdDescElementPIDPitch'
            default_position: 0x800 | 11 << 5 | 2
            draw_order: 180
            positionable: true
            preview: 'PIT  58  50  22'
        PID_YAW:
            name: 'PID_YAW'
            text: 'osdTextElementPIDYaw'
            desc: 'osdDescElementPIDYaw'
            default_position: 0x800 | 12 << 5 | 2
            draw_order: 190
            positionable: true
            preview: 'YAW  70  45  20'
        POWER:
            name: 'POWER'
            text: 'osdTextElementPower'
            desc: 'osdDescElementPower'
            default_position: 15 << 5 | 2
            draw_order: 200
            positionable: true
            preview: ->
                if semver.gte(CONFIG.apiVersion, '1.36.0') then ' 142W' else '142W'
        PID_RATE_PROFILE:
            name: 'PID_RATE_PROFILE'
            text: 'osdTextElementPIDRateProfile'
            desc: 'osdDescElementPIDRateProfile'
            default_position: 0x800 | 13 << 5 | 2
            draw_order: 210
            positionable: true
            preview: '1-2'
        BATTERY_WARNING:
            name: 'BATTERY_WARNING'
            text: 'osdTextElementBatteryWarning'
            desc: 'osdDescElementBatteryWarning'
            default_position: -1
            positionable: true
            preview: 'LOW VOLTAGE'
        AVG_CELL_VOLTAGE:
            name: 'AVG_CELL_VOLTAGE'
            text: 'osdTextElementAvgCellVoltage'
            desc: 'osdDescElementAvgCellVoltage'
            default_position: 12 << 5
            draw_order: 230
            positionable: true
            preview: FONT.symbol(SYM.BATTERY) + '3.98' + FONT.symbol(SYM.VOLT)
        PITCH_ANGLE:
            name: 'PITCH_ANGLE'
            text: 'osdTextElementPitchAngle'
            desc: 'osdDescElementPitchAngle'
            default_position: -1
            draw_order: 250
            positionable: true
            preview: FONT.symbol(SYM.PITCH) + '-00.0'
        ROLL_ANGLE:
            name: 'ROLL_ANGLE'
            text: 'osdTextElementRollAngle'
            desc: 'osdDescElementRollAngle'
            default_position: -1
            draw_order: 260
            positionable: true
            preview: FONT.symbol(SYM.ROLL) + '-00.0'
        MAIN_BATT_USAGE:
            name: 'MAIN_BATT_USAGE'
            text: 'osdTextElementMainBattUsage'
            desc: 'osdDescElementMainBattUsage'
            default_position: -17
            draw_order: 270
            positionable: true
            preview: FONT.symbol(SYM.PB_START) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_FULL) + FONT.symbol(SYM.PB_END) + FONT.symbol(SYM.PB_EMPTY) + FONT.symbol(SYM.PB_CLOSE)
        ARMED_TIME:
            name: 'ARMED_TIME'
            text: 'osdTextElementArmedTime'
            desc: 'osdDescElementArmedTime'
            default_position: -1
            positionable: true
            preview: FONT.symbol(SYM.FLY_M) + '02:07'
        HOME_DIR:
            name: 'HOME_DIRECTION'
            text: 'osdTextElementHomeDirection'
            desc: 'osdDescElementHomeDirection'
            default_position: -1
            draw_order: 850
            positionable: true
            preview: FONT.symbol(SYM.ARROW_SOUTH + 2)
        HOME_DIST:
            name: 'HOME_DISTANCE'
            text: 'osdTextElementHomeDistance'
            desc: 'osdDescElementHomeDistance'
            default_position: -1
            draw_order: 840
            positionable: true
            preview: (osd_data) ->
                FONT.symbol(SYM.HOMEFLAG) + '432' + FONT.symbol(if osd_data.unit_mode == 0 then SYM.FEET else SYM.METRE)
        NUMERICAL_HEADING:
            name: 'NUMERICAL_HEADING'
            text: 'osdTextElementNumericalHeading'
            desc: 'osdDescElementNumericalHeading'
            default_position: -1
            draw_order: 290
            positionable: true
            preview: FONT.symbol(SYM.ARROW_EAST) + '90'
        NUMERICAL_VARIO:
            name: 'NUMERICAL_VARIO'
            text: 'osdTextElementNumericalVario'
            desc: 'osdDescElementNumericalVario'
            default_position: -1
            draw_order: 300
            positionable: true
            preview: (osd_data) ->
                FONT.symbol(SYM.ARROW_SMALL_UP) + '8.7' + (if osd_data.unit_mode == 0 then FONT.symbol(SYM.FTPS) else FONT.symbol(SYM.MPS))
        COMPASS_BAR:
            name: 'COMPASS_BAR'
            text: 'osdTextElementCompassBar'
            desc: 'osdDescElementCompassBar'
            default_position: -1
            draw_order: 310
            positionable: true
            preview: (osd_data) ->
                FONT.symbol(SYM.HEADING_W) + FONT.symbol(SYM.HEADING_LINE) + FONT.symbol(SYM.HEADING_DIVIDED_LINE) + FONT.symbol(SYM.HEADING_LINE) + FONT.symbol(SYM.HEADING_N) + FONT.symbol(SYM.HEADING_LINE) + FONT.symbol(SYM.HEADING_DIVIDED_LINE) + FONT.symbol(SYM.HEADING_LINE) + FONT.symbol(SYM.HEADING_E)
        WARNINGS:
            name: 'WARNINGS'
            text: 'osdTextElementWarnings'
            desc: 'osdDescElementWarnings'
            default_position: -1
            draw_order: 220
            positionable: true
            preview: 'LOW VOLTAGE'
        ESC_TEMPERATURE:
            name: 'ESC_TEMPERATURE'
            text: 'osdTextElementEscTemperature'
            desc: 'osdDescElementEscTemperature'
            default_position: -1
            draw_order: 900
            positionable: true
            preview: (osd_data) ->
                'E' + OSD.generateTemperaturePreview(osd_data, 45)
        ESC_RPM:
            name: 'ESC_RPM'
            text: 'osdTextElementEscRpm'
            desc: 'osdDescElementEscRpm'
            default_position: -1
            draw_order: 1000
            positionable: true
            preview: [
                '22600'
                '22600'
                '22600'
                '22600'
            ]
        REMAINING_TIME_ESTIMATE:
            name: 'REMAINING_TIME_ESTIMATE'
            text: 'osdTextElementRemaningTimeEstimate'
            desc: 'osdDescElementRemaningTimeEstimate'
            default_position: -1
            draw_order: 80
            positionable: true
            preview: '01:13'
        RTC_DATE_TIME:
            name: 'RTC_DATE_TIME'
            text: 'osdTextElementRtcDateTime'
            desc: 'osdDescElementRtcDateTime'
            default_position: -1
            draw_order: 360
            positionable: true
            preview: '2017-11-11 16:20:00'
        ADJUSTMENT_RANGE:
            name: 'ADJUSTMENT_RANGE'
            text: 'osdTextElementAdjustmentRange'
            desc: 'osdDescElementAdjustmentRange'
            default_position: -1
            draw_order: 370
            positionable: true
            preview: 'PITCH/ROLL P: 42'
        TIMER_1:
            name: 'TIMER_1'
            text: 'osdTextElementTimer1'
            desc: 'osdDescElementTimer1'
            default_position: -1
            draw_order: 60
            positionable: true
            preview: (osd_data) ->
                OSD.generateTimerPreview osd_data, 0
        TIMER_2:
            name: 'TIMER_2'
            text: 'osdTextElementTimer2'
            desc: 'osdDescElementTimer2'
            default_position: -1
            draw_order: 70
            positionable: true
            preview: (osd_data) ->
                OSD.generateTimerPreview osd_data, 1
        CORE_TEMPERATURE:
            name: 'CORE_TEMPERATURE'
            text: 'osdTextElementCoreTemperature'
            desc: 'osdDescElementCoreTemperature'
            default_position: -1
            draw_order: 380
            positionable: true
            preview: (osd_data) ->
                'C' + OSD.generateTemperaturePreview(osd_data, 33)
        ANTI_GRAVITY:
            name: 'ANTI_GRAVITY'
            text: 'osdTextAntiGravity'
            desc: 'osdDescAntiGravity'
            default_position: -1
            draw_order: 320
            positionable: true
            preview: 'AG'
        G_FORCE:
            name: 'G_FORCE'
            text: 'osdTextGForce'
            desc: 'osdDescGForce'
            default_position: -1
            draw_order: 15
            positionable: true
            preview: '1.0G'
        MOTOR_DIAG:
            name: 'MOTOR_DIAGNOSTICS'
            text: 'osdTextElementMotorDiag'
            desc: 'osdDescElementMotorDiag'
            default_position: -1
            draw_order: 335
            positionable: true
            preview: FONT.symbol(0x84) + FONT.symbol(0x85) + FONT.symbol(0x84) + FONT.symbol(0x83)
        LOG_STATUS:
            name: 'LOG_STATUS'
            text: 'osdTextElementLogStatus'
            desc: 'osdDescElementLogStatus'
            default_position: -1
            draw_order: 330
            positionable: true
            preview: FONT.symbol(SYM.BBLOG) + '16'
        FLIP_ARROW:
            name: 'FLIP_ARROW'
            text: 'osdTextElementFlipArrow'
            desc: 'osdDescElementFlipArrow'
            default_position: -1
            draw_order: 340
            positionable: true
            preview: FONT.symbol(SYM.ARROW_EAST)
        LINK_QUALITY:
            name: 'LINK_QUALITY'
            text: 'osdTextElementLinkQuality'
            desc: 'osdDescElementLinkQuality'
            default_position: -1
            draw_order: 390
            positionable: true
            preview: FONT.symbol(SYM.LINK_QUALITY) + '8'
        FLIGHT_DIST:
            name: 'FLIGHT_DISTANCE'
            text: 'osdTextElementFlightDist'
            desc: 'osdDescElementFlightDist'
            default_position: -1
            draw_order: 860
            positionable: true
            preview: (osd_data) ->
                FONT.symbol(SYM.TOTAL_DIST) + '653' + FONT.symbol(if osd_data.unit_mode == 0 then SYM.FEET else SYM.METRE)
        STICK_OVERLAY_LEFT:
            name: 'STICK_OVERLAY_LEFT'
            text: 'osdTextElementStickOverlayLeft'
            desc: 'osdDescElementStickOverlayLeft'
            default_position: -1
            draw_order: 400
            positionable: true
            preview: OSD.drawStickOverlayPreview
        STICK_OVERLAY_RIGHT:
            name: 'STICK_OVERLAY_RIGHT'
            text: 'osdTextElementStickOverlayRight'
            desc: 'osdDescElementStickOverlayRight'
            default_position: -1
            draw_order: 410
            positionable: true
            preview: OSD.drawStickOverlayPreview
        DISPLAY_NAME:
            name: 'DISPLAY_NAME'
            text: 'osdTextElementDisplayName'
            desc: 'osdDescElementDisplayName'
            default_position: -77
            draw_order: 350
            positionable: true
            preview: (osd_data) ->
                OSD.generateDisplayName osd_data, 1
        ESC_RPM_FREQ:
            name: 'ESC_RPM_FREQ'
            text: 'osdTextElementEscRpmFreq'
            desc: 'osdDescElementEscRpmFreq'
            default_position: -1
            draw_order: 1010
            positionable: true
            preview: [
                '22600'
                '22600'
                '22600'
                '22600'
            ]
        RATE_PROFILE_NAME:
            name: 'RATE_PROFILE_NAME'
            text: 'osdTextElementRateProfileName'
            desc: 'osdDescElementRateProfileName'
            default_position: -1
            draw_order: 420
            positionable: true
            preview: 'RATE_1'
        PID_PROFILE_NAME:
            name: 'PID_PROFILE_NAME'
            text: 'osdTextElementPidProfileName'
            desc: 'osdDescElementPidProfileName'
            default_position: -1
            draw_order: 430
            positionable: true
            preview: 'PID_1'
        OSD_PROFILE_NAME:
            name: 'OSD_PROFILE_NAME'
            text: 'osdTextElementOsdProfileName'
            desc: 'osdDescElementOsdProfileName'
            default_position: -1
            draw_order: 440
            positionable: true
            preview: 'OSD_1'
        RSSI_DBM_VALUE:
            name: 'OSD_PROFILE_NAME'
            text: 'osdTextElementRssiDbmValue'
            desc: 'osdDescElementRssiDbmValue'
            default_position: -1
            draw_order: 395
            positionable: true
            preview: FONT.symbol(SYM.RSSI) + '-130'
    return

OSD.constants =
    VISIBLE: 0x0800
    VIDEO_TYPES: [
        'AUTO'
        'PAL'
        'NTSC'
    ]
    VIDEO_LINES:
        PAL: 16
        NTSC: 13
    VIDEO_BUFFER_CHARS:
        PAL: 480
        NTSC: 390
    UNIT_TYPES: [
        'IMPERIAL'
        'METRIC'
    ]
    TIMER_PRECISION: [
        'SECOND'
        'HUNDREDTH'
        'TENTH'
    ]
    AHISIDEBARWIDTHPOSITION: 7
    AHISIDEBARHEIGHTPOSITION: 3
    UNKNOWN_DISPLAY_FIELD:
        name: 'UNKNOWN'
        text: 'osdTextElementUnknown'
        desc: 'osdDescElementUnknown'
        default_position: -1
        positionable: true
        preview: 'UNKNOWN '
    ALL_STATISTIC_FIELDS:
        MAX_SPEED:
            name: 'MAX_SPEED'
            text: 'osdTextStatMaxSpeed'
            desc: 'osdDescStatMaxSpeed'
        MIN_BATTERY:
            name: 'MIN_BATTERY'
            text: 'osdTextStatMinBattery'
            desc: 'osdDescStatMinBattery'
        MIN_RSSI:
            name: 'MIN_RSSI'
            text: 'osdTextStatMinRssi'
            desc: 'osdDescStatMinRssi'
        MAX_CURRENT:
            name: 'MAX_CURRENT'
            text: 'osdTextStatMaxCurrent'
            desc: 'osdDescStatMaxCurrent'
        USED_MAH:
            name: 'USED_MAH'
            text: 'osdTextStatUsedMah'
            desc: 'osdDescStatUsedMah'
        MAX_ALTITUDE:
            name: 'MAX_ALTITUDE'
            text: 'osdTextStatMaxAltitude'
            desc: 'osdDescStatMaxAltitude'
        BLACKBOX:
            name: 'BLACKBOX'
            text: 'osdTextStatBlackbox'
            desc: 'osdDescStatBlackbox'
        END_BATTERY:
            name: 'END_BATTERY'
            text: 'osdTextStatEndBattery'
            desc: 'osdDescStatEndBattery'
        FLYTIME:
            name: 'FLY_TIME'
            text: 'osdTextStatFlyTime'
            desc: 'osdDescStatFlyTime'
        ARMEDTIME:
            name: 'ARMED_TIME'
            text: 'osdTextStatArmedTime'
            desc: 'osdDescStatArmedTime'
        MAX_DISTANCE:
            name: 'MAX_DISTANCE'
            text: 'osdTextStatMaxDistance'
            desc: 'osdDescStatMaxDistance'
        BLACKBOX_LOG_NUMBER:
            name: 'BLACKBOX_LOG_NUMBER'
            text: 'osdTextStatBlackboxLogNumber'
            desc: 'osdDescStatBlackboxLogNumber'
        TIMER_1:
            name: 'TIMER_1'
            text: 'osdTextStatTimer1'
            desc: 'osdDescStatTimer1'
        TIMER_2:
            name: 'TIMER_2'
            text: 'osdTextStatTimer2'
            desc: 'osdDescStatTimer2'
        RTC_DATE_TIME:
            name: 'RTC_DATE_TIME'
            text: 'osdTextStatRtcDateTime'
            desc: 'osdDescStatRtcDateTime'
        STAT_BATTERY:
            name: 'BATTERY_VOLTAGE'
            text: 'osdTextStatBattery'
            desc: 'osdDescStatBattery'
        MAX_G_FORCE:
            name: 'MAX_G_FORCE'
            text: 'osdTextStatGForce'
            desc: 'osdDescStatGForce'
        MAX_ESC_TEMP:
            name: 'MAX_ESC_TEMP'
            text: 'osdTextStatEscTemperature'
            desc: 'osdDescStatEscTemperature'
        MAX_ESC_RPM:
            name: 'MAX_ESC_RPM'
            text: 'osdTextStatEscRpm'
            desc: 'osdDescStatEscRpm'
        MIN_LINK_QUALITY:
            name: 'MIN_LINK_QUALITY'
            text: 'osdTextStatMinLinkQuality'
            desc: 'osdDescStatMinLinkQuality'
        FLIGHT_DISTANCE:
            name: 'FLIGHT_DISTANCE'
            text: 'osdTextStatFlightDistance'
            desc: 'osdTextStatFlightDistance'
        MAX_FFT:
            name: 'MAX_FFT'
            text: 'osdTextStatMaxFFT'
            desc: 'osdDescStatMaxFFT'
        TOTAL_FLIGHTS:
            name: 'TOTAL_FLIGHTS'
            text: 'osdTextStatTotalFlights'
            desc: 'osdDescStatTotalFlights'
        TOTAL_FLIGHT_TIME:
            name: 'TOTAL_FLIGHT_TIME'
            text: 'osdTextStatTotalFlightTime'
            desc: 'osdDescStatTotalFlightTime'
        TOTAL_FLIGHT_DIST:
            name: 'TOTAL_FLIGHT_DIST'
            text: 'osdTextStatTotalFlightDistance'
            desc: 'osdDescStatTotalFlightDistance'
        MIN_RSSI_DBM:
            name: 'MIN_RSSI_DBM'
            text: 'osdTextStatMinRssiDbm'
            desc: 'osdDescStatMinRssiDbm'
    ALL_WARNINGS:
        ARMING_DISABLED:
            name: 'ARMING_DISABLED'
            text: 'osdWarningTextArmingDisabled'
            desc: 'osdWarningArmingDisabled'
        BATTERY_NOT_FULL:
            name: 'BATTERY_NOT_FULL'
            text: 'osdWarningTextBatteryNotFull'
            desc: 'osdWarningBatteryNotFull'
        BATTERY_WARNING:
            name: 'BATTERY_WARNING'
            text: 'osdWarningTextBatteryWarning'
            desc: 'osdWarningBatteryWarning'
        BATTERY_CRITICAL:
            name: 'BATTERY_CRITICAL'
            text: 'osdWarningTextBatteryCritical'
            desc: 'osdWarningBatteryCritical'
        VISUAL_BEEPER:
            name: 'VISUAL_BEEPER'
            text: 'osdWarningTextVisualBeeper'
            desc: 'osdWarningVisualBeeper'
        CRASH_FLIP_MODE:
            name: 'CRASH_FLIP_MODE'
            text: 'osdWarningTextCrashFlipMode'
            desc: 'osdWarningCrashFlipMode'
        ESC_FAIL:
            name: 'ESC_FAIL'
            text: 'osdWarningTextEscFail'
            desc: 'osdWarningEscFail'
        CORE_TEMPERATURE:
            name: 'CORE_TEMPERATURE'
            text: 'osdWarningTextCoreTemperature'
            desc: 'osdWarningCoreTemperature'
        RC_SMOOTHING_FAILURE:
            name: 'RC_SMOOTHING_FAILURE'
            text: 'osdWarningTextRcSmoothingFailure'
            desc: 'osdWarningRcSmoothingFailure'
        FAILSAFE:
            name: 'FAILSAFE'
            text: 'osdWarningTextFailsafe'
            desc: 'osdWarningFailsafe'
        LAUNCH_CONTROL:
            name: 'LAUNCH_CONTROL'
            text: 'osdWarningTextLaunchControl'
            desc: 'osdWarningLaunchControl'
        GPS_RESCUE_UNAVAILABLE:
            name: 'GPS_RESCUE_UNAVAILABLE'
            text: 'osdWarningTextGpsRescueUnavailable'
            desc: 'osdWarningGpsRescueUnavailable'
        GPS_RESCUE_DISABLED:
            name: 'GPS_RESCUE_DISABLED'
            text: 'osdWarningTextGpsRescueDisabled'
            desc: 'osdWarningGpsRescueDisabled'
        RSSI:
            name: 'RSSI'
            text: 'osdWarningTextRSSI'
            desc: 'osdWarningRSSI'
        LINK_QUALITY:
            name: 'LINK_QUALITY'
            text: 'osdWarningTextLinkQuality'
            desc: 'osdWarningLinkQuality'
        RSSI_DBM:
            name: 'RSSI_DBM'
            text: 'osdWarningTextRssiDbm'
            desc: 'osdWarningRssiDbm'
    FONT_TYPES: [
        {
            file: 'default'
            name: 'Default'
        }
        {
            file: 'bold'
            name: 'Bold'
        }
        {
            file: 'large'
            name: 'Large'
        }
        {
            file: 'extra_large'
            name: 'Extra Large'
        }
        {
            file: 'orniflight'
            name: 'OrniFlight'
        }
        {
            file: 'digital'
            name: 'Digital'
        }
        {
            file: 'clarity'
            name: 'Clarity'
        }
        {
            file: 'vision'
            name: 'Vision'
        }
        {
            file: 'impact'
            name: 'Impact'
        }
        {
            file: 'impact_mini'
            name: 'Impact Mini'
        }
    ]

OSD.searchLimitsElement = (arrayElements) ->
    # Search minimum and maximum
    limits = 
        minX: 0
        maxX: 0
        minY: 0
        maxY: 0
    if arrayElements.length == 0
        return limits
    if arrayElements[0].constructor == String
        limits.maxY = arrayElements.length
        limits.minY = 0
        limits.minX = 0
        arrayElements.forEach (valor, indice, array) ->
            limits.maxX = Math.max(valor.length, limits.maxX)
            return
    else
        arrayElements.forEach (valor, indice, array) ->
            limits.minX = Math.min(valor.x, limits.minX)
            limits.maxX = Math.max(valor.x, limits.maxX)
            limits.minY = Math.min(valor.y, limits.minY)
            limits.maxY = Math.max(valor.y, limits.maxY)
            return
    limits

# Pick display fields by version, order matters, so these are going in an array... pry could iterate the example map instead

OSD.chooseFields = ->
    F = OSD.ALL_DISPLAY_FIELDS
    # version 3.0.1
    if semver.gte(CONFIG.apiVersion, '1.21.0')
        OSD.constants.DISPLAY_FIELDS = [
            F.RSSI_VALUE
            F.MAIN_BATT_VOLTAGE
            F.CROSSHAIRS
            F.ARTIFICIAL_HORIZON
            F.HORIZON_SIDEBARS
        ]
        if semver.lt(CONFIG.apiVersion, '1.36.0')
            OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                F.ONTIME
                F.FLYTIME
            ])
        else
            OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                F.TIMER_1
                F.TIMER_2
            ])
        OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
            F.FLYMODE
            F.CRAFT_NAME
            F.THROTTLE_POSITION
            F.VTX_CHANNEL
            F.CURRENT_DRAW
            F.MAH_DRAWN
            F.GPS_SPEED
            F.GPS_SATS
            F.ALTITUDE
        ])
        if semver.gte(CONFIG.apiVersion, '1.31.0')
            OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                F.PID_ROLL
                F.PID_PITCH
                F.PID_YAW
                F.POWER
            ])
            if semver.gte(CONFIG.apiVersion, '1.32.0')
                OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                    F.PID_RATE_PROFILE
                    if semver.gte(CONFIG.apiVersion, '1.36.0') then F.WARNINGS else F.BATTERY_WARNING
                    F.AVG_CELL_VOLTAGE
                ])
                if semver.gte(CONFIG.apiVersion, '1.34.0')
                    OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                        F.GPS_LON
                        F.GPS_LAT
                        F.DEBUG
                    ])
                    if semver.gte(CONFIG.apiVersion, '1.35.0')
                        OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                            F.PITCH_ANGLE
                            F.ROLL_ANGLE
                        ])
                        if semver.gte(CONFIG.apiVersion, '1.36.0')
                            OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                                F.MAIN_BATT_USAGE
                                F.DISARMED
                                F.HOME_DIR
                                F.HOME_DIST
                                F.NUMERICAL_HEADING
                                F.NUMERICAL_VARIO
                                F.COMPASS_BAR
                                F.ESC_TEMPERATURE
                                F.ESC_RPM
                            ])
                            if semver.gte(CONFIG.apiVersion, '1.37.0')
                                OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                                    F.REMAINING_TIME_ESTIMATE
                                    F.RTC_DATE_TIME
                                    F.ADJUSTMENT_RANGE
                                    F.CORE_TEMPERATURE
                                ])
                                if semver.gte(CONFIG.apiVersion, '1.39.0')
                                    OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([ F.ANTI_GRAVITY ])
                                    if semver.gte(CONFIG.apiVersion, '1.40.0')
                                        OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([ F.G_FORCE ])
                                        if semver.gte(CONFIG.apiVersion, '1.41.0')
                                            OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                                                F.MOTOR_DIAG
                                                F.LOG_STATUS
                                                F.FLIP_ARROW
                                                F.LINK_QUALITY
                                                F.FLIGHT_DIST
                                                F.STICK_OVERLAY_LEFT
                                                F.STICK_OVERLAY_RIGHT
                                                F.DISPLAY_NAME
                                                F.ESC_RPM_FREQ
                                            ])
                                            if semver.gte(CONFIG.apiVersion, '1.42.0')
                                                OSD.constants.DISPLAY_FIELDS = OSD.constants.DISPLAY_FIELDS.concat([
                                                    F.RATE_PROFILE_NAME
                                                    F.PID_PROFILE_NAME
                                                    F.OSD_PROFILE_NAME
                                                    F.RSSI_DBM_VALUE
                                                ])
    else
        OSD.constants.DISPLAY_FIELDS = [
            F.MAIN_BATT_VOLTAGE
            F.RSSI_VALUE
            F.TIMER
            F.THROTTLE_POSITION
            F.CPU_LOAD
            F.VTX_CHANNEL
            F.VOLTAGE_WARNING
            F.ARMED
            F.DISARMED
            F.ARTIFICIAL_HORIZON
            F.HORIZON_SIDEBARS
            F.CURRENT_DRAW
            F.MAH_DRAWN
            F.CRAFT_NAME
            F.ALTITUDE
        ]
    # Choose statistic fields
    # Nothing much to do here, I'm preempting there being new statistics
    F = OSD.constants.ALL_STATISTIC_FIELDS
    # ** IMPORTANT **
    #
    # Starting with 1.39.0 (firmware 3.4) the OSD stats selection options
    # are ordered in the same sequence as displayed on-screen in the OSD.
    # If future versions of the firmware implement changes to the on-screen ordering,
    # that needs to be implemented here as well. Simply appending new stats does not
    # require a completely new section for the version - only reordering.
    if semver.lt(CONFIG.apiVersion, '1.39.0')
        OSD.constants.STATISTIC_FIELDS = [
            F.MAX_SPEED
            F.MIN_BATTERY
            F.MIN_RSSI
            F.MAX_CURRENT
            F.USED_MAH
            F.MAX_ALTITUDE
            F.BLACKBOX
            F.END_BATTERY
            F.TIMER_1
            F.TIMER_2
            F.MAX_DISTANCE
            F.BLACKBOX_LOG_NUMBER
        ]
        if semver.gte(CONFIG.apiVersion, '1.37.0')
            OSD.constants.STATISTIC_FIELDS = OSD.constants.STATISTIC_FIELDS.concat([ F.RTC_DATE_TIME ])
    else
        # Starting with 1.39.0 OSD stats are reordered to match how they're presented on screen
        OSD.constants.STATISTIC_FIELDS = [
            F.RTC_DATE_TIME
            F.TIMER_1
            F.TIMER_2
            F.MAX_SPEED
            F.MAX_DISTANCE
            F.MIN_BATTERY
            F.END_BATTERY
            F.STAT_BATTERY
            F.MIN_RSSI
            F.MAX_CURRENT
            F.USED_MAH
            F.MAX_ALTITUDE
            F.BLACKBOX
            F.BLACKBOX_LOG_NUMBER
        ]
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            OSD.constants.STATISTIC_FIELDS = OSD.constants.STATISTIC_FIELDS.concat([
                F.MAX_G_FORCE
                F.MAX_ESC_TEMP
                F.MAX_ESC_RPM
                F.MIN_LINK_QUALITY
                F.FLIGHT_DISTANCE
                F.MAX_FFT
            ])
        if semver.gte(CONFIG.apiVersion, '1.42.0')
            OSD.constants.STATISTIC_FIELDS = OSD.constants.STATISTIC_FIELDS.concat([
                F.TOTAL_FLIGHTS
                F.TOTAL_FLIGHT_TIME
                F.TOTAL_FLIGHT_DIST
                F.MIN_RSSI_DBM
            ])
    # Choose warnings
    # Nothing much to do here, I'm preempting there being new warnings
    F = OSD.constants.ALL_WARNINGS
    OSD.constants.WARNINGS = [
        F.ARMING_DISABLED
        F.BATTERY_NOT_FULL
        F.BATTERY_WARNING
        F.BATTERY_CRITICAL
        F.VISUAL_BEEPER
        F.CRASH_FLIP_MODE
    ]
    if semver.gte(CONFIG.apiVersion, '1.39.0')
        OSD.constants.WARNINGS = OSD.constants.WARNINGS.concat([
            F.ESC_FAIL
            F.CORE_TEMPERATURE
            F.RC_SMOOTHING_FAILURE
        ])
    if semver.gte(CONFIG.apiVersion, '1.41.0')
        OSD.constants.WARNINGS = OSD.constants.WARNINGS.concat([
            F.FAILSAFE
            F.LAUNCH_CONTROL
            F.GPS_RESCUE_UNAVAILABLE
            F.GPS_RESCUE_DISABLED
        ])
    OSD.constants.TIMER_TYPES = [
        'ON_TIME'
        'TOTAL_ARMED_TIME'
        'LAST_ARMED_TIME'
    ]
    if semver.gte(CONFIG.apiVersion, '1.42.0')
        OSD.constants.TIMER_TYPES = OSD.constants.TIMER_TYPES.concat([ 'ON_ARM_TIME' ])
        OSD.constants.WARNINGS = OSD.constants.WARNINGS.concat([
            F.RSSI
            F.LINK_QUALITY
            F.RSSI_DBM
        ])
    return

OSD.updateDisplaySize = ->
    video_type = OSD.constants.VIDEO_TYPES[OSD.data.video_system]
    if video_type == 'AUTO'
        video_type = 'PAL'
    # compute the size
    OSD.data.display_size =
        x: FONT.constants.SIZES.LINE
        y: OSD.constants.VIDEO_LINES[video_type]
        total: null
    return

OSD.drawByOrder = (selectedPosition, field, charCode, x, y) ->
    # Check if there is other field at the same position
    if OSD.data.preview[selectedPosition] != undefined
        oldField = OSD.data.preview[selectedPosition][0]
        if oldField != null
            if oldField.draw_order != undefined
                if field.draw_order == undefined or field.draw_order < oldField.draw_order
                    # Not overwrite old field
                    return
        # Default action, overwrite old field
        OSD.data.preview[selectedPosition++] = [
            field
            charCode
            x
            y
        ]
    return

OSD.msp =
    helpers:
        unpack:
            position: (bits, c) ->
                display_item = {}
                positionable = if typeof c.positionable == 'function' then c.positionable() else c.positionable
                default_position = if typeof c.default_position == 'function' then c.default_position() else c.default_position
                display_item.positionable = positionable
                if semver.gte(CONFIG.apiVersion, '1.21.0')
                    # size * y + x
                    display_item.position = if positionable then FONT.constants.SIZES.LINE * (bits >> 5 & 0x001F) + (bits & 0x001F) else default_position
                    display_item.isVisible = []
                    osd_profile = 0
                    while osd_profile < OSD.getNumberOfProfiles()
                        display_item.isVisible[osd_profile] = (bits & OSD.constants.VISIBLE << osd_profile) != 0
                        osd_profile++
                else
                    display_item.position = if bits == -1 then default_position else bits
                    display_item.isVisible = [ bits != -1 ]
                display_item
            timer: (bits, c) ->
                timer = 
                    src: bits & 0x0F
                    precision: bits >> 4 & 0x0F
                    alarm: bits >> 8 & 0xFF
                timer
        pack:
            position: (display_item) ->
                isVisible = display_item.isVisible
                position = display_item.position
                if semver.gte(CONFIG.apiVersion, '1.21.0')
                    packed_visible = 0
                    osd_profile = 0
                    while osd_profile < OSD.getNumberOfProfiles()
                        packed_visible |= if isVisible[osd_profile] then OSD.constants.VISIBLE << osd_profile else 0
                        osd_profile++
                    packed_visible | (position / FONT.constants.SIZES.LINE & 0x001F) << 5 | position % FONT.constants.SIZES.LINE
                else
                    if isVisible[0] then (if position == -1 then 0 else position) else -1
            timer: (_timer) ->
                _timer.src & 0x0F | (_timer.precision & 0x0F) << 4 | (_timer.alarm & 0xFF) << 8
    encodeOther: ->
        result = [
            -1
            OSD.data.video_system
        ]
        if OSD.data.state.haveOsdFeature and semver.gte(CONFIG.apiVersion, '1.21.0')
            result.push8 OSD.data.unit_mode
            # watch out, order matters! match the firmware
            result.push8 OSD.data.alarms.rssi.value
            result.push16 OSD.data.alarms.cap.value
            if semver.lt(CONFIG.apiVersion, '1.36.0')
                result.push16 OSD.data.alarms.time.value
            else
                # This value is unused by the firmware with configurable timers
                result.push16 0
            result.push16 OSD.data.alarms.alt.value
            if semver.gte(CONFIG.apiVersion, '1.37.0')
                warningFlags = 0
                i = 0
                while i < OSD.data.warnings.length
                    if OSD.data.warnings[i].enabled
                        warningFlags |= 1 << i
                    i++
                console.log warningFlags
                result.push16 warningFlags
                if semver.gte(CONFIG.apiVersion, '1.41.0')
                    result.push32 warningFlags
                    result.push8 OSD.data.osd_profiles.selected + 1
        result
    encodeLayout: (display_item) ->
        buffer = []
        buffer.push8 display_item.index
        buffer.push16 @helpers.pack.position(display_item)
        buffer
    encodeStatistics: (stat_item) ->
        buffer = []
        buffer.push8 stat_item.index
        buffer.push16 stat_item.enabled
        buffer.push8 0
        buffer
    encodeTimer: (timer) ->
        buffer = [
            -2
            timer.index
        ]
        buffer.push16 @helpers.pack.timer(timer)
        buffer
    decode: (payload) ->
        `var v`
        `var i`
        `var j`
        view = payload.data
        d = OSD.data
        displayItemsCountActual = OSD.constants.DISPLAY_FIELDS.length
        d.flags = view.readU8()
        if d.flags > 0
            if payload.length > 1
                d.video_system = view.readU8()
                if semver.gte(CONFIG.apiVersion, '1.21.0') and bit_check(d.flags, 0)
                    d.unit_mode = view.readU8()
                    d.alarms = {}
                    d.alarms['rssi'] =
                        display_name: i18n.getMessage('osdTimerAlarmOptionRssi')
                        value: view.readU8()
                    d.alarms['cap'] =
                        display_name: i18n.getMessage('osdTimerAlarmOptionCapacity')
                        value: view.readU16()
                    if semver.lt(CONFIG.apiVersion, '1.36.0')
                        d.alarms['time'] =
                            display_name: 'Minutes'
                            value: view.readU16()
                    else
                        # This value was obsoleted by the introduction of configurable timers, and has been reused to encode the number of display elements sent in this command
                        view.readU8()
                        tmp = view.readU8()
                        if semver.gte(CONFIG.apiVersion, '1.37.0')
                            displayItemsCountActual = tmp
                    d.alarms['alt'] =
                        display_name: i18n.getMessage('osdTimerAlarmOptionAltitude')
                        value: view.readU16()
        d.state = {}
        d.state.haveSomeOsd = d.flags != 0
        d.state.haveMax7456Video = bit_check(d.flags, 4) or d.flags == 1 and semver.lt(CONFIG.apiVersion, '1.34.0')
        d.state.haveOsdFeature = bit_check(d.flags, 0) or d.flags == 1 and semver.lt(CONFIG.apiVersion, '1.34.0')
        d.state.isOsdSlave = bit_check(d.flags, 1) and semver.gte(CONFIG.apiVersion, '1.34.0')
        d.display_items = []
        d.stat_items = []
        d.warnings = []
        d.timers = []
        # Read display element positions, the parsing is done later because we need the number of profiles
        items_positions_read = []
        while view.offset < view.byteLength and items_positions_read.length < displayItemsCountActual
            v = null
            if semver.gte(CONFIG.apiVersion, '1.21.0')
                v = view.readU16()
            else
                v = view.read16()
            items_positions_read.push v
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            # Parse statistics display enable
            expectedStatsCount = view.readU8()
            if expectedStatsCount != OSD.constants.STATISTIC_FIELDS.length
                console.error 'Firmware is transmitting a different number of statistics (' + expectedStatsCount + ') to what the configurator is expecting (' + OSD.constants.STATISTIC_FIELDS.length + ')'
            i = 0
            while i < expectedStatsCount
                _v = view.readU8()
                # Known statistics field
                if i < OSD.constants.STATISTIC_FIELDS.length
                    _c = OSD.constants.STATISTIC_FIELDS[i]
                    d.stat_items.push
                        name: _c.name
                        text: _c.text
                        desc: _c.desc
                        index: i
                        enabled: _v == 1
                    # Read all the data for any statistics we don't know about
                else
                    statisticNumber = i - (OSD.constants.STATISTIC_FIELDS.length) + 1
                    d.stat_items.push
                        name: 'UNKNOWN'
                        text: [
                            'osdTextStatUnknown'
                            statisticNumber
                        ]
                        desc: 'osdDescStatUnknown'
                        index: i
                        enabled: _v == 1
                i++
            # Parse configurable timers
            expectedTimersCount = view.readU8()
            while view.offset < view.byteLength and expectedTimersCount > 0
                v = view.readU16()
                j = d.timers.length
                d.timers.push $.extend({ index: j }, @helpers.unpack.timer(v, c))
                expectedTimersCount--
            # Read all the data for any timers we don't know about
            while expectedTimersCount > 0
                view.readU16()
                expectedTimersCount--
            # Parse enabled warnings
            warningCount = OSD.constants.WARNINGS.length
            warningFlags = view.readU16()
            if semver.gte(CONFIG.apiVersion, '1.41.0')
                warningCount = view.readU8()
                # the flags were replaced with a 32bit version
                warningFlags = view.readU32()
            i = 0
            while i < warningCount
                # Known warning field
                if i < OSD.constants.WARNINGS.length
                    d.warnings.push $.extend(OSD.constants.WARNINGS[i], enabled: (warningFlags & 1 << i) != 0)
                    # Push Unknown Warning field
                else
                    warningNumber = i - (OSD.constants.WARNINGS.length) + 1
                    d.warnings.push
                        name: 'UNKNOWN'
                        text: [
                            'osdWarningTextUnknown'
                            warningNumber
                        ]
                        desc: 'osdWarningUnknown'
                        enabled: (warningFlags & 1 << i) != 0
                i++
        # OSD profiles
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            d.osd_profiles.number = view.readU8()
            d.osd_profiles.selected = view.readU8() - 1
        else
            d.osd_profiles.number = 1
            d.osd_profiles.selected = 0
        # Now we have the number of profiles, process the OSD elements
        _j = 0
        while _j < items_positions_read.length
            item = items_positions_read[_j]
            j = d.display_items.length
            c = undefined
            suffix = undefined
            ignoreSize = false
            if d.display_items.length < OSD.constants.DISPLAY_FIELDS.length
                c = OSD.constants.DISPLAY_FIELDS[j]
            else
                c = OSD.constants.UNKNOWN_DISPLAY_FIELD
                suffix = '' + 1 + d.display_items.length - (OSD.constants.DISPLAY_FIELDS.length)
                ignoreSize = true
            d.display_items.push $.extend({
                name: c.name
                text: if suffix then [
                    c.text
                    suffix
                ] else c.text
                desc: c.desc
                index: j
                draw_order: c.draw_order
                preview: if suffix then c.preview + suffix else c.preview
                ignoreSize: ignoreSize
            }, @helpers.unpack.position(item, c))
            _j++
        # Generate OSD element previews and positionable that are defined by a function
        _iterator = _createForOfIteratorHelper(d.display_items)
        _step = undefined
        try
            _iterator.s()
            while !(_step = _iterator.n()).done
                _item = _step.value
                if typeof _item.preview == 'function'
                    _item.preview = _item.preview(d)
        catch err
            _iterator.e err
        finally
            _iterator.f()
        OSD.updateDisplaySize()
        return
OSD.GUI = {}
OSD.GUI.preview =
    onMouseEnter: ->
        if !$(this).data('field')
            return
        $('#element-fields .field-' + $(this).data('field').index).addClass 'mouseover'
        return
    onMouseLeave: ->
        if !$(this).data('field')
            return
        $('#element-fields .field-' + $(this).data('field').index).removeClass 'mouseover'
        return
    onDragStart: (e) ->
        ev = e.originalEvent
        display_item = OSD.data.display_items[$(ev.target).data('field').index]
        xPos = ev.currentTarget.dataset.x
        yPos = ev.currentTarget.dataset.y
        offsetX = 6
        offsetY = 9
        if display_item.preview.constructor == Array
            arrayElements = display_item.preview
            limits = OSD.searchLimitsElement(arrayElements)
            xPos -= limits.minX
            yPos -= limits.minY
            offsetX += xPos * 12
            offsetY += yPos * 18
        ev.dataTransfer.setData 'text/plain', $(ev.target).data('field').index
        ev.dataTransfer.setData 'x', ev.currentTarget.dataset.x
        ev.dataTransfer.setData 'y', ev.currentTarget.dataset.y
        ev.dataTransfer.setDragImage $(this).data('field').preview_img, offsetX, offsetY
        return
    onDragOver: (e) ->
        ev = e.originalEvent
        ev.preventDefault()
        ev.dataTransfer.dropEffect = 'move'
        $(this).css background: 'rgba(0,0,0,.5)'
        return
    onDragLeave: (e) ->
        # brute force un-styling on drag leave
        $(this).removeAttr 'style'
        return
    onDrop: (e) ->
        ev = e.originalEvent
        field_id = parseInt(ev.dataTransfer.getData('text/plain'))
        display_item = OSD.data.display_items[field_id]
        position = $(this).removeAttr('style').data('position')
        cursor = position
        cursorX = cursor % FONT.constants.SIZES.LINE
        if display_item.preview.constructor == Array
            console.log 'Initial Drop Position: ' + position
            x = parseInt(ev.dataTransfer.getData('x'))
            y = parseInt(ev.dataTransfer.getData('y'))
            console.log 'XY Co-ords:' + x + '-' + y
            position -= x
            position -= y * FONT.constants.SIZES.LINE
            console.log 'Calculated Position: ' + position
        if !display_item.ignoreSize
            if display_item.preview.constructor != Array
                # Standard preview, string type
                overflows_line = FONT.constants.SIZES.LINE - (position % FONT.constants.SIZES.LINE + display_item.preview.length)
                if overflows_line < 0
                    position += overflows_line
            else
                # Advanced preview, array type
                arrayElements = display_item.preview
                limits = OSD.searchLimitsElement(arrayElements)
                selectedPositionX = position % FONT.constants.SIZES.LINE
                selectedPositionY = Math.trunc(position / FONT.constants.SIZES.LINE)
                if arrayElements[0].constructor == String
                    if position < 0
                        return
                    if selectedPositionX > cursorX
                        # TRUE -> Detected wrap around
                        position += FONT.constants.SIZES.LINE - selectedPositionX
                        selectedPositionY++
                    else if selectedPositionX + limits.maxX > FONT.constants.SIZES.LINE
                        # TRUE -> right border of the element went beyond left edge of screen.
                        position -= selectedPositionX + limits.maxX - (FONT.constants.SIZES.LINE)
                    if selectedPositionY < 0
                        position += Math.abs(selectedPositionY) * FONT.constants.SIZES.LINE
                    else if selectedPositionY + limits.maxY > OSD.data.display_size.y
                        position -= (selectedPositionY + limits.maxY - (OSD.data.display_size.y)) * FONT.constants.SIZES.LINE
                else
                    if limits.minX < 0 and selectedPositionX + limits.minX < 0
                        position += Math.abs(selectedPositionX + limits.minX)
                    else if limits.maxX > 0 and selectedPositionX + limits.maxX >= FONT.constants.SIZES.LINE
                        position -= selectedPositionX + limits.maxX + 1 - (FONT.constants.SIZES.LINE)
                    if limits.minY < 0 and selectedPositionY + limits.minY < 0
                        position += Math.abs(selectedPositionY + limits.minY) * FONT.constants.SIZES.LINE
                    else if limits.maxY > 0 and selectedPositionY + limits.maxY >= OSD.data.display_size.y
                        position -= (selectedPositionY + limits.maxY - (OSD.data.display_size.y) + 1) * FONT.constants.SIZES.LINE
        if semver.gte(CONFIG.apiVersion, '1.21.0')
            # unsigned now
        else
            if position > OSD.data.display_size.total / 2
                position = position - (OSD.data.display_size.total)
        $('input.' + field_id + '.position').val(position).change()
        return
TABS.osd = {}

TABS.osd.initialize = (callback) ->
    self = this
    if GUI.active_tab != 'osd'
        GUI.active_tab = 'osd'
    $('#content').load './tabs/osd.html', ->
        # Prepare symbols depending on the version

        titleizeField = (field) ->
            finalFieldName = null
            if field.text
                if Array.isArray(field.text) and i18n.existsMessage(field.text[0])
                    finalFieldName = i18n.getMessage(field.text[0], field.text.slice(1))
                else
                    finalFieldName = i18n.getMessage(field.text)
            finalFieldName

        insertOrdered = (fieldList, field) ->
            if field.name == 'UNKNOWN'
                fieldList.append field
            else
                added = false
                currentLocale = i18n.getCurrentLocale().replace('_', '-')
                fieldList.children().each ->
                    if $(this).text().localeCompare(field.text(), currentLocale, sensitivity: 'base') > 0
                        $(this).before field
                        added = true
                        return false
                    return
                if !added
                    fieldList.append field
            return

        # 2 way binding... sorta

        updateOsdView = ->
            # ask for the OSD config data
            MSP.promise(MSPCodes.MSP_OSD_CONFIG).then (info) ->
                `var i`
                `var type`
                `var $checkbox`
                `var alarm`
                `var $field`
                `var desc`
                `var $field`
                `var desc`
                `var i`
                `var i`
                `var i`
                `var charCode`
                `var img`
                `var charCode`
                `var img`
                `var i`
                `var charCode`
                `var charCode`
                OSD.chooseFields()
                OSD.msp.decode info
                if OSD.data.state.haveSomeOsd == 0
                    $('.unsupported').fadeIn()
                    return
                $('.supported').fadeIn()
                # video mode
                $videoTypes = $('.video-types').empty()
                i = 0
                while i < OSD.constants.VIDEO_TYPES.length
                    type = OSD.constants.VIDEO_TYPES[i]
                    $checkbox = $('<label/>').append($('<input name="video_system" type="radio"/>' + i18n.getMessage('osdSetupVideoFormatOption' + inflection.camelize(type.toLowerCase())) + '</label>').prop('checked', i == OSD.data.video_system).data('type', type).data('type', i))
                    $videoTypes.append $checkbox
                    i++
                $videoTypes.find(':radio').click (e) ->
                    OSD.data.video_system = $(this).data('type')
                    MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeOther()).then ->
                        updateOsdView()
                        return
                    return
                if semver.gte(CONFIG.apiVersion, '1.21.0')
                    # units
                    $('.units-container').show()
                    $unitMode = $('.units').empty()
                    i = 0
                    while i < OSD.constants.UNIT_TYPES.length
                        type = OSD.constants.UNIT_TYPES[i]
                        $checkbox = $('<label/>').append($('<input name="unit_mode" type="radio"/>' + i18n.getMessage('osdSetupUnitsOption' + inflection.camelize(type.toLowerCase())) + '</label>').prop('checked', i == OSD.data.unit_mode).data('type', type).data('type', i))
                        $unitMode.append $checkbox
                        i++
                    $unitMode.find(':radio').click (e) ->
                        OSD.data.unit_mode = $(this).data('type')
                        MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeOther()).then ->
                            updateOsdView()
                            return
                        return
                    # alarms
                    $('.alarms-container').show()
                    $alarms = $('.alarms').empty()
                    for k of OSD.data.alarms
                        alarm = OSD.data.alarms[k]
                        alarmInput = $('<input name="alarm" type="number" id="' + k + '"/>' + alarm.display_name + '</label>')
                        alarmInput.val alarm.value
                        alarmInput.focusout (e) ->
                            OSD.data.alarms[$(this)[0].id].value = $(this)[0].value
                            MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeOther()).then ->
                                updateOsdView()
                                return
                            return
                        $input = $('<label/>').append(alarmInput)
                        $alarms.append $input
                    if semver.gte(CONFIG.apiVersion, '1.36.0')
                        # Timers
                        $('.timers-container').show()
                        $timers = $('#timer-fields').empty()
                        _iterator2 = _createForOfIteratorHelper(OSD.data.timers)
                        _step2 = undefined
                        try
                            _iterator2.s()
                            while !(_step2 = _iterator2.n()).done
                                tim = _step2.value
                                $timerConfig = $('<div class="switchable-field field-' + tim.index + '"/>')
                                timerTable = $('<table />')
                                $timerConfig.append timerTable
                                timerTableRow = $('<tr />')
                                timerTable.append timerTableRow
                                # Timer number
                                timerTableRow.append '<td>' + tim.index + 1 + '</td>'
                                # Source
                                sourceTimerTableData = $('<td class="osd_tip"></td>')
                                sourceTimerTableData.attr 'title', i18n.getMessage('osdTimerSourceTooltip')
                                sourceTimerTableData.append '<label for="timerSource_' + tim.index + '" class="char-label">' + i18n.getMessage('osdTimerSource') + '</label>'
                                src = $('<select class="timer-option" id="timerSource_' + tim.index + '"></select>')
                                OSD.constants.TIMER_TYPES.forEach (e, i) ->
                                    src.append '<option value="' + i + '">' + i18n.getMessage('osdTimerSourceOption' + inflection.camelize(e.toLowerCase())) + '</option>'
                                    return
                                src[0].selectedIndex = tim.src
                                src.blur (e) ->
                                    idx = $(this)[0].id.split('_')[1]
                                    OSD.data.timers[idx].src = $(this)[0].selectedIndex
                                    MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeTimer(OSD.data.timers[idx])).then ->
                                        updateOsdView()
                                        return
                                    return
                                sourceTimerTableData.append src
                                timerTableRow.append sourceTimerTableData
                                # Precision
                                timerTableRow = $('<tr />')
                                timerTable.append timerTableRow
                                precisionTimerTableData = $('<td class="osd_tip"></td>')
                                precisionTimerTableData.attr 'title', i18n.getMessage('osdTimerPrecisionTooltip')
                                precisionTimerTableData.append '<label for="timerPrec_' + tim.index + '" class="char-label">' + i18n.getMessage('osdTimerPrecision') + '</label>'
                                precision = $('<select class="timer-option osd_tip" id="timerPrec_' + tim.index + '"></select>')
                                OSD.constants.TIMER_PRECISION.forEach (e, i) ->
                                    precision.append '<option value="' + i + '">' + i18n.getMessage('osdTimerPrecisionOption' + inflection.camelize(e.toLowerCase())) + '</option>'
                                    return
                                precision[0].selectedIndex = tim.precision
                                precision.blur (e) ->
                                    idx = $(this)[0].id.split('_')[1]
                                    OSD.data.timers[idx].precision = $(this)[0].selectedIndex
                                    MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeTimer(OSD.data.timers[idx])).then ->
                                        updateOsdView()
                                        return
                                    return
                                precisionTimerTableData.append precision
                                timerTableRow.append '<td></td>'
                                timerTableRow.append precisionTimerTableData
                                # Alarm
                                timerTableRow = $('<tr />')
                                timerTable.append timerTableRow
                                alarmTimerTableData = $('<td class="osd_tip"></td>')
                                alarmTimerTableData.attr 'title', i18n.getMessage('osdTimerAlarmTooltip')
                                alarmTimerTableData.append '<label for="timerAlarm_' + tim.index + '" class="char-label">' + i18n.getMessage('osdTimerAlarm') + '</label>'
                                alarm = $('<input class="timer-option osd_tip" name="alarm" type="number" min=0 id="timerAlarm_' + tim.index + '"/>')
                                alarm[0].value = tim.alarm
                                alarm.blur (e) ->
                                    idx = $(this)[0].id.split('_')[1]
                                    OSD.data.timers[idx].alarm = $(this)[0].value
                                    MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeTimer(OSD.data.timers[idx])).then ->
                                        updateOsdView()
                                        return
                                    return
                                alarmTimerTableData.append alarm
                                timerTableRow.append '<td></td>'
                                timerTableRow.append alarmTimerTableData
                                $timers.append $timerConfig
                            # Post flight statistics
                        catch err
                            _iterator2.e err
                        finally
                            _iterator2.f()
                        $('.stats-container').show()
                        $statsFields = $('#post-flight-stat-fields').empty()
                        _iterator3 = _createForOfIteratorHelper(OSD.data.stat_items)
                        _step3 = undefined
                        try
                            _iterator3.s()
                            while !(_step3 = _iterator3.n()).done
                                _field = _step3.value
                                if !_field.name
                                    continue
                                $field = $('<div class="switchable-field field-' + _field.index + '"/>')
                                desc = null
                                if _field.desc and _field.desc.length
                                    desc = i18n.getMessage(_field.desc)
                                if desc and desc.length
                                    $field[0].classList.add 'osd_tip'
                                    $field.attr 'title', desc
                                $field.append $('<input type="checkbox" name="' + _field.name + '" class="togglesmall"></input>').data('field', _field).attr('checked', _field.enabled).change((e) ->
                                    field = $(this).data('field')
                                    field.enabled = !field.enabled
                                    MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeStatistics(field)).then ->
                                        updateOsdView()
                                        return
                                    return
                                )
                                $field.append '<label for="' + _field.name + '" class="char-label">' + titleizeField(_field) + '</label>'
                                # Insert in alphabetical order, with unknown fields at the end
                                insertOrdered $statsFields, $field
                            # Warnings
                        catch err
                            _iterator3.e err
                        finally
                            _iterator3.f()
                        $('.warnings-container').show()
                        $warningFields = $('#warnings-fields').empty()
                        _iterator4 = _createForOfIteratorHelper(OSD.data.warnings)
                        _step4 = undefined
                        try
                            _iterator4.s()
                            while !(_step4 = _iterator4.n()).done
                                _field2 = _step4.value
                                if !_field2.name
                                    continue
                                $field = $('<div class="switchable-field field-' + _field2.index + '"/>')
                                desc = null
                                if _field2.desc and _field2.desc.length
                                    desc = i18n.getMessage(_field2.desc)
                                if desc and desc.length
                                    $field[0].classList.add 'osd_tip'
                                    $field.attr 'title', desc
                                $field.append $('<input type="checkbox" name="' + _field2.name + '" class="togglesmall"></input>').data('field', _field2).attr('checked', _field2.enabled).change((e) ->
                                    field = $(this).data('field')
                                    field.enabled = !field.enabled
                                    MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeOther()).then ->
                                        updateOsdView()
                                        return
                                    return
                                )
                                finalFieldName = titleizeField(_field2)
                                $field.append '<label for="' + _field2.name + '" class="char-label">' + finalFieldName + '</label>'
                                # Insert in alphabetical order, with unknown fields at the end
                                insertOrdered $warningFields, $field
                        catch err
                            _iterator4.e err
                        finally
                            _iterator4.f()
                if !OSD.data.state.haveMax7456Video
                    $('.requires-max7456').hide()
                if !OSD.data.state.haveOsdFeature
                    $('.requires-osd-feature').hide()
                numberOfProfiles = OSD.getNumberOfProfiles()
                # Header for the switches
                headerSwitches_e = $('.elements').find('.osd-profiles-header')
                if headerSwitches_e.children().length == 0
                    profileNumber = 0
                    while profileNumber < numberOfProfiles
                        headerSwitches_e.append '<span class="profileOsdHeader">' + profileNumber + 1 + '</span>'
                        profileNumber++
                # Populate the profiles selector preview and current active
                osdProfileSelector_e = $('.osdprofile-selector')
                osdProfileActive_e = $('.osdprofile-active')
                if osdProfileSelector_e.children().length == 0
                    _profileNumber = 0
                    while _profileNumber < numberOfProfiles
                        optionText = i18n.getMessage('osdSetupPreviewSelectProfileElement', profileNumber: _profileNumber + 1)
                        osdProfileSelector_e.append new Option(optionText, _profileNumber)
                        osdProfileActive_e.append new Option(optionText, _profileNumber)
                        _profileNumber++
                # Select the current OSD profile
                osdProfileActive_e.val OSD.data.osd_profiles.selected
                # Populate the fonts selector preview
                osdFontSelector_e = $('.osdfont-selector')
                osdFontPresetsSelector_e = $('.fontpresets')
                if osdFontSelector_e.children().length == 0
                    # Custom font selected by the user
                    option = $('<option>',
                        text: i18n.getMessage('osdSetupFontPresetsSelectorCustomOption')
                        value: -1
                        'disabled': 'disabled'
                        'style': 'display: none;')
                    osdFontSelector_e.append $(option)
                    # Standard fonts
                    OSD.constants.FONT_TYPES.forEach (e, i) ->
                        `var optionText`
                        optionText = i18n.getMessage('osdSetupPreviewSelectFontElement', fontName: e.name)
                        osdFontSelector_e.append new Option(optionText, e.file)
                        return
                    osdFontSelector_e.change ->
                        # Change the font selected in the Font Manager, in this way it is easier to flash if the user likes it
                        osdFontPresetsSelector_e.val(@value).change()
                        return
                # Select the same element than the Font Manager window
                osdFontSelector_e.val if osdFontPresetsSelector_e.val() != null then osdFontPresetsSelector_e.val() else -1
                # Hide custom if not used
                $('.osdfont-selector option[value=-1]').toggle osdFontSelector_e.val() == -1
                # display fields on/off and position
                $displayFields = $('#element-fields').empty()
                enabledCount = 0
                _iterator5 = _createForOfIteratorHelper(OSD.data.display_items)
                _step5 = undefined
                try
                    _iterator5.s()
                    while !(_step5 = _iterator5.n()).done
                        _field3 = _step5.value
                        # versioning related, if the field doesn't exist at the current flight controller version, just skip it
                        if !_field3.name
                            continue
                        if _field3.isVisible[OSD.getCurrentPreviewProfile()]
                            enabledCount++
                        $field = $('<div class="switchable-field field-' + _field3.index + '"/>')
                        desc = null
                        if _field3.desc and _field3.desc.length
                            desc = i18n.getMessage(_field3.desc)
                        if desc and desc.length
                            $field[0].classList.add 'osd_tip'
                            $field.attr 'title', desc
                        osd_profile = 0
                        while osd_profile < OSD.getNumberOfProfiles()
                            $field.append $('<input type="checkbox" name="' + _field3.name + '"></input>').data('field', _field3).data('osd_profile', osd_profile).attr('checked', _field3.isVisible[osd_profile]).change((e) ->
                                field = $(this).data('field')
                                profile = $(this).data('osd_profile')
                                $position = $(this).parent().find('.position.' + field.name)
                                field.isVisible[profile] = !field.isVisible[profile]
                                if field.isVisible[OSD.getCurrentPreviewProfile()]
                                    $position.show()
                                else
                                    $position.hide()
                                MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeLayout(field)).then ->
                                    updateOsdView()
                                    return
                                return
                            )
                            osd_profile++
                        _finalFieldName = titleizeField(_field3)
                        $field.append '<label for="' + _field3.name + '" class="char-label">' + _finalFieldName + '</label>'
                        if _field3.positionable and _field3.isVisible[OSD.getCurrentPreviewProfile()]
                            $field.append $('<input type="number" class="' + _field3.index + ' position"></input>').data('field', _field3).val(_field3.position).change($.debounce(250, (e) ->
                                field = $(this).data('field')
                                position = parseInt($(this).val())
                                field.position = position
                                MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeLayout(field)).then ->
                                    updateOsdView()
                                    return
                                return
                            ))
                        # Insert in alphabetical order, with unknown fields at the end
                        insertOrdered $displayFields, $field
                catch err
                    _iterator5.e err
                finally
                    _iterator5.f()
                GUI.switchery()
                # buffer the preview
                OSD.data.preview = []
                OSD.data.display_size.total = OSD.data.display_size.x * OSD.data.display_size.y
                _iterator6 = _createForOfIteratorHelper(OSD.data.display_items)
                _step6 = undefined
                try
                    _iterator6.s()
                    while !(_step6 = _iterator6.n()).done
                        _field4 = _step6.value
                        # reset fields that somehow end up off the screen
                        if _field4.position > OSD.data.display_size.total
                            _field4.position = 0
                    # clear the buffer
                catch err
                    _iterator6.e err
                finally
                    _iterator6.f()
                i = 0
                while i < OSD.data.display_size.total
                    OSD.data.preview.push [
                        null
                        ' '.charCodeAt(0)
                        null
                        null
                    ]
                    i++
                # draw all the displayed items and the drag and drop preview images
                _iterator7 = _createForOfIteratorHelper(OSD.data.display_items)
                _step7 = undefined
                try
                    _iterator7.s()
                    while !(_step7 = _iterator7.n()).done
                        _field5 = _step7.value
                        if !_field5.preview or !_field5.isVisible[OSD.getCurrentPreviewProfile()]
                            continue
                        selectedPosition = if _field5.position >= 0 then _field5.position else _field5.position + OSD.data.display_size.total
                        # create the preview image
                        _field5.preview_img = new Image
                        canvas = document.createElement('canvas')
                        ctx = canvas.getContext('2d')
                        # Standard preview, type String
                        if _field5.preview.constructor != Array
                            # fill the screen buffer
                            i = 0
                            while i < _field5.preview.length
                                # Add the character to the preview
                                charCode = _field5.preview.charCodeAt(i)
                                OSD.drawByOrder selectedPosition++, _field5, charCode, i, 1
                                # Image used when "dragging" the element
                                if _field5.positionable
                                    img = new Image
                                    img.src = FONT.draw(charCode)
                                    ctx.drawImage img, i * 12, 0
                                i++
                        else
                            arrayElements = _field5.preview
                            i = 0
                            while i < arrayElements.length
                                element = arrayElements[i]
                                #Add string to the preview.
                                if element.constructor == String
                                    j = 0
                                    while j < element.length
                                        charCode = element.charCodeAt(j)
                                        OSD.drawByOrder selectedPosition++, _field5, charCode, j, i
                                        # Image used when "dragging" the element
                                        if _field5.positionable
                                            img = new Image
                                            img.src = FONT.draw(charCode)
                                            ctx.drawImage img, j * 12, i * 18
                                        j++
                                    selectedPosition = selectedPosition - (element.length) + FONT.constants.SIZES.LINE
                                else
                                    limits = OSD.searchLimitsElement(arrayElements)
                                    offsetX = 0
                                    offsetY = 0
                                    if limits.minX < 0
                                        offsetX = -limits.minX
                                    if limits.minY < 0
                                        offsetY = -limits.minY
                                    # Add the character to the preview
                                    charCode = element.sym
                                    OSD.drawByOrder selectedPosition + element.x + element.y * FONT.constants.SIZES.LINE, _field5, charCode, element.x, element.y
                                    # Image used when "dragging" the element
                                    if _field5.positionable
                                        img = new Image
                                        img.src = FONT.draw(charCode)
                                        ctx.drawImage img, (element.x + offsetX) * 12, (element.y + offsetY) * 18
                                i++
                        _field5.preview_img.src = canvas.toDataURL('image/png')
                        # Required for NW.js - Otherwise the <img /> will
                        #consume drag/drop events.
                        _field5.preview_img.style.pointerEvents = 'none'
                    # render
                catch err
                    _iterator7.e err
                finally
                    _iterator7.f()
                $preview = $('.display-layout .preview').empty()
                $row = $('<div class="row"/>')
                i = 0
                while i < OSD.data.display_size.total
                    charCode = OSD.data.preview[i]
                    if _typeof(charCode) == 'object'
                        field = OSD.data.preview[i][0]
                        charCode = OSD.data.preview[i][1]
                        x = OSD.data.preview[i][2]
                        y = OSD.data.preview[i][3]
                    $img = $('<div class="char" draggable><img src=' + FONT.draw(charCode) + '></img></div>').on('mouseenter', OSD.GUI.preview.onMouseEnter).on('mouseleave', OSD.GUI.preview.onMouseLeave).on('dragover', OSD.GUI.preview.onDragOver).on('dragleave', OSD.GUI.preview.onDragLeave).on('drop', OSD.GUI.preview.onDrop).data('field', field).data('position', i)
                    # Required for NW.js - Otherwise the <img /> will
                    # consume drag/drop events.
                    $img.find('img').css 'pointer-events', 'none'
                    $img.attr('data-x', x).attr 'data-y', y
                    if field and field.positionable
                        $img.addClass('field-' + field.index).data('field', field).prop('draggable', true).on 'dragstart', OSD.GUI.preview.onDragStart
                    else
                    $row.append $img
                    if ++i % OSD.data.display_size.x == 0
                        $preview.append $row
                        $row = $('<div class="row"/>')
                # Remove last tooltips
                _iterator8 = _createForOfIteratorHelper(OSD.data.tooltips)
                _step8 = undefined
                try
                    _iterator8.s()
                    while !(_step8 = _iterator8.n()).done
                        tt = _step8.value
                        tt.destroy()
                catch err
                    _iterator8.e err
                finally
                    _iterator8.f()
                OSD.data.tooltips = []
                # Generate tooltips for OSD elements
                $('.osd_tip').each ->
                    OSD.data.tooltips.push $(this).jBox('Tooltip',
                        delayOpen: 100
                        delayClose: 100
                        position:
                            x: 'right'
                            y: 'center'
                        outside: 'x')
                    return
                return
            return

        SYM.loadSymbols()
        OSD.loadDisplayFields()
        # Generate font type select element
        fontPresetsElement = $('.fontpresets')
        OSD.constants.FONT_TYPES.forEach (e, i) ->
            option = $('<option>',
                'data-font-file': e.file
                value: e.file
                text: e.name)
            fontPresetsElement.append $(option)
            return
        fontbuttons = $('.fontpresets_wrapper')
        fontbuttons.append $('<button>',
            class: 'load_font_file'
            i18n: 'osdSetupOpenFont')
        # must invoke before i18n.localizePage() since it adds translation keys for expected logo size
        LogoManager.init FONT, SYM.LOGO
        # translate to user-selected language
        i18n.localizePage()
        # Open modal window
        OSD.GUI.fontManager = new jBox('Modal',
            width: 750
            height: 455
            closeButton: 'title'
            animation: false
            attach: $('#fontmanager')
            title: 'OSD Font Manager'
            content: $('#fontmanagercontent'))
        $('.elements-container div.cf_tip').attr 'title', i18n.getMessage('osdSectionHelpElements')
        $('.videomode-container div.cf_tip').attr 'title', i18n.getMessage('osdSectionHelpVideoMode')
        $('.units-container div.cf_tip').attr 'title', i18n.getMessage('osdSectionHelpUnits')
        $('.timers-container div.cf_tip').attr 'title', i18n.getMessage('osdSectionHelpTimers')
        $('.alarms-container div.cf_tip').attr 'title', i18n.getMessage('osdSectionHelpAlarms')
        $('.stats-container div.cf_tip').attr 'title', i18n.getMessage('osdSectionHelpStats')
        $('.warnings-container div.cf_tip').attr 'title', i18n.getMessage('osdSectionHelpWarnings')
        $('.osdprofile-selector').change updateOsdView
        $('.osdprofile-active').change ->
            OSD.data.osd_profiles.selected = parseInt($(this).val())
            MSP.promise(MSPCodes.MSP_SET_OSD_CONFIG, OSD.msp.encodeOther()).then ->
                updateOsdView()
                return
            return
        $('a.save').click ->
            `var self`
            self = this
            MSP.promise MSPCodes.MSP_EEPROM_WRITE
            GUI.log i18n.getMessage('osdSettingsSaved')
            oldText = $(this).text()
            $(this).html i18n.getMessage('osdButtonSaved')
            setTimeout (->
                $(self).html oldText
                return
            ), 2000
            return
        # font preview window
        fontPreviewElement = $('.font-preview')
        # init structs once, also clears current font
        FONT.initData()
        fontPresetsElement.change (e) ->
            $font = $('.fontpresets option:selected')
            fontver = 1
            if semver.gte(CONFIG.apiVersion, '1.42.0')
                fontver = 2
            $('.font-manager-version-info').text i18n.getMessage('osdDescribeFontVersion' + fontver)
            $.get './resources/osd/' + fontver + '/' + $font.data('font-file') + '.mcm', (data) ->
                FONT.parseMCMFontFile data
                FONT.preview fontPreviewElement
                LogoManager.drawPreview()
                updateOsdView()
                $('.fontpresets option[value=-1]').hide()
                return
            return
        # load the first font when we change tabs
        fontPresetsElement.change()
        $('button.load_font_file').click ->
            FONT.openFontFile().then(->
                FONT.preview fontPreviewElement
                LogoManager.drawPreview()
                updateOsdView()
                $('.font-manager-version-info').text i18n.getMessage('osdDescribeFontVersionCUSTOM')
                $('.fontpresets option[value=-1]').show()
                $('.fontpresets').val -1
                return
            ).catch (error) ->
                console.error error
            return
        # font upload
        $('a.flash_font').click ->
            if !GUI.connect_lock
                # button disabled while flashing is in progress
                $('a.flash_font').addClass 'disabled'
                $('.progressLabel').text i18n.getMessage('osdSetupUploadingFont')
                FONT.upload($('.progress').val(0)).then ->
                    $('.progressLabel').text i18n.getMessage('osdSetupUploadingFontEnd', length: FONT.data.characters.length)
                    return
            return
        # replace logo
        $('a.replace_logo').click ->
            if GUI.connect_lock
                # button disabled while flashing is in progress
                return
            LogoManager.openImage().then((ctx) ->
                LogoManager.replaceLogoInFont ctx
                LogoManager.drawPreview()
                LogoManager.showUploadHint()
                return
            ).catch (error) ->
                console.error error
            return
        $(document).on 'click', 'span.progressLabel a.save_font', ->
            chrome.fileSystem.chooseEntry {
                type: 'saveFile'
                suggestedName: 'baseflight'
                accepts: [ {
                    description: 'MCM files'
                    extensions: [ 'mcm' ]
                } ]
            }, (fileEntry) ->
                if chrome.runtime.lastError
                    console.error chrome.runtime.lastError.message
                    return
                chrome.fileSystem.getDisplayPath fileEntry, (path) ->
                    console.log 'Saving firmware to: ' + path
                    # check if file is writable
                    chrome.fileSystem.isWritableEntry fileEntry, (isWritable) ->
                        if isWritable
                            blob = new Blob([ intel_hex ], type: 'text/plain')
                            fileEntry.createWriter ((writer) ->
                                truncated = false

                                writer.onerror = (e) ->
                                    console.error e
                                    return

                                writer.onwriteend = ->
                                    if !truncated
                                        # onwriteend will be fired again when truncation is finished
                                        truncated = true
                                        writer.truncate blob.size
                                        return
                                    return

                                writer.write blob
                                return
                            ), (e) ->
                                console.error e
                                return
                        else
                            console.log 'You don\'t have write permissions for this file, sorry.'
                            GUI.log i18n.getMessage('osdWritePermissions')
                        return
                    return
                return
            return
        $(document).keypress (e) ->
            if e.which == 13
                # enter
                # Trigger regular Flashing sequence
                $('a.flash_font').click()
            return
        GUI.content_ready callback
        return
    return

TABS.osd.cleanup = (callback) ->
    PortHandler.flush_callbacks()
    if OSD.GUI.fontManager
        OSD.GUI.fontManager.destroy()
    # unbind "global" events
    $(document).unbind 'keypress'
    $(document).off 'click', 'span.progressLabel a'
    if callback
        callback()
    return