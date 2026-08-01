removePromptHash = (promptText) ->
    promptText.replace /^# /, ''

cliBufferCharsToDelete = (command, buffer) ->
    commonChars = 0
    i = 0
    while i < buffer.length
        if command[i] == buffer[i]
            commonChars++
        else
            break
        i++
    buffer.length - commonChars

commandWithBackSpaces = (command, buffer, noOfCharsToDelete) ->
    backspace = String.fromCharCode(127)
    backspace.repeat(noOfCharsToDelete) + command.substring(buffer.length - noOfCharsToDelete, command.length)

getCliCommand = (command, cliBuffer) ->
    buffer = removePromptHash(cliBuffer)
    bufferRegex = new RegExp('^' + buffer, 'g')
    if command.match(bufferRegex)
        return command.replace(bufferRegex, '')
    noOfCharsToDelete = cliBufferCharsToDelete(command, buffer)
    commandWithBackSpaces command, buffer, noOfCharsToDelete

copyToClipboard = (text) ->

    onCopySuccessful = ->
        analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'CliCopyToClipboard', text.length
        button = $('.tab-cli .copy')
        origText = button.text()
        origWidth = button.css('width')
        button.text i18n.getMessage('cliCopySuccessful')
        button.css
            width: origWidth
            textAlign: 'center'
        setTimeout (->
            button.text origText
            button.css
                width: ''
                textAlign: ''
            return
        ), 1500
        return

    onCopyFailed = (ex) ->
        console.warn ex
        return

    Clipboard.writeText text, onCopySuccessful, onCopyFailed
    return

writeToOutput = (text) ->
    $('.tab-cli .window .wrapper').append text
    $('.tab-cli .window').scrollTop $('.tab-cli .window .wrapper').height()
    return

writeLineToOutput = (text) ->
    if CliAutoComplete.isBuilding()
        CliAutoComplete.builderParseLine text
        return
        # suppress output if in building state
    if text.startsWith('###ERROR: ')
        writeToOutput '<span class="error_message">' + text + '</span><br>'
    else
        writeToOutput text + '<br>'
    return

setPrompt = (text) ->
    $('.tab-cli textarea').val text
    return

'use strict'
TABS.cli =
    lineDelayMs: 15
    profileSwitchDelayMs: 100
    outputHistory: ''
    cliBuffer: ''
    GUI: snippetPreviewWindow: null

