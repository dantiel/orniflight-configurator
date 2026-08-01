'use strict'
minRc = 1000
midRc = 1500
maxRc = 2000

RateCurve = (useLegacyCurve) ->
    @useLegacyCurve = useLegacyCurve
    @maxAngularVel = null

    @constrain = (value, min, max) ->
        Math.max min, Math.min(value, max)

    @rcCommand = (rcData, rcRate, deadband) ->
        tmp = Math.min(Math.max(Math.abs(rcData - midRc) - deadband, 0), 500)
        result = tmp * rcRate
        if rcData < midRc
            result = -result
        result

    @drawRateCurve = (rate, rcRate, rcExpo, superExpoActive, deadband, limit, maxAngularVel, context, width, height) ->
        canvasHeightScale = height / (2 * maxAngularVel)
        stepWidth = context.lineWidth
        context.save()
        context.translate width / 2, height / 2
        context.beginPath()
        rcData = minRc
        context.moveTo -500, -canvasHeightScale * @rcCommandRawToDegreesPerSecond(rcData, rate, rcRate, rcExpo, superExpoActive, deadband, limit)
        rcData = rcData + stepWidth
        while rcData <= maxRc
            context.lineTo rcData - midRc, -canvasHeightScale * @rcCommandRawToDegreesPerSecond(rcData, rate, rcRate, rcExpo, superExpoActive, deadband, limit)
            rcData = rcData + stepWidth
        context.stroke()
        context.restore()
        return

    @drawLegacyRateCurve = (rate, rcRate, rcExpo, context, width, height) ->
        # math magic by englishman
        rateY = height * rcRate
        rateY = rateY + 1 / (1 - (rateY / height * rate))
        # draw
        context.beginPath()
        context.moveTo 0, height
        context.quadraticCurveTo width * 11 / 20, height - (rateY / 2 * (1 - rcExpo)), width, height - rateY
        context.stroke()
        return

    @drawStickPosition = (rcData, rate, rcRate, rcExpo, superExpoActive, deadband, limit, maxAngularVel, context, stickColor) ->
        DEFAULT_SIZE = 60
        # canvas units, relative size of the stick indicator (larger value is smaller indicator)
        rateScaling = context.canvas.height / 2 / maxAngularVel
        currentValue = @rcCommandRawToDegreesPerSecond(rcData, rate, rcRate, rcExpo, superExpoActive, deadband, limit)
        if rcData != undefined
            context.save()
            context.fillStyle = stickColor or '#000000'
            context.translate context.canvas.width / 2, context.canvas.height / 2
            context.beginPath()
            context.arc rcData - 1500, -rateScaling * currentValue, context.canvas.height / DEFAULT_SIZE, 0, 2 * Math.PI
            context.fill()
            context.restore()
        if Math.abs(currentValue) < 0.5 then 0 else currentValue.toFixed(0)
        # The calculated value in deg/s is returned from the function call for further processing.

    return

RateCurve::rcCommandRawToDegreesPerSecond = (rcData, rate, rcRate, rcExpo, superExpoActive, deadband, limit) ->
    `var maxRc`
    angleRate = undefined
    if rate != undefined and rcRate != undefined and rcExpo != undefined
        if rcRate > 2
            rcRate = rcRate + (rcRate - 2) * 14.54
        maxRc = 500 * rcRate
        rcCommandf = @rcCommand(rcData, rcRate, deadband) / maxRc
        rcCommandfAbs = Math.abs(rcCommandf)
        expoPower = undefined
        rcRateConstant = undefined
        if semver.gte(CONFIG.apiVersion, '1.20.0')
            expoPower = 3
            rcRateConstant = 200
        else
            expoPower = 2
            rcRateConstant = 205.85
        if rcExpo > 0
            rcCommandf = rcCommandf * rcCommandfAbs ** expoPower * rcExpo + rcCommandf * (1 - rcExpo)
        if superExpoActive
            rcFactor = 1 / @constrain(1 - (rcCommandfAbs * rate), 0.01, 1)
            angleRate = rcRateConstant * rcRate * rcCommandf
            # 200 should be variable checked on version (older versions it's 205,9)
            angleRate = angleRate * rcFactor
        else
            angleRate = (rate * 100 + 27) * rcCommandf / 16 / 4.1
            # Only applies to old versions ?
        angleRate = @constrain(angleRate, -1 * limit, limit)
        # Rate limit from profile
    angleRate

RateCurve::getMaxAngularVel = (rate, rcRate, rcExpo, superExpoActive, deadband, limit) ->
    maxAngularVel = undefined
    if !@useLegacyCurve
        maxAngularVel = @rcCommandRawToDegreesPerSecond(maxRc, rate, rcRate, rcExpo, superExpoActive, deadband, limit)
    maxAngularVel

RateCurve::setMaxAngularVel = (value) ->
    @maxAngularVel = Math.ceil(value / 200) * 200
    @maxAngularVel

RateCurve::draw = (rate, rcRate, rcExpo, superExpoActive, deadband, limit, maxAngularVel, context) ->
    if rate != undefined and rcRate != undefined and rcExpo != undefined
        height = context.canvas.height
        width = context.canvas.width
        if @useLegacyCurve
            @drawLegacyRateCurve rate, rcRate, rcExpo, context, width, height
        else
            @drawRateCurve rate, rcRate, rcExpo, superExpoActive, deadband, limit, maxAngularVel, context, width, height
    return

