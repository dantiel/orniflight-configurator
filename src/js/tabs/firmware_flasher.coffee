_typeof = (o) ->
    '@babel/helpers - typeof'
    _typeof = if 'function' == typeof Symbol and 'symbol' == typeof Symbol.iterator then ((o) ->
        typeof o
    ) else ((o) ->
        if o and 'function' == typeof Symbol and o.constructor == Symbol and o != Symbol.prototype then 'symbol' else typeof o
    )
    _typeof(o)

'use strict'
TABS.firmware_flasher =
    releases: null
    releaseChecker: new ReleaseChecker('firmware', 'https://api.github.com/repos/dantiel/orniflight/releases')
    jenkinsLoader: new JenkinsLoader('https://ci.orniflight.tech')
    localFirmwareLoaded: false
    selectedBoard: undefined
    intel_hex: undefined
    parsed_hex: undefined
    unifiedTargetConfig: undefined
    unifiedTargetConfigName: undefined
    isConfigLocal: false
    remoteUnifiedTargetConfig: undefined

TABS.firmware_flasher.initialize = (callback) ->
    self = this

    ###*
    # Change boldness of firmware option depending on cache status
    # 
    # @param {Descriptor} release 
    ###

    onFirmwareCacheUpdate = (release) ->
        $('option[value=\'{0}\']'.format(release.version)).css 'font-weight', if FirmwareCache.has(release) then 'bold' else 'normal'
        return

    onDocumentLoad = ->

        parse_hex = (str, callback) ->
            # parsing hex in different thread
            worker = new Worker('./js/workers/hex_parser.js')
            # "callback"

            worker.onmessage = (event) ->
                callback event.data
                return

            # send data/string over for processing
            worker.postMessage str
            return

        show_loaded_hex = (summary) ->
            self.flashingMessage '<a class="save_firmware" href="#" title="Save Firmware">' + i18n.getMessage('firmwareFlasherFirmwareOnlineLoaded', self.parsed_hex.bytes_total) + '</a>', self.FLASH_MESSAGE_TYPES.NEUTRAL
            self.enableFlashing true
            targetName = TABS.firmware_flasher.selectedBoard
            TARGET_REGEXP = /^([^+-]+)(?:\+(.{1,4})|-legacy)?$/
            targetParts = targetName.match(TARGET_REGEXP)
            if targetParts
                targetName = targetParts[1]
                if targetParts[2]
                    $('div.release_info #manufacturerInfo').show()
                    $('div.release_info #manufacturer').text targetParts[2]
                else
                    $('div.release_info #manufacturerInfo').hide()
            $('div.release_info .target').text targetName
            $('div.release_info .name').text(summary.version).prop 'href', summary.releaseUrl
            $('div.release_info .date').text summary.date
            $('div.release_info .file').text(summary.file).prop 'href', summary.url
            formattedNotes = summary.notes.replace(/#(\d+)/g, '[#$1](https://github.com/dantiel/orniflight/pull/$1)')
            formattedNotes = marked(formattedNotes)
            $('div.release_info .notes').html formattedNotes
            $('div.release_info .notes').find('a').each ->
                $(this).attr 'target', '_blank'
                return
            $('div.release_info').slideDown()
            return

        process_hex = (data, summary) ->
            self.intel_hex = data
            parse_hex self.intel_hex, (data) ->
                self.parsed_hex = data
                if self.parsed_hex
                    analytics.setFirmwareData analytics.DATA.FIRMWARE_SIZE, self.parsed_hex.bytes_total
                    if !FirmwareCache.has(summary)
                        FirmwareCache.put summary, self.intel_hex
                    show_loaded_hex summary
                else
                    self.flashingMessage 'firmwareFlasherHexCorrupted', self.FLASH_MESSAGE_TYPES.INVALID
                return
            return

        onLoadSuccess = (data, summary) ->
            self.localFirmwareLoaded = false
            # The path from getting a firmware doesn't fill in summary.
            summary = if _typeof(summary) == 'object' then summary else $('select[name="firmware_version"] option:selected').data('summary')
            process_hex data, summary
            $('a.load_remote_file').removeClass 'disabled'
            $('a.load_remote_file').text i18n.getMessage('firmwareFlasherButtonLoadOnline')
            return

        populateBoardOptions = (builds) ->
            if !builds
                $('select[name="board"]').empty().append '<option value="0">Offline</option>'
                $('select[name="firmware_version"]').empty().append '<option value="0">Offline</option>'
                return
            boards_e = $('select[name="board"]')
            boards_e.empty()
            boards_e.append $('<option value=\'0\' i18n=\'firmwareFlasherOptionLabelSelectBoard\'></option>')
            versions_e = $('select[name="firmware_version"]')
            versions_e.empty()
            versions_e.append $('<option value=\'0\' i18n=\'firmwareFlasherOptionLabelSelectFirmwareVersion\'></option>')
            selectTargets = []
            Object.keys(builds).sort().forEach (target, i) ->
                descriptors = builds[target]
                descriptors.forEach (descriptor) ->
                    if $.inArray(target, selectTargets) == -1
                        selectTargets.push target
                        select_e = $('<option value=\'{0}\'>{0}</option>'.format(descriptor.target))
                        boards_e.append select_e
                    return
                return
            TABS.firmware_flasher.releases = builds
            ConfigStorage.get 'selected_board', (result) ->
                if result.selected_board
                    boardBuilds = builds[result.selected_board]
                    $('select[name="board"]').val(if boardBuilds then result.selected_board else 0).trigger 'change'
                return
            return

        processBoardOptions = (releaseData, showDevReleases) ->
            releases = {}
            sortedTargets = []
            unsortedTargets = []
            releaseData.forEach (release) ->
                release.assets.forEach (asset) ->
                    targetFromFilenameExpression = /orniflight_([\d.]+)?_?(\w+)(\-.*)?\.(.*)/
                    match = targetFromFilenameExpression.exec(asset.name)
                    if !showDevReleases and release.prerelease or !match
                        return
                    target = match[2]
                    if $.inArray(target, unsortedTargets) == -1
                        unsortedTargets.push target
                    return
                sortedTargets = unsortedTargets.sort()
                return
            sortedTargets.forEach (release) ->
                releases[release] = []
                return
            releaseData.forEach (release) ->
                versionFromTagExpression = /v?(.*)/
                matchVersionFromTag = versionFromTagExpression.exec(release.tag_name)
                version = matchVersionFromTag[1]
                release.assets.forEach (asset) ->
                    targetFromFilenameExpression = /orniflight_([\d.]+)?_?(\w+)(\-.*)?\.(.*)/
                    match = targetFromFilenameExpression.exec(asset.name)
                    if !showDevReleases and release.prerelease or !match
                        return
                    target = match[2]
                    format = match[4]
                    if format != 'hex'
                        return
                    date = new Date(release.published_at)
                    formattedDate = ('0' + date.getDate()).slice(-2) + '-' + ('0' + date.getMonth() + 1).slice(-2) + '-' + date.getFullYear() + ' ' + ('0' + date.getHours()).slice(-2) + ':' + ('0' + date.getMinutes()).slice(-2)
                    descriptor = 
                        'releaseUrl': release.html_url
                        'name': version
                        'version': version
                        'url': asset.browser_download_url
                        'file': asset.name
                        'target': target
                        'date': formattedDate
                        'notes': release.body
                    releases[target].push descriptor
                    return
                return
            loadUnifiedBuilds releases
            return

        checkOneVersionForUnification = (version) ->
            semver.gte version.split(' ')[0], '4.1.0-RC1'

        checkBuildsForUnification = (builds) ->
            # Find a build that is newer than 4.1.0, return true if found
            foundSuitable = false
            Object.keys(builds).forEach (key) ->
                builds[key].forEach (target) ->
                    if checkOneVersionForUnification(target.version)
                        foundSuitable = true
                    return
                return
            foundSuitable

        loadUnifiedBuilds = (builds) ->
            expirationPeriod = 3600 * 2
            # Two of your earth hours.
            checkTime = Math.floor(Date.now() / 1000)
            # Lets deal in seconds.
            if builds and checkBuildsForUnification(builds)
                console.log 'loaded some builds for later'
                storageTag = 'unifiedSourceCache'
                chrome.storage.local.get storageTag, (result) ->
                    storageObj = result[storageTag]
                    if !storageObj or !storageObj.lastUpdate or checkTime - (storageObj.lastUpdate) > expirationPeriod
                        console.log 'go get', unifiedSource
                        $.get(unifiedSource, (data, textStatus, jqXHR) ->
                            # Cache the information for later use.
                            newStorageObj = {}
                            newDataObj = {}
                            newDataObj.lastUpdate = checkTime
                            newDataObj.data = data
                            newStorageObj[storageTag] = newDataObj
                            chrome.storage.local.set newStorageObj
                            parseUnifiedBuilds data, builds
                            return
                        ).fail (xhr) ->
                            console.log 'failed to get new', unifiedSource, 'cached data', Math.floor((checkTime - (storageObj.lastUpdate)) / 60), 'mins old'
                            parseUnifiedBuilds storageObj.data, builds
                            return
                    else
                        # In the event that the cache is okay
                        console.log 'unified config cached data', Math.floor((checkTime - (storageObj.lastUpdate)) / 60), 'mins old'
                        parseUnifiedBuilds storageObj.data, builds
                    return
            else
                populateBoardOptions builds
            return

        parseUnifiedBuilds = (data, builds) ->
            if !data
                return
            releases = {}
            unifiedConfigs = {}
            items = {}
            unifiedTargetNames = []
            data.forEach (target) ->
                TARGET_REGEXP = /^(?:([^-]{1,4})-)?(.*).config$/
                targetParts = target.name.match(TARGET_REGEXP)
                if !targetParts
                    return
                boardName = targetParts[2]
                manufacturerId = targetParts[1]
                targetName = undefined
                displayName = undefined
                if manufacturerId
                    targetName = boardName + '+' + manufacturerId
                    displayName = boardName + ' (' + manufacturerId + ')'
                else
                    targetName = boardName
                unifiedTargetNames.push boardName
                unifiedConfigs[targetName] = target.download_url
                items[targetName] = displayName: displayName
                # Chicken and egg problem: We need to know what Unified Target this configuration uses before reading the configuration.
                # Solving this by assuming that all Unified Targets have the same availability for now.
                DEFAULT_UNIFIED_TARGET_NAME = 'STM32F405'
                releases[targetName] = builds[DEFAULT_UNIFIED_TARGET_NAME]
                return
            Object.keys(builds).forEach (key) ->
                targetName = undefined
                displayName = undefined
                if unifiedTargetNames.includes(key)
                    targetName = ''.concat(key, '-legacy')
                    displayName = i18n.getMessage('firmwareFlasherLegacyLabel', target: key)
                else
                    targetName = key
                items[targetName] = displayName: displayName
                releases[targetName] = builds[key]
                return
            boards_e = $('select[name="board"]')
            versions_e = $('select[name="firmware_version"]')
            boards_e.empty().append $('<option value=\'0\' i18n=\'firmwareFlasherOptionLabelSelectBoard\'></option>')
            versions_e.empty().append $('<option value=\'0\' i18n=\'firmwareFlasherOptionLabelSelectFirmwareVersion\'></option>')
            selectTargets = []
            Object.keys(items).sort().forEach (target, i) ->
                item = items[target]
                select_e = $('<option value=\'{0}\'>{1}</option>'.format(target, items[target].displayName or target))
                boards_e.append select_e
                return
            TABS.firmware_flasher.releases = releases
            TABS.firmware_flasher.unifiedConfigs = unifiedConfigs
            ConfigStorage.get 'selected_board', (result) ->
                if result.selected_board
                    boardReleases = TABS.firmware_flasher.unifiedConfigs[result.selected_board] or TABS.firmware_flasher.releases[result.selected_board]
                    $('select[name="board"]').val(if boardReleases then result.selected_board else 0).trigger 'change'
                return
            return

        buildBuildTypeOptionsList = ->
            buildType_e.empty()
            buildTypesToShow.forEach (build, index) ->
                buildType_e.append $('<option value=\'{0}\'>{1}</option>'.format(index, if build.tag then i18n.getMessage(build.tag) else build.title))
                return
            $('select[name="build_type"]').val $('select[name="build_type"] option:first').val()
            return

        showOrHideBuildTypes = ->
            showExtraReleases = $(this).is(':checked')
            if showExtraReleases
                $('tr.build_type').show()
                $('tr.expert_mode').show()
            else
                $('tr.build_type').hide()
                $('tr.expert_mode').hide()
                buildType_e.val(0).trigger 'change'
            return

        showOrHideBuildTypeSelect = ->
            expertModeChecked = $(this).is(':checked')
            globalExpertMode_e.prop 'checked', expertModeChecked
            if expertModeChecked
                buildTypesToShow = buildTypes.concat(ciBuildsTypes)
                buildBuildTypeOptionsList()
            else
                buildTypesToShow = buildTypes
                buildBuildTypeOptionsList()
                buildType_e.val(0).trigger 'change'
            return

        populateVersions = (versions_element, targetVersions, target) ->
            versions_element.empty()
            if targetVersions
                versions_element.append $('<option value=\'0\'>{0} {1}</option>'.format(i18n.getMessage('firmwareFlasherOptionLabelSelectFirmwareVersionFor'), target))
                targetVersions.forEach (descriptor) ->
                    if self.remoteUnifiedTargetConfig and !checkOneVersionForUnification(descriptor.version)
                        return
                    select_e = $('<option value=\'{0}\'>{0} - {1}</option>'.format(descriptor.version, descriptor.date)).css('font-weight', if FirmwareCache.has(descriptor) then 'bold' else 'normal')
                    select_e.data 'summary', descriptor
                    versions_element.append select_e
                    return
                # Assume flashing latest, so default to it.
                versions_element.prop('selectedIndex', 1).change()
            return

        grabBuildNameFromConfig = (config) ->
            bareBoard = undefined
            try
                bareBoard = config.split('\n')[0].split(' ')[3]
            catch e
                bareBoard = undefined
                console.log 'grabBuildNameFromConfig failed: ', e.message
            bareBoard

        setUnifiedConfig = (target, configText, bareBoard) ->
            # a target might request a firmware with the same name, remove configuration in this case.
            if bareBoard == target
                console.log bareBoard, '==', target
                if !self.isConfigLocal
                    self.unifiedTargetConfig = undefined
                    self.unifiedTargetConfigName = undefined
                    self.remoteUnifiedTargetConfig = undefined
                else
                    self.remoteUnifiedTargetConfig = undefined
            else
                self.unifiedTargetConfig = configText
                self.unifiedTargetConfigName = ''.concat(target, '.config')
                self.isConfigLocal = false
                self.remoteUnifiedTargetConfig = configText
            return

        clearBufferedFirmware = ->
            self.isConfigLocal = false
            self.unifiedTargetConfig = undefined
            self.unifiedTargetConfigName = undefined
            self.remoteUnifiedTargetConfig = undefined
            self.intel_hex = undefined
            self.parsed_hex = undefined
            self.localFirmwareLoaded = false
            return

        flashingMessageLocal = ->
            # used by the a.load_file hook, evaluate the loaded information, and enable flashing if suitable
            if self.isConfigLocal and !self.parsed_hex
                self.flashingMessage i18n.getMessage('firmwareFlasherLoadedConfig'), self.FLASH_MESSAGE_TYPES.NEUTRAL
            if self.isConfigLocal and self.parsed_hex and !self.localFirmwareLoaded
                self.enableFlashing true
                self.flashingMessage i18n.getMessage('firmwareFlasherFirmwareLocalLoaded', self.parsed_hex.bytes_total), self.FLASH_MESSAGE_TYPES.NEUTRAL
            if self.localFirmwareLoaded
                self.enableFlashing true
                self.flashingMessage i18n.getMessage('firmwareFlasherFirmwareLocalLoaded', self.parsed_hex.bytes_total), self.FLASH_MESSAGE_TYPES.NEUTRAL
            return

        cleanUnifiedConfigFile = (input) ->
            output = []
            inComment = false
            i = 0
            while i < input.length
                if input.charAt(i) == '\n' or input.charAt(i) == '\u000d'
                    inComment = false
                if input.charAt(i) == '#'
                    inComment = true
                if !inComment and input.charCodeAt(i) > 255
                    # Note: we're not showing this error in orniflight-configurator
                    throw new Error('commands are limited to characters 0-255, comments have no limitation')
                if input.charCodeAt(i) > 255
                    output.push '_'
                else
                    output.push input.charAt(i)
                i++
            output.join ''

        flashFirmware = (firmware) ->
            options = {}
            eraseAll = false
            if $('input.erase_chip').is(':checked')
                options.erase_chip = true
                eraseAll = true
            analytics.setFirmwareData analytics.DATA.FIRMWARE_ERASE_ALL, eraseAll.toString()
            if String($('div#port-picker #port').val()) != 'DFU'
                if String($('div#port-picker #port').val()) != '0'
                    port = String($('div#port-picker #port').val())
                    baud = undefined
                    baud = 115200
                    if $('input.updating').is(':checked')
                        options.no_reboot = true
                    else
                        options.reboot_baud = parseInt($('div#port-picker #baud').val())
                    if $('input.flash_manual_baud').is(':checked')
                        baud = parseInt($('#flash_manual_baud_rate').val())
                    analytics.sendEvent analytics.EVENT_CATEGORIES.FIRMWARE, 'Flashing', self.unifiedTargetConfigName or null
                    STM32.connect port, baud, firmware, options
                else
                    console.log 'Please select valid serial port'
                    GUI.log i18n.getMessage('firmwareFlasherNoValidPort')
            else
                analytics.sendEvent analytics.EVENT_CATEGORIES.FIRMWARE, 'Flashing', self.unifiedTargetConfigName or null
                STM32DFU.connect usbDevices, firmware, options
            return

        FirmwareCache.load()
        FirmwareCache.onPutToCache onFirmwareCacheUpdate
        FirmwareCache.onRemoveFromCache onFirmwareCacheUpdate
        buildTypes = [
            {
                tag: 'firmwareFlasherOptionLabelBuildTypeRelease'
                loader: ->
                    self.releaseChecker.loadReleaseData (releaseData) ->
                        processBoardOptions releaseData, true

            }
            {
                tag: 'firmwareFlasherOptionLabelBuildTypeReleaseCandidate'
                loader: ->
                    self.releaseChecker.loadReleaseData (releaseData) ->
                        processBoardOptions releaseData, true

            }
        ]
        ciBuildsTypes = self.jenkinsLoader._jobs.map((job) ->
            if job.title == 'Development'
                return {
                    tag: 'firmwareFlasherOptionLabelBuildTypeDevelopment'
                    loader: ->
                        self.jenkinsLoader.loadBuilds job.name, loadUnifiedBuilds

                }
            {
                title: job.title
                loader: ->
                    self.jenkinsLoader.loadBuilds job.name, loadUnifiedBuilds

            }
        )
        buildTypesToShow = undefined
        buildType_e = $('select[name="build_type"]')
        globalExpertMode_e = $('input[name="expertModeCheckbox"]')
        expertMode_e = $('.tab-firmware_flasher input.expert_mode')
        expertMode_e.prop 'checked', globalExpertMode_e.is(':checked')
        $('input.show_development_releases').change(showOrHideBuildTypes).change()
        expertMode_e.change(showOrHideBuildTypeSelect).change()
        # translate to user-selected language
        i18n.localizePage()
        buildType_e.change ->
            analytics.setFirmwareData analytics.DATA.FIRMWARE_CHANNEL, $(this).find('option:selected').text()
            $('a.load_remote_file').addClass 'disabled'
            build_type = $(this).val()
            $('select[name="board"]').empty().append $('<option value=\'0\' i18n=\'firmwareFlasherOptionLoading\'></option>')
            $('select[name="firmware_version"]').empty().append $('<option value=\'0\' i18n=\'firmwareFlasherOptionLoading\'></option>')
            i18n.localizePage()
            if !GUI.connect_lock
                TABS.firmware_flasher.unifiedConfigs = {}
                buildTypesToShow[build_type].loader()
            chrome.storage.local.set 'selected_build_type': build_type
            return
        $('select[name="board"]').change ->
            $('a.load_remote_file').addClass 'disabled'
            target = $(this).val()
            if !GUI.connect_lock
                if TABS.firmware_flasher.selectedBoard != target
                    # We're sure the board actually changed
                    if self.isConfigLocal
                        console.log 'Board changed, unloading local config'
                        self.isConfigLocal = false
                        self.unifiedTargetConfig = undefined
                        self.unifiedTargetConfigName = undefined
                ConfigStorage.set 'selected_board': target
                TABS.firmware_flasher.selectedBoard = target
                TABS.firmware_flasher.bareBoard = undefined
                console.log 'board changed to', target
                self.flashingMessage('firmwareFlasherLoadFirmwareFile', self.FLASH_MESSAGE_TYPES.NEUTRAL).flashProgress 0
                $('div.git_info').slideUp()
                $('div.release_info').slideUp()
                if !self.localFirmwareLoaded
                    self.enableFlashing false
                versions_e = $('select[name="firmware_version"]')
                if target == 0
                    # target == 0 is the "Choose a Board" option. Throw out anything loaded
                    clearBufferedFirmware()
                    versions_e.empty()
                    versions_e.append $('<option value=\'0\'>{0}</option>'.format(i18n.getMessage('firmwareFlasherOptionLabelSelectFirmwareVersion')))
                else
                    # Show a loading message as there is a delay in loading a configuration
                    versions_e.empty()
                    versions_e.append $('<option value=\'0\'>{0}</option>'.format(i18n.getMessage('firmwareFlasherOptionLoading')))
                    selecteBuild = buildTypesToShow[$('select[name="build_type"]').val()]
                    if TABS.firmware_flasher.unifiedConfigs[target]
                        storageTag = 'unifiedConfigLast'
                        expirationPeriod = 3600
                        # One of your earth hours.
                        checkTime = Math.floor(Date.now() / 1000)
                        # Lets deal in seconds.
                        chrome.storage.local.get storageTag, (result) ->
                            storageObj = result[storageTag]
                            bareBoard = null
                            # Check to see if the cached configuration is the one we want.
                            if !storageObj or !storageObj.target or storageObj.target != target
                                # Have to go and try and get the unified config, and then do stuff
                                $.get(TABS.firmware_flasher.unifiedConfigs[target], (data) ->
                                    console.log 'got unified config'
                                    # cache it for later
                                    tempObj = {}
                                    tempObj['data'] = data
                                    tempObj['target'] = target
                                    tempObj['checkTime'] = checkTime
                                    newStorageObj = {}
                                    newStorageObj[storageTag] = tempObj
                                    chrome.storage.local.set newStorageObj
                                    bareBoard = grabBuildNameFromConfig(data)
                                    TABS.firmware_flasher.bareBoard = bareBoard
                                    setUnifiedConfig target, data, bareBoard
                                    populateVersions versions_e, TABS.firmware_flasher.releases[bareBoard], target
                                    return
                                ).fail (xhr) ->
                                    #TODO error, populate nothing?
                                    self.unifiedTargetConfig = undefined
                                    self.unifiedTargetConfigName = undefined
                                    self.isConfigLocal = false
                                    self.remoteUnifiedTargetConfig = undefined
                                    baseFileName = TABS.firmware_flasher.unifiedConfigs[target].reverse()[0]
                                    GUI.log i18n.getMessage('firmwareFlasherFailedToLoadUnifiedConfig', remote_file: baseFileName)
                                    return
                            else
                                console.log 'We have the config cached for', target
                                data = storageObj.data
                                bareBoard = grabBuildNameFromConfig(data)
                                TABS.firmware_flasher.bareBoard = bareBoard
                                setUnifiedConfig target, data, bareBoard
                                populateVersions versions_e, TABS.firmware_flasher.releases[bareBoard], target
                            return
                    else
                        if !self.isConfigLocal
                            self.unifiedTargetConfig = undefined
                            self.unifiedTargetConfigName = undefined
                            self.remoteUnifiedTargetConfig = undefined
                        else
                            self.remoteUnifiedTargetConfig = undefined
                        TABS.firmware_flasher.bareBoard = target
                        populateVersions versions_e, TABS.firmware_flasher.releases[target], target
            return
        # UI Hooks
        $('a.load_file').click ->
            # Guard against rapid double-clicks opening multiple file dialogs

            cleanupDialog = ->
                self._fileDialogOpen = false
                fileInput.remove()
                return

            if self._fileDialogOpen
                return
            self._fileDialogOpen = true
            self.enableFlashing false
            analytics.setFirmwareData analytics.DATA.FIRMWARE_CHANNEL, undefined
            analytics.setFirmwareData analytics.DATA.FIRMWARE_SOURCE, 'file'
            # Use native <input type="file"> instead of chrome.fileSystem (unstable in Chromium 130+)
            fileInput = $('<input type="file" accept=".hex,.config" style="display:none">')
            $('body').append fileInput
            fileInput.on 'change', (e) ->
                file = e.target.files[0]
                if !file
                    cleanupDialog()
                    return
                # hide github info (if it exists)
                $('div.git_info').slideUp()
                console.log 'Loading file from: ' + file.name
                analytics.setFirmwareData analytics.DATA.FIRMWARE_NAME, file.name
                reader = new FileReader

                reader.onerror = (err) ->
                    console.error 'Failed to read file: ' + file.name, err
                    self.flashingMessage 'firmwareFlasherHexCorrupted', self.FLASH_MESSAGE_TYPES.INVALID
                    cleanupDialog()
                    return

                reader.onloadend = (e) ->
                    if reader.error
                        cleanupDialog()
                        return
                    if e.total != 0 and e.total == e.loaded
                        console.log 'File loaded (' + e.loaded + ')'
                        if file.name.split('.').pop().toLowerCase() == 'hex'
                            self.intel_hex = e.target.result
                            parse_hex self.intel_hex, (data) ->
                                self.parsed_hex = data
                                if self.parsed_hex
                                    analytics.setFirmwareData analytics.DATA.FIRMWARE_SIZE, self.parsed_hex.bytes_total
                                    self.localFirmwareLoaded = true
                                    flashingMessageLocal()
                                else
                                    self.flashingMessage 'firmwareFlasherHexCorrupted', self.FLASH_MESSAGE_TYPES.INVALID
                                return
                        else
                            clearBufferedFirmware()
                            try
                                self.unifiedTargetConfig = cleanUnifiedConfigFile(e.target.result)
                                self.unifiedTargetConfigName = file.name
                                self.isConfigLocal = true
                                flashingMessageLocal()
                            catch err
                                self.flashingMessage 'firmwareFlasherConfigCorrupted', self.FLASH_MESSAGE_TYPES.INVALID
                                GUI.log i18n.getMessage('firmwareFlasherConfigCorruptedLogMessage')
                        cleanupDialog()
                    else if e.total == 0
                        console.log 'Empty file selected, ignoring'
                        self.flashingMessage 'firmwareFlasherHexCorrupted', self.FLASH_MESSAGE_TYPES.INVALID
                        cleanupDialog()
                    return

                reader.readAsText file
                return
            fileInput.trigger 'click'
            return

        ###*
        # Lock / Unlock the firmware download button according to the firmware selection dropdown.
        ###

        $('select[name="firmware_version"]').change (evt) ->
            $('div.release_info').slideUp()
            if !self.localFirmwareLoaded
                self.enableFlashing false
                self.flashingMessage i18n.getMessage('firmwareFlasherLoadFirmwareFile'), self.FLASH_MESSAGE_TYPES.NEUTRAL
                if self.parsed_hex and self.parsed_hex.bytes_total
                    # Changing the board triggers a version change, so we need only dump it here.
                    console.log 'throw out loaded hex'
                    self.intel_hex = undefined
                    self.parsed_hex = undefined
            release = $('option:selected', evt.target).data('summary')
            isCached = FirmwareCache.has(release)
            if evt.target.value == '0' or isCached
                if isCached
                    analytics.setFirmwareData analytics.DATA.FIRMWARE_SOURCE, 'cache'
                    FirmwareCache.get release, (cached) ->
                        analytics.setFirmwareData analytics.DATA.FIRMWARE_NAME, release.file
                        console.info 'Release found in cache: ' + release.file
                        onLoadSuccess cached.hexdata, release
                        return
                $('a.load_remote_file').addClass 'disabled'
            else
                $('a.load_remote_file').removeClass 'disabled'
            return
        $('a.load_remote_file').click (evt) ->

            failed_to_load = ->
                $('span.progressLabel').attr('i18n', 'firmwareFlasherFailedToLoadOnlineFirmware').removeClass 'i18n-replaced'
                $('a.load_remote_file').removeClass 'disabled'
                $('a.load_remote_file').text i18n.getMessage('firmwareFlasherButtonLoadOnline')
                i18n.localizePage()
                return

            self.enableFlashing false
            self.localFirmwareLoaded = false
            analytics.setFirmwareData analytics.DATA.FIRMWARE_SOURCE, 'http'
            if $('select[name="firmware_version"]').val() == '0'
                GUI.log i18n.getMessage('firmwareFlasherNoFirmwareSelected')
                return
            summary = $('select[name="firmware_version"] option:selected').data('summary')
            if summary
                # undefined while list is loading or while running offline
                if self.isConfigLocal and FirmwareCache.has(summary)
                    # Load the .hex from Cache if available when the user is providing their own config.
                    analytics.setFirmwareData analytics.DATA.FIRMWARE_SOURCE, 'cache'
                    FirmwareCache.get summary, (cached) ->
                        analytics.setFirmwareData analytics.DATA.FIRMWARE_NAME, summary.file
                        console.info 'Release found in cache: ' + summary.file
                        onLoadSuccess cached.hexdata, summary
                        return
                    return
                analytics.setFirmwareData analytics.DATA.FIRMWARE_NAME, summary.file
                $('a.load_remote_file').text i18n.getMessage('firmwareFlasherButtonDownloading')
                $('a.load_remote_file').addClass 'disabled'
                $.get(summary.url, onLoadSuccess).fail failed_to_load
            else
                $('span.progressLabel').attr('i18n', 'firmwareFlasherFailedToLoadOnlineFirmware').removeClass 'i18n-replaced'
                i18n.localizePage()
            return
        $('a.flash_firmware').click ->
            if !$(this).hasClass('disabled')
                if !GUI.connect_lock
                    # button disabled while flashing is in progress
                    if self.parsed_hex != false
                        try
                            if self.unifiedTargetConfig and !self.parsed_hex.configInserted
                                configInserter = new ConfigInserter
                                if configInserter.insertConfig(self.parsed_hex, self.unifiedTargetConfig)
                                    self.parsed_hex.configInserted = true
                                else
                                    console.log 'Firmware does not support custom defaults.'
                                    self.unifiedTargetConfig = undefined
                                    self.unifiedTargetConfigName = undefined
                            flashFirmware self.parsed_hex
                        catch e
                            console.log 'Flashing failed: '.concat(e.message)
                    else
                        $('span.progressLabel').attr('i18n', 'firmwareFlasherFirmwareNotLoaded').removeClass 'i18n-replaced'
                        i18n.localizePage()
            return
        $(document).on 'click', 'span.progressLabel a.save_firmware', ->
            summary = $('select[name="firmware_version"] option:selected').data('summary')
            # Guard: no firmware selected or no hex data to save
            if !summary or !summary.file
                console.error 'Save firmware: no firmware version selected'
                return
            if !self.intel_hex
                console.error 'Save firmware: no firmware data loaded'
                GUI.log i18n.getMessage('firmwareFlasherFirmwareNotLoaded')
                return
            # Use native NW.js nwsaveas input instead of chrome.fileSystem (unstable in Chromium 130+)
            saveInput = $('<input type="file" nwsaveas="' + summary.file + '" accept=".hex" style="display:none">')
            $('body').append saveInput
            saveInput.on 'change', (e) ->
                savePath = e.target.value
                if !savePath
                    saveInput.remove()
                    return
                console.log 'Saving firmware to: ' + savePath
                blob = new Blob([ self.intel_hex ], type: 'text/plain')
                reader = new FileReader

                reader.onerror = (err) ->
                    console.error 'Failed to read firmware blob for save', err
                    GUI.log i18n.getMessage('firmwareFlasherWritePermissions')
                    saveInput.remove()
                    return

                reader.onloadend = ->
                    if reader.error or !reader.result
                        saveInput.remove()
                        return
                        # handled by reader.onerror (or corrupted read)
                    buffer = Buffer.from(new Uint8Array(reader.result))
                    require('fs').writeFile savePath, buffer, (err) ->
                        if err
                            console.error 'Failed to write firmware file: ' + err.message
                            GUI.log i18n.getMessage('firmwareFlasherWritePermissions')
                        else
                            console.log 'Firmware saved successfully to: ' + savePath
                        saveInput.remove()
                        return
                    return

                reader.readAsArrayBuffer blob
                return
            saveInput.trigger 'click'
            return
        chrome.storage.local.get 'selected_build_type', (result) ->
            # ensure default build type is selected
            buildType_e.val(result.selected_build_type or 0).trigger 'change'
            return
        ConfigStorage.get 'no_reboot_sequence', (result) ->
            if result.no_reboot_sequence
                $('input.updating').prop 'checked', true
                $('.flash_on_connect_wrapper').show()
            else
                $('input.updating').prop 'checked', false
            # bind UI hook so the status is saved on change
            $('input.updating').change ->
                status = $(this).is(':checked')
                if status
                    $('.flash_on_connect_wrapper').show()
                else
                    $('input.flash_on_connect').prop('checked', false).change()
                    $('.flash_on_connect_wrapper').hide()
                ConfigStorage.set 'no_reboot_sequence': status
                return
            $('input.updating').change()
            return
        ConfigStorage.get 'flash_manual_baud', (result) ->
            if result.flash_manual_baud
                $('input.flash_manual_baud').prop 'checked', true
            else
                $('input.flash_manual_baud').prop 'checked', false
            # bind UI hook so the status is saved on change
            $('input.flash_manual_baud').change ->
                status = $(this).is(':checked')
                ConfigStorage.set 'flash_manual_baud': status
                return
            $('input.flash_manual_baud').change()
            return
        ConfigStorage.get 'flash_manual_baud_rate', (result) ->
            $('#flash_manual_baud_rate').val result.flash_manual_baud_rate
            # bind UI hook so the status is saved on change
            $('#flash_manual_baud_rate').change ->
                baud = parseInt($('#flash_manual_baud_rate').val())
                ConfigStorage.set 'flash_manual_baud_rate': baud
                return
            $('input.flash_manual_baud_rate').change()
            return
        $('input.flash_on_connect').change(->
            status = $(this).is(':checked')
            if status

                _catch_new_port = ->
                    PortHandler.port_detected 'flash_detected_device', ((result) ->
                        port = result[0]
                        if !GUI.connect_lock
                            GUI.log i18n.getMessage('firmwareFlasherFlashTrigger', [ port ])
                            console.log 'Detected: ' + port + ' - triggering flash on connect'
                            # Trigger regular Flashing sequence
                            GUI.timeout_add 'initialization_timeout', (->
                                $('a.flash_firmware').click()
                                return
                            ), 100
                            # timeout so bus have time to initialize after being detected by the system
                        else
                            GUI.log i18n.getMessage('firmwareFlasherPreviousDevice', [ port ])
                        # Since current port_detected request was consumed, create new one
                        _catch_new_port()
                        return
                    ), false, true
                    return

                _catch_new_port()
            else
                PortHandler.flush_callbacks()
            return
        ).change()
        ConfigStorage.get 'erase_chip', (result) ->
            if result.erase_chip
                $('input.erase_chip').prop 'checked', true
            else
                $('input.erase_chip').prop 'checked', false
            $('input.erase_chip').change(->
                ConfigStorage.set 'erase_chip': $(this).is(':checked')
                return
            ).change()
            return
        chrome.storage.local.get 'show_development_releases', (result) ->
            $('input.show_development_releases').prop('checked', if result.show_development_releases != undefined then result.show_development_releases else true).change(->
                chrome.storage.local.set 'show_development_releases': $(this).is(':checked')
                return
            ).change()
            return
        $(document).keypress (e) ->
            if e.which == 13
                # enter
                # Trigger regular Flashing sequence
                $('a.flash_firmware').click()
            return
        # Update Firmware button at top
        $('div#flashbutton a.flash_state').addClass 'active'
        $('div#flashbutton a.flash').addClass 'active'
        GUI.content_ready callback
        return

    if GUI.active_tab != 'firmware_flasher'
        GUI.active_tab = 'firmware_flasher'
    self.selectedBoard = undefined
    self.localFirmwareLoaded = false
    self.isConfigLocal = false
    self.intel_hex = undefined
    self.parsed_hex = undefined
    unifiedSource = 'https://api.github.com/repos/dantiel/orniflight/contents/configs/default'
    self.jenkinsLoader.loadJobs 'Firmware', ->
        $('#content').load './tabs/firmware_flasher.html', onDocumentLoad
        return
    return

TABS.firmware_flasher.cleanup = (callback) ->
    PortHandler.flush_callbacks()
    FirmwareCache.unload()
    # unbind "global" events
    $(document).unbind 'keypress'
    $(document).off 'click', 'span.progressLabel a'
    # Update Firmware button at top
    $('div#flashbutton a.flash_state').removeClass 'active'
    $('div#flashbutton a.flash').removeClass 'active'
    analytics.resetFirmwareData()
    if callback
        callback()
    return

TABS.firmware_flasher.enableFlashing = (enabled) ->
    self = this
    if enabled
        $('a.flash_firmware').removeClass 'disabled'
    else
        $('a.flash_firmware').addClass 'disabled'
    return

TABS.firmware_flasher.FLASH_MESSAGE_TYPES =
    NEUTRAL: 'NEUTRAL'
    VALID: 'VALID'
    INVALID: 'INVALID'
    ACTION: 'ACTION'

TABS.firmware_flasher.flashingMessage = (message, type) ->
    self = this
    progressLabel_e = $('span.progressLabel')
    switch type
        when self.FLASH_MESSAGE_TYPES.VALID
            progressLabel_e.removeClass('invalid actionRequired').addClass 'valid'
        when self.FLASH_MESSAGE_TYPES.INVALID
            progressLabel_e.removeClass('valid actionRequired').addClass 'invalid'
        when self.FLASH_MESSAGE_TYPES.ACTION
            progressLabel_e.removeClass('valid invalid').addClass 'actionRequired'
        else
            progressLabel_e.removeClass 'valid invalid actionRequired'
            break
    if message != null
        if i18next.exists(message)
            progressLabel_e.attr('i18n', message).removeClass 'i18n-replaced'
            i18n.localizePage()
        else
            progressLabel_e.removeAttr 'i18n'
            progressLabel_e.html message
    self

TABS.firmware_flasher.flashProgress = (value) ->
    $('.progress').val value
    this

