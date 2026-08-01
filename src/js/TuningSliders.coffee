'use strict'
TuningSliders = 
    MasterSliderValue: 1
    PDRatioSliderValue: 1
    PDGainSliderValue: 1
    ResponseSliderValue: 1
    pidSlidersUnavailable: false
    gyroFilterSliderValue: 1
    dtermFilterSliderValue: 1
    filterGyroSliderUnavailable: false
    filterDTermSliderUnavailable: false
    dMinFeatureEnabled: true
    defaultPDRatio: 0
    PID_DEFAULT: []
    FILTER_DEFAULT: {}
    cachedPidSliderValues: false
    cachedGyroSliderValues: false
    cachedDTermSliderValues: false
    expertMode: false

TuningSliders.initialize = ->
    @PID_DEFAULT = FC.getPidDefaults()
    @FILTER_DEFAULT = FC.getFilterDefaults()
    @setDMinFeatureEnabled $('#dMinSwitch').is(':checked')
    @setExpertMode $('input[name="expertModeCheckbox"]').is(':checked')
    @initPidSlidersPosition()
    @initGyroFilterSliderPosition()
    @initDTermFilterSliderPosition()
    # after refresh cached values are not available
    @cachedPidSliderValues = false
    @cachedGyroSliderValues = false
    @cachedDTermSliderValues = false
    @updatePidSlidersDisplay()
    @updateFilterSlidersDisplay()
    return

TuningSliders.setDMinFeatureEnabled = (dMinFeatureEnabled) ->
    @dMinFeatureEnabled = dMinFeatureEnabled
    if @dMinFeatureEnabled
        @defaultPDRatio = @PID_DEFAULT[0] / @PID_DEFAULT[2]
    else
        @defaultPDRatio = @PID_DEFAULT[0] / @PID_DEFAULT[3]
    return

TuningSliders.setExpertMode = (expertMode) ->
    @expertMode = expertMode
    allTuningSliderElements = $('#tuningMasterSlider, #tuningPDRatioSlider, #tuningPDGainSlider,                                    #tuningResponseSlider, #tuningGyroFilterSlider, #tuningDTermFilterSlider')
    if @expertMode
        allTuningSliderElements.removeClass 'nonExpertModeSliders'
    else
        allTuningSliderElements.addClass 'nonExpertModeSliders'
    return

TuningSliders.scaleSliderValue = (value) ->
    if value > 1
        Math.round(((value - 1) * 2 + 1) * 10) / 10
    else
        value

TuningSliders.downscaleSliderValue = (value) ->
    if value > 1
        (value - 1) / 2 + 1
    else
        value

TuningSliders.initPidSlidersPosition = ->
    # used to estimate PID slider positions based on PIDF values, and set respective slider position
    # provides only an estimation due to limitation of feature without firmware support, to be improved in later versions
    @MasterSliderValue = Math.round(PIDs[2][1] / @PID_DEFAULT[11] * 10) / 10
    @PDRatioSliderValue = Math.round(PIDs[0][0] / PIDs[0][2] / @defaultPDRatio * 10) / 10
    if @dMinFeatureEnabled
        @PDGainSliderValue = Math.round(ADVANCED_TUNING.dMinRoll / @MasterSliderValue / @PID_DEFAULT[3] * 10) / 10
    else
        @PDGainSliderValue = Math.round(PIDs[0][2] / @MasterSliderValue / @PID_DEFAULT[3] * 10) / 10
    @ResponseSliderValue = Math.round(ADVANCED_TUNING.feedforwardRoll / @MasterSliderValue / @PID_DEFAULT[4] * 10) / 10
    $('output[name="tuningMasterSlider-number"]').val @MasterSliderValue
    $('output[name="tuningPDRatioSlider-number"]').val @PDRatioSliderValue
    $('output[name="tuningPDGainSlider-number"]').val @PDGainSliderValue
    $('output[name="tuningResponseSlider-number"]').val @ResponseSliderValue
    $('#tuningMasterSlider').val @downscaleSliderValue(@MasterSliderValue)
    $('#tuningPDRatioSlider').val @downscaleSliderValue(@PDRatioSliderValue)
    $('#tuningPDGainSlider').val @downscaleSliderValue(@PDGainSliderValue)
    $('#tuningResponseSlider').val @downscaleSliderValue(@ResponseSliderValue)
    return

