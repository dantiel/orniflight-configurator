# return true if user has choose a special peripheral

isPeripheralSelected = (peripheralName) ->
    portIndex = 0
    while portIndex < SERIAL_CONFIG.ports.length
        serialPort = SERIAL_CONFIG.ports[portIndex]
        if serialPort.functions.indexOf(peripheralName) >= 0
            return true
        portIndex++
    false

# Adjust the real name for a modeId. Useful if it belongs to a peripheral

adjustBoxNameIfPeripheralWithModeID = (modeId, defaultName) ->
    if isPeripheralSelected('RUNCAM_DEVICE_CONTROL')
        switch modeId
            when 32
                # BOXCAMERA1
                return i18n.getMessage('modeCameraWifi')
            when 33
                # BOXCAMERA2
                return i18n.getMessage('modeCameraPower')
            when 34
                # BOXCAMERA3
                return i18n.getMessage('modeCameraChangeMode')
            else
                return defaultName
    defaultName

'use strict'

