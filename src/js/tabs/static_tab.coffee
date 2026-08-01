'use strict'
TABS.staticTab = {}

TABS.staticTab.initialize = (staticTabName, callback) ->
    self = this
    if GUI.active_tab != staticTabName
        GUI.active_tab = staticTabName
    tabFile = './tabs/' + staticTabName + '.html'
    $('#content').html '<div id="tab-static"><div id="tab-static-contents"></div>'
    $('#tab-static-contents').load tabFile, ->
        # translate to user-selected language
        i18n.localizePage()
        GUI.content_ready callback
        return
    return

# Just noting that other tabs have cleanup functions.

