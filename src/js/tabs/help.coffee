'use strict'
TABS.help = {}

TABS.help.initialize = (callback) ->
    self = this
    if GUI.active_tab != 'help'
        GUI.active_tab = 'help'
    $('#content').load './tabs/help.html', ->
        i18n.localizePage()
        GUI.content_ready callback
        return
    return

TABS.help.cleanup = (callback) ->
    if callback
        callback()
    return

