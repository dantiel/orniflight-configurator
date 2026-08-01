formaDoBaterDasAsas = (anguloDoCiclo, fBater, fRetorno, limiarShared) ->
    `var theta`
    if fBater >= 7.999 and fRetorno >= 7.999
        theta = anguloDoCiclo % TWO_PI
        if theta < 0
            theta += TWO_PI
        limiarFP = if limiarShared != null then limiarShared else PI
        return if theta < limiarFP then 1.0 else -1.0
    theta = anguloDoCiclo % TWO_PI
    if theta < 0
        theta += TWO_PI
    fD = Math.max(0, Math.min(8, fBater))
    fS = Math.max(0, Math.min(8, fRetorno))
    limiar = if limiarShared != null then limiarShared else TWO_PI * 0.5
    descida = theta < limiar
    t = if descida then theta / limiar else (theta - limiar) / (TWO_PI - limiar)
    ferocidade = if descida then fD else fS
    d = ferocidade / 8.0
    dh = d * 0.5
    if d >= 1.0
        return if descida then 1.0 else -1.0
    if t < dh
        return if descida then 1.0 else -1.0
    if t > 1.0 - dh
        return if descida then -1.0 else 1.0
    ramp = Math.cos(PI * (t - dh) / (1.0 - d))
    if descida then ramp else -ramp

'use strict'
# OrniFlight — mixer list: only MIXER_SERVO_ORNITHOPTER (27) is supported.
# Sparse array keyed by firmware mixer enum value.
mixerList = []
mixerList[27] =
    name: 'Ornithopter'
    model: 'custom'
    image: 'ornithopter'
# =========================================================================
#  Waveform Engine — ported from Gralha Azul (trapezoidal flapping model)
# =========================================================================
TWO_PI = 2 * Math.PI
PI = Math.PI
# =========================================================================
#  3D Ornithopter Model — procedural, wing-pair count adapts to servo count.
#  Dual-mode: live servo PWM data from FC overrides internal waveform.
#  Waveform plotter shows actual wing angles per servo.
# =========================================================================

Model = (wrapper, canvas, waveCanvas) ->
    useWebGLRenderer = @canUseWebGLRenderer()
    @wrapper = wrapper
    @canvas = canvas
    @waveCanvas = if waveCanvas and waveCanvas.length then waveCanvas[0] else waveCanvas or null
    @waveCtx = if @waveCanvas then @waveCanvas.getContext('2d') else null
    @animationFrame = null
    @lastFlapTime = 0
    @flapAngle = 0
    @waveHistory = []
    @WAVE_LEN = 200
    # Servo data from flight controller (live PWM values)
    @servoData = null
    # array of PWM values (int16, 1000-2000)
    @servoTimestamp = 0
    # performance.now() when last received
    @SERVO_TIMEOUT = 150
    # ms — fall back to waveform if no fresh data
    # Flap state
    @flapParams =
        throttle: 1280
        yaw: 1500
        frequency: 6.0
        amplitude: 30.0
        ferocityDown: 4.0
        ferocityUp: 4.0
        phaseShifts: [
            0
            0
            0
            0
        ]
        mountAngles: [
            0
            0
            0
            0
        ]
        servoCount: 4
    # Per-servo angle history for waveform plotter
    @servoAngles = []
    if useWebGLRenderer
        @renderer = new (THREE.WebGLRenderer)(
            canvas: @canvas[0]
            alpha: true
            antialias: true)
    else
        @renderer = new (THREE.CanvasRenderer)(
            canvas: @canvas[0]
            alpha: true)
    @renderer.setSize @wrapper.width() * 2, @wrapper.height() * 2
    # Scene
    @scene = new (THREE.Scene)
    @modelWrapper = new (THREE.Object3D)
    @camera = new (THREE.PerspectiveCamera)(60, @wrapper.width() / @wrapper.height(), 1, 10000)
    @camera.position.z = 125
    ambient = new (THREE.AmbientLight)(0x404040)
    directional = new (THREE.DirectionalLight)(new (THREE.Color)(1, 1, 1), 1.5)
    directional.position.set 0, 1, 0
    @scene.add ambient
    @scene.add directional
    @scene.add @camera
    @scene.add @modelWrapper
    # Materials
    @_matFuselage = new (THREE.MeshPhongMaterial)(
        color: 0x2a3040
        specular: 0x111111
        shininess: 10)
    @_matWing = new (THREE.MeshPhongMaterial)(
        color: 0xf0c060
        specular: 0x111111
        shininess: 5
        transparent: true
        opacity: 0.75
        side: THREE.DoubleSide)
    @_matPivot = new (THREE.MeshPhongMaterial)(
        color: 0x5865f2
        specular: 0x111111
        shininess: 20)
    @_matHead = new (THREE.MeshPhongMaterial)(
        color: 0x3a4a5a
        specular: 0x111111
        shininess: 10)
    @_matTail = new (THREE.MeshPhongMaterial)(
        color: 0x2a3040
        specular: 0x111111
        shininess: 5
        side: THREE.DoubleSide)
    # Per-pair Z-positions along fuselage
    @_pairZPositions =
        1: [ 0 ]
        2: [
            -10
            12
        ]
        3: [
            -16
            0
            16
        ]
        4: [
            -18
            -6
            6
            18
        ]
    # Detect mixer — default to Ornithopter (27) when no FC connected
    mixer = if typeof MIXER_CONFIG != 'undefined' and MIXER_CONFIG.mixer then MIXER_CONFIG.mixer else 27
    # Derive wing-pair count from SERVO_CONFIG when available, else default 2
    pairCount = 2
    if typeof SERVO_CONFIG != 'undefined' and SERVO_CONFIG.length
        pairCount = Math.max(1, Math.min(4, Math.floor(SERVO_CONFIG.length / 2)))
    if mixer == 27
        @buildOrnithopter pairCount
        @startAnimation()
    else
        model_file = if useWebGLRenderer then (mixerList[mixer] or model: 'custom').model else 'fallback'
        if model_file == 'custom'
            model_file = 'fallback'
        @loadJSON model_file, ((model) ->
            @model = model
            @modelWrapper.add model
            @scene.add @modelWrapper
            @render()
            return
        ).bind(this)
    return

