Number::clamp = (min, max) ->
    Math.min Math.max(this, min), max

###*
# String formatting now supports currying (partial application).
# For a format string with N replacement indices, you can call .format
# with M <= N arguments. The result is going to be a format string
# with N-M replacement indices, properly counting from 0 .. N-M.
# The following Example should explain the usage of partial applied format:
#  "{0}:{1}:{2}".format("a","b","c") === "{0}:{1}:{2}".format("a","b").format("c")
#  "{0}:{1}:{2}".format("a").format("b").format("c") === "{0}:{1}:{2}".format("a").format("b", "c")
#
###

String::format = ->
    args = arguments
    @replace /\{(\d+)\}/g, (t, i) ->
        if args[i] != undefined then args[i] else '{' + i - (args.length) + '}'

Array::push8 = (val) ->
    @push 0xFF & val
    this

Array::push16 = (val) ->
    # low byte
    @push 0x00FF & val
    # high byte
    @push val >> 8
    # chainable
    this

Array::push32 = (val) ->
    @push8(val).push8(val >> 8).push8(val >> 16).push8 val >> 24
    this

DataView::offset = 0

DataView::readU8 = ->
    if @byteLength >= @offset + 1
        @getUint8 @offset++
    else
        null

DataView::readU16 = ->
    if @byteLength >= @offset + 2
        @readU8() + @readU8() * 256
    else
        null

DataView::readU32 = ->
    if @byteLength >= @offset + 4
        @readU16() + @readU16() * 65536
    else
        null

DataView::read8 = ->
    if @byteLength >= @offset + 1
        @getInt8 @offset++, 1
    else
        null

DataView::read16 = ->
    @offset += 2
    if @byteLength >= @offset
        @getInt16 @offset - 2, 1
    else
        null

DataView::read32 = ->
    @offset += 4
    if @byteLength >= @offset
        @getInt32 @offset - 4, 1
    else
        null