TABS.cli.initialize = (callback) ->
    self = this

    executeCommands = (out_string) ->
        self.history.add out_string.trim()
        outputArray = out_string.split('\n')
        Promise.reduce outputArray, ((delay, line, index) ->
            new Promise((resolve) ->
                GUI.timeout_add 'CLI_send_slowly', (->
                    processingDelay = self.lineDelayMs
                    line = line.trim()
                    if line.toLowerCase().startsWith('profile')
                        processingDelay = self.profileSwitchDelayMs
                    isLastCommand = outputArray.length == index + 1
                    if isLastCommand and self.cliBuffer
                        line = getCliCommand(line, self.cliBuffer)
                    self.sendLine line, ->
                        resolve processingDelay
                        return
                    return
                ), delay
                return
)
        ), 0
        return

    if GUI.active_tab != 'cli'
        GUI.active_tab = 'cli'
    self.outputHistory = ''
    self.cliBuffer = ''
    enterKeyCode = 13
    $('#content').load './tabs/cli.html', ->
        # translate to user-selected language
        i18n.localizePage()
        CONFIGURATOR.cliActive = true
        textarea = $('.tab-cli textarea[name="commands"]')
        CliAutoComplete.initialize textarea, self.sendLine.bind(self), writeToOutput
        $(CliAutoComplete).on 'build:start', ->
            textarea.val('').attr('placeholder', i18n.getMessage('cliInputPlaceholderBuilding')).prop 'disabled', true
            return
        $(CliAutoComplete).on 'build:stop', ->
            textarea.attr('placeholder', i18n.getMessage('cliInputPlaceholder')).prop('disabled', false).focus()
            return
        $('.tab-cli .save').click ->
            prefix = 'cli'
            suffix = 'txt'
            filename = generateFilename(prefix, suffix)
            accepts = [ {
                description: suffix.toUpperCase() + ' files'
                extensions: [ suffix ]
            } ]
            chrome.fileSystem.chooseEntry {
                type: 'saveFile'
                suggestedName: filename
                accepts: accepts
            }, (entry) ->
                if chrome.runtime.lastError
                    console.error chrome.runtime.lastError.message
                    return
                if !entry
                    console.log 'No file selected'
                    return
                entry.createWriter ((writer) ->

                    writer.onerror = ->
                        console.error 'Failed to write file'
                        return

                    writer.onwriteend = ->
                        if self.outputHistory.length > 0 and writer.length == 0
                            writer.write new Blob([ self.outputHistory ], type: 'text/plain')
                        else
                            analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'CliSave', self.outputHistory.length
                            console.log 'write complete'
                        return

                    writer.truncate 0
                    return
                ), ->
                    console.error 'Failed to get file writer'
                    return
                return
            return
        $('.tab-cli .clear').click ->
            self.outputHistory = ''
            $('.tab-cli .window .wrapper').empty()
            return
        if Clipboard.available
            $('.tab-cli .copy').click ->
                copyToClipboard self.outputHistory
                return
        else
            $('.tab-cli .copy').hide()
        $('.tab-cli .load').click ->
            accepts = [
                {
                    description: 'Config files'
                    extensions: [
                        'txt'
                        'config'
                    ]
                }
                { description: 'All files' }
            ]
            chrome.fileSystem.chooseEntry {
                type: 'openFile'
                accepts: accepts
            }, (entry) ->

                executeSnippet = (fileName) ->
                    commands = previewArea.val()
                    analytics.sendEvent analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, 'CliExecuteFromFile', fileName
                    executeCommands commands
                    self.GUI.snippetPreviewWindow.close()
                    return

                previewCommands = (result, fileName) ->
                    if !self.GUI.snippetPreviewWindow
                        self.GUI.snippetPreviewWindow = new jBox('Modal',
                            id: 'snippetPreviewWindow'
                            width: 'auto'
                            height: 'auto'
                            closeButton: 'title'
                            animation: false
                            isolateScroll: false
                            title: i18n.getMessage('cliConfirmSnippetDialogTitle', fileName: fileName)
                            content: $('#snippetpreviewcontent')
                            onCreated: ->
                                $('#snippetpreviewcontent a.confirm').click ->
                                    executeSnippet fileName
                                    return
                                return
)
                    previewArea.val result
                    self.GUI.snippetPreviewWindow.open()
                    return

                if chrome.runtime.lastError
                    console.error chrome.runtime.lastError.message
                    return
                if !entry
                    console.log 'No file selected'
                    return
                previewArea = $('#snippetpreviewcontent textarea#preview')
                entry.file (file) ->
                    reader = new FileReader

                    reader.onload = ->
                        previewCommands reader.result, file.name

                    reader.onerror = ->
                        console.error reader.error

                    reader.readAsText file
                    return
                return
            return
        # Tab key detection must be on keydown,
        # `keypress`/`keyup` happens too late, as `textarea` will have already lost focus.
        textarea.keydown (event) ->
            tabKeyCode = 9
            if event.which == tabKeyCode
                # prevent default tabbing behaviour
                event.preventDefault()
                if !CliAutoComplete.isEnabled()
                    # Native FC autoComplete
                    outString = textarea.val()
                    lastCommand = outString.split('\n').pop()
                    command = getCliCommand(lastCommand, self.cliBuffer)
                    if command
                        self.sendNativeAutoComplete command
                        textarea.val ''
                else if !CliAutoComplete.isOpen() and !CliAutoComplete.isBuilding()
                    # force show autocomplete on Tab
                    CliAutoComplete.openLater true
            return
        textarea.keypress (event) ->
            if event.which == enterKeyCode
                event.preventDefault()
                # prevent the adding of new line
                if CliAutoComplete.isBuilding()
                    return
                    # silently ignore commands if autocomplete is still building
                out_string = textarea.val()
                executeCommands out_string
                textarea.val ''
            return
        textarea.keyup (event) ->
            keyUp = 38: true
            keyDown = 40: true
            if CliAutoComplete.isOpen()
                return
                # disable history keys if autocomplete is open
            if event.keyCode of keyUp
                textarea.val self.history.prev()
            if event.keyCode of keyDown
                textarea.val self.history.next()
            return
        # give input element user focus
        textarea.focus()
        GUI.timeout_add 'enter_cli', (->
            # Enter CLI mode
            bufferOut = new ArrayBuffer(1)
            bufView = new Uint8Array(bufferOut)
            bufView[0] = 0x23
            # #
            serial.send bufferOut
            return
        ), 250
        GUI.content_ready callback
        return
    return

TABS.cli.history =
    history: []
    index: 0