# ---- Legacy model loading ----

Model::loadJSON = (model_file, callback) ->
    loader = new (THREE.JSONLoader)
    loader.load './resources/models/' + model_file + '.json', (geometry, materials) ->
        modelMaterial = new (THREE.MeshFaceMaterial)(materials)
        model = new (THREE.Mesh)(geometry, modelMaterial)
        model.scale.set 15, 15, 15
        callback model
        return
    return

# ---- Build fuselage + tail ----

Model::_buildFixedBody = ->
    fuselageGeo = new (THREE.BoxGeometry)(8, 10, 55)
    fuselage = new (THREE.Mesh)(fuselageGeo, @_matFuselage)
    fuselage.position.set 0, 0, 0
    fuselage.name = 'fuselage'
    @modelWrapper.add fuselage
    headGeo = new (THREE.CylinderGeometry)(0, 4.5, 12, 8)
    head = new (THREE.Mesh)(headGeo, @_matHead)
    head.position.set 0, 2, 30
    head.rotation.x = -PI / 2
    head.name = 'head'
    @modelWrapper.add head
    tailGeo = new (THREE.BoxGeometry)(14, 0.8, 8)
    tail = new (THREE.Mesh)(tailGeo, @_matTail)
    tail.position.set 0, 1, -25
    tail.name = 'tail'
    @modelWrapper.add tail
    finGeo = new (THREE.BoxGeometry)(0.8, 8, 8)
    fin = new (THREE.Mesh)(finGeo, @_matTail)
    fin.position.set 0, 4, -25
    fin.name = 'fin'
    @modelWrapper.add fin
    return

# ---- Procedural Ornithopter Builder ----

