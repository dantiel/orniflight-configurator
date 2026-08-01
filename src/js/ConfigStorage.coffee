'use strict'
# idea here is to abstract around the use of chrome.storage.local as it functions differently from "localStorage" and IndexedDB
# localStorage deals with strings, not objects, so the objects have been serialized.
ConfigStorage = 
    get: (key, callback) ->
        `var obj`
        if GUI.isChromeApp()
            chrome.storage.local.get key, callback
        else
            #console.log('Abstraction.get',key);
            if Array.isArray(key)
                obj = {}
                key.forEach (element) ->
                    try
                        obj = Object.assign({}, obj, JSON.parse(window.localStorage.getItem(element)))
                    catch e
                        # is okay
                    return
                callback obj
            else
                keyValue = window.localStorage.getItem(key)
                if keyValue
                    obj = {}
                    try
                        obj = JSON.parse(keyValue)
                    catch e
                        # It's fine if we fail that parse
                    callback obj
                else
                    callback {}
        return
    set: (input) ->
        if GUI.isChromeApp()
            chrome.storage.local.set input
        else
            #console.log('Abstraction.set',input);
            Object.keys(input).forEach (element) ->
                tmpObj = {}
                tmpObj[element] = input[element]
                window.localStorage.setItem element, JSON.stringify(tmpObj)
                return
        return

