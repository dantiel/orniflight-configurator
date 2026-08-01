'use strict'

ReleaseChecker = (releaseName, releaseUrl) ->
    self = this
    self._releaseName = releaseName
    self._releaseDataTag = self._releaseName + 'ReleaseData'
    self._releaseLastUpdateTag = self._releaseName + 'ReleaseLastUpdate'
    self._releaseUrl = releaseUrl
    return

ReleaseChecker::loadReleaseData = (processFunction) ->
    self = this
    chrome.storage.local.get [
        self._releaseLastUpdateTag
        self._releaseDataTag
    ], (result) ->
        releaseDataTimestamp = $.now()
        cacheReleaseData = result[self._releaseDataTag]
        cachedReleaseLastUpdate = result[self._releaseLastUpdateTag]
        if !cacheReleaseData or !cachedReleaseLastUpdate or releaseDataTimestamp - cachedReleaseLastUpdate > 300 * 1000
            $.get(self._releaseUrl, (releaseData) ->
                GUI.log i18n.getMessage('releaseCheckLoaded', [ self._releaseName ])
                data = {}
                data[self._releaseDataTag] = releaseData
                data[self._releaseLastUpdateTag] = releaseDataTimestamp
                chrome.storage.local.set data, ->
                self._processReleaseData releaseData, processFunction
                return
            ).fail (data) ->
                message = ''
                if data['responseJSON']
                    message = data['responseJSON'].message
                GUI.log i18n.getMessage('releaseCheckFailed', [
                    self._releaseName
                    message
                ])
                self._processReleaseData cacheReleaseData, processFunction
                return
        else
            if cacheReleaseData
                GUI.log i18n.getMessage('releaseCheckCached', [ self._releaseName ])
            self._processReleaseData cacheReleaseData, processFunction
        return
    return

ReleaseChecker::_processReleaseData = (releaseData, processFunction) ->
    if releaseData
        processFunction releaseData
    else
        GUI.log i18n.getMessage('releaseCheckNoInfo', [ self._releaseName ])
        processFunction()
    return