Model::buildOrnithopter = (pairCount) ->
    pairCount = Math.max(1, Math.min(4, pairCount or 2))
    if @wingPivots
        pp = 0
        while pp < @wingPivots.length
            old = @wingPivots[pp]
            if old.leftPivot
                @modelWrapper.remove old.leftPivot
            if old.rightPivot
                @modelWrapper.remove old.rightPivot
            pp++
    while @modelWrapper.children.length > 0
        @modelWrapper.remove @modelWrapper.children[0]
    @_buildFixedBody()
    @wingPivots = []
    wingGeo = new (THREE.BoxGeometry)(65, 0.8, 12)
    zPositions = @_pairZPositions[pairCount] or @_pairZPositions[2]
    p = 0
    while p < pairCount
        z = zPositions[p]
        wingPair = 
            leftPivot: null
            rightPivot: null
        leftPivot = new (THREE.Object3D)
        leftPivot.position.set -4.5, 1, z
        leftPivot.name = 'wingPair' + p + '_left'
        @modelWrapper.add leftPivot
        leftWing = new (THREE.Mesh)(wingGeo, @_matWing)
        leftWing.position.set -32.5, 0, 0
        leftPivot.add leftWing
        wingPair.leftPivot = leftPivot
        rightPivot = new (THREE.Object3D)
        rightPivot.position.set 4.5, 1, z
        rightPivot.name = 'wingPair' + p + '_right'
        @modelWrapper.add rightPivot
        rightWing = new (THREE.Mesh)(wingGeo, @_matWing)
        rightWing.position.set 32.5, 0, 0
        rightPivot.add rightWing
        wingPair.rightPivot = rightPivot
        sphereGeo = new (THREE.SphereGeometry)(2, 8, 8)
        sphereL = new (THREE.Mesh)(sphereGeo, @_matPivot)
        sphereL.position.copy leftPivot.position
        @modelWrapper.add sphereL
        sphereR = new (THREE.Mesh)(sphereGeo, @_matPivot)
        sphereR.position.copy rightPivot.position
        @modelWrapper.add sphereR
        @wingPivots.push wingPair
        p++
    @flapParams.servoCount = pairCount * 2
    @servoAngles = []
    s = 0
    while s < pairCount * 2
        @servoAngles.push 0
        s++
    @render()
    return

# ---- Servo position override (from MSP_SERVO live data) ----
# pwmArray: array of PWM values from FC servo[] (1000-2000 range, 1500=neutral)

Model::setServoPositions = (pwmArray) ->
    if !pwmArray or !pwmArray.length
        return
    @servoData = pwmArray.slice(0, 8)
    @servoTimestamp = performance.now()
    return

# ---- Animation Loop (dual-mode: servo data or waveform) ----

Model::startAnimation = ->
    self = this

    animLoop = (timestamp) ->
        `var p`
        `var mountAngle`
        self.animationFrame = requestAnimationFrame(animLoop)
        if !self.flapParams
            return
        dt = if self.lastFlapTime then (timestamp - (self.lastFlapTime)) * 0.001 else 0.016
        if dt <= 0
            dt = 0.001
        if dt > 0.1
            dt = 0.1
        self.lastFlapTime = timestamp
        # Advance waveform clock (always, for fallback + plotter reference)
        freq = self.flapParams.frequency or 6.0
        self.flapAngle += freq * TWO_PI * dt
        if self.flapAngle > TWO_PI * 10
            self.flapAngle %= TWO_PI
        pairCount = if self.wingPivots then self.wingPivots.length else 0
        servoCount = pairCount * 2
        # ---- MODE: Live servo data (fresh) ----
        useServoData = self.servoData and self.servoTimestamp and performance.now() - (self.servoTimestamp) < self.SERVO_TIMEOUT
        if useServoData
            # Map PWM→angle: (pwm - 1500) / 500 * 45°
            # 1500 = neutral (0°), 1000→-45°, 2000→+45°
            PWM_NEUTRAL = 1500
            PWM_RANGE = 500
            MAX_ANGLE_DEG = 45
            p = 0
            while p < pairCount
                siL = p * 2
                siR = p * 2 + 1
                pwmL = if siL < self.servoData.length then self.servoData[siL] else PWM_NEUTRAL
                pwmL_clamped = Math.max(1000, Math.min(2000, pwmL or PWM_NEUTRAL))
                angleL = (pwmL_clamped - PWM_NEUTRAL) / PWM_RANGE * MAX_ANGLE_DEG
                pwmR = if siR < self.servoData.length then self.servoData[siR] else PWM_NEUTRAL
                pwmR_clamped = Math.max(1000, Math.min(2000, pwmR or PWM_NEUTRAL))
                angleR = (pwmR_clamped - PWM_NEUTRAL) / PWM_RANGE * MAX_ANGLE_DEG
                # Mount angle offset from ADVANCED_TUNING
                mountAngle = self.flapParams.mountAngles[p] or 0
                self.wingPivots[p].leftPivot.rotation.z = (mountAngle + angleL) * PI / 180
                self.wingPivots[p].rightPivot.rotation.z = (mountAngle + angleR) * PI / 180
                self.servoAngles[siL] = mountAngle + angleL
                self.servoAngles[siR] = mountAngle + angleR
                p++
        else
            # ---- MODE: Internal waveform (fallback) ----
            throttle = self.flapParams.throttle or 1280
            yaw = self.flapParams.yaw or 1500
            amplitude = self.flapParams.amplitude or 30.0
            fD = self.flapParams.ferocityDown or 4.0
            fU = self.flapParams.ferocityUp or 4.0
            throttleFactor = Math.max(0, Math.min(1, (throttle - 1040) / 960))
            ampDeg = amplitude * throttleFactor
            yawDiff = (yaw - 1500) / 500
            leftAmp = Math.max(0, Math.min(55, ampDeg * (1.0 - (yawDiff * 0.5))))
            rightAmp = Math.max(0, Math.min(55, ampDeg * (1.0 + yawDiff * 0.5)))
            p = 0
            while p < pairCount
                phaseShift = (self.flapParams.phaseShifts[p] or 0) * PI / 180
                mountAngle = (self.flapParams.mountAngles[p] or 0) * PI / 180
                phase = self.flapAngle + phaseShift
                waveVal = formaDoBaterDasAsas(phase, fD, fU, null)
                leftAngle = mountAngle + waveVal * leftAmp * PI / 180
                rightAngle = mountAngle - (waveVal * rightAmp * PI / 180)
                self.wingPivots[p].leftPivot.rotation.z = leftAngle
                self.wingPivots[p].rightPivot.rotation.z = rightAngle
                si = p * 2
                self.servoAngles[si] = leftAngle * 180 / PI
                self.servoAngles[si + 1] = rightAngle * 180 / PI
                p++
        self.render()
        self.drawWavePlotter()
        return

    @animationFrame = requestAnimationFrame(animLoop)
    return

