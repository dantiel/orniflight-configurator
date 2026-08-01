'use strict'

Analytics = (trackingId, userId, appName, appVersion, changesetId, os, checkForDebugVersions, optOut, debugMode, buildType) ->
    @_trackingId = trackingId
    @setOptOut optOut
    @_googleAnalytics = googleAnalytics
    @_googleAnalytics.initialize @_trackingId,
        storage: 'none'
        clientId: userId
        debug: ! !debugMode
    # Make it work for the Chrome App:
    @_googleAnalytics.set 'forceSSL', true
    @_googleAnalytics.set 'transport', 'xhr'
    # Make it work for NW.js:
    @_googleAnalytics.set 'checkProtocolTask', null
    @_googleAnalytics.set 'appName', appName
    @_googleAnalytics.set 'appVersion', if debugMode then appVersion + '-debug' else appVersion
    @EVENT_CATEGORIES =
        APPLICATION: 'Application'
        FLIGHT_CONTROLLER: 'FlightController'
        FIRMWARE: 'Firmware'
    @DATA =
        BOARD_TYPE: 'boardType'
        API_VERSION: 'apiVersion'
        FIRMWARE_TYPE: 'firmwareType'
        FIRMWARE_VERSION: 'firmwareVersion'
        FIRMWARE_NAME: 'firmwareName'
        FIRMWARE_SOURCE: 'firmwareSource'
        FIRMWARE_CHANNEL: 'firmwareChannel'
        FIRMWARE_ERASE_ALL: 'firmwareEraseAll'
        FIRMWARE_SIZE: 'firmwareSize'
        MCU_ID: 'mcuId'
        LOGGING_STATUS: 'loggingStatus'
        LOG_SIZE: 'logSize'
        TARGET_NAME: 'targetName'
        BOARD_NAME: 'boardName'
        MANUFACTURER_ID: 'manufacturerId'
        MCU_TYPE: 'mcuType'
    @DIMENSIONS =
        CONFIGURATOR_OS: 1
        BOARD_TYPE: 2
        FIRMWARE_TYPE: 3
        FIRMWARE_VERSION: 4
        API_VERSION: 5
        FIRMWARE_NAME: 6
        FIRMWARE_SOURCE: 7
        FIRMWARE_ERASE_ALL: 8
        CONFIGURATOR_EXPERT_MODE: 9
        FIRMWARE_CHANNEL: 10
        LOGGING_STATUS: 11
        MCU_ID: 12
        CONFIGURATOR_CHANGESET_ID: 13
        CONFIGURATOR_USE_DEBUG_VERSIONS: 14
        TARGET_NAME: 15
        BOARD_NAME: 16
        MANUFACTURER_ID: 17
        MCU_TYPE: 18
        CONFIGURATOR_BUILD_TYPE: 19
    @METRICS =
        FIRMWARE_SIZE: 1
        LOG_SIZE: 2
    @setDimension @DIMENSIONS.CONFIGURATOR_OS, os
    @setDimension @DIMENSIONS.CONFIGURATOR_CHANGESET_ID, changesetId
    @setDimension @DIMENSIONS.CONFIGURATOR_USE_DEBUG_VERSIONS, checkForDebugVersions
    @setDimension @DIMENSIONS.CONFIGURATOR_BUILD_TYPE, buildType
    @resetFlightControllerData()
    @resetFirmwareData()
    return

Analytics::setDimension = (dimension, value) ->
    dimensionName = 'dimension' + dimension
    @_googleAnalytics.custom dimensionName, value
    return

Analytics::setMetric = (metric, value) ->
    metricName = 'metric' + metric
    @_googleAnalytics.custom metricName, value
    return

Analytics::sendEvent = (category, action, options) ->
    @_googleAnalytics.event category, action, options
    return

Analytics::sendChangeEvents = (category, changeList) ->
    for actionName of changeList
        if changeList.hasOwnProperty(actionName)
            actionValue = changeList[actionName]
            if actionValue != undefined
                @sendEvent category, actionName, eventLabel: actionValue
    return

Analytics::sendAppView = (viewName) ->
    @_googleAnalytics.screenview viewName
    return

Analytics::sendTiming = (category, timing, value) ->
    @_googleAnalytics.timing category, timing, value
    return

Analytics::sendException = (message) ->
    @_googleAnalytics.exception message
    return

Analytics::setOptOut = (optOut) ->
    window['ga-disable-' + @_trackingId] = ! !optOut
    return

Analytics::_rebuildFlightControllerEvent = ->
    @setDimension @DIMENSIONS.BOARD_TYPE, @_flightControllerData[@DATA.BOARD_TYPE]
    @setDimension @DIMENSIONS.FIRMWARE_TYPE, @_flightControllerData[@DATA.FIRMWARE_TYPE]
    @setDimension @DIMENSIONS.FIRMWARE_VERSION, @_flightControllerData[@DATA.FIRMWARE_VERSION]
    @setDimension @DIMENSIONS.API_VERSION, @_flightControllerData[@DATA.API_VERSION]
    @setDimension @DIMENSIONS.LOGGING_STATUS, @_flightControllerData[@DATA.LOGGING_STATUS]
    @setDimension @DIMENSIONS.MCU_ID, @_flightControllerData[@DATA.MCU_ID]
    @setMetric @METRICS.LOG_SIZE, @_flightControllerData[@DATA.LOG_SIZE]
    @setDimension @DIMENSIONS.TARGET_NAME, @_flightControllerData[@DATA.TARGET_NAME]
    @setDimension @DIMENSIONS.BOARD_NAME, @_flightControllerData[@DATA.BOARD_NAME]
    @setDimension @DIMENSIONS.MANUFACTURER_ID, @_flightControllerData[@DATA.MANUFACTURER_ID]
    @setDimension @DIMENSIONS.MCU_TYPE, @_flightControllerData[@DATA.MCU_TYPE]
    return

Analytics::setFlightControllerData = (property, value) ->
    @_flightControllerData[property] = value
    @_rebuildFlightControllerEvent()
    return

Analytics::resetFlightControllerData = ->
    @_flightControllerData = {}
    @_rebuildFlightControllerEvent()
    return

Analytics::_rebuildFirmwareEvent = ->
    @setDimension @DIMENSIONS.FIRMWARE_NAME, @_firmwareData[@DATA.FIRMWARE_NAME]
    @setDimension @DIMENSIONS.FIRMWARE_SOURCE, @_firmwareData[@DATA.FIRMWARE_SOURCE]
    @setDimension @DIMENSIONS.FIRMWARE_ERASE_ALL, @_firmwareData[@DATA.FIRMWARE_ERASE_ALL]
    @setDimension @DIMENSIONS.FIRMWARE_CHANNEL, @_firmwareData[@DATA.FIRMWARE_CHANNEL]
    @setMetric @METRICS.FIRMWARE_SIZE, @_firmwareData[@DATA.FIRMWARE_SIZE]
    return

Analytics::setFirmwareData = (property, value) ->
    @_firmwareData[property] = value
    @_rebuildFirmwareEvent()
    return

Analytics::resetFirmwareData = ->
    @_firmwareData = {}
    @_rebuildFirmwareEvent()
    return