TuningSliders.initGyroFilterSliderPosition = ->
    @gyroFilterSliderValue = Math.round((FILTER_CONFIG.gyro_lowpass_dyn_min_hz + FILTER_CONFIG.gyro_lowpass_dyn_max_hz + FILTER_CONFIG.gyro_lowpass2_hz) / (@FILTER_DEFAULT.gyro_lowpass_dyn_min_hz + @FILTER_DEFAULT.gyro_lowpass_dyn_max_hz + @FILTER_DEFAULT.gyro_lowpass2_hz) * 100) / 100
    $('output[name="tuningGyroFilterSlider-number"]').val @gyroFilterSliderValue
    $('#tuningGyroFilterSlider').val @downscaleSliderValue(@gyroFilterSliderValue)
    return

TuningSliders.initDTermFilterSliderPosition = ->
    @dtermFilterSliderValue = Math.round((FILTER_CONFIG.dterm_lowpass_dyn_min_hz + FILTER_CONFIG.dterm_lowpass_dyn_max_hz + FILTER_CONFIG.dterm_lowpass2_hz) / (@FILTER_DEFAULT.dterm_lowpass_dyn_min_hz + @FILTER_DEFAULT.dterm_lowpass_dyn_max_hz + @FILTER_DEFAULT.dterm_lowpass2_hz) * 100) / 100
    $('output[name="tuningDTermFilterSlider-number"]').val @dtermFilterSliderValue
    $('#tuningDTermFilterSlider').val @downscaleSliderValue(@dtermFilterSliderValue)
    return

TuningSliders.resetPidSliders = ->
    if !@cachedPidSliderValues
        $('#tuningMasterSlider').val 1
        $('#tuningPDRatioSlider').val 1
        $('#tuningPDGainSlider').val 1
        $('#tuningResponseSlider').val 1
        @MasterSliderValue = 1
        @PDRatioSliderValue = 1
        @PDGainSliderValue = 1
        @ResponseSliderValue = 1
    @calculateNewPids()
    @updatePidSlidersDisplay()
    return

TuningSliders.resetGyroFilterSlider = ->
    if !@cachedGyroSliderValues
        $('#tuningGyroFilterSlider').val 1
        @gyroFilterSliderValue = 1
    @calculateNewGyroFilters()
    @updateFilterSlidersDisplay()
    return

TuningSliders.resetDTermFilterSlider = ->
    if !@cachedDTermSliderValues
        $('#tuningDTermFilterSlider').val 1
        @dtermFilterSliderValue = 1
    @calculateNewDTermFilters()
    @updateFilterSlidersDisplay()
    return

TuningSliders.updatePidSlidersDisplay = ->
    # check if pid values changed manually by saving current values, doing the slider based calculation, and comaparing
    # if values before and after calculation, if all of them are equal the values haven't been changed manually
    WARNING_P_GAIN = 70
    WARNING_I_GAIN = 120
    WARNING_DMAX_GAIN = 60
    WARNING_DMIN_GAIN = 40
    @pidSlidersUnavailable = false
    currentPIDs = []
    PID_names.forEach (elementPid, indexPid) ->
        searchRow = $('.pid_tuning .' + elementPid + ' input')
        searchRow.each (indexInput) ->
            if indexPid < 3 and indexInput < 5
                currentPIDs.push $(this).val()
            return
        return
    @calculateNewPids()
    PID_names.forEach (elementPid, indexPid) ->
        searchRow = $('.pid_tuning .' + elementPid + ' input')
        searchRow.each (indexInput) ->
            if indexPid < 3 and indexInput < 5
                if currentPIDs[indexPid * 5 + indexInput] != $(this).val()
                    TuningSliders.pidSlidersUnavailable = true
                $(this).val currentPIDs[indexPid * 5 + indexInput]
            return
        return
    if $('input[id="useIntegratedYaw"]').is(':checked')
        @pidSlidersUnavailable = true
    if !@pidSlidersUnavailable
        @cachedPidSliderValues = true
    $('.tuningPIDSliders').toggle !@pidSlidersUnavailable
    $('.subtab-pid .slidersDisabled').toggle @pidSlidersUnavailable
    $('.subtab-pid .nonExpertModeSlidersNote').toggle !@pidSlidersUnavailable and !@expertMode
    $('.subtab-pid .slidersWarning').toggle (PIDs[1][0] > WARNING_P_GAIN or PIDs[1][1] > WARNING_I_GAIN or PIDs[1][2] > WARNING_DMAX_GAIN or ADVANCED_TUNING.dMinPitch > WARNING_DMIN_GAIN) and !@pidSlidersUnavailable
    return

TuningSliders.updateFilterSlidersDisplay = ->
    # check if filters changed manually by comapring current value and those based on slider position
    WARNING_FILTER_HIGH_GAIN = 1.4
    WARNING_FILTER_LOW_GAIN = 0.7
    @filterGyroSliderUnavailable = false
    @filterDTermSliderUnavailable = false
    if $('.pid_filter input[name="gyroLowpassDynMinFrequency"]').val() != Math.round(@FILTER_DEFAULT.gyro_lowpass_dyn_min_hz * @gyroFilterSliderValue) or $('.pid_filter input[name="gyroLowpassDynMaxFrequency"]').val() != Math.round(@FILTER_DEFAULT.gyro_lowpass_dyn_max_hz * @gyroFilterSliderValue) or $('.pid_filter select[name="gyroLowpassDynType"]').val() != @FILTER_DEFAULT.gyro_lowpass_type or $('.pid_filter input[name="gyroLowpass2Frequency"]').val() != Math.round(@FILTER_DEFAULT.gyro_lowpass2_hz * @gyroFilterSliderValue) or $('.pid_filter select[name="gyroLowpass2Type"]').val() != @FILTER_DEFAULT.gyro_lowpass2_type
        $('.tuningFilterSliders .sliderLabels tr:first-child').hide()
        @filterGyroSliderUnavailable = true
    else
        $('.tuningFilterSliders .sliderLabels tr:first-child').show()
        @cachedGyroSliderValues = true
    if $('.pid_filter input[name="dtermLowpassDynMinFrequency"]').val() != Math.round(@FILTER_DEFAULT.dterm_lowpass_dyn_min_hz * @dtermFilterSliderValue) or $('.pid_filter input[name="dtermLowpassDynMaxFrequency"]').val() != Math.round(@FILTER_DEFAULT.dterm_lowpass_dyn_max_hz * @dtermFilterSliderValue) or $('.pid_filter select[name="dtermLowpassDynType"]').val() != @FILTER_DEFAULT.dterm_lowpass_type or $('.pid_filter input[name="dtermLowpass2Frequency"]').val() != Math.round(@FILTER_DEFAULT.dterm_lowpass2_hz * @dtermFilterSliderValue) or $('.pid_filter select[name="dtermLowpass2Type"]').val() != @FILTER_DEFAULT.dterm_lowpass2_type
        $('.tuningFilterSliders .sliderLabels tr:last-child').hide()
        @filterDTermSliderUnavailable = true
    else
        $('.tuningFilterSliders .sliderLabels tr:last-child').show()
        @cachedDTermSliderValues = true
    $('.tuningFilterSliders').toggle !(@filterGyroSliderUnavailable and @filterDTermSliderUnavailable)
    $('.subtab-filter .slidersDisabled').toggle @filterGyroSliderUnavailable or @filterDTermSliderUnavailable
    $('.subtab-filter .nonExpertModeSlidersNote').toggle (!@filterGyroSliderUnavailable or !@filterDTermSliderUnavailable) and !@expertMode
    $('.subtab-filter .slidersWarning').toggle (@gyroFilterSliderValue >= WARNING_FILTER_HIGH_GAIN or @gyroFilterSliderValue <= WARNING_FILTER_LOW_GAIN) and !@filterGyroSliderUnavailable or (@dtermFilterSliderValue >= WARNING_FILTER_HIGH_GAIN or @dtermFilterSliderValue <= WARNING_FILTER_LOW_GAIN) and !@filterDTermSliderUnavailable
    return

TuningSliders.calculateNewPids = ->
    # this is the main calculation for PID sliders, inputs are in form of slider position values
    # values get set both into forms and their respective variables
    MAX_PID_GAIN = 200
    MAX_DMIN_GAIN = 100
    MAX_FF_GAIN = 2000
    if @dMinFeatureEnabled
        #dmin
        ADVANCED_TUNING.dMinRoll = Math.round(@PID_DEFAULT[3] * @PDGainSliderValue)
        ADVANCED_TUNING.dMinPitch = Math.round(@PID_DEFAULT[8] * @PDGainSliderValue)
        # dmax
        PIDs[0][2] = Math.round(@PID_DEFAULT[2] * @PDGainSliderValue)
        PIDs[1][2] = Math.round(@PID_DEFAULT[7] * @PDGainSliderValue)
    else
        ADVANCED_TUNING.dMinRoll = 0
        ADVANCED_TUNING.dMinPitch = 0
        PIDs[0][2] = Math.round(@PID_DEFAULT[3] * @PDGainSliderValue)
        PIDs[1][2] = Math.round(@PID_DEFAULT[8] * @PDGainSliderValue)
    PIDs[2][0] = Math.round(@PID_DEFAULT[10] * @PDGainSliderValue)
    # p
    PIDs[0][0] = Math.round(PIDs[0][2] * @defaultPDRatio * @PDRatioSliderValue)
    PIDs[1][0] = Math.round(PIDs[1][2] * @defaultPDRatio * @PDRatioSliderValue)
    # ff
    ADVANCED_TUNING.feedforwardRoll = Math.round(@PID_DEFAULT[4] * @ResponseSliderValue)
    ADVANCED_TUNING.feedforwardPitch = Math.round(@PID_DEFAULT[9] * @ResponseSliderValue)
    ADVANCED_TUNING.feedforwardYaw = Math.round(@PID_DEFAULT[14] * ((@ResponseSliderValue - 1) / 3 + 1))
    # master slider part
    # these are not calculated anywhere other than master slider multiplier therefore set at default before every calculation
    PIDs[0][1] = @PID_DEFAULT[1]
    PIDs[1][1] = @PID_DEFAULT[6]
    PIDs[2][1] = @PID_DEFAULT[11]
    # yaw d, dmin
    PIDs[2][2] = @PID_DEFAULT[12]
    ADVANCED_TUNING.dMinYaw = @PID_DEFAULT[13]
    #master slider multiplication, max value 200 for main PID values
    i = 0
    while i < 3
        j = 0
        while j < 3
            PIDs[j][i] = Math.min(Math.round(PIDs[j][i] * @MasterSliderValue), MAX_PID_GAIN)
            j++
        i++
    ADVANCED_TUNING.feedforwardRoll = Math.min(Math.round(ADVANCED_TUNING.feedforwardRoll * @MasterSliderValue), MAX_FF_GAIN)
    ADVANCED_TUNING.feedforwardPitch = Math.min(Math.round(ADVANCED_TUNING.feedforwardPitch * @MasterSliderValue), MAX_FF_GAIN)
    ADVANCED_TUNING.feedforwardYaw = Math.min(Math.round(ADVANCED_TUNING.feedforwardYaw * @MasterSliderValue), MAX_FF_GAIN)
    if @dMinFeatureEnabled
        ADVANCED_TUNING.dMinRoll = Math.min(Math.round(ADVANCED_TUNING.dMinRoll * @MasterSliderValue), MAX_DMIN_GAIN)
        ADVANCED_TUNING.dMinPitch = Math.min(Math.round(ADVANCED_TUNING.dMinPitch * @MasterSliderValue), MAX_DMIN_GAIN)
        ADVANCED_TUNING.dMinYaw = Math.min(Math.round(ADVANCED_TUNING.dMinYaw * @MasterSliderValue), MAX_DMIN_GAIN)
    $('output[name="tuningMasterSlider-number"]').val @MasterSliderValue
    $('output[name="tuningPDRatioSlider-number"]').val @PDRatioSliderValue
    $('output[name="tuningPDGainSlider-number"]').val @PDGainSliderValue
    $('output[name="tuningResponseSlider-number"]').val @ResponseSliderValue
    # updates values in forms
    PID_names.forEach (elementPid, indexPid) ->
        searchRow = $('.pid_tuning .' + elementPid + ' input')
        searchRow.each (indexInput) ->
            if indexPid < 3 and indexInput < 3
                $(this).val PIDs[indexPid][indexInput]
            return
        return
    $('.pid_tuning input[name="dMinRoll"]').val ADVANCED_TUNING.dMinRoll
    $('.pid_tuning input[name="dMinPitch"]').val ADVANCED_TUNING.dMinPitch
    $('.pid_tuning input[name="dMinYaw"]').val ADVANCED_TUNING.dMinYaw
    $('.pid_tuning .ROLL input[name="f"]').val ADVANCED_TUNING.feedforwardRoll
    $('.pid_tuning .PITCH input[name="f"]').val ADVANCED_TUNING.feedforwardPitch
    $('.pid_tuning .YAW input[name="f"]').val ADVANCED_TUNING.feedforwardYaw
    return

TuningSliders.calculateNewGyroFilters = ->
    # calculate, set and display new values in forms based on slider position
    FILTER_CONFIG.gyro_lowpass_dyn_min_hz = Math.round(@FILTER_DEFAULT.gyro_lowpass_dyn_min_hz * @gyroFilterSliderValue)
    FILTER_CONFIG.gyro_lowpass_dyn_max_hz = Math.round(@FILTER_DEFAULT.gyro_lowpass_dyn_max_hz * @gyroFilterSliderValue)
    FILTER_CONFIG.gyro_lowpass2_hz = Math.round(@FILTER_DEFAULT.gyro_lowpass2_hz * @gyroFilterSliderValue)
    FILTER_CONFIG.gyro_lowpass_type = @FILTER_DEFAULT.gyro_lowpass_type
    FILTER_CONFIG.gyro_lowpass2_type = @FILTER_DEFAULT.gyro_lowpass2_type
    $('.pid_filter input[name="gyroLowpassDynMinFrequency"]').val FILTER_CONFIG.gyro_lowpass_dyn_min_hz
    $('.pid_filter input[name="gyroLowpassDynMaxFrequency"]').val FILTER_CONFIG.gyro_lowpass_dyn_max_hz
    $('.pid_filter input[name="gyroLowpass2Frequency"]').val FILTER_CONFIG.gyro_lowpass2_hz
    $('.pid_filter select[name="gyroLowpassDynType').val FILTER_CONFIG.gyro_lowpass_type
    $('.pid_filter select[name="gyroLowpass2Type').val FILTER_CONFIG.gyro_lowpass2_type
    $('output[name="tuningGyroFilterSlider-number"]').val @gyroFilterSliderValue
    return

TuningSliders.calculateNewDTermFilters = ->
    # calculate, set and display new values in forms based on slider position
    FILTER_CONFIG.dterm_lowpass_dyn_min_hz = Math.round(@FILTER_DEFAULT.dterm_lowpass_dyn_min_hz * @dtermFilterSliderValue)
    FILTER_CONFIG.dterm_lowpass_dyn_max_hz = Math.round(@FILTER_DEFAULT.dterm_lowpass_dyn_max_hz * @dtermFilterSliderValue)
    FILTER_CONFIG.dterm_lowpass2_hz = Math.round(@FILTER_DEFAULT.dterm_lowpass2_hz * @dtermFilterSliderValue)
    FILTER_CONFIG.dterm_lowpass_type = @FILTER_DEFAULT.dterm_lowpass_type
    FILTER_CONFIG.dterm_lowpass2_type = @FILTER_DEFAULT.dterm_lowpass2_type
    $('.pid_filter input[name="dtermLowpassDynMinFrequency"]').val FILTER_CONFIG.dterm_lowpass_dyn_min_hz
    $('.pid_filter input[name="dtermLowpassDynMaxFrequency"]').val FILTER_CONFIG.dterm_lowpass_dyn_max_hz
    $('.pid_filter input[name="dtermLowpass2Frequency"]').val FILTER_CONFIG.dterm_lowpass2_hz
    $('.pid_filter select[name="dtermLowpassDynType').val FILTER_CONFIG.dterm_lowpass_type
    $('.pid_filter select[name="dtermLowpass2Type').val FILTER_CONFIG.dterm_lowpass2_type
    $('output[name="tuningDTermFilterSlider-number"]').val @dtermFilterSliderValue
    return