# ---- Wave Plotter: one curve per servo, live or simulated ----

Model::drawWavePlotter = ->
    `var s`
    `var j`
    `var xx`
    `var yy`
    if !@waveCtx or !@waveCanvas
        return
    servoCount = if @servoAngles then @servoAngles.length else 4
    cosVal = Math.cos(@flapAngle)
    useServo = @servoData and @servoTimestamp and performance.now() - (@servoTimestamp) < @SERVO_TIMEOUT
    # Push history
    entry = 
        sin: cosVal
        live: useServo
    s = 0
    while s < servoCount
        entry['s' + s] = @servoAngles[s] or 0
        s++
    @waveHistory.push entry
    if @waveHistory.length > @WAVE_LEN
        @waveHistory.shift()
    ctx = @waveCtx
    W = @waveCanvas.width
    H = @waveCanvas.height
    ctx.clearRect 0, 0, W, H
    margin = 
        top: 8
        right: 10
        bottom: 14
        left: 10
    pw = W - (margin.left) - (margin.right)
    ph = H - (margin.top) - (margin.bottom)
    midY = margin.top + ph / 2
    AMP_REF = 55
    ampY = ph / 2
    # Grid
    ctx.strokeStyle = 'rgba(48,54,61,0.6)'
    ctx.lineWidth = 0.5
    i = 0
    while i <= 4
        y = margin.top + ph * i / 4
        ctx.beginPath()
        ctx.moveTo margin.left, y
        ctx.lineTo W - (margin.right), y
        ctx.stroke()
        i++
    ctx.strokeStyle = '#30363d'
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo margin.left, midY
    ctx.lineTo W - (margin.right), midY
    ctx.stroke()
    n = @waveHistory.length
    if n < 2
        return
    xScale = pw / (n - 1)
    # cos(θ) reference — dim blue
    ctx.strokeStyle = '#58a6ff'
    ctx.lineWidth = 1.2
    ctx.globalAlpha = 0.3
    ctx.beginPath()
    j = 0
    while j < n
        xx = margin.left + j * xScale
        yy = midY - (@waveHistory[j].sin * ampY)
        if j == 0
            ctx.moveTo xx, yy
        else
            ctx.lineTo xx, yy
        j++
    ctx.stroke()
    ctx.globalAlpha = 1
    # Mode indicator
    ctx.fillStyle = if useServo then '#3fb950' else '#f0c060'
    ctx.font = '8px monospace'
    ctx.fillText (if useServo then 'LIVE' else 'SIM'), margin.left, margin.top + 8
    # Per-servo curves
    servoColors = [
        '#3fb950'
        '#f3f'
        '#00d4ff'
        '#f0c060'
        '#58a6ff'
        '#ff7b72'
        '#d2a8ff'
        '#ffa657'
    ]
    pairLabels = [
        'F'
        '2'
        '3'
        '4'
    ]
    s = 0
    while s < servoCount
        color = servoColors[s % servoColors.length]
        isLeft = s % 2 == 0
        pairIdx = Math.floor(s / 2)
        ctx.strokeStyle = color
        ctx.lineWidth = if isLeft then 1.2 else 0.9
        ctx.globalAlpha = 0.85
        ctx.setLineDash if isLeft then [] else [
            3
            2
        ]
        ctx.beginPath()
        key = 's' + s
        j = 0
        while j < n
            xx = margin.left + j * xScale
            val = @waveHistory[j][key] or 0
            yy = midY - (val / AMP_REF * ampY)
            if j == 0
                ctx.moveTo xx, yy
            else
                ctx.lineTo xx, yy
            j++
        ctx.stroke()
        ctx.globalAlpha = 1
        ctx.setLineDash []
        # Label
        lastVal = @waveHistory[n - 1][key] or 0
        labelY = midY - (lastVal / AMP_REF * ampY)
        ctx.fillStyle = color
        ctx.font = '9px monospace'
        ctx.fillText pairLabels[pairIdx] + (if isLeft then 'L' else 'R'), margin.left + pw + 1, labelY + 3
        s++
    return