TABS.cli.history.add = (str) ->
    @history.push str
    @index = @history.length
    return

TABS.cli.history.prev = ->
    if @index > 0
        @index -= 1
    @history[@index]

TABS.cli.history.next = ->
    if @index < @history.length
        @index += 1
    @history[@index - 1]

backspaceCode = 8
lineFeedCode = 10
carriageReturnCode = 13

TABS.cli.read = (readInfo) ->

    ###Some info about handling line feeds and carriage return
         line feed = LF = \n = 0x0A = 10
        carriage return = CR = \r = 0x0D = 13
         MAC only understands CR
        Linux and Unix only understand LF
        Windows understands (both) CRLF
        Chrome OS currently unknown
    ###

    data = new Uint8Array(readInfo.data)
    validateText = ''
    sequenceCharsToSkip = 0
    i = 0
    while i < data.length
        currentChar = String.fromCharCode(data[i])
        if !CONFIGURATOR.cliValid
            # try to catch part of valid CLI enter message
            validateText += currentChar
            writeToOutput currentChar
            i++
            continue
        escapeSequenceCode = 27
        escapeSequenceCharLength = 3
        if data[i] == escapeSequenceCode and !sequenceCharsToSkip
            # ESC + other
            sequenceCharsToSkip = escapeSequenceCharLength
        if sequenceCharsToSkip
            sequenceCharsToSkip--
            i++
            continue
        switch data[i]
            when lineFeedCode
                if GUI.operating_system == 'Windows'
                    writeLineToOutput @cliBuffer
                    @cliBuffer = ''
            when carriageReturnCode
                if GUI.operating_system != 'Windows'
                    writeLineToOutput @cliBuffer
                    @cliBuffer = ''
            when 60
                @cliBuffer += '&lt'
            when 62
                @cliBuffer += '&gt'
            when backspaceCode
                @cliBuffer = @cliBuffer.slice(0, -1)
                @outputHistory = @outputHistory.slice(0, -1)
                i++
                continue
            else
                @cliBuffer += currentChar
        if !CliAutoComplete.isBuilding()
            # do not include the building dialog into the history
            @outputHistory += currentChar
        if @cliBuffer == 'Rebooting'
            CONFIGURATOR.cliActive = false
            CONFIGURATOR.cliValid = false
            GUI.log i18n.getMessage('cliReboot')
            reinitialiseConnection self
        i++
    if !CONFIGURATOR.cliValid and validateText.indexOf('CLI') != -1
        GUI.log i18n.getMessage('cliEnter')
        CONFIGURATOR.cliValid = true
        # begin output history with the prompt (last line of welcome message)
        # this is to match the content of the history with what the user sees on this tab
        lastLine = validateText.split('\n').pop()
        @outputHistory = lastLine
        validateText = ''
        if CliAutoComplete.isEnabled() and !CliAutoComplete.isBuilding()
            # start building autoComplete
            CliAutoComplete.builderStart()
    if !CliAutoComplete.isEnabled()
        setPrompt removePromptHash(@cliBuffer)
    return

TABS.cli.sendLine = (line, callback) ->
    @send line + '\n', callback
    return

TABS.cli.sendNativeAutoComplete = (line, callback) ->
    @send line + '\u0009', callback
    return

TABS.cli.send = (line, callback) ->
    bufferOut = new ArrayBuffer(line.length)
    bufView = new Uint8Array(bufferOut)
    c_key = 0
    while c_key < line.length
        bufView[c_key] = line.charCodeAt(c_key)
        c_key++
    serial.send bufferOut, callback
    return

TABS.cli.cleanup = (callback) ->
    if TABS.cli.GUI.snippetPreviewWindow
        TABS.cli.GUI.snippetPreviewWindow.destroy()
        TABS.cli.GUI.snippetPreviewWindow = null
    if !(CONFIGURATOR.connectionValid and CONFIGURATOR.cliValid and CONFIGURATOR.cliActive)
        if callback
            callback()
        return
    @send getCliCommand('exit\u000d', @cliBuffer), (writeInfo) ->
        # we could handle this "nicely", but this will do for now
        # (another approach is however much more complicated):
        # we can setup an interval asking for data lets say every 200ms, when data arrives, callback will be triggered and tab switched
        # we could probably implement this someday
        if callback
            callback()
        CONFIGURATOR.cliActive = false
        CONFIGURATOR.cliValid = false
        return
    CliAutoComplete.cleanup()
    $(CliAutoComplete).off()
    return

