'use strict'
TABS.landing = {}

TABS.landing.initialize = (callback) ->
    self = this
    if GUI.active_tab != 'landing'
        GUI.active_tab = 'landing'
    $('#content').load './tabs/landing.html', ->
        bottomSection = $('.languageSwitcher')

        showLang = (newLang) ->
            `var bottomSection`
            bottomSection = $('.languageSwitcher')
            bottomSection.find('a').each (index) ->
                element = $(this)
                languageSelected = element.attr('lang')
                if newLang == languageSelected
                    element.removeClass 'selected_language'
                    element.addClass 'selected_language'
                else
                    element.removeClass 'selected_language'
                return
            return

        bottomSection.html ' <span i18n="language_choice_message"></span>'
        bottomSection.append ' <a href="#" i18n="language_default_pretty" lang="DEFAULT"></a>'
        languagesAvailables = i18n.getLanguagesAvailables()
        languagesAvailables.forEach (element) ->
            bottomSection.append ' <a href="#" lang="' + element + '" i18n="language_' + element + '"></a>'
            return
        bottomSection.find('a').each (index) ->
            element = $(this)
            element.click ->
                `var element`
                element = $(this)
                languageSelected = element.attr('lang')
                if !languageSelected
                    return
                if i18n.selectedLanguage != languageSelected
                    i18n.changeLanguage languageSelected
                    showLang languageSelected
                return
            return
        showLang i18n.selectedLanguage
        # translate to user-selected language
        i18n.localizePage()
        GUI.content_ready callback
        return
    return

TABS.landing.cleanup = (callback) ->
    if callback
        callback()
    return