# ---- Set flap state from external data ----

Model::setFlapState = (params) ->
    `var i`
    if !@flapParams
        return
    if params.throttle != undefined
        @flapParams.throttle = params.throttle
    if params.yaw != undefined
        @flapParams.yaw = params.yaw
    if params.frequency != undefined
        @flapParams.frequency = params.frequency
    if params.amplitude != undefined
        @flapParams.amplitude = params.amplitude
    if params.ferocityDown != undefined
        @flapParams.ferocityDown = params.ferocityDown
    if params.ferocityUp != undefined
        @flapParams.ferocityUp = params.ferocityUp
    if params.phaseShifts != undefined
        i = 0
        while i < 4
            @flapParams.phaseShifts[i] = if params.phaseShifts[i] != undefined then params.phaseShifts[i] else 0
            i++
    if params.mountAngles != undefined
        i = 0
        while i < 4
            @flapParams.mountAngles[i] = if params.mountAngles[i] != undefined then params.mountAngles[i] else 0
            i++
    if params.servoCount != undefined and params.servoCount != @flapParams.servoCount
        @flapParams.servoCount = params.servoCount
        @buildOrnithopter Math.max(1, Math.floor(params.servoCount / 2))
    return

# ---- Rotation (stick input / attitude) ----

Model::rotateTo = (x, y, z) ->
    if @wingPivots
        @modelWrapper.rotation.x = x
        @modelWrapper.rotation.y = y
        @modelWrapper.rotation.z = z
    else if @model
        @model.rotation.x = x
        @modelWrapper.rotation.y = y
        @model.rotation.z = z
    if !@animationFrame
        @render()
    return

Model::rotateBy = (x, y, z) ->
    if !@model and !@wingPivots
        return
    if @wingPivots
        @modelWrapper.rotateX x
        @modelWrapper.rotateY y
        @modelWrapper.rotateZ z
    else
        @model.rotateX x
        @model.rotateY y
        @model.rotateZ z
    if !@animationFrame
        @render()
    return

# ---- Render ----

Model::render = ->
    if !@model and !@wingPivots
        return
    @renderer.render @scene, @camera
    return

# ---- Resize ----

Model::resize = ->
    @renderer.setSize @wrapper.width() * 2, @wrapper.height() * 2
    @camera.aspect = @wrapper.width() / @wrapper.height()
    @camera.updateProjectionMatrix()
    @render()
    return

# ---- WebGL detection ----

Model::canUseWebGLRenderer = ->
    detector_canvas = document.createElement('canvas')
    window.WebGLRenderingContext and (detector_canvas.getContext('webgl') or detector_canvas.getContext('experimental-webgl'))

# ---- Cleanup ----

Model::dispose = ->
    if @animationFrame
        cancelAnimationFrame @animationFrame
        @animationFrame = null
    if @renderer
        @renderer.forceContextLoss()
        @renderer.dispose()
    return