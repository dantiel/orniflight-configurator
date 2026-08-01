'use strict'
TABS.pid_tuning =
    RATE_PROFILE_MASK: 128
    showAllPids: false
    updating: true
    dirty: false
    currentProfile: null
    currentRateProfile: null
    SETPOINT_WEIGHT_RANGE_LOW: 2.55
    SETPOINT_WEIGHT_RANGE_HIGH: 20
    SETPOINT_WEIGHT_RANGE_LEGACY: 2.54
    activeSubtab: 'pid'
    analyticsChanges: {}

TABS.pid_tuning.initialize = (callback) ->
    self = this

    load_html = ->
        $('#content').load './tabs/pid_tuning.html', process_html
        return

    pid_and_rc_to_form = ->

        adjustDMin = (dElement, dMinElement) ->
            dValue = parseInt(dElement.val())
            dMinValue = parseInt(dMinElement.val())
            dMinLimit = Math.min(Math.max(dValue - 1, 0), 100)
            if dMinValue > dMinLimit
                dMinElement.val dMinLimit
            dMinElement.attr 'max', dMinLimit
            return

        # The notch cutoff must be smaller than the notch frecuency

        adjustNotchCutoff = (frequencyName, cutoffName) ->
            frecuency = parseInt($('.pid_filter input[name=\'' + frequencyName + '\']').val())
            cutoff = parseInt($('.pid_filter input[name=\'' + cutoffName + '\']').val())
            # Change the max and refresh the value if needed
            maxCutoff = if frecuency == 0 then 0 else frecuency - 1
            $('.pid_filter input[name=\'' + cutoffName + '\']').attr 'max', maxCutoff
            if cutoff >= frecuency
                $('.pid_filter input[name=\'' + cutoffName + '\']').val maxCutoff
            return

        self.setProfile()
        if semver.gte(CONFIG.apiVersion, '1.20.0')
            self.setRateProfile()
        # Fill in the data from PIDs array
        # For each pid name
        PID_names.forEach (elementPid, indexPid) ->
            # Look into the PID table to a row with the name of the pid
            searchRow = $('.pid_tuning .' + elementPid + ' input')
            # Assign each value
            searchRow.each (indexInput) ->
                if PIDs[indexPid][indexInput] != undefined
                    $(this).val PIDs[indexPid][indexInput]
                return
            return
        # Fill in data from RC_tuning object
        $('.pid_tuning input[name="rc_rate"]').val RC_tuning.RC_RATE.toFixed(2)
        $('.pid_tuning input[name="roll_pitch_rate"]').val RC_tuning.roll_pitch_rate.toFixed(2)
        $('.pid_tuning input[name="roll_rate"]').val RC_tuning.roll_rate.toFixed(2)
        $('.pid_tuning input[name="pitch_rate"]').val RC_tuning.pitch_rate.toFixed(2)
        $('.pid_tuning input[name="yaw_rate"]').val RC_tuning.yaw_rate.toFixed(2)
        $('.pid_tuning input[name="rc_expo"]').val RC_tuning.RC_EXPO.toFixed(2)
        $('.pid_tuning input[name="rc_yaw_expo"]').val RC_tuning.RC_YAW_EXPO.toFixed(2)
        $('.throttle input[name="mid"]').val RC_tuning.throttle_MID.toFixed(2)
        $('.throttle input[name="expo"]').val RC_tuning.throttle_EXPO.toFixed(2)
        $('.tpa input[name="tpa"]').val RC_tuning.dynamic_THR_PID.toFixed(2)
        $('.tpa input[name="tpa-breakpoint"]').val RC_tuning.dynamic_THR_breakpoint
        if semver.lt(CONFIG.apiVersion, '1.10.0')
            $('.pid_tuning input[name="rc_yaw_expo"]').hide()
            $('.pid_tuning input[name="rc_expo"]').attr 'rowspan', '3'
        if semver.gte(CONFIG.apiVersion, '1.16.0')
            $('input[id="vbatpidcompensation"]').prop 'checked', ADVANCED_TUNING.vbatPidCompensation != 0
        if semver.gte(CONFIG.apiVersion, '1.16.0')
            $('#pid-tuning .delta select').val ADVANCED_TUNING.deltaMethod
        if semver.gte(CONFIG.apiVersion, '1.16.0')
            $('.pid_tuning input[name="rc_rate_yaw"]').val RC_tuning.rcYawRate.toFixed(2)
            $('.pid_filter input[name="gyroLowpassFrequency"]').val FILTER_CONFIG.gyro_lowpass_hz
            $('.pid_filter input[name="dtermLowpassFrequency"]').val FILTER_CONFIG.dterm_lowpass_hz
            $('.pid_filter input[name="yawLowpassFrequency"]').val FILTER_CONFIG.yaw_lowpass_hz
        else
            $('.tab-pid_tuning .subtab-filter').hide()
            $('.tab-pid_tuning .tab_container').hide()
            $('.pid_tuning input[name="rc_rate_yaw"]').hide()
        if semver.gte(CONFIG.apiVersion, '1.20.0') or semver.gte(CONFIG.apiVersion, '1.16.0') and FEATURE_CONFIG.features.isEnabled('SUPEREXPO_RATES')
            $('#pid-tuning .rate').text i18n.getMessage('pidTuningSuperRate')
        else
            $('#pid-tuning .rate').text i18n.getMessage('pidTuningRate')
        if semver.gte(CONFIG.apiVersion, '1.20.0')
            $('.pid_filter input[name="gyroNotch1Frequency"]').val FILTER_CONFIG.gyro_notch_hz
            $('.pid_filter input[name="gyroNotch1Cutoff"]').val FILTER_CONFIG.gyro_notch_cutoff
            $('.pid_filter input[name="dTermNotchFrequency"]').val FILTER_CONFIG.dterm_notch_hz
            $('.pid_filter input[name="dTermNotchCutoff"]').val FILTER_CONFIG.dterm_notch_cutoff
            dtermSetpointTransitionNumberElement = $('input[name="dtermSetpointTransition-number"]')
            if semver.gte(CONFIG.apiVersion, '1.38.0')
                dtermSetpointTransitionNumberElement.attr 'min', 0.00
            else
                dtermSetpointTransitionNumberElement.attr 'min', 0.01
            dtermSetpointTransitionNumberElement.val ADVANCED_TUNING.dtermSetpointTransition / 100
            $('input[name="dtermSetpoint-number"]').val ADVANCED_TUNING.dtermSetpointWeight / 100
        else
            $('.pid_filter .newFilter').hide()
        if semver.gte(CONFIG.apiVersion, '1.21.0')
            $('.pid_filter input[name="gyroNotch2Frequency"]').val FILTER_CONFIG.gyro_notch2_hz
            $('.pid_filter input[name="gyroNotch2Cutoff"]').val FILTER_CONFIG.gyro_notch2_cutoff
        else
            $('.pid_filter .gyroNotch2').hide()
        if semver.gte(CONFIG.apiVersion, '1.24.0')
            $('.pid_tuning input[name="angleLimit"]').val ADVANCED_TUNING.levelAngleLimit
            $('.pid_tuning input[name="sensitivity"]').val ADVANCED_TUNING.levelSensitivity
        else
            $('.pid_sensitivity').hide()
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            $('.pid_filter select[name="dtermLowpassType"]').val FILTER_CONFIG.dterm_lowpass_type
            $('.antigravity input[name="itermThrottleThreshold"]').val ADVANCED_TUNING.itermThrottleThreshold
            $('.antigravity input[name="itermAcceleratorGain"]').val ADVANCED_TUNING.itermAcceleratorGain / 1000
            if FEATURE_CONFIG.features.isEnabled('ANTI_GRAVITY')
                $('.antigravity').show()
            else
                $('.antigravity').hide()
            antiGravitySwitch = $('#antiGravitySwitch')
            antiGravitySwitch.prop 'checked', ADVANCED_TUNING.itermAcceleratorGain != 1000
            antiGravitySwitch.change ->
                checked = $(this).is(':checked')
                if checked
                    $('.antigravity input[name="itermAcceleratorGain"]').val Math.max(ADVANCED_TUNING.itermAcceleratorGain / 1000, 1.1)
                    $('.antigravity .suboption').show()
                    if ADVANCED_TUNING.antiGravityMode == 0
                        $('.antigravity .antiGravityThres').hide()
                    if semver.gte(CONFIG.apiVersion, '1.40.0')
                        $('.antigravity .antiGravityMode').show()
                    else
                        $('.antigravity .antiGravityMode').hide()
                else
                    $('.antigravity select[id="antiGravityMode"]').val 0
                    $('.antigravity input[name="itermAcceleratorGain"]').val 1
                    $('.antigravity .suboption').hide()
                return
            antiGravitySwitch.change()
        else
            $('.dtermLowpassType').hide()
            $('.antigravity').hide()
        if semver.gte(CONFIG.apiVersion, '1.37.0')
            $('.pid_tuning input[name="rc_rate_pitch"]').val RC_tuning.rcPitchRate.toFixed(2)
            $('.pid_tuning input[name="rc_pitch_expo"]').val RC_tuning.RC_PITCH_EXPO.toFixed(2)
        if semver.gte(CONFIG.apiVersion, '1.39.0')
            $('.pid_filter input[name="gyroLowpass2Frequency"]').val FILTER_CONFIG.gyro_lowpass2_hz
            $('.pid_filter select[name="gyroLowpassType"]').val FILTER_CONFIG.gyro_lowpass_type
            $('.pid_filter select[name="gyroLowpass2Type"]').val FILTER_CONFIG.gyro_lowpass2_type
            $('.pid_filter input[name="dtermLowpass2Frequency"]').val FILTER_CONFIG.dterm_lowpass2_hz
            # We load it again because the limits are now bigger than in 1.16.0
            $('.pid_filter input[name="gyroLowpassFrequency"]').attr 'max', '16000'
            $('.pid_filter input[name="gyroLowpassFrequency"]').val FILTER_CONFIG.gyro_lowpass_hz
            #removes 5th column which is Feedforward
            $('#pid_main .pid_titlebar2 th').attr 'colspan', 4
        else
            $('.gyroLowpass2').hide()
            $('.gyroLowpass2Type').hide()
            $('.dtermLowpass2').hide()
            $('#pid_main .pid_titlebar2 th').attr 'colspan', 4
        if semver.gte(CONFIG.apiVersion, '1.40.0')
            # I Term Rotation
            $('input[id="itermrotation"]').prop 'checked', ADVANCED_TUNING.itermRotation != 0
            # Smart Feed Forward
            $('input[id="smartfeedforward"]').prop 'checked', ADVANCED_TUNING.smartFeedforward != 0
            # I Term Relax
            itermRelaxCheck = $('input[id="itermrelax"]')
            itermRelaxCheck.prop 'checked', ADVANCED_TUNING.itermRelax != 0
            $('select[id="itermrelaxAxes"]').val if ADVANCED_TUNING.itermRelax > 0 then ADVANCED_TUNING.itermRelax else 1
            $('select[id="itermrelaxType"]').val ADVANCED_TUNING.itermRelaxType
            $('input[name="itermRelaxCutoff"]').val ADVANCED_TUNING.itermRelaxCutoff
            itermRelaxCheck.change ->
                checked = $(this).is(':checked')
                if checked
                    $('.itermrelax .suboption').show()
                    if semver.gte(CONFIG.apiVersion, '1.42.0')
                        $('.itermRelaxCutoff').show()
                    else
                        $('.itermRelaxCutoff').hide()
                else
                    $('.itermrelax .suboption').hide()
                return
            itermRelaxCheck.change()
            # Absolute Control
            absoluteControlGainNumberElement = $('input[name="absoluteControlGain-number"]')
            absoluteControlGainNumberElement.val(ADVANCED_TUNING.absoluteControlGain).trigger 'input'
            # Throttle Boost
            throttleBoostNumberElement = $('input[name="throttleBoost-number"]')
            throttleBoostNumberElement.val(ADVANCED_TUNING.throttleBoost).trigger 'input'
            # Acro Trainer
            acroTrainerAngleLimitNumberElement = $('input[name="acroTrainerAngleLimit-number"]')
            acroTrainerAngleLimitNumberElement.val(ADVANCED_TUNING.acroTrainerAngleLimit).trigger 'input'
            # Yaw D
            $('.pid_tuning .YAW input[name="d"]').val PIDs[2][2]
            # PID Yaw D
            # Feedforward
            $('.pid_tuning .ROLL input[name="f"]').val ADVANCED_TUNING.feedforwardRoll
            $('.pid_tuning .PITCH input[name="f"]').val ADVANCED_TUNING.feedforwardPitch
            $('.pid_tuning .YAW input[name="f"]').val ADVANCED_TUNING.feedforwardYaw
            $('#pid_main .pid_titlebar2 th').attr 'colspan', 5
            feedforwardTransitionNumberElement = $('input[name="feedforwardTransition-number"]')
            feedforwardTransitionNumberElement.val ADVANCED_TUNING.feedforwardTransition / 100
            freqChannelNumberElement = $('input[name="freqChannel-number"]')
            freqChannelNumberElement.val ADVANCED_TUNING.ornithopter_freq_channel / 1
            freqMinNumberElement = $('input[name="freqMin-number"]')
            freqMinNumberElement.val ADVANCED_TUNING.ornithopter_freq_min / 1
            freqMaxNumberElement = $('input[name="freqMax-number"]')
            freqMaxNumberElement.val ADVANCED_TUNING.ornithopter_freq_max / 1
            servoSpeedDegSNumberElement = $('input[name="servoSpeedDegS-number"]')
            servoSpeedDegSNumberElement.val ADVANCED_TUNING.servo_speed_deg_s / 1
            servoMaxAmplitudeNumberElement = $('input[name="servoMaxAmplitude-number"]')
            servoMaxAmplitudeNumberElement.val ADVANCED_TUNING.servo_max_amplitude / 1
            flapMagnitudeNumberElement = $('input[name="flapMagnitude-number"]')
            flapMagnitudeNumberElement.val ADVANCED_TUNING.flap_magnitude / 1
            # AntiGravity Mode
            antiGravityModeSelect = $('.antigravity select[id="antiGravityMode"]')
            antiGravityModeSelect.change ->
                antiGravityModeValue = $('.antigravity select[id="antiGravityMode"]').val()
                # Smooth removes threshold
                if antiGravityModeValue == 0
                    $('.antiGravityThres').hide()
                else
                    $('.antiGravityThres').show()
                return
            antiGravityModeSelect.val(ADVANCED_TUNING.antiGravityMode).change()
        else
            $('.itermrotation').hide()
            $('.smartfeedforward').hide()
            $('.itermrelax').hide()
            $('.absoluteControlGain').hide()
            $('.throttleBoost').hide()
            $('.acroTrainerAngleLimit').hide()
            $('.pid_tuning .YAW input[name="d"]').hide()
            # Feedforward column
            $('#pid_main tr :nth-child(6)').hide()
            $('#pid-tuning .feedforwardTransition').hide()
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            $('select[id="throttleLimitType"]').val RC_tuning.throttleLimitType
            $('.throttle_limit input[name="throttleLimitPercent"]').val RC_tuning.throttleLimitPercent
            $('.pid_filter select[name="dtermLowpass2Type"]').val FILTER_CONFIG.dterm_lowpass2_type
            $('.pid_filter input[name="gyroLowpassDynMinFrequency"]').val FILTER_CONFIG.gyro_lowpass_dyn_min_hz
            $('.pid_filter input[name="gyroLowpassDynMaxFrequency"]').val FILTER_CONFIG.gyro_lowpass_dyn_max_hz
            $('.pid_filter select[name="gyroLowpassDynType"]').val FILTER_CONFIG.gyro_lowpass_type
            $('.pid_filter input[name="dtermLowpassDynMinFrequency"]').val FILTER_CONFIG.dterm_lowpass_dyn_min_hz
            $('.pid_filter input[name="dtermLowpassDynMaxFrequency"]').val FILTER_CONFIG.dterm_lowpass_dyn_max_hz
            $('.pid_filter select[name="dtermLowpassDynType"]').val FILTER_CONFIG.dterm_lowpass_type
            $('.pid_tuning input[name="dMinRoll"]').val ADVANCED_TUNING.dMinRoll
            $('.pid_tuning input[name="dMinPitch"]').val ADVANCED_TUNING.dMinPitch
            $('.pid_tuning input[name="dMinYaw"]').val ADVANCED_TUNING.dMinYaw
            $('.dminGroup input[name="dMinGain"]').val ADVANCED_TUNING.dMinGain
            $('.dminGroup input[name="dMinAdvance"]').val ADVANCED_TUNING.dMinAdvance
            $('input[id="useIntegratedYaw"]').prop 'checked', ADVANCED_TUNING.useIntegratedYaw != 0
            #dmin column
            $('#pid_main .pid_titlebar2 th').attr 'colspan', 6
        else
            $('.throttle_limit').hide()
            $('.gyroLowpassDyn').hide()
            $('.dtermLowpassDyn').hide()
            $('.dtermLowpass2TypeGroup').hide()
            $('.dminGroup').hide()
            $('.dMinDisabledNote').hide()
            #dmin column
            $('#pid_main tr :nth-child(5)').hide()
            $('.integratedYaw').hide()
        if semver.gte(CONFIG.apiVersion, '1.42.0')
            $('.tab-pid_tuning .subtab-ondas').show()
        else
            $('.tab-pid_tuning .subtab-ondas').hide()
        $('.subtab-ondas input[name="cadenceGain"]').val ADVANCED_TUNING.cadence_gain
        $('.subtab-ondas input[name="ferocityDGain"]').val ADVANCED_TUNING.ferocity_d_gain
        $('.subtab-ondas input[name="balanceGain"]').val ADVANCED_TUNING.balance_gain
        $('.subtab-ondas input[name="ferocityPGain"]').val ADVANCED_TUNING.ferocity_p_gain
        $('.subtab-ondas input[name="ferocityRollGain"]').val ADVANCED_TUNING.ferocity_roll_gain
        $('.subtab-ondas input[name="ferocityYawGain"]').val ADVANCED_TUNING.ferocity_yaw_gain
        $('.subtab-ondas input[name="warpGain"]').val ADVANCED_TUNING.warp_gain
        $('.subtab-ondas input[name="warpYawGain"]').val ADVANCED_TUNING.warp_yaw_gain
        $('.subtab-ondas input[name="anchorGain"]').val ADVANCED_TUNING.anchor_gain
        $('.subtab-ondas input[name="resonanceGain"]').val ADVANCED_TUNING.resonance_gain
        if semver.gte(CONFIG.apiVersion, '1.43.0')
            $('.subtab-ondas .wingGeometry').show()
            $('.subtab-ondas input[name="servoMountAngle0"]').val ADVANCED_TUNING.servo_mount_angle_0 or 0
            $('.subtab-ondas input[name="servoMountAngle1"]').val ADVANCED_TUNING.servo_mount_angle_1 or 0
            $('.subtab-ondas input[name="servoMountAngle2"]').val ADVANCED_TUNING.servo_mount_angle_2 or 0
            $('.subtab-ondas input[name="servoMountAngle3"]').val ADVANCED_TUNING.servo_mount_angle_3 or 0
            $('.subtab-ondas input[name="flappingPhaseShift0"]').val ADVANCED_TUNING.flapping_phase_shift_0 or 0
            $('.subtab-ondas input[name="flappingPhaseShift1"]').val ADVANCED_TUNING.flapping_phase_shift_1 or 0
            $('.subtab-ondas input[name="flappingPhaseShift2"]').val ADVANCED_TUNING.flapping_phase_shift_2 or 0
            $('.subtab-ondas input[name="flappingPhaseShift3"]').val ADVANCED_TUNING.flapping_phase_shift_3 or 0
            $('.subtab-ondas input[name="wingOriginOffset0"]').val ADVANCED_TUNING.wing_origin_offset_0 or 0
            $('.subtab-ondas input[name="wingOriginOffset1"]').val ADVANCED_TUNING.wing_origin_offset_1 or 0
            $('.subtab-ondas input[name="wingOriginOffset2"]').val ADVANCED_TUNING.wing_origin_offset_2 or 0
            $('.subtab-ondas input[name="wingOriginOffset3"]').val ADVANCED_TUNING.wing_origin_offset_3 or 0
            $('.subtab-ondas .advancedOndas').show()
            $('.subtab-ondas input[name="prescienceGain"]').val ADVANCED_TUNING.prescience_gain or 0
            $('.subtab-ondas input[name="espelhoGain"]').val ADVANCED_TUNING.espelho_gain or 0
            $('.subtab-ondas input[name="saudadeGain"]').val ADVANCED_TUNING.saudade_gain or 0
            $('.subtab-ondas input[name="ssffGain"]').val ADVANCED_TUNING.ssff_gain or 0
            if semver.gte(CONFIG.apiVersion, '1.46.0')
                $('.subtab-ondas .ornithopterProfile').show()
                $('.subtab-ondas .aeroelasticOndas').show()
                $('.subtab-ondas select[name="ornithopterProfile"]').val ADVANCED_TUNING.ornithopter_profile_index or 0
                $('.subtab-ondas input[name="ferocityDownstroke"]').val ADVANCED_TUNING.ferocity_downstroke or 0
                $('.subtab-ondas input[name="ferocityUpstroke"]').val ADVANCED_TUNING.ferocity_upstroke or 0
                $('.subtab-ondas input[name="aeroelasticGlideCoefficient"]').val ADVANCED_TUNING.aeroelastic_glide_coefficient or 0
                $('.subtab-ondas input[name="aeroelasticFlapCoefficient"]').val ADVANCED_TUNING.aeroelastic_flap_coefficient or 0
            else
                $('.subtab-ondas .ornithopterProfile').hide()
                $('.subtab-ondas .aeroelasticOndas').hide()
        else
            $('.subtab-ondas .wingGeometry').hide()
            $('.subtab-ondas .advancedOndas').hide()
            $('.subtab-ondas .ornithopterProfile').hide()
            $('.subtab-ondas .aeroelasticOndas').hide()
        if semver.gte(CONFIG.apiVersion, '1.42.0')
            $('.smartfeedforward').hide()
            if FEATURE_CONFIG.features.isEnabled('DYNAMIC_FILTER')
                $('.dynamicNotch').show()
            else
                $('.dynamicNotch').hide()
            $('.pid_filter select[name="dynamicNotchRange"]').val FILTER_CONFIG.dyn_notch_range
            $('.pid_filter input[name="dynamicNotchWidthPercent"]').val FILTER_CONFIG.dyn_notch_width_percent
            $('.pid_filter input[name="dynamicNotchQ"]').val FILTER_CONFIG.dyn_notch_q
            $('.pid_filter input[name="dynamicNotchMinHz"]').val FILTER_CONFIG.dyn_notch_min_hz
            $('.rpmFilter').toggle MOTOR_CONFIG.use_dshot_telemetry
            $('.pid_filter input[name="rpmFilterHarmonics"]').val FILTER_CONFIG.gyro_rpm_notch_harmonics
            $('.pid_filter input[name="rpmFilterMinHz"]').val FILTER_CONFIG.gyro_rpm_notch_min_hz
            $('.pid_filter #rpmFilterEnabled').change(->
                harmonics = $('.pid_filter input[name="rpmFilterHarmonics"]').val()
                checked = $(this).is(':checked') and harmonics != 0
                $('.pid_filter input[name="rpmFilterHarmonics"]').attr 'disabled', !checked
                $('.pid_filter input[name="rpmFilterMinHz"]').attr 'disabled', !checked
                if harmonics == 0
                    $('.pid_filter input[name="rpmFilterHarmonics"]').val FILTER_DEFAULT.gyro_rpm_notch_harmonics
                return
            ).prop('checked', FILTER_CONFIG.gyro_rpm_notch_harmonics != 0).change()
        else
            $('.itermRelaxCutoff').hide()
            $('.dynamicNotch').hide()
            $('.rpmFilter').hide()
        $('input[id="useIntegratedYaw"]').change(->
            checked = $(this).is(':checked')
            $('#pidTuningIntegratedYawCaution').toggle checked
            return
        ).change()
        $('.pid_tuning .ROLL input[name="d"]').change(->
            dMinElement = $('.pid_tuning input[name="dMinRoll"]')
            adjustDMin $(this), dMinElement
            return
        ).change()
        $('.pid_tuning .PITCH input[name="d"]').change(->
            dMinElement = $('.pid_tuning input[name="dMinPitch"]')
            adjustDMin $(this), dMinElement
            return
        ).change()
        $('.pid_tuning .YAW input[name="d"]').change(->
            dMinElement = $('.pid_tuning input[name="dMinYaw"]')
            adjustDMin $(this), dMinElement
            return
        ).change()
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            dMinSwitch = $('#dMinSwitch')
            dMinSwitch.prop 'checked', ADVANCED_TUNING.dMinRoll > 0 or ADVANCED_TUNING.dMinPitch > 0 or ADVANCED_TUNING.dMinYaw > 0
            dMinSwitch.change ->
                checked = $(this).is(':checked')
                if checked
                    if $('.pid_tuning input[name="dMinRoll"]').val() == 0 and $('.pid_tuning input[name="dMinPitch"]').val() == 0 and $('.pid_tuning input[name="dMinYaw"]').val() == 0
                        # when enabling dmin set its value based on 0.57x of actual dmax, dmin is limited to 100
                        $('.pid_tuning input[name="dMinRoll"]').val Math.min(Math.round($('.pid_tuning .ROLL input[name="d"]').val() * 0.57), 100)
                        $('.pid_tuning input[name="dMinPitch"]').val Math.min(Math.round($('.pid_tuning .PITCH input[name="d"]').val() * 0.57), 100)
                        $('.pid_tuning input[name="dMinYaw"]').val Math.min(Math.round($('.pid_tuning .YAW input[name="d"]').val() * 0.57), 100)
                    else
                        $('.pid_tuning input[name="dMinRoll"]').val ADVANCED_TUNING.dMinRoll
                        $('.pid_tuning input[name="dMinPitch"]').val ADVANCED_TUNING.dMinPitch
                        $('.pid_tuning input[name="dMinYaw"]').val ADVANCED_TUNING.dMinYaw
                    $('.dMinDisabledNote').hide()
                    $('.dminGroup .suboption').show()
                    $('#pid_main tr :nth-child(5)').show()
                    $('#pid_main .pid_titlebar2 th').attr 'colspan', 6
                else
                    $('.pid_tuning input[name="dMinRoll"]').val 0
                    $('.pid_tuning input[name="dMinPitch"]').val 0
                    $('.pid_tuning input[name="dMinYaw"]').val 0
                    $('.dMinDisabledNote').show()
                    $('.dminGroup .suboption').hide()
                    $('#pid_main tr :nth-child(5)').hide()
                    $('#pid_main .pid_titlebar2 th').attr 'colspan', 5
                return
            dMinSwitch.change()
        $('input[id="gyroNotch1Enabled"]').change ->
            checked = $(this).is(':checked')
            hz = if FILTER_CONFIG.gyro_notch_hz > 0 then FILTER_CONFIG.gyro_notch_hz else FILTER_DEFAULT.gyro_notch_hz
            $('.pid_filter input[name="gyroNotch1Frequency"]').val(if checked then hz else 0).attr('disabled', !checked).attr('min', if checked then 1 else 0).change()
            $('.pid_filter input[name="gyroNotch1Cutoff"]').attr('disabled', !checked).change()
            return
        $('input[id="gyroNotch2Enabled"]').change ->
            checked = $(this).is(':checked')
            hz = if FILTER_CONFIG.gyro_notch2_hz > 0 then FILTER_CONFIG.gyro_notch2_hz else FILTER_DEFAULT.gyro_notch2_hz
            $('.pid_filter input[name="gyroNotch2Frequency"]').val(if checked then hz else 0).attr('disabled', !checked).attr('min', if checked then 1 else 0).change()
            $('.pid_filter input[name="gyroNotch2Cutoff"]').attr('disabled', !checked).change()
            return
        $('input[id="dtermNotchEnabled"]').change ->
            checked = $(this).is(':checked')
            hz = if FILTER_CONFIG.dterm_notch_hz > 0 then FILTER_CONFIG.dterm_notch_hz else FILTER_DEFAULT.dterm_notch_hz
            $('.pid_filter input[name="dTermNotchFrequency"]').val(if checked then hz else 0).attr('disabled', !checked).attr('min', if checked then 1 else 0).change()
            $('.pid_filter input[name="dTermNotchCutoff"]').attr('disabled', !checked).change()
            return
        $('input[id="gyroLowpassEnabled"]').change ->
            checked = $(this).is(':checked')
            disabledByDynamicLowpass = $('input[id="gyroLowpassDynEnabled"]').is(':checked')
            cutoff = if FILTER_CONFIG.gyro_lowpass_hz > 0 then FILTER_CONFIG.gyro_lowpass_hz else FILTER_DEFAULT.gyro_lowpass_hz
            type = if FILTER_CONFIG.gyro_lowpass_hz > 0 then FILTER_CONFIG.gyro_lowpass_type else FILTER_DEFAULT.gyro_lowpass_type
            $('.pid_filter input[name="gyroLowpassFrequency"]').val(if checked or disabledByDynamicLowpass then cutoff else 0).attr 'disabled', !checked
            $('.pid_filter select[name="gyroLowpassType"]').val(type).attr 'disabled', !checked
            if checked
                $('input[id="gyroLowpassDynEnabled"]').prop('checked', false).change()
            self.updateFilterWarning()
            return
        $('input[id="gyroLowpassDynEnabled"]').change ->
            checked = $(this).is(':checked')
            cutoff_min = FILTER_DEFAULT.gyro_lowpass_dyn_min_hz
            type = FILTER_DEFAULT.gyro_lowpass_type
            if FILTER_CONFIG.gyro_lowpass_dyn_min_hz > 0 and FILTER_CONFIG.gyro_lowpass_dyn_min_hz < FILTER_CONFIG.gyro_lowpass_dyn_max_hz
                cutoff_min = FILTER_CONFIG.gyro_lowpass_dyn_min_hz
                type = FILTER_CONFIG.gyro_lowpass_type
            $('.pid_filter input[name="gyroLowpassDynMinFrequency"]').val(if checked then cutoff_min else 0).attr 'disabled', !checked
            $('.pid_filter input[name="gyroLowpassDynMaxFrequency"]').attr 'disabled', !checked
            $('.pid_filter select[name="gyroLowpassDynType"]').val(type).attr 'disabled', !checked
            if checked
                $('input[id="gyroLowpassEnabled"]').prop('checked', false).change()
            else if FILTER_CONFIG.gyro_lowpass_hz > 0 and !$('input[id="gyroLowpassEnabled"]').is(':checked')
                $('input[id="gyroLowpassEnabled"]').prop('checked', true).change()
            self.updateFilterWarning()
            return
        $('input[id="gyroLowpass2Enabled"]').change ->
            checked = $(this).is(':checked')
            cutoff = if FILTER_CONFIG.gyro_lowpass2_hz > 0 then FILTER_CONFIG.gyro_lowpass2_hz else FILTER_DEFAULT.gyro_lowpass2_hz
            type = if FILTER_CONFIG.gyro_lowpass2_hz > 0 then FILTER_CONFIG.gyro_lowpass2_type else FILTER_DEFAULT.gyro_lowpass2_type
            $('.pid_filter input[name="gyroLowpass2Frequency"]').val(if checked then cutoff else 0).attr 'disabled', !checked
            $('.pid_filter select[name="gyroLowpass2Type"]').val(type).attr 'disabled', !checked
            return
        $('input[id="dtermLowpassEnabled"]').change ->
            checked = $(this).is(':checked')
            disabledByDynamicLowpass = $('input[id="dtermLowpassDynEnabled"]').is(':checked')
            cutoff = if FILTER_CONFIG.dterm_lowpass_hz > 0 then FILTER_CONFIG.dterm_lowpass_hz else FILTER_DEFAULT.dterm_lowpass_hz
            type = if FILTER_CONFIG.dterm_lowpass_hz > 0 then FILTER_CONFIG.dterm_lowpass_type else FILTER_DEFAULT.dterm_lowpass_type
            $('.pid_filter input[name="dtermLowpassFrequency"]').val(if checked or disabledByDynamicLowpass then cutoff else 0).attr 'disabled', !checked
            $('.pid_filter select[name="dtermLowpassType"]').val(type).attr 'disabled', !checked
            if checked
                $('input[id="dtermLowpassDynEnabled"]').prop('checked', false).change()
            self.updateFilterWarning()
            return
        $('input[id="dtermLowpassDynEnabled"]').change ->
            checked = $(this).is(':checked')
            cutoff_min = FILTER_DEFAULT.dterm_lowpass_dyn_min_hz
            type = FILTER_DEFAULT.dterm_lowpass_type
            if FILTER_CONFIG.dterm_lowpass_dyn_min_hz > 0 and FILTER_CONFIG.dterm_lowpass_dyn_min_hz < FILTER_CONFIG.dterm_lowpass_dyn_max_hz
                cutoff_min = FILTER_CONFIG.dterm_lowpass_dyn_min_hz
                type = FILTER_CONFIG.dterm_lowpass_type
            $('.pid_filter input[name="dtermLowpassDynMinFrequency"]').val(if checked then cutoff_min else 0).attr 'disabled', !checked
            $('.pid_filter input[name="dtermLowpassDynMaxFrequency"]').attr 'disabled', !checked
            $('.pid_filter select[name="dtermLowpassDynType"]').val(type).attr 'disabled', !checked
            if checked
                $('input[id="dtermLowpassEnabled"]').prop('checked', false).change()
            else if FILTER_CONFIG.dterm_lowpass_hz > 0 and !$('input[id="dtermLowpassEnabled"]').is(':checked')
                $('input[id="dtermLowpassEnabled"]').prop('checked', true).change()
            self.updateFilterWarning()
            return
        $('input[id="dtermLowpass2Enabled"]').change ->
            checked = $(this).is(':checked')
            cutoff = if FILTER_CONFIG.dterm_lowpass2_hz > 0 then FILTER_CONFIG.dterm_lowpass2_hz else FILTER_DEFAULT.dterm_lowpass2_hz
            type = if FILTER_CONFIG.dterm_lowpass2_hz > 0 then FILTER_CONFIG.dterm_lowpass2_type else FILTER_DEFAULT.dterm_lowpass2_type
            $('.pid_filter input[name="dtermLowpass2Frequency"]').val(if checked then cutoff else 0).attr 'disabled', !checked
            $('.pid_filter select[name="dtermLowpass2Type"]').val(type).attr 'disabled', !checked
            return
        $('input[id="yawLowpassEnabled"]').change ->
            checked = $(this).is(':checked')
            cutoff = if FILTER_CONFIG.yaw_lowpass_hz > 0 then FILTER_CONFIG.yaw_lowpass_hz else FILTER_DEFAULT.yaw_lowpass_hz
            $('.pid_filter input[name="yawLowpassFrequency"]').val(if checked then cutoff else 0).attr 'disabled', !checked
            return
        $('input[name="gyroNotch1Frequency"]').change(->
            adjustNotchCutoff 'gyroNotch1Frequency', 'gyroNotch1Cutoff'
            return
        ).change()
        $('input[name="gyroNotch2Frequency"]').change(->
            adjustNotchCutoff 'gyroNotch2Frequency', 'gyroNotch2Cutoff'
            return
        ).change()
        $('input[name="dTermNotchFrequency"]').change(->
            adjustNotchCutoff 'dTermNotchFrequency', 'dTermNotchCutoff'
            return
        ).change()
        # Initial state of the filters: enabled or disabled
        $('input[id="gyroNotch1Enabled"]').prop('checked', FILTER_CONFIG.gyro_notch_hz != 0).change()
        $('input[id="gyroNotch2Enabled"]').prop('checked', FILTER_CONFIG.gyro_notch2_hz != 0).change()
        $('input[id="dtermNotchEnabled"]').prop('checked', FILTER_CONFIG.dterm_notch_hz != 0).change()
        $('input[id="gyroLowpassEnabled"]').prop('checked', FILTER_CONFIG.gyro_lowpass_hz != 0).change()
        $('input[id="gyroLowpassDynEnabled"]').prop('checked', FILTER_CONFIG.gyro_lowpass_dyn_min_hz != 0 and FILTER_CONFIG.gyro_lowpass_dyn_min_hz < FILTER_CONFIG.gyro_lowpass_dyn_max_hz).change()
        $('input[id="gyroLowpass2Enabled"]').prop('checked', FILTER_CONFIG.gyro_lowpass2_hz != 0).change()
        $('input[id="dtermLowpassEnabled"]').prop('checked', FILTER_CONFIG.dterm_lowpass_hz != 0).change()
        $('input[id="dtermLowpassDynEnabled"]').prop('checked', FILTER_CONFIG.dterm_lowpass_dyn_min_hz != 0 and FILTER_CONFIG.dterm_lowpass_dyn_min_hz < FILTER_CONFIG.dterm_lowpass_dyn_max_hz).change()
        $('input[id="dtermLowpass2Enabled"]').prop('checked', FILTER_CONFIG.dterm_lowpass2_hz != 0).change()
        $('input[id="yawLowpassEnabled"]').prop('checked', FILTER_CONFIG.yaw_lowpass_hz != 0).change()
        return

    form_to_pid_and_rc = ->
        # Fill in the data from PIDs array
        # Catch all the changes and stuff the inside PIDs array
        # For each pid name
        PID_names.forEach (elementPid, indexPid) ->
            # Look into the PID table to a row with the name of the pid
            searchRow = $('.pid_tuning .' + elementPid + ' input')
            # Assign each value
            searchRow.each (indexInput) ->
                if $(this).val()
                    PIDs[indexPid][indexInput] = parseFloat($(this).val())
                return
            return
        # catch RC_tuning changes
        RC_tuning.RC_RATE = parseFloat($('.pid_tuning input[name="rc_rate"]').val())
        RC_tuning.roll_pitch_rate = parseFloat($('.pid_tuning input[name="roll_pitch_rate"]').val())
        RC_tuning.roll_rate = parseFloat($('.pid_tuning input[name="roll_rate"]').val())
        RC_tuning.pitch_rate = parseFloat($('.pid_tuning input[name="pitch_rate"]').val())
        RC_tuning.yaw_rate = parseFloat($('.pid_tuning input[name="yaw_rate"]').val())
        RC_tuning.RC_EXPO = parseFloat($('.pid_tuning input[name="rc_expo"]').val())
        RC_tuning.RC_YAW_EXPO = parseFloat($('.pid_tuning input[name="rc_yaw_expo"]').val())
        RC_tuning.rcYawRate = parseFloat($('.pid_tuning input[name="rc_rate_yaw"]').val())
        RC_tuning.rcPitchRate = parseFloat($('.pid_tuning input[name="rc_rate_pitch"]').val())
        RC_tuning.RC_PITCH_EXPO = parseFloat($('.pid_tuning input[name="rc_pitch_expo"]').val())
        RC_tuning.throttle_MID = parseFloat($('.throttle input[name="mid"]').val())
        RC_tuning.throttle_EXPO = parseFloat($('.throttle input[name="expo"]').val())
        RC_tuning.dynamic_THR_PID = parseFloat($('.tpa input[name="tpa"]').val())
        RC_tuning.dynamic_THR_breakpoint = parseInt($('.tpa input[name="tpa-breakpoint"]').val())
        FILTER_CONFIG.gyro_lowpass_hz = parseInt($('.pid_filter input[name="gyroLowpassFrequency"]').val())
        FILTER_CONFIG.dterm_lowpass_hz = parseInt($('.pid_filter input[name="dtermLowpassFrequency"]').val())
        FILTER_CONFIG.yaw_lowpass_hz = parseInt($('.pid_filter input[name="yawLowpassFrequency"]').val())
        if semver.gte(CONFIG.apiVersion, '1.16.0') and !semver.gte(CONFIG.apiVersion, '1.20.0')
            FEATURE_CONFIG.features.updateData $('input[name="SUPEREXPO_RATES"]')
        if semver.gte(CONFIG.apiVersion, '1.16.0')
            ADVANCED_TUNING.vbatPidCompensation = if $('input[id="vbatpidcompensation"]').is(':checked') then 1 else 0
        if semver.gte(CONFIG.apiVersion, '1.16.0')
            ADVANCED_TUNING.deltaMethod = $('#pid-tuning .delta select').val()
        if semver.gte(CONFIG.apiVersion, '1.20.0')
            ADVANCED_TUNING.dtermSetpointTransition = parseInt($('input[name="dtermSetpointTransition-number"]').val() * 100)
            ADVANCED_TUNING.dtermSetpointWeight = parseInt($('input[name="dtermSetpoint-number"]').val() * 100)
            FILTER_CONFIG.gyro_notch_hz = parseInt($('.pid_filter input[name="gyroNotch1Frequency"]').val())
            FILTER_CONFIG.gyro_notch_cutoff = parseInt($('.pid_filter input[name="gyroNotch1Cutoff"]').val())
            FILTER_CONFIG.dterm_notch_hz = parseInt($('.pid_filter input[name="dTermNotchFrequency"]').val())
            FILTER_CONFIG.dterm_notch_cutoff = parseInt($('.pid_filter input[name="dTermNotchCutoff"]').val())
            if semver.gte(CONFIG.apiVersion, '1.21.0')
                FILTER_CONFIG.gyro_notch2_hz = parseInt($('.pid_filter input[name="gyroNotch2Frequency"]').val())
                FILTER_CONFIG.gyro_notch2_cutoff = parseInt($('.pid_filter input[name="gyroNotch2Cutoff"]').val())
        if semver.gte(CONFIG.apiVersion, '1.24.0')
            ADVANCED_TUNING.levelAngleLimit = parseInt($('.pid_tuning input[name="angleLimit"]').val())
            ADVANCED_TUNING.levelSensitivity = parseInt($('.pid_tuning input[name="sensitivity"]').val())
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            FILTER_CONFIG.dterm_lowpass_type = $('.pid_filter select[name="dtermLowpassType"]').val()
            ADVANCED_TUNING.itermThrottleThreshold = parseInt($('.antigravity input[name="itermThrottleThreshold"]').val())
            ADVANCED_TUNING.itermAcceleratorGain = parseInt($('.antigravity input[name="itermAcceleratorGain"]').val() * 1000)
        if semver.gte(CONFIG.apiVersion, '1.39.0')
            FILTER_CONFIG.gyro_lowpass2_hz = parseInt($('.pid_filter input[name="gyroLowpass2Frequency"]').val())
            FILTER_CONFIG.gyro_lowpass_type = parseInt($('.pid_filter select[name="gyroLowpassType"]').val())
            FILTER_CONFIG.gyro_lowpass2_type = parseInt($('.pid_filter select[name="gyroLowpass2Type"]').val())
            FILTER_CONFIG.dterm_lowpass2_hz = parseInt($('.pid_filter input[name="dtermLowpass2Frequency"]').val())
        if semver.gte(CONFIG.apiVersion, '1.40.0')
            ADVANCED_TUNING.itermRotation = if $('input[id="itermrotation"]').is(':checked') then 1 else 0
            ADVANCED_TUNING.smartFeedforward = if $('input[id="smartfeedforward"]').is(':checked') then 1 else 0
            ADVANCED_TUNING.itermRelax = if $('input[id="itermrelax"]').is(':checked') then $('select[id="itermrelaxAxes"]').val() else 0
            ADVANCED_TUNING.itermRelaxType = $('select[id="itermrelaxType"]').val()
            ADVANCED_TUNING.itermRelaxCutoff = parseInt($('input[name="itermRelaxCutoff"]').val())
            ADVANCED_TUNING.absoluteControlGain = $('input[name="absoluteControlGain-number"]').val()
            ADVANCED_TUNING.throttleBoost = $('input[name="throttleBoost-number"]').val()
            ADVANCED_TUNING.acroTrainerAngleLimit = $('input[name="acroTrainerAngleLimit-number"]').val()
            ADVANCED_TUNING.feedforwardRoll = parseInt($('.pid_tuning .ROLL input[name="f"]').val())
            ADVANCED_TUNING.feedforwardPitch = parseInt($('.pid_tuning .PITCH input[name="f"]').val())
            ADVANCED_TUNING.feedforwardYaw = parseInt($('.pid_tuning .YAW input[name="f"]').val())
            ADVANCED_TUNING.feedforwardTransition = parseInt($('input[name="feedforwardTransition-number"]').val() * 100)
            ADVANCED_TUNING.ornithopter_freq_channel = parseInt($('input[name="freqChannel-number"]').val() * 1)
            ADVANCED_TUNING.ornithopter_freq_min = parseInt($('input[name="freqMin-number"]').val() * 1)
            ADVANCED_TUNING.ornithopter_freq_max = parseInt($('input[name="freqMax-number"]').val() * 1)
            ADVANCED_TUNING.servo_speed_deg_s = parseInt($('input[name="servoSpeedDegS-number"]').val() * 1)
            ADVANCED_TUNING.servo_max_amplitude = parseInt($('input[name="servoMaxAmplitude-number"]').val() * 1)
            ADVANCED_TUNING.flap_magnitude = parseInt($('input[name="flapMagnitude-number"]').val() * 1)
            ADVANCED_TUNING.flapBaseFrequency = 0
            # wire compat — removed param, always 0
            ADVANCED_TUNING.antiGravityMode = $('select[id="antiGravityMode"]').val()
        if semver.gte(CONFIG.apiVersion, '1.41.0')
            RC_tuning.throttleLimitType = $('select[id="throttleLimitType"]').val()
            RC_tuning.throttleLimitPercent = parseInt($('.throttle_limit input[name="throttleLimitPercent"]').val())
            FILTER_CONFIG.dterm_lowpass2_type = $('.pid_filter select[name="dtermLowpass2Type"]').val()
            FILTER_CONFIG.gyro_lowpass_dyn_min_hz = parseInt($('.pid_filter input[name="gyroLowpassDynMinFrequency"]').val())
            FILTER_CONFIG.gyro_lowpass_dyn_max_hz = parseInt($('.pid_filter input[name="gyroLowpassDynMaxFrequency"]').val())
            FILTER_CONFIG.dterm_lowpass_dyn_min_hz = parseInt($('.pid_filter input[name="dtermLowpassDynMinFrequency"]').val())
            FILTER_CONFIG.dterm_lowpass_dyn_max_hz = parseInt($('.pid_filter input[name="dtermLowpassDynMaxFrequency"]').val())
            if FILTER_CONFIG.gyro_lowpass_dyn_min_hz > 0 and FILTER_CONFIG.gyro_lowpass_dyn_min_hz < FILTER_CONFIG.gyro_lowpass_dyn_max_hz
                FILTER_CONFIG.gyro_lowpass_type = $('.pid_filter select[name="gyroLowpassDynType"]').val()
            if FILTER_CONFIG.dterm_lowpass_dyn_min_hz > 0 and FILTER_CONFIG.dterm_lowpass_dyn_min_hz < FILTER_CONFIG.dterm_lowpass_dyn_max_hz
                FILTER_CONFIG.dterm_lowpass_type = $('.pid_filter select[name="dtermLowpassDynType"]').val()
            ADVANCED_TUNING.dMinRoll = parseInt($('.pid_tuning input[name="dMinRoll"]').val())
            ADVANCED_TUNING.dMinPitch = parseInt($('.pid_tuning input[name="dMinPitch"]').val())
            ADVANCED_TUNING.dMinYaw = parseInt($('.pid_tuning input[name="dMinYaw"]').val())
            ADVANCED_TUNING.dMinGain = parseInt($('.dminGroup input[name="dMinGain"]').val())
            ADVANCED_TUNING.dMinAdvance = parseInt($('.dminGroup input[name="dMinAdvance"]').val())
            ADVANCED_TUNING.useIntegratedYaw = if $('input[id="useIntegratedYaw"]').is(':checked') then 1 else 0
        if semver.gte(CONFIG.apiVersion, '1.42.0')
            FILTER_CONFIG.dyn_notch_range = parseInt($('.pid_filter select[name="dynamicNotchRange"]').val())
            FILTER_CONFIG.dyn_notch_width_percent = parseInt($('.pid_filter input[name="dynamicNotchWidthPercent"]').val())
            FILTER_CONFIG.dyn_notch_q = parseInt($('.pid_filter input[name="dynamicNotchQ"]').val())
            FILTER_CONFIG.dyn_notch_min_hz = parseInt($('.pid_filter input[name="dynamicNotchMinHz"]').val())
            rpmFilterEnabled = $('.pid_filter #rpmFilterEnabled').is(':checked')
            FILTER_CONFIG.gyro_rpm_notch_harmonics = if rpmFilterEnabled then parseInt($('.pid_filter input[name="rpmFilterHarmonics"]').val()) else 0
            FILTER_CONFIG.gyro_rpm_notch_min_hz = parseInt($('.pid_filter input[name="rpmFilterMinHz"]').val())
        ADVANCED_TUNING.cadence_gain = parseInt($('.subtab-ondas input[name="cadenceGain"]').val())
        ADVANCED_TUNING.ferocity_d_gain = parseInt($('.subtab-ondas input[name="ferocityDGain"]').val())
        ADVANCED_TUNING.balance_gain = parseInt($('.subtab-ondas input[name="balanceGain"]').val())
        ADVANCED_TUNING.ferocity_p_gain = parseInt($('.subtab-ondas input[name="ferocityPGain"]').val())
        ADVANCED_TUNING.ferocity_roll_gain = parseInt($('.subtab-ondas input[name="ferocityRollGain"]').val())
        ADVANCED_TUNING.ferocity_yaw_gain = parseInt($('.subtab-ondas input[name="ferocityYawGain"]').val())
        ADVANCED_TUNING.warp_gain = parseInt($('.subtab-ondas input[name="warpGain"]').val())
        ADVANCED_TUNING.warp_yaw_gain = parseInt($('.subtab-ondas input[name="warpYawGain"]').val())
        ADVANCED_TUNING.anchor_gain = parseInt($('.subtab-ondas input[name="anchorGain"]').val())
        ADVANCED_TUNING.resonance_gain = parseInt($('.subtab-ondas input[name="resonanceGain"]').val())
        if semver.gte(CONFIG.apiVersion, '1.43.0')
            ADVANCED_TUNING.servo_mount_angle_0 = parseInt($('.subtab-ondas input[name="servoMountAngle0"]').val())
            ADVANCED_TUNING.servo_mount_angle_1 = parseInt($('.subtab-ondas input[name="servoMountAngle1"]').val())
            ADVANCED_TUNING.servo_mount_angle_2 = parseInt($('.subtab-ondas input[name="servoMountAngle2"]').val())
            ADVANCED_TUNING.servo_mount_angle_3 = parseInt($('.subtab-ondas input[name="servoMountAngle3"]').val())
            ADVANCED_TUNING.flapping_phase_shift_0 = parseInt($('.subtab-ondas input[name="flappingPhaseShift0"]').val())
            ADVANCED_TUNING.flapping_phase_shift_1 = parseInt($('.subtab-ondas input[name="flappingPhaseShift1"]').val())
            ADVANCED_TUNING.flapping_phase_shift_2 = parseInt($('.subtab-ondas input[name="flappingPhaseShift2"]').val())
            ADVANCED_TUNING.flapping_phase_shift_3 = parseInt($('.subtab-ondas input[name="flappingPhaseShift3"]').val())
            ADVANCED_TUNING.wing_origin_offset_0 = parseInt($('.subtab-ondas input[name="wingOriginOffset0"]').val())
            ADVANCED_TUNING.wing_origin_offset_1 = parseInt($('.subtab-ondas input[name="wingOriginOffset1"]').val())
            ADVANCED_TUNING.wing_origin_offset_2 = parseInt($('.subtab-ondas input[name="wingOriginOffset2"]').val())
            ADVANCED_TUNING.wing_origin_offset_3 = parseInt($('.subtab-ondas input[name="wingOriginOffset3"]').val())
            $('.subtab-ondas input[name="wingOriginOffset0"]').val ADVANCED_TUNING.wing_origin_offset_0 or 0
            $('.subtab-ondas input[name="wingOriginOffset1"]').val ADVANCED_TUNING.wing_origin_offset_1 or 0
            $('.subtab-ondas input[name="wingOriginOffset2"]').val ADVANCED_TUNING.wing_origin_offset_2 or 0
            $('.subtab-ondas input[name="wingOriginOffset3"]').val ADVANCED_TUNING.wing_origin_offset_3 or 0
            ADVANCED_TUNING.prescience_gain = parseInt($('.subtab-ondas input[name="prescienceGain"]').val())
            ADVANCED_TUNING.espelho_gain = parseInt($('.subtab-ondas input[name="espelhoGain"]').val())
            ADVANCED_TUNING.saudade_gain = parseInt($('.subtab-ondas input[name="saudadeGain"]').val())
            ADVANCED_TUNING.ssff_gain = parseInt($('.subtab-ondas input[name="ssffGain"]').val())
            if semver.gte(CONFIG.apiVersion, '1.46.0')
                ADVANCED_TUNING.ferocity_downstroke = parseInt($('.subtab-ondas input[name="ferocityDownstroke"]').val())
                ADVANCED_TUNING.ferocity_upstroke = parseInt($('.subtab-ondas input[name="ferocityUpstroke"]').val())
                ADVANCED_TUNING.aeroelastic_glide_coefficient = parseInt($('.subtab-ondas input[name="aeroelasticGlideCoefficient"]').val())
                ADVANCED_TUNING.aeroelastic_flap_coefficient = parseInt($('.subtab-ondas input[name="aeroelasticFlapCoefficient"]').val())
        return

    showAllPids = ->
        # Hide all optional elements
        $('.pid_optional tr').hide()
        # Hide all rows
        $('.pid_optional table').hide()
        # Hide tables
        $('.pid_optional').hide()
        # Hide general div
        # Only show rows supported by the firmware
        PID_names.forEach (elementPid) ->
            # Show rows for the PID
            $('.pid_tuning .' + elementPid).show()
            # Show titles and other elements needed by the PID
            $('.needed_by_' + elementPid).show()
            return
        # Special case
        if semver.lt(CONFIG.apiVersion, '1.24.0')
            $('#pid_sensitivity').hide()
        return

    hideUnusedPids = ->
        if !have_sensor(CONFIG.activeSensors, 'acc')
            $('#pid_accel').hide()

        hideSensorPid = (element, sensorReady) ->
            isVisible = element.is(':visible')
            if !isVisible or !sensorReady
                element.hide()
                isVisible = false
            isVisible

        isVisibleBaroMagGps = false
        isVisibleBaroMagGps |= hideSensorPid($('#pid_baro'), have_sensor(CONFIG.activeSensors, 'baro') or have_sensor(CONFIG.activeSensors, 'sonar'))
        isVisibleBaroMagGps |= hideSensorPid($('#pid_mag'), have_sensor(CONFIG.activeSensors, 'mag'))
        isVisibleBaroMagGps |= hideSensorPid($('#pid_gps'), have_sensor(CONFIG.activeSensors, 'GPS'))
        if !isVisibleBaroMagGps
            $('#pid_baro_mag_gps').hide()
        return

    drawAxes = (curveContext, width, height) ->
        curveContext.strokeStyle = '#000000'
        curveContext.lineWidth = 4
        # Horizontal
        curveContext.beginPath()
        curveContext.moveTo 0, height / 2
        curveContext.lineTo width, height / 2
        curveContext.stroke()
        # Vertical
        curveContext.beginPath()
        curveContext.moveTo width / 2, 0
        curveContext.lineTo width / 2, height
        curveContext.stroke()
        return

    checkInput = (element) ->
        value = parseFloat(element.val())
        if value < parseFloat(element.prop('min')) or value > parseFloat(element.prop('max'))
            value = undefined
        value

    printMaxAngularVel = (rate, rcRate, rcExpo, useSuperExpo, deadband, limit, maxAngularVelElement) ->
        maxAngularVel = self.rateCurve.getMaxAngularVel(rate, rcRate, rcExpo, useSuperExpo, deadband, limit).toFixed(0)
        maxAngularVelElement.text maxAngularVel
        maxAngularVel

    drawCurve = (rate, rcRate, rcExpo, useSuperExpo, deadband, limit, maxAngularVel, colour, yOffset, context) ->
        context.save()
        context.strokeStyle = colour
        context.translate 0, yOffset
        self.rateCurve.draw rate, rcRate, rcExpo, useSuperExpo, deadband, limit, maxAngularVel, context
        context.restore()
        return

    process_html = ->

        activateSubtab = (subtabName) ->
            names = [
                'pid'
                'rates'
                'ondas'
                'filter'
            ]
            if !names.includes(subtabName)
                console.debug 'Invalid subtab name: "' + subtabName + '"'
                return
            _k = 0
            while _k < names.length
                name = names[_k]
                el = $('.tab-pid_tuning .subtab-' + name)
                el[if name == subtabName then 'show' else 'hide']()
                _k++
            $('.tab-pid_tuning .tab_container td').removeClass 'active'
            $('.tab-pid_tuning .tab_container .' + subtabName).addClass 'active'
            self.activeSubtab = subtabName
            return

        loadProfilesList = ->
            numberOfProfiles = 3
            if semver.gte(CONFIG.apiVersion, '1.20.0') and CONFIG.numProfiles == 2
                numberOfProfiles = 2
            profileElements = []
            i = 0
            while i < numberOfProfiles
                profileElements.push i18n.getMessage('pidTuningProfileOption', [ i + 1 ])
                i++
            profileElements

        loadRateProfilesList = ->
            numberOfRateProfiles = 6
            if semver.lt(CONFIG.apiVersion, '1.37.0')
                numberOfRateProfiles = 3
            rateProfileElements = []
            i = 0
            while i < numberOfRateProfiles
                rateProfileElements.push i18n.getMessage('pidTuningRateProfileOption', [ i + 1 ])
                i++
            rateProfileElements

        populateProfilesSelector = (selectProfileValues) ->
            profileSelect = $('select[name="profile"]')
            selectProfileValues.forEach (value, key) ->
                profileSelect.append '<option value="' + key + '">' + value + '</option>'
                return
            return

        populateRateProfilesSelector = (selectRateProfileValues) ->
            rateProfileSelect = $('select[name="rate_profile"]')
            selectRateProfileValues.forEach (value, key) ->
                rateProfileSelect.append '<option value="' + key + '">' + value + '</option>'
                return
            return

        populateOrnithopterProfileSelector = ->
            profileSelect = $('.subtab-ondas select[name="ornithopterProfile"]')
            i = 0
            while i < 3
                profileSelect.append '<option value="' + i + '">' + i18n.getMessage('pidTuningOrnithopterProfileOption', [ i + 1 ]) + '</option>'
                i++
            return

        updatePidDisplay = ->
            if !self.showAllPids
                hideUnusedPids()
                showAllButton.text i18n.getMessage('pidTuningShowAllPids')
            else
                showAllPids()
                showAllButton.text i18n.getMessage('pidTuningHideUnusedPids')
            return

        checkUpdateDtermTransitionWarning = (value) ->
            if value > 0 and value < 0.1
                dtermTransitionWarningElement.show()
            else
                dtermTransitionWarningElement.hide()
            return

        # DTerm filter options

        loadFilterTypeValues = ->
            filterTypeValues = []
            filterTypeValues.push 'PT1'
            filterTypeValues.push 'BIQUAD'
            if semver.lt(CONFIG.apiVersion, '1.39.0')
                filterTypeValues.push 'FIR'
            filterTypeValues

        populateFilterTypeSelector = (name, selectDtermValues) ->
            dtermFilterSelect = $('select[name="' + name + '"]')
            selectDtermValues.forEach (value, key) ->
                dtermFilterSelect.append '<option value="' + key + '">' + value + '</option>'
                return
            return

        # Added in API 1.42.0

        loadDynamicNotchRangeValues = ->
            dynamicNotchRangeValues = [
                'HIGH'
                'MEDIUM'
                'LOW'
                'AUTO'
            ]
            dynamicNotchRangeValues

        populateDynamicNotchRangeSelect = (selectDynamicNotchRangeValues) ->
            dynamicNotchRangeSelect = $('select[name="dynamicNotchRange"]')
            selectDynamicNotchRangeValues.forEach (value, key) ->
                dynamicNotchRangeSelect.append '<option value="' + key + '">' + value + '</option>'
                return
            return

        updateRates = (event) ->
            setTimeout (->
                # let global validation trigger and adjust the values first
                if event
                    # if an event is passed, then use it
                    targetElement = $(event.target)
                    targetValue = checkInput(targetElement)
                    if self.currentRates.hasOwnProperty(targetElement.attr('name')) and targetValue != undefined
                        self.currentRates[targetElement.attr('name')] = targetValue
                        updateNeeded = true
                    if targetElement.attr('name') == 'rc_rate' and semver.lt(CONFIG.apiVersion, '1.16.0')
                        self.currentRates.rc_rate_yaw = targetValue
                    if targetElement.attr('name') == 'roll_pitch_rate' and semver.lt(CONFIG.apiVersion, '1.7.0')
                        self.currentRates.roll_rate = targetValue
                        self.currentRates.pitch_rate = targetValue
                        updateNeeded = true
                    if targetElement.attr('name') == 'SUPEREXPO_RATES'
                        self.currentRates.superexpo = targetElement.is(':checked')
                        updateNeeded = true
                    if targetElement.attr('name') == 'rc_rate' and semver.lt(CONFIG.apiVersion, '1.37.0')
                        self.currentRates.rc_rate_pitch = targetValue
                    if targetElement.attr('name') == 'rc_expo' and semver.lt(CONFIG.apiVersion, '1.37.0')
                        self.currentRates.rc_pitch_expo = targetValue
                else
                    # no event was passed, just force a graph update
                    updateNeeded = true
                if updateNeeded
                    curveHeight = rcCurveElement.height
                    curveWidth = rcCurveElement.width
                    lineScale = curveContext.canvas.width / curveContext.canvas.clientWidth
                    curveContext.clearRect 0, 0, curveWidth, curveHeight
                    if !useLegacyCurve
                        maxAngularVel = Math.max(printMaxAngularVel(self.currentRates.roll_rate, self.currentRates.rc_rate, self.currentRates.rc_expo, self.currentRates.superexpo, self.currentRates.deadband, self.currentRates.roll_rate_limit, self.maxAngularVelRollElement), printMaxAngularVel(self.currentRates.pitch_rate, self.currentRates.rc_rate_pitch, self.currentRates.rc_pitch_expo, self.currentRates.superexpo, self.currentRates.deadband, self.currentRates.pitch_rate_limit, self.maxAngularVelPitchElement), printMaxAngularVel(self.currentRates.yaw_rate, self.currentRates.rc_rate_yaw, self.currentRates.rc_yaw_expo, self.currentRates.superexpo, self.currentRates.yawDeadband, self.currentRates.yaw_rate_limit, self.maxAngularVelYawElement))
                        # make maxAngularVel multiple of 200deg/s so that the auto-scale doesn't keep changing for small changes of the maximum curve
                        maxAngularVel = self.rateCurve.setMaxAngularVel(maxAngularVel)
                        drawAxes curveContext, curveWidth, curveHeight
                    else
                        maxAngularVel = 0
                    curveContext.lineWidth = 2 * lineScale
                    drawCurve self.currentRates.roll_rate, self.currentRates.rc_rate, self.currentRates.rc_expo, self.currentRates.superexpo, self.currentRates.deadband, self.currentRates.roll_rate_limit, maxAngularVel, '#ff0000', 0, curveContext
                    drawCurve self.currentRates.pitch_rate, self.currentRates.rc_rate_pitch, self.currentRates.rc_pitch_expo, self.currentRates.superexpo, self.currentRates.deadband, self.currentRates.pitch_rate_limit, maxAngularVel, '#00ff00', -4, curveContext
                    drawCurve self.currentRates.yaw_rate, self.currentRates.rc_rate_yaw, self.currentRates.rc_yaw_expo, self.currentRates.superexpo, self.currentRates.yawDeadband, self.currentRates.yaw_rate_limit, maxAngularVel, '#0000ff', 4, curveContext
                    self.updateRatesLabels()
                    updateNeeded = false
                return
            ), 0
            return

        if semver.gte(CONFIG.apiVersion, '1.16.0') and !semver.gte(CONFIG.apiVersion, '1.20.0')
            FEATURE_CONFIG.features.generateElements $('.tab-pid_tuning .features')
        else
            $('.tab-pid_tuning .pidTuningFeatures').hide()
        if semver.lt(CONFIG.apiVersion, '1.39.0')
            $('input[name="dtermSetpoint-number"]').attr 'max', self.SETPOINT_WEIGHT_RANGE_LEGACY
        # translate to user-selected language
        i18n.localizePage()
        # Local cache of current rates
        self.currentRates =
            roll_rate: RC_tuning.roll_rate
            pitch_rate: RC_tuning.pitch_rate
            yaw_rate: RC_tuning.yaw_rate
            rc_rate: RC_tuning.RC_RATE
            rc_rate_yaw: RC_tuning.rcYawRate
            rc_expo: RC_tuning.RC_EXPO
            rc_yaw_expo: RC_tuning.RC_YAW_EXPO
            rc_rate_pitch: RC_tuning.rcPitchRate
            rc_pitch_expo: RC_tuning.RC_PITCH_EXPO
            superexpo: FEATURE_CONFIG.features.isEnabled('SUPEREXPO_RATES')
            deadband: RC_DEADBAND_CONFIG.deadband
            yawDeadband: RC_DEADBAND_CONFIG.yaw_deadband
            roll_rate_limit: RC_tuning.roll_rate_limit
            pitch_rate_limit: RC_tuning.pitch_rate_limit
            yaw_rate_limit: RC_tuning.yaw_rate_limit
        if semver.lt(CONFIG.apiVersion, '1.7.0')
            self.currentRates.roll_rate = RC_tuning.roll_pitch_rate
            self.currentRates.pitch_rate = RC_tuning.roll_pitch_rate
        if semver.lt(CONFIG.apiVersion, '1.16.0')
            self.currentRates.rc_rate_yaw = self.currentRates.rc_rate
        if semver.gte(CONFIG.apiVersion, '1.20.0')
            self.currentRates.superexpo = true
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            $('.pid_tuning input[name="sensitivity"]').hide()
            $('.pid_tuning .levelSensitivityHeader').empty()
        if semver.lt(CONFIG.apiVersion, '1.37.0')
            self.currentRates.rc_rate_pitch = self.currentRates.rc_rate
            self.currentRates.rc_expo_pitch = self.currentRates.rc_expo
        activateSubtab self.activeSubtab
        $('.tab-pid_tuning .tab_container .pid').on 'click', ->
            activateSubtab 'pid'
        $('.tab-pid_tuning .tab_container .rates').on 'click', ->
            activateSubtab 'rates'
        $('.tab-pid_tuning .tab_container .ondas').on 'click', ->
            activateSubtab 'ondas'
        $('.tab-pid_tuning .tab_container .filter').on 'click', ->
            activateSubtab 'filter'
        # This vars are used here for populate the profile (and rate profile) selector AND in the copy profile (and rate profile) window
        selectRateProfileValues = loadRateProfilesList()
        selectProfileValues = loadProfilesList()
        populateProfilesSelector selectProfileValues
        populateRateProfilesSelector selectRateProfileValues
        if semver.gte(CONFIG.apiVersion, '1.46.0')
            populateOrnithopterProfileSelector()
        showAllButton = $('#showAllPids')
        showAllPids()
        updatePidDisplay()
        showAllButton.on 'click', ->
            self.showAllPids = !self.showAllPids
            updatePidDisplay()
            return
        $('#resetProfile').on 'click', ->
            self.updating = true
            MSP.promise(MSPCodes.MSP_SET_RESET_CURR_PID).then ->
                self.refresh ->
                    self.updating = false
                    GUI.log i18n.getMessage('pidTuningProfileReset')
                    return
                return
            return
        $('.tab-pid_tuning select[name="profile"]').change ->
            self.currentProfile = parseInt($(this).val())
            self.updating = true
            $(this).prop 'disabled', 'true'
            MSP.promise(MSPCodes.MSP_SELECT_SETTING, [ self.currentProfile ]).then ->
                self.refresh ->
                    self.updating = false
                    $('.tab-pid_tuning select[name="profile"]').prop 'disabled', 'false'
                    CONFIG.profile = self.currentProfile
                    GUI.log i18n.getMessage('pidTuningLoadedProfile', [ self.currentProfile + 1 ])
                    return
                return
            return
        $('.subtab-ondas select[name="ornithopterProfile"]').change ->
            self.updating = true
            ADVANCED_TUNING.ornithopter_profile_index = parseInt($(this).val())
            $(this).prop 'disabled', true
            MSP.promise(MSPCodes.MSP_SET_PID_ADVANCED, mspHelper.crunch(MSPCodes.MSP_SET_PID_ADVANCED)).then(->
                MSP.promise MSPCodes.MSP_PID_ADVANCED
            ).then ->
                self.updatePidControllerParameters()
                self.updating = false
                $('.subtab-ondas select[name="ornithopterProfile"]').prop 'disabled', false
                GUI.log i18n.getMessage('pidTuningOrnithopterProfileLoaded', [ ADVANCED_TUNING.ornithopter_profile_index + 1 ])
                return
            return
        if semver.gte(CONFIG.apiVersion, '1.20.0')
            $('.tab-pid_tuning select[name="rate_profile"]').change ->
                self.currentRateProfile = parseInt($(this).val())
                self.updating = true
                $(this).prop 'disabled', 'true'
                MSP.promise(MSPCodes.MSP_SELECT_SETTING, [ self.currentRateProfile + self.RATE_PROFILE_MASK ]).then ->
                    self.refresh ->
                        self.updating = false
                        $('.tab-pid_tuning select[name="rate_profile"]').prop 'disabled', 'false'
                        CONFIG.rateProfile = self.currentRateProfile
                        GUI.log i18n.getMessage('pidTuningLoadedRateProfile', [ self.currentRateProfile + 1 ])
                        return
                    return
                return
            dtermTransitionNumberElement = $('input[name="dtermSetpointTransition-number"]')
            dtermTransitionWarningElement = $('#pid-tuning .dtermSetpointTransitionWarning')
            checkUpdateDtermTransitionWarning dtermTransitionNumberElement.val()
            #Use 'input' event for coupled controls to allow synchronized update
            dtermTransitionNumberElement.on 'input', ->
                checkUpdateDtermTransitionWarning $(this).val()
                return
        else
            $('.tab-pid_tuning .rate_profile').hide()
            $('#pid-tuning .dtermSetpointTransition').hide()
            $('#pid-tuning .dtermSetpoint').hide()
        if !semver.gte(CONFIG.apiVersion, '1.16.0')
            $('#pid-tuning .delta').hide()
            $('.tab-pid_tuning .note').hide()
        # Add a name to each row of PIDs if empty
        $('.pid_tuning tr').each ->
            i = 0
            while i < PID_names.length
                if $(this).hasClass(PID_names[i])
                    firstColumn = $(this).find('td:first')
                    if !firstColumn.text()
                        firstColumn.text PID_names[i]
                i++
            return
        if semver.gte(CONFIG.apiVersion, '1.42.0')
            populateDynamicNotchRangeSelect loadDynamicNotchRangeValues()
        populateFilterTypeSelector 'gyroLowpassType', loadFilterTypeValues()
        populateFilterTypeSelector 'gyroLowpassDynType', loadFilterTypeValues()
        populateFilterTypeSelector 'gyroLowpass2Type', loadFilterTypeValues()
        populateFilterTypeSelector 'dtermLowpassType', loadFilterTypeValues()
        populateFilterTypeSelector 'dtermLowpass2Type', loadFilterTypeValues()
        populateFilterTypeSelector 'dtermLowpassDynType', loadFilterTypeValues()
        pid_and_rc_to_form()
        pidController_e = $('select[name="controller"]')
        if semver.lt(CONFIG.apiVersion, '1.31.0')
            pidControllerList = undefined
            if semver.lt(CONFIG.apiVersion, '1.14.0')
                pidControllerList = [
                    { name: 'MultiWii (Old)' }
                    { name: 'MultiWii (rewrite)' }
                    { name: 'LuxFloat' }
                    { name: 'MultiWii (2.3 - latest)' }
                    { name: 'MultiWii (2.3 - hybrid)' }
                    { name: 'Harakiri' }
                ]
            else if semver.lt(CONFIG.apiVersion, '1.20.0')
                pidControllerList = [
                    { name: '' }
                    { name: 'Integer' }
                    { name: 'Float' }
                ]
            else
                pidControllerList = [
                    { name: 'Legacy' }
                    { name: 'OrniFlight' }
                ]
            i = 0
            while i < pidControllerList.length
                pidController_e.append '<option value="' + i + '">' + pidControllerList[i].name + '</option>'
                i++
            if semver.gte(CONFIG.apiVersion, CONFIGURATOR.pidControllerChangeMinApiVersion)
                pidController_e.val PID.controller
                self.updatePidControllerParameters()
            else
                GUI.log i18n.getMessage('pidTuningUpgradeFirmwareToChangePidController', [
                    CONFIG.apiVersion
                    CONFIGURATOR.pidControllerChangeMinApiVersion
                ])
                pidController_e.empty()
                pidController_e.append '<option value="">Unknown</option>'
                pidController_e.prop 'disabled', true
        else
            $('.tab-pid_tuning div.controller').hide()
            self.updatePidControllerParameters()
        if semver.lt(CONFIG.apiVersion, '1.7.0')
            $('.tpa .tpa-breakpoint').hide()
            $('.pid_tuning .roll_rate').hide()
            $('.pid_tuning .pitch_rate').hide()
        else
            $('.pid_tuning .roll_pitch_rate').hide()
        if semver.gte(CONFIG.apiVersion, '1.37.0')
            $('.pid_tuning .bracket').hide()
            $('.pid_tuning input[name=rc_rate]').parent().attr 'class', 'pid_data'
            $('.pid_tuning input[name=rc_rate]').parent().attr 'rowspan', 1
            $('.pid_tuning input[name=rc_expo]').parent().attr 'class', 'pid_data'
            $('.pid_tuning input[name=rc_expo]').parent().attr 'rowspan', 1
        else
            $('.pid_tuning input[name=rc_rate_pitch]').parent().hide()
            $('.pid_tuning input[name=rc_pitch_expo]').parent().hide()
        if useLegacyCurve
            $('.new_rates').hide()
        # Getting the DOM elements for curve display
        rcCurveElement = $('.rate_curve canvas#rate_curve_layer0').get(0)
        curveContext = rcCurveElement.getContext('2d')
        updateNeeded = true
        maxAngularVel = undefined
        # make these variables global scope so that they can be accessed by the updateRates function.
        self.maxAngularVelRollElement = $('.pid_tuning .maxAngularVelRoll')
        self.maxAngularVelPitchElement = $('.pid_tuning .maxAngularVelPitch')
        self.maxAngularVelYawElement = $('.pid_tuning .maxAngularVelYaw')
        rcCurveElement.width = 1000
        rcCurveElement.height = 1000
        # UI Hooks
        # curves
        $('input.feature').on 'input change', updateRates
        $('.pid_tuning').on('input change', updateRates).trigger 'input'
        $('.throttle input').on('input change', ->
            setTimeout (->
                # let global validation trigger and adjust the values first
                throttleMidE = $('.throttle input[name="mid"]')
                throttleExpoE = $('.throttle input[name="expo"]')
                mid = parseFloat(throttleMidE.val())
                expo = parseFloat(throttleExpoE.val())
                throttleCurve = $('.throttle .throttle_curve canvas').get(0)
                context = throttleCurve.getContext('2d')
                # local validation to deal with input event
                if mid >= parseFloat(throttleMidE.prop('min')) and mid <= parseFloat(throttleMidE.prop('max')) and expo >= parseFloat(throttleExpoE.prop('min')) and expo <= parseFloat(throttleExpoE.prop('max'))
                    # continue
                else
                    return
                canvasHeight = throttleCurve.height
                canvasWidth = throttleCurve.width
                # math magic by englishman
                midx = canvasWidth * mid
                midxl = midx * 0.5
                midxr = (canvasWidth - midx) * 0.5 + midx
                midy = canvasHeight - (midx * canvasHeight / canvasWidth)
                midyl = canvasHeight - ((canvasHeight - midy) * 0.5 * (expo + 1))
                midyr = midy / 2 * (expo + 1)
                # draw
                context.clearRect 0, 0, canvasWidth, canvasHeight
                context.beginPath()
                context.moveTo 0, canvasHeight
                context.quadraticCurveTo midxl, midyl, midx, midy
                context.moveTo midx, midy
                context.quadraticCurveTo midxr, midyr, canvasWidth, 0
                context.lineWidth = 2
                context.strokeStyle = '#8998fe'
                context.stroke()
                return
            ), 0
            return
        ).trigger 'input'
        $('a.refresh').click ->
            self.refresh ->
                GUI.log i18n.getMessage('pidTuningDataRefreshed')
                return
            return
        $('#pid-tuning').find('input').each (k, item) ->
            if $(item).attr('class') != 'feature toggle' and $(item).attr('class') != 'nonProfile'
                $(item).change ->
                    self.setDirty true
                    return
            return
        dialogCopyProfile = $('.dialogCopyProfile')[0]
        DIALOG_MODE_PROFILE = 0
        DIALOG_MODE_RATEPROFILE = 1
        dialogCopyProfileMode = undefined
        if semver.gte(CONFIG.apiVersion, '1.36.0')
            selectProfile = $('.selectProfile')
            selectRateProfile = $('.selectRateProfile')
            $.each selectProfileValues, (key, value) ->
                if key != CONFIG.profile
                    selectProfile.append new Option(value, key)
                return
            $.each selectRateProfileValues, (key, value) ->
                if key != CONFIG.rateProfile
                    selectRateProfile.append new Option(value, key)
                return
            $('.copyprofilebtn').click ->
                $('.dialogCopyProfile').find('.contentProfile').show()
                $('.dialogCopyProfile').find('.contentRateProfile').hide()
                dialogCopyProfileMode = DIALOG_MODE_PROFILE
                dialogCopyProfile.showModal()
                return
            $('.copyrateprofilebtn').click ->
                $('.dialogCopyProfile').find('.contentProfile').hide()
                $('.dialogCopyProfile').find('.contentRateProfile').show()
                dialogCopyProfileMode = DIALOG_MODE_RATEPROFILE
                dialogCopyProfile.showModal()
                return
            $('.dialogCopyProfile-cancelbtn').click ->
                dialogCopyProfile.close()
                return
            $('.dialogCopyProfile-confirmbtn').click ->

                close_dialog = ->
                    dialogCopyProfile.close()
                    return

                switch dialogCopyProfileMode
                    when DIALOG_MODE_PROFILE
                        COPY_PROFILE.type = DIALOG_MODE_PROFILE
                        # 0 = pid profile
                        COPY_PROFILE.dstProfile = parseInt(selectProfile.val())
                        COPY_PROFILE.srcProfile = CONFIG.profile
                        MSP.send_message MSPCodes.MSP_COPY_PROFILE, mspHelper.crunch(MSPCodes.MSP_COPY_PROFILE), false, close_dialog
                    when DIALOG_MODE_RATEPROFILE
                        COPY_PROFILE.type = DIALOG_MODE_RATEPROFILE
                        # 1 = rate profile
                        COPY_PROFILE.dstProfile = parseInt(selectRateProfile.val())
                        COPY_PROFILE.srcProfile = CONFIG.rateProfile
                        MSP.send_message MSPCodes.MSP_COPY_PROFILE, mspHelper.crunch(MSPCodes.MSP_COPY_PROFILE), false, close_dialog
                    else
                        close_dialog()
                        break
                return
        else
            $('.copyprofilebtn').hide()
            $('.copyrateprofilebtn').hide()
        if semver.gte(CONFIG.apiVersion, '1.42.0')
            # filter and tuning sliders
            TuningSliders.initialize()
            self.analyticsChanges = {}
            # UNSCALED non expert slider constrain values
            NON_EXPERT_SLIDER_MAX = 1.25
            NON_EXPERT_SLIDER_MIN = 0.7
            $('input[name="expertModeCheckbox"]').change ->
                if TuningSliders.expertMode != $(this).is(':checked')
                    TuningSliders.setExpertMode $(this).is(':checked')
                    TuningSliders.updatePidSlidersDisplay()
                    TuningSliders.updateFilterSlidersDisplay()
                return
            $('#dMinSwitch').change ->
                TuningSliders.setDMinFeatureEnabled $(this).is(':checked')
                # switch dmin and dmax values on dmin on/off if sliders available
                if !TuningSliders.pidSlidersUnavailable
                    if TuningSliders.dMinFeatureEnabled
                        ADVANCED_TUNING.dMinRoll = PIDs[0][2]
                        ADVANCED_TUNING.dMinPitch = PIDs[1][2]
                        ADVANCED_TUNING.dMinYaw = PIDs[2][2]
                    else
                        PIDs[0][2] = ADVANCED_TUNING.dMinRoll
                        PIDs[1][2] = ADVANCED_TUNING.dMinPitch
                        PIDs[2][2] = ADVANCED_TUNING.dMinYaw
                    TuningSliders.calculateNewPids()
                return
            # integrated yaw doesn't work with sliders therefore sliders are disabled
            $('input[id="useIntegratedYaw"]').change ->
                TuningSliders.updatePidSlidersDisplay()
            # pid sliders inputs
            $('#tuningMasterSlider, #tuningPDRatioSlider, #tuningPDGainSlider, #tuningResponseSlider').on 'input', ->
                slider = $(this)
                # adjust step for more smoothness above 1x
                if slider.val() >= 1
                    slider.attr 'step', 0.05
                else
                    slider.attr 'step', 0.1
                if !TuningSliders.expertMode
                    if slider.val() > NON_EXPERT_SLIDER_MAX
                        slider.val NON_EXPERT_SLIDER_MAX
                    else if slider.val() < NON_EXPERT_SLIDER_MIN
                        slider.val NON_EXPERT_SLIDER_MIN
                scaledValue = TuningSliders.scaleSliderValue(slider.val())
                if slider.is('#tuningMasterSlider')
                    TuningSliders.MasterSliderValue = scaledValue
                else if slider.is('#tuningPDRatioSlider')
                    TuningSliders.PDRatioSliderValue = scaledValue
                else if slider.is('#tuningPDGainSlider')
                    TuningSliders.PDGainSliderValue = scaledValue
                else if slider.is('#tuningResponseSlider')
                    TuningSliders.ResponseSliderValue = scaledValue
                TuningSliders.calculateNewPids()
                self.analyticsChanges['PidTuningSliders'] = 'On'
                return
            $('#tuningMasterSlider, #tuningPDRatioSlider, #tuningPDGainSlider, #tuningResponseSlider').mousedown ->
                # adjust step for more smoothness above 1x on mousedown
                slider = $(this)
                if slider.val() >= 1
                    slider.attr 'step', 0.05
                else
                    slider.attr 'step', 0.1
                return
            $('#tuningMasterSlider, #tuningPDRatioSlider, #tuningPDGainSlider, #tuningResponseSlider').mouseup ->
                # readjust dmin maximums
                $('.pid_tuning .ROLL input[name="d"]').change()
                $('.pid_tuning .PITCH input[name="d"]').change()
                $('.pid_tuning .YAW input[name="d"]').change()
                TuningSliders.updatePidSlidersDisplay()
                return
            # reset to middle with double click
            $('#tuningMasterSlider, #tuningPDRatioSlider, #tuningPDGainSlider, #tuningResponseSlider').dblclick ->
                slider = $(this)
                slider.val 1
                if slider.is('#tuningMasterSlider')
                    TuningSliders.MasterSliderValue = 1
                else if slider.is('#tuningPDRatioSlider')
                    TuningSliders.PDRatioSliderValue = 1
                else if slider.is('#tuningPDGainSlider')
                    TuningSliders.PDGainSliderValue = 1
                else if slider.is('#tuningResponseSlider')
                    TuningSliders.ResponseSliderValue = 1
                TuningSliders.calculateNewPids()
                TuningSliders.updatePidSlidersDisplay()
                return
            # enable PID sliders button
            $('a.buttonPidTuningSliders').click ->
                # if values were previously changed manually and then sliders are reactivated, reset pids to previous valid values if available, else default
                TuningSliders.resetPidSliders()
                # disable integrated yaw when enabling sliders
                if $('input[id="useIntegratedYaw"]').is(':checked')
                    $('input[id="useIntegratedYaw"]').prop('checked', true).click()
                self.analyticsChanges['PidTuningSliders'] = 'On'
                return
            # filter slider inputs
            $('#tuningGyroFilterSlider, #tuningDTermFilterSlider').on 'input', ->
                slider = $(this)
                if !TuningSliders.expertMode
                    if slider.val() > NON_EXPERT_SLIDER_MAX
                        slider.val NON_EXPERT_SLIDER_MAX
                    else if slider.val() < NON_EXPERT_SLIDER_MIN
                        slider.val NON_EXPERT_SLIDER_MIN
                scaledValue = TuningSliders.scaleSliderValue(slider.val())
                if slider.is('#tuningGyroFilterSlider')
                    TuningSliders.gyroFilterSliderValue = scaledValue
                    TuningSliders.calculateNewGyroFilters()
                    self.analyticsChanges['GyroFilterTuningSlider'] = 'On'
                else if slider.is('#tuningDTermFilterSlider')
                    TuningSliders.dtermFilterSliderValue = scaledValue
                    TuningSliders.calculateNewDTermFilters()
                    self.analyticsChanges['DTermFilterTuningSlider'] = 'On'
                return
            $('#tuningGyroFilterSlider, #tuningDTermFilterSlider').mouseup ->
                TuningSliders.updateFilterSlidersDisplay()
                return
            # reset to middle with double click
            $('#tuningGyroFilterSlider, #tuningDTermFilterSlider').dblclick ->
                slider = $(this)
                slider.val 1
                if slider.is('#tuningGyroFilterSlider')
                    TuningSliders.gyroFilterSliderValue = 1
                    TuningSliders.calculateNewGyroFilters()
                else if slider.is('#tuningDTermFilterSlider')
                    TuningSliders.dtermFilterSliderValue = 1
                    TuningSliders.calculateNewDTermFilters()
                TuningSliders.updateFilterSlidersDisplay()
                return
            # enable PID sliders button
            $('a.buttonFilterTuningSliders').click ->
                if TuningSliders.filterGyroSliderUnavailable
                    # update switchery dynamically based on defaults
                    $('input[id="gyroLowpassDynEnabled"]').prop('checked', false).click()
                    $('input[id="gyroLowpassEnabled"]').prop('checked', true).click()
                    $('input[id="gyroLowpass2Enabled"]').prop('checked', false).click()
                    TuningSliders.resetGyroFilterSlider()
                    self.analyticsChanges['GyroFilterTuningSlider'] = 'On'
                if TuningSliders.filterDTermSliderUnavailable
                    $('input[id="dtermLowpassDynEnabled"]').prop('checked', false).click()
                    $('input[id="dtermLowpassEnabled"]').prop('checked', true).click()
                    $('input[id="dtermLowpass2Enabled"]').prop('checked', false).click()
                    TuningSliders.resetDTermFilterSlider()
                    self.analyticsChanges['DTermFilterTuningSlider'] = 'On'
                return
            # update on pid table inputs
            $('#pid_main input').on 'input', ->
                TuningSliders.updatePidSlidersDisplay()
                self.analyticsChanges['PidTuningSliders'] = 'Off'
                return
            # update on filter value or type changes
            $('.pid_filter tr:not(.newFilter) input, .pid_filter tr:not(.newFilter) select').on 'input', ->
                TuningSliders.updateFilterSlidersDisplay()
                if TuningSliders.filterGyroSliderUnavailable
                    self.analyticsChanges['GyroFilterTuningSlider'] = 'Off'
                if TuningSliders.filterDTermSliderUnavailable
                    self.analyticsChanges['DTermFilterTuningSlider'] = 'Off'
                return
            # update on filter switch changes
            $('.pid_filter tr:not(.newFilter) .inputSwitch input').change ->
                $('.pid_filter input').triggerHandler 'input'
            $('.tuningHelp').hide()
        else
            $('.tuningPIDSliders').hide()
            $('.tuningFilterSliders').hide()
            $('.slidersDisabled').hide()
            $('.slidersWarning').hide()
            $('.nonExpertModeSlidersNote').hide()
            $('.tuningHelpSliders').hide()
        if semver.gte(CONFIG.apiVersion, '1.16.0')
            $('#pid-tuning .delta select').change ->
                self.setDirty true
                return
        if semver.lt(CONFIG.apiVersion, '1.31.0')
            pidController_e.change ->
                self.setDirty true
                self.updatePidControllerParameters()
                return
        # update == save.
        $('a.update').click ->
            form_to_pid_and_rc()
            self.updating = true
            Promise.resolve(true).then(->
                promise = undefined
                if semver.gte(CONFIG.apiVersion, CONFIGURATOR.pidControllerChangeMinApiVersion) and semver.lt(CONFIG.apiVersion, '1.31.0')
                    PID.controller = pidController_e.val()
                    promise = MSP.promise(MSPCodes.MSP_SET_PID_CONTROLLER, mspHelper.crunch(MSPCodes.MSP_SET_PID_CONTROLLER))
                promise
            ).then(->
                MSP.promise MSPCodes.MSP_SET_PID, mspHelper.crunch(MSPCodes.MSP_SET_PID)
            ).then(->
                MSP.promise MSPCodes.MSP_SET_PID_ADVANCED, mspHelper.crunch(MSPCodes.MSP_SET_PID_ADVANCED)
            ).then(->
                MSP.promise MSPCodes.MSP_SET_FILTER_CONFIG, mspHelper.crunch(MSPCodes.MSP_SET_FILTER_CONFIG)
            ).then(->
                MSP.promise MSPCodes.MSP_SET_RC_TUNING, mspHelper.crunch(MSPCodes.MSP_SET_RC_TUNING)
            ).then(->
                MSP.promise MSPCodes.MSP_EEPROM_WRITE
            ).then ->
                self.updating = false
                self.setDirty false
                GUI.log i18n.getMessage('pidTuningEepromSaved')
                return
            analytics.sendChangeEvents analytics.EVENT_CATEGORIES.FLIGHT_CONTROLLER, self.analyticsChanges
            self.analyticsChanges = {}
            return
        # Setup model for rates preview
        self.initRatesPreview()
        self.renderModel()
        self.updating = false
        # enable RC data pulling for rates preview
        GUI.interval_add 'receiver_pull', self.getRecieverData, true
        # status data pulled via separate timer with static speed
        GUI.interval_add 'status_pull', (->
            MSP.send_message MSPCodes.MSP_STATUS
            return
        ), 250, true
        GUI.content_ready callback
        return

    if GUI.active_tab != 'pid_tuning'
        GUI.active_tab = 'pid_tuning'
        self.activeSubtab = 'pid'
    # Update filtering defaults based on API version
    FILTER_DEFAULT = FC.getFilterDefaults()
    # requesting MSP_STATUS manually because it contains CONFIG.profile
    MSP.promise(MSPCodes.MSP_STATUS).then(->
        if semver.gte(CONFIG.apiVersion, CONFIGURATOR.pidControllerChangeMinApiVersion)
            return MSP.promise(MSPCodes.MSP_PID_CONTROLLER)
        return
    ).then(->
        MSP.promise MSPCodes.MSP_PIDNAMES
    ).then(->
        MSP.promise MSPCodes.MSP_PID
    ).then(->
        if semver.gte(CONFIG.apiVersion, '1.16.0')
            return MSP.promise(MSPCodes.MSP_PID_ADVANCED)
        return
    ).then(->
        MSP.promise MSPCodes.MSP_RC_TUNING
    ).then(->
        MSP.promise MSPCodes.MSP_FILTER_CONFIG
    ).then(->
        MSP.promise MSPCodes.MSP_RC_DEADBAND
    ).then(->
        MSP.promise MSPCodes.MSP_MOTOR_CONFIG
    ).then ->
        MSP.send_message MSPCodes.MSP_MIXER_CONFIG, false, false, load_html
        return
    useLegacyCurve = false
    if !semver.gte(CONFIG.apiVersion, '1.16.0')
        useLegacyCurve = true
    self.rateCurve = new RateCurve(useLegacyCurve)
    return

