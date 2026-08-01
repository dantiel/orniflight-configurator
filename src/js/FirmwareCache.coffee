###*
# Caching of previously downloaded firmwares and release descriptions
# 
# Depends on LRUMap for which the docs can be found here:
# https://github.com/rsms/js-lru
###

###*
# @typedef {object} Descriptor Release descriptor object
# @property {string} releaseUrl
# @property {string} name
# @property {string} version
# @property {string} url
# @property {string} file
# @property {string} target
# @property {string} date
# @property {string} notes
# @property {string} status
# @see buildBoardOptions() in {@link release_checker.js}
###

###*
# @typedef {object} CacheItem
# @property {Descriptor} release
# @property {string} hexdata
###

###*
# Manages caching of downloaded firmware files
###

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

_typeof = (o) ->
    '@babel/helpers - typeof'
    _typeof = if 'function' == typeof Symbol and 'symbol' == typeof Symbol.iterator then ((o) ->
        typeof o
    ) else ((o) ->
        if o and 'function' == typeof Symbol and o.constructor == Symbol and o != Symbol.prototype then 'symbol' else typeof o
    )
    _typeof(o)

'use strict'
FirmwareCache = do ->
    onPutToCacheCallback = undefined
    onRemoveFromCacheCallback = undefined
    JournalStorage = do ->
        CACHEKEY = 'firmware-cache-journal'

        ###*
        # @param {Array} data LRU key-value pairs
        ###

        persist = (data) ->
            obj = {}
            obj[CACHEKEY] = data
            chrome.storage.local.set obj
            return

        ###*
        # @param {Function} callback 
        ###

        load = (callback) ->
            chrome.storage.local.get CACHEKEY, (obj) ->
                entries = if _typeof(obj) == 'object' and obj.hasOwnProperty(CACHEKEY) then obj[CACHEKEY] else []
                callback entries
                return
            return

        {
            persist: persist
            load: load
        }
    journal = new LRUMap(100)
    journalLoaded = false

    ###*
    # @param {Descriptor} release 
    # @returns {string} A key used to store a release in the journal
    ###

    keyOf = (release) ->
        release.file

    ###*
    # @param {string} key 
    # @returns {string} A key for storing cached data for a release
    ###

    withCachePrefix = (key) ->
        'cache:' + key

    ###*
    # @param {Descriptor} release
    # @returns {boolean}
    ###

    has = (release) ->
        if !release
            return false
        if !journalLoaded
            console.warn 'Cache not yet loaded'
            return false
        journal.has keyOf(release)

    ###*
    # @param {Descriptor} release
    # @param {string} hexdata
    ###

    put = (release, hexdata) ->
        if !journalLoaded
            console.warn 'Cache journal not yet loaded'
            return
        key = keyOf(release)
        if has(release)
            console.debug 'Firmware is already cached: ' + key
            return
        journal.set key, true
        JournalStorage.persist journal.toJSON()
        obj = {}
        obj[withCachePrefix(key)] =
            release: release
            hexdata: hexdata
        chrome.storage.local.set obj, ->
            onPutToCache release
            return
        return

    ###*
    # @param {Descriptor} release
    # @param {Function} callback
    ###

    get = (release, callback) ->
        if !journalLoaded
            console.warn 'Cache journal not yet loaded'
            return undefined
        key = keyOf(release)
        if !has(release)
            console.debug 'Firmware is not cached: ' + key
            return
        cacheKey = withCachePrefix(key)
        chrome.storage.local.get cacheKey, (obj) ->

            ###* @type {CacheItem} ###

            cached = if _typeof(obj) == 'object' and obj.hasOwnProperty(cacheKey) then obj[cacheKey] else null
            callback cached
            return
        return

    ###*
    # Remove all cached data
    ###

    invalidate = ->
        if !journalLoaded
            console.warn 'Cache journal not yet loaded'
            return undefined
        cacheKeys = []
        _iterator = _createForOfIteratorHelper(journal.keys())
        _step = undefined
        try
            _iterator.s()
            while !(_step = _iterator.n()).done
                key = _step.value
                cacheKeys.push withCachePrefix(key)
        catch err
            _iterator.e err
        finally
            _iterator.f()
        chrome.storage.local.get cacheKeys, (obj) ->
            if _typeof(obj) != 'object'
                return
            _i = 0
            _cacheKeys = cacheKeys
            while _i < _cacheKeys.length
                cacheKey = _cacheKeys[_i]
                if obj.hasOwnProperty(cacheKey)

                    ###* @type {CacheItem} ###

                    item = obj[cacheKey]
                    onRemoveFromCache item.release
                _i++
            chrome.storage.local.remove cacheKeys
            return
        journal.clear()
        JournalStorage.persist journal.toJSON()
        return

    ###*
    # @param {Descriptor} release 
    ###

    onPutToCache = (release) ->
        if typeof onPutToCacheCallback == 'function'
            onPutToCacheCallback release
        console.info 'Release put to cache: ' + keyOf(release)
        return

    ###*
    # @param {Descriptor} release 
    ###

    onRemoveFromCache = (release) ->
        if typeof onRemoveFromCacheCallback == 'function'
            onRemoveFromCacheCallback release
        console.debug 'Cache data removed: ' + keyOf(release)
        return

    ###*
    # @param {Array} entries 
    ###

    onEntriesLoaded = (entries) ->
        pairs = []
        _iterator2 = _createForOfIteratorHelper(entries)
        _step2 = undefined
        try
            _iterator2.s()
            while !(_step2 = _iterator2.n()).done
                entry = _step2.value
                pairs.push [
                    entry.key
                    entry.value
                ]
        catch err
            _iterator2.e err
        finally
            _iterator2.f()
        journal.assign pairs
        journalLoaded = true
        console.info 'Firmware cache journal loaded; number of entries: ' + entries.length
        return

    journal.shift = ->
        # remove cached data for oldest release
        oldest = LRUMap::shift.call(this)
        if oldest == undefined
            return undefined
        key = oldest[0]
        cacheKey = withCachePrefix(key)
        chrome.storage.local.get cacheKey, (obj) ->

            ###* @type {CacheItem} ###

            cached = if _typeof(obj) == 'object' and obj.hasOwnProperty(cacheKey) then obj[cacheKey] else null
            if cached == null
                return
            chrome.storage.local.remove cacheKey, ->
                onRemoveFromCache cached.release
                return
            return
        oldest

    {
        has: has
        put: put
        get: get
        onPutToCache: (callback) ->
            onPutToCacheCallback = callback
        onRemoveFromCache: (callback) ->
            onRemoveFromCacheCallback = callback
        load: ->
            JournalStorage.load onEntriesLoaded
            return
        unload: ->
            JournalStorage.persist journal.toJSON()
            journal.clear()
            return
        invalidate: invalidate
    }