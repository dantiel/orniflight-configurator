###
# Reads the chrome config, if DEFAULT or there is no config stored,
# returns the current locale to the callback
###

getStoredUserLocale = (cb) ->
    ConfigStorage.get 'userLanguageSelect', (result) ->
        userLanguage = 'DEFAULT'
        if result.userLanguageSelect
            userLanguage = result.userLanguageSelect
        i18n.selectedLanguage = userLanguage
        userLanguage = getValidLocale(userLanguage)
        cb userLanguage
        return
    return

getValidLocale = (userLocale) ->
    if userLocale == 'DEFAULT'
        userLocale = window.navigator.userLanguage or window.navigator.language
        console.log 'Detected locale ' + userLocale
        # The i18next can fallback automatically to the dialect, but needs to be used with hyphen and 
        # we use underscore because the eventPage.js uses Chrome localization that needs underscore.
        # If at some moment we get rid of the Chrome localization we can remove all of this
        userLocale = userLocale.replace('-', '_')
        # Locale not found
        if languagesAvailables.indexOf(userLocale) == -1
            # Is a composite locale?
            underscorePosition = userLocale.indexOf('_')
            if underscorePosition != -1
                userLocale = userLocale.substring(0, underscorePosition)
                # Locale dialect fallback not found
                if languagesAvailables.indexOf(userLocale) == -1
                    userLocale = 'en'
                    # Fallback language
            else
                userLocale = 'en'
    userLocale

'use strict'

###
# Wrapper around the i18n system
###

i18n = {}
i18n.ready = false
languagesAvailables = [
    'ca'
    'de'
    'en'
    'es'
    'fr'
    'gl'
    'hr'
    'id'
    'it'
    'ja'
    'ko'
    'lv'
    'pt'
    'ru'
    'sv'
    'zh_CN'
]

###*
# Functions that depend on the i18n framework
###

i18n.init = (cb) ->
    getStoredUserLocale (userLanguage) ->
        i18next.use(i18nextXHRBackend).init {
            lng: userLanguage
            getAsync: false
            debug: true
            ns: [ 'messages' ]
            defaultNS: [ 'messages' ]
            fallbackLng: 'en'
            backend: loadPath: './_locales/{{lng}}/{{ns}}.json'
        }, (err, t) ->
            if err != undefined
                console.error 'Error loading i18n ' + err
            else
                console.log 'i18n system loaded'
                i18n.ready = true
                i18n.localizePage true
                updateStatusBarVersion()
                detectedLanguage = i18n.getMessage('language_' + getValidLocale('DEFAULT'))
                i18n.addResources 'detectedLanguage': detectedLanguage
            if cb != undefined
                cb()
            return
        return
    # Subsequent language changes (user switches language after init)
    i18next.on 'languageChanged', (newLang) ->
        return unless i18n.ready

        translate = (messageID) ->
            i18n.getMessage messageID

        i18n.localizePage true
        updateStatusBarVersion()
        return
    return

i18n.changeLanguage = (languageSelected) ->
    ConfigStorage.set 'userLanguageSelect': languageSelected
    i18next.changeLanguage getValidLocale(languageSelected)
    i18n.selectedLanguage = languageSelected
    GUI.log i18n.getMessage('language_changed')
    return

i18n.getMessage = (messageID, parameters) ->
    translatedString = undefined
    # Option 1, no parameters or Object as parameters (i18Next type parameters)
    if parameters == undefined or parameters.constructor != Array and parameters instanceof Object
        translatedString = i18next.t(messageID + '.message', parameters)
        # Option 2: parameters as $1, $2, etc.
        # (deprecated, from the old Chrome i18n
    else
        translatedString = i18next.t(messageID + '.message')
        if parameters.constructor != Array
            parameters = [ parameters ]
        parameters.forEach (element, index) ->
            translatedString = translatedString.replace('$' + index + 1, element)
            return
    translatedString

i18n.getLanguagesAvailables = ->
    languagesAvailables

i18n.getCurrentLocale = ->
    i18next.language

i18n.existsMessage = (key) ->
    i18next.exists key

###*
# Helper functions, don't depend of the i18n framework
###

i18n.localizePage = (forceReTranslate) ->
    localized = 0

    translate = (messageID) ->
        localized++
        i18n.getMessage messageID

    if forceReTranslate
        $('[i18n]').each ->
            element = $(this)
            element.html translate(element.attr('i18n'))
            return
        $('[i18n_title]').each ->
            element = $(this)
            element.attr 'title', translate(element.attr('i18n_title'))
            return
        $('[i18n_value]').each ->
            element = $(this)
            element.val translate(element.attr('i18n_value'))
            return
        $('[i18n_placeholder]').each ->
            element = $(this)
            element.attr 'placeholder', translate(element.attr('i18n_placeholder'))
            return
    else
        $('[i18n]:not(.i18n-replaced)').each ->
            element = $(this)
            element.html translate(element.attr('i18n'))
            element.addClass 'i18n-replaced'
            return
        $('[i18n_title]:not(.i18n_title-replaced)').each ->
            element = $(this)
            element.attr 'title', translate(element.attr('i18n_title'))
            element.addClass 'i18n_title-replaced'
            return
        $('[i18n_value]:not(.i18n_value-replaced)').each ->
            element = $(this)
            element.val translate(element.attr('i18n_value'))
            element.addClass 'i18n_value-replaced'
            return
        $('[i18n_placeholder]:not(.i18n_placeholder-replaced)').each ->
            element = $(this)
            element.attr 'placeholder', translate(element.attr('i18n_placeholder'))
            element.addClass 'i18n_placeholder-replaced'
            return
    localized

i18n.addResources = (bundle) ->

    takeFirst = (obj) ->
        if obj.hasOwnProperty('length') and 0 < obj.length then obj[0] else obj

    lang = takeFirst(i18next.options.fallbackLng)
    ns = takeFirst(i18next.options.defaultNS)
    i18next.addResourceBundle lang, ns, bundle, true, true
    return