TABS.pid_tuning.getRecieverData = ->
    MSP.send_message MSPCodes.MSP_RC, false, false
    return

TABS.pid_tuning.initRatesPreview = ->
    @keepRendering = true
    @model = new Model($('.rates_preview'), $('.rates_preview canvas'))
    $('.tab-pid_tuning .tab_container .rates').on 'click', $.proxy(@model.resize, @model)
    $('.tab-pid_tuning .tab_container .rates').on 'click', $.proxy(@updateRatesLabels, this)
    $(window).on 'resize', $.proxy(@model.resize, @model)
    $(window).on 'resize', $.proxy(@updateRatesLabels, this)
    return

TABS.pid_tuning.renderModel = ->
    if @keepRendering
        requestAnimationFrame @renderModel.bind(this)
    if !@clock
        @clock = new (THREE.Clock)
    if RC.channels[0] and RC.channels[1] and RC.channels[2]
        delta = @clock.getDelta()
        roll = delta * @rateCurve.rcCommandRawToDegreesPerSecond(RC.channels[0], @currentRates.roll_rate, @currentRates.rc_rate, @currentRates.rc_expo, @currentRates.superexpo, @currentRates.deadband, @currentRates.roll_rate_limit)
        pitch = delta * @rateCurve.rcCommandRawToDegreesPerSecond(RC.channels[1], @currentRates.pitch_rate, @currentRates.rc_rate_pitch, @currentRates.rc_pitch_expo, @currentRates.superexpo, @currentRates.deadband, @currentRates.pitch_rate_limit)
        yaw = delta * @rateCurve.rcCommandRawToDegreesPerSecond(RC.channels[2], @currentRates.yaw_rate, @currentRates.rc_rate_yaw, @currentRates.rc_yaw_expo, @currentRates.superexpo, @currentRates.yawDeadband, @currentRates.yaw_rate_limit)
        @model.rotateBy -degToRad(pitch), -degToRad(yaw), -degToRad(roll)
        if @checkRC()
            @updateRatesLabels()
        # has the RC data changed ?
    return

TABS.pid_tuning.cleanup = (callback) ->
    self = this
    if self.model
        $(window).off 'resize', $.proxy(self.model.resize, self.model)
        self.model.dispose()
    $(window).off 'resize', $.proxy(@updateRatesLabels, this)
    self.keepRendering = false
    if callback
        callback()
    return

TABS.pid_tuning.refresh = (callback) ->
    self = this
    GUI.tab_switch_cleanup ->
        self.initialize()
        self.setDirty false
        if callback
            callback()
        return
    return

TABS.pid_tuning.setProfile = ->
    self = this
    self.currentProfile = CONFIG.profile
    $('.tab-pid_tuning select[name="profile"]').val self.currentProfile
    return

TABS.pid_tuning.setRateProfile = ->
    self = this
    self.currentRateProfile = CONFIG.rateProfile
    $('.tab-pid_tuning select[name="rate_profile"]').val self.currentRateProfile
    return

TABS.pid_tuning.setDirty = (isDirty) ->
    self = this
    self.dirty = isDirty
    $('.tab-pid_tuning select[name="profile"]').prop 'disabled', isDirty
    if semver.gte(CONFIG.apiVersion, '1.20.0')
        $('.tab-pid_tuning select[name="rate_profile"]').prop 'disabled', isDirty
    return

TABS.pid_tuning.checkUpdateProfile = (updateRateProfile) ->
    self = this
    if GUI.active_tab == 'pid_tuning'
        if !self.updating and !self.dirty
            changedProfile = false
            if self.currentProfile != CONFIG.profile
                self.setProfile()
                changedProfile = true
            changedRateProfile = false
            if semver.gte(CONFIG.apiVersion, '1.20.0') and updateRateProfile and self.currentRateProfile != CONFIG.rateProfile
                self.setRateProfile()
                changedRateProfile = true
            if changedProfile or changedRateProfile
                self.refresh ->
                    if changedProfile
                        GUI.log i18n.getMessage('pidTuningReceivedProfile', [ CONFIG.profile + 1 ])
                        CONFIG.profile = self.currentProfile
                    if changedRateProfile
                        GUI.log i18n.getMessage('pidTuningReceivedRateProfile', [ CONFIG.rateProfile + 1 ])
                        CONFIG.rateProfile = self.currentRateProfile
                    return
    return

TABS.pid_tuning.checkRC = ->
    # Function monitors for change in the primary axes rc received data and returns true if a change is detected.
    if !@oldRC
        @oldRC = [
            RC.channels[0]
            RC.channels[1]
            RC.channels[2]
        ]
    # Monitor RC.channels and detect change of value;
    rateCurveUpdateRequired = false
    i = 0
    while i < @oldRC.length
        # has the value changed ?
        if @oldRC[i] != RC.channels[i]
            @oldRC[i] = RC.channels[i]
            rateCurveUpdateRequired = true
            # yes, then an update of the values displayed on the rate curve graph is required
        i++
    rateCurveUpdateRequired

TABS.pid_tuning.updatePidControllerParameters = ->
    if semver.gte(CONFIG.apiVersion, '1.20.0') and semver.lt(CONFIG.apiVersion, '1.31.0') and $('.tab-pid_tuning select[name="controller"]').val() == '0'
        $('.pid_tuning .YAW_JUMP_PREVENTION').show()
        $('#pid-tuning .delta').show()
        $('#pid-tuning .dtermSetpointTransition').hide()
        $('#pid-tuning .dtermSetpoint').hide()
    else
        $('.pid_tuning .YAW_JUMP_PREVENTION').hide()
        if semver.gte(CONFIG.apiVersion, '1.40.0')
            $('#pid-tuning .dtermSetpointTransition').hide()
            $('#pid-tuning .dtermSetpoint').hide()
        else
            $('#pid-tuning .dtermSetpointTransition').show()
            $('#pid-tuning .dtermSetpoint').show()
        $('#pid-tuning .delta').hide()
    return

TABS.pid_tuning.updateRatesLabels = ->
    self = this
    if !self.rateCurve.useLegacyCurve and self.rateCurve.maxAngularVel

        drawAxisLabel = (context, axisLabel, x, y, align, color) ->
            context.fillStyle = color or '#000000'
            context.textAlign = align or 'center'
            context.fillText axisLabel, x, y
            return

        drawBalloonLabel = (context, axisLabel, x, y, align, colors, dirty) ->

            ###*
            # curveContext is the canvas to draw on
            # axisLabel is the string to display in the center of the balloon
            # x, y are the coordinates of the point of the balloon
            # align is whether the balloon appears to the left (align 'right') or right (align left) of the x,y coordinates
            # colors is an object defining color, border and text are the fill color, border color and text color of the balloon
            ###

            DEFAULT_OFFSET = 125
            # in canvas scale; this is the horizontal length of the pointer
            DEFAULT_RADIUS = 10
            # in canvas scale, this is the radius around the balloon
            DEFAULT_MARGIN = 5
            # in canvas scale, this is the margin around the balloon when it overlaps
            fontSize = parseInt(context.font)
            # calculate the width and height required for the balloon
            width = context.measureText(axisLabel).width * 1.2
            height = fontSize * 1.5
            # the balloon is bigger than the text height
            pointerY = y
            # always point to the required Y
            # coordinate, even if we move the balloon itself to keep it on the canvas
            # setup balloon background
            context.fillStyle = colors.color or '#ffffff'
            context.strokeStyle = colors.border or '#000000'
            # correct x position to account for window scaling
            x *= context.canvas.clientWidth / context.canvas.clientHeight
            # adjust the coordinates for determine where the balloon background should be drawn
            x += (if align == 'right' then -(width + DEFAULT_OFFSET) else 0) + (if align == 'left' then DEFAULT_OFFSET else 0)
            y -= height / 2
            if y < 0
                y = 0
            else if y > context.height
                y = context.height
            # prevent balloon from going out of canvas
            # check that the balloon does not already overlap
            i = 0
            while i < dirty.length
                if x >= dirty[i].left and x <= dirty[i].right or x + width >= dirty[i].left and x + width <= dirty[i].right
                    # does it overlap horizontally
                    if y >= dirty[i].top and y <= dirty[i].bottom or y + height >= dirty[i].top and y + height <= dirty[i].bottom
                        # this overlaps another balloon
                        # snap above or snap below
                        if y <= (dirty[i].bottom - (dirty[i].top)) / 2 and dirty[i].top - height > 0
                            y = dirty[i].top - height
                        else
                            # snap down
                            y = dirty[i].bottom
                i++
            # Add the draw area to the dirty array
            dirty.push
                left: x
                right: x + width
                top: y - DEFAULT_MARGIN
                bottom: y + height + DEFAULT_MARGIN
            pointerLength = (height - (2 * DEFAULT_RADIUS)) / 6
            context.beginPath()
            context.moveTo x + DEFAULT_RADIUS, y
            context.lineTo x + width - DEFAULT_RADIUS, y
            context.quadraticCurveTo x + width, y, x + width, y + DEFAULT_RADIUS
            if align == 'right'
                # point is to the right
                context.lineTo x + width, y + DEFAULT_RADIUS + pointerLength
                context.lineTo x + width + DEFAULT_OFFSET, pointerY
                # point
                context.lineTo x + width, y + height - DEFAULT_RADIUS - pointerLength
            context.lineTo x + width, y + height - DEFAULT_RADIUS
            context.quadraticCurveTo x + width, y + height, x + width - DEFAULT_RADIUS, y + height
            context.lineTo x + DEFAULT_RADIUS, y + height
            context.quadraticCurveTo x, y + height, x, y + height - DEFAULT_RADIUS
            if align == 'left'
                # point is to the left
                context.lineTo x, y + height - DEFAULT_RADIUS - pointerLength
                context.lineTo x - DEFAULT_OFFSET, pointerY
                # point
                context.lineTo x, y + DEFAULT_RADIUS - pointerLength
            context.lineTo x, y + DEFAULT_RADIUS
            context.quadraticCurveTo x, y, x + DEFAULT_RADIUS, y
            context.closePath()
            # fill in the balloon background
            context.fill()
            context.stroke()
            # and add the label
            drawAxisLabel context, axisLabel, x + width / 2, y + (height + fontSize) / 2 - 4, 'center', colors.text
            return

        BALLOON_COLORS = 
            roll:
                color: 'rgba(255,128,128,0.4)'
                border: 'rgba(255,128,128,0.6)'
                text: '#000000'
            pitch:
                color: 'rgba(128,255,128,0.4)'
                border: 'rgba(128,255,128,0.6)'
                text: '#000000'
            yaw:
                color: 'rgba(128,128,255,0.4)'
                border: 'rgba(128,128,255,0.6)'
                text: '#000000'
        rcStickElement = $('.rate_curve canvas#rate_curve_layer1').get(0)
        if rcStickElement
            rcStickElement.width = 1000
            rcStickElement.height = 1000
            stickContext = rcStickElement.getContext('2d')
            stickContext.save()
            maxAngularVelRoll = self.maxAngularVelRollElement.text() + ' deg/s'
            maxAngularVelPitch = self.maxAngularVelPitchElement.text() + ' deg/s'
            maxAngularVelYaw = self.maxAngularVelYawElement.text() + ' deg/s'
            currentValues = []
            balloonsDirty = []
            curveHeight = rcStickElement.height
            curveWidth = rcStickElement.width
            maxAngularVel = self.rateCurve.maxAngularVel
            windowScale = 400 / stickContext.canvas.clientHeight
            rateScale = curveHeight / 2 / maxAngularVel
            lineScale = stickContext.canvas.width / stickContext.canvas.clientWidth
            textScale = stickContext.canvas.clientHeight / stickContext.canvas.clientWidth
            stickContext.clearRect 0, 0, curveWidth, curveHeight
            # calculate the fontSize based upon window scaling
            if windowScale <= 1
                stickContext.font = '24pt Verdana, Arial, sans-serif'
            else
                stickContext.font = 24 * windowScale + 'pt Verdana, Arial, sans-serif'
            if RC.channels[0] and RC.channels[1] and RC.channels[2]
                currentValues.push self.rateCurve.drawStickPosition(RC.channels[0], self.currentRates.roll_rate, self.currentRates.rc_rate, self.currentRates.rc_expo, self.currentRates.superexpo, self.currentRates.deadband, self.currentRates.roll_rate_limit, maxAngularVel, stickContext, '#FF8080') + ' deg/s'
                currentValues.push self.rateCurve.drawStickPosition(RC.channels[1], self.currentRates.pitch_rate, self.currentRates.rc_rate_pitch, self.currentRates.rc_pitch_expo, self.currentRates.superexpo, self.currentRates.deadband, self.currentRates.pitch_rate_limit, maxAngularVel, stickContext, '#80FF80') + ' deg/s'
                currentValues.push self.rateCurve.drawStickPosition(RC.channels[2], self.currentRates.yaw_rate, self.currentRates.rc_rate_yaw, self.currentRates.rc_yaw_expo, self.currentRates.superexpo, self.currentRates.yawDeadband, self.currentRates.yaw_rate_limit, maxAngularVel, stickContext, '#8080FF') + ' deg/s'
            else
                currentValues = []
            stickContext.lineWidth = lineScale
            # use a custom scale so that the text does not appear stretched
            stickContext.scale textScale, 1
            # add the maximum range label
            drawAxisLabel stickContext, maxAngularVel.toFixed(0) + ' deg/s', (curveWidth / 2 - 10) / textScale, parseInt(stickContext.font) * 1.2, 'right'
            # and then the balloon labels.
            balloonsDirty = []
            # reset the dirty balloon draw area (for overlap detection)
            # create an array of balloons to draw
            balloons = [
                {
                    value: parseInt(maxAngularVelRoll)
                    balloon: ->
                        drawBalloonLabel stickContext, maxAngularVelRoll, curveWidth, rateScale * (maxAngularVel - parseInt(maxAngularVelRoll)), 'right', BALLOON_COLORS.roll, balloonsDirty
                        return

                }
                {
                    value: parseInt(maxAngularVelPitch)
                    balloon: ->
                        drawBalloonLabel stickContext, maxAngularVelPitch, curveWidth, rateScale * (maxAngularVel - parseInt(maxAngularVelPitch)), 'right', BALLOON_COLORS.pitch, balloonsDirty
                        return

                }
                {
                    value: parseInt(maxAngularVelYaw)
                    balloon: ->
                        drawBalloonLabel stickContext, maxAngularVelYaw, curveWidth, rateScale * (maxAngularVel - parseInt(maxAngularVelYaw)), 'right', BALLOON_COLORS.yaw, balloonsDirty
                        return

                }
            ]
            # and sort them in descending order so the largest value is at the top always
            balloons.sort (a, b) ->
                b.value - (a.value)
            # add the current rc values
            if currentValues[0] and currentValues[1] and currentValues[2]
                balloons.push {
                    value: parseInt(currentValues[0])
                    balloon: ->
                        drawBalloonLabel stickContext, currentValues[0], 10, 150, 'none', BALLOON_COLORS.roll, balloonsDirty
                        return

                }, {
                    value: parseInt(currentValues[1])
                    balloon: ->
                        drawBalloonLabel stickContext, currentValues[1], 10, 250, 'none', BALLOON_COLORS.pitch, balloonsDirty
                        return

                },
                    value: parseInt(currentValues[2])
                    balloon: ->
                        drawBalloonLabel stickContext, currentValues[2], 10, 350, 'none', BALLOON_COLORS.yaw, balloonsDirty
                        return
            # then display them on the chart
            i = 0
            while i < balloons.length
                balloons[i].balloon()
                i++
            stickContext.restore()
    return

TABS.pid_tuning.updateFilterWarning = ->
    gyroDynamicLowpassEnabled = undefined
    gyroLowpass1Enabled = $('input[id="gyroLowpassEnabled"]').is(':checked')
    dtermDynamicLowpassEnabled = $('input[id="dtermLowpassDynEnabled"]').is(':checked')
    dtermLowpass1Enabled = $('input[id="dtermLowpassEnabled"]').is(':checked')
    warning_e = $('#pid-tuning .filterWarning')
    warningDynamicNotch_e = $('#pid-tuning .dynamicNotchWarning')
    if !(gyroDynamicLowpassEnabled or gyroLowpass1Enabled) or !(dtermDynamicLowpassEnabled or dtermLowpass1Enabled)
        warning_e.show()
    else
        warning_e.hide()
    if semver.gte(CONFIG.apiVersion, '1.42.0')
        if FEATURE_CONFIG.features.isEnabled('DYNAMIC_FILTER')
            warningDynamicNotch_e.hide()
        else
            warningDynamicNotch_e.show()
    else
        warningDynamicNotch_e.hide()
    return

