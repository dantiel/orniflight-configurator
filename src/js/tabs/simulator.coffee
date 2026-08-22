'use strict'

# ╔══════════════════════════════════════════════════════════════╗
# ║  ORNIFLIGHT SIMULATOR — Firmware-exact ONDAS Pipeline      ║
# ║  PID → Modulation → Servo Mixer → Physics → 3D Model       ║
# ║  Left-drag: orbit camera  |  Right-drag: disturb model     ║
# ╚══════════════════════════════════════════════════════════════╝

PI = Math.PI
TWO_PI = 2 * PI
DT = 1.0 / 30.0

TABS.simulator = {}

# ── Servo arrangements: named ornithopter servo layouts. Each defines the
# wing-pair count, CG station (σ·100, + = nose) and per-pair mount geometry
# (θ in deg, distance in σ·100). Replaces a bare pair-count slider.
TABS.simulator.ARRANGEMENTS =
    tandem_x:
        pairs: 2
        cg: 0
        angles: [30, -30, 0, 0]
        dists: [40, -40, 0, 0]
    single:
        pairs: 1
        cg: -20
        angles: [0, 0, 0, 0]
        dists: [0, 0, 0, 0]
    single_canard:
        pairs: 1
        cg: 20
        angles: [0, 0, 0, 0]
        dists: [0, 0, 0, 0]
    tandem_parallel:
        pairs: 2
        cg: 0
        angles: [20, 20, 0, 0]
        dists: [40, -40, 0, 0]
    triple:
        pairs: 3
        cg: 0
        angles: [30, 0, -30, 0]
        dists: [45, 0, -45, 0]
    quad:
        pairs: 4
        cg: 0
        angles: [30, 10, -10, -30]
        dists: [50, 17, -17, -50]
    double_decker:
        pairs: 4
        cg: 0
        angles: [30, 30, -30, -30]
        dists: [40, 40, -40, -40]
        ys: [6, -6, 6, -6]

DEFAULT_ARRANGEMENT = 'tandem_x'
HALF_BODY = 27.5   # half-fuselage model units — σ ∈ [−1,+1] → Z = σ × HALF_BODY

TABS.simulator.initialize = (callback) ->
    self = this
    $('#content').load 'tabs/simulator.html', ->
        self._initUI()
        self._initModel()
        self._initPhysics()
        self._startLoop()
        GUI.content_ready callback

# ═══════════════════════════════════════════════════════════════
#  UI SETUP
# ═══════════════════════════════════════════════════════════════

TABS.simulator._initUI = ->
    self = this
    self._disturbDragging = false
    self._disturbStartX = 0
    self._disturbStartY = 0

    # Slider config map — read all named inputs
    sliderNames = [
        'amp_max', 'freq_max', 'servo_speed', 'disturb_force',
        'cg_position',
        'mount_angle_0', 'mount_angle_1', 'mount_angle_2', 'mount_angle_3',
        'mount_distance_0', 'mount_distance_1', 'mount_distance_2', 'mount_distance_3',
        'aeroelastic_coef', 'glide_aero_coef',
        'cadence_gain', 'ferocity_p_gain', 'ferocity_d_gain', 'balance_gain',
        'warp_gain', 'warp_yaw_gain', 'warp_pitch_gain', 'ferocity_roll_gain', 'ferocity_yaw_gain',
        'ssff', 'anchor_gain', 'attitude_P',
        'stick_fero', 'stick_asym', 'stick_lrdiff', 'stick_fadiff',
        'roll_P', 'roll_I', 'roll_D',
        'pitch_P', 'pitch_I', 'pitch_D',
        'yaw_P', 'yaw_I', 'yaw_D', 'yaw_amp_mix'
    ]

    self._readSliders = ->
        self.cfg = {}
        for s in sliderNames
            el = $("input[name=\"#{s}\"]")
            self.cfg[s] = if el.length then parseFloat(el.val()) else 0
        arrEl = $("select[name='arrangement']")
        self.cfg.arrangement = if arrEl.length then arrEl.val() else DEFAULT_ARRANGEMENT
        self._readWingConfig()

    self._readSliders()

    # Live slider updates
    $('.sim-right input[type="range"]').on 'input', ->
        name = $(this).attr('name')
        self.cfg[name] = parseFloat($(this).val())
        $(".val[data-for='#{name}']").text $(this).val()
        # Sync number input if present
        numEl = $("input[name='#{name}_num']")
        if numEl.length then numEl.val $(this).val()
        # Mount geometry (CG / per-pair angle & distance) → live re-read
        if name == 'cg_position' or name.indexOf('mount_') == 0
            self._readWingConfig()
            # Fore/aft station sliders move the wings live (no full rebuild)
            if name.indexOf('mount_distance_') == 0 and self.model
                n = self._pairCount ? 2
                zPositions = ((self._mountDist[p] ? 0) * HALF_BODY for p in [0...n])
                self.model.setPairStations zPositions

    # Servo arrangement selector → apply named geometry + rebuild model
    $("select[name='arrangement']").on 'change', ->
        self._applyArrangement $(this).val()

    # Number input sync back to slider
    $('.sim-right input.pid-num').on 'input', ->
        numName = $(this).attr('name')
        baseName = numName.replace /_num$/, ''
        val = parseFloat($(this).val()) || 0
        self.cfg[baseName] = val
        $("input[name='#{baseName}']").val val
        $(".val[data-for='#{baseName}']").text val

    # Preset buttons
    $('.preset-btn').on 'click', ->
        preset = $(this).data('preset')
        self._applyPreset(preset)

    # Stick inputs — auto-center on release
    self.stickThrottle = 1500
    self.stickRoll = 1500
    self.stickPitch = 1500
    self.stickYaw = 1500

    centerStick = (el, key) ->
        el.val(1500)
        el.siblings('.stick-val').text('1500')
        self[key] = 1500

    # Throttle does NOT auto-center (stays where set)
    $('.stick-throttle').on 'input', ->
        self.stickThrottle = parseInt($(this).val())
        $(this).siblings('.stick-val').text $(this).val()

    for [sel, key] in [['.stick-roll','stickRoll'], ['.stick-pitch','stickPitch'], ['.stick-yaw','stickYaw']]
        do (sel, key) ->
            el = $(sel)
            el.on 'input', ->
                self[key] = parseInt($(this).val())
                $(this).siblings('.stick-val').text $(this).val()
            el.on 'mouseup touchend', -> centerStick(el, key)
            el.parent().on 'mouseleave', -> centerStick(el, key)

    # Canvas events: LEFT drag = orbit (Model handles), RIGHT drag = disturb
    self._disturbDeltaX = 0
    self._disturbDeltaY = 0

    canvas = $('#canvas_wrapper canvas')
    canvas.on 'mousedown', (e) ->
        return unless e.button == 2  # right button only
        e.preventDefault()
        self._disturbDragging = true
        self._disturbStartX = e.clientX
        self._disturbStartY = e.clientY
        self._disturbDeltaX = 0
        self._disturbDeltaY = 0
        $('#canvas_wrapper').addClass 'disturb-active'

    $(document).on 'mousemove.sim', (e) ->
        return unless self._disturbDragging
        self._disturbDeltaX = e.clientX - self._disturbStartX
        self._disturbDeltaY = e.clientY - self._disturbStartY

    $(document).on 'mouseup.sim', ->
        return unless self._disturbDragging
        self._disturbDragging = false
        self._disturbDeltaX = 0
        self._disturbDeltaY = 0
        $('#canvas_wrapper').removeClass 'disturb-active'

    # Action buttons
    $('.disturb-btn').on 'click', ->
        f = self.cfg.disturb_force
        self.gyroRoll  += (Math.random() - 0.5) * f
        self.gyroPitch += (Math.random() - 0.5) * f
        self.gyroYaw   += (Math.random() - 0.5) * f * 0.7

    $('.reset-btn').on 'click', ->
        self.gyroRoll = self.gyroPitch = self.gyroYaw = 0
        self.attRoll  = self.attPitch  = self.attYaw  = 0
        for ax in ['roll','pitch','yaw']
            self.pidState[ax].Sum = 0
            self.pidState[ax].SumF = 0
            self.pidState[ax].I = 0
            self.pidState[ax].prevErr = 0
        self._slew.freq = 0;    self._slew.freqMod = 1.0
        self._slew.amp = 0;     self._slew.feroBase = 0.5
        self._slew.feroDiffR = 0; self._slew.feroDiffY = 0; self._slew.feroPitchFA = 0
        self._slew.asymBias = 0;  self._slew.phaseYaw = 0;  self._slew.ampYaw = 0
        for i in [0...(self._pairCount ? 2) * 2]
            self._slewFlapCenter[i] = 0

    # View lock checkbox
    self._viewLocked = false
    $('#view_lock_cb').on 'change', ->
        self._viewLocked = $(this).is(':checked')
        if self.model
            self.model.lockView = self._viewLocked

# ═══════════════════════════════════════════════════════════════
#  WING CONFIG — per-pair mount angle + mount distance + CG

TABS.simulator._readWingConfig = ->
    self = this
    arr = self.cfg.arrangement or DEFAULT_ARRANGEMENT
    spec = TABS.simulator.ARRANGEMENTS[arr] or TABS.simulator.ARRANGEMENTS[DEFAULT_ARRANGEMENT]
    self._arrangement = arr
    self._pairCount = spec.pairs
    # Normalized station σ ∈ [−1, +1]: + = nose, − = tail, 0 = centre
    self._cg = (self.cfg.cg_position ? spec.cg) / 100.0
    self._mountAngle = []
    self._mountDist  = []
    self._mountY     = []
    for p in [0...4]
        self._mountAngle[p] = self.cfg['mount_angle_' + p] ? (spec.angles[p] ? 0)
        self._mountDist[p]  = (self.cfg['mount_distance_' + p] ? (spec.dists[p] ? 0)) / 100.0
        self._mountY[p]     = spec.ys?[p] ? 1
    return

# Rebuild 3D geometry + slew arrays when wing-pair count changes.
TABS.simulator._applyWingGeometry = ->
    self = this
    return unless self.model
    n = self._pairCount
    yPositions = (self._mountY[p] ? 1 for p in [0...n])
    zPositions = ((self._mountDist[p] ? 0) * HALF_BODY for p in [0...n])
    self.model.setPairCount(n, yPositions, zPositions)
    self._slewMountL = []
    self._slewMountR = []
    for p in [0...n]
        t = self._mountAngle[p] ? 0
        self._slewMountL[p] = t
        self._slewMountR[p] = -t
    for i in [0...n * 2]
        self._slewFlapCenter[i] = 0
        self._slewFeroDL[i] = 0.5; self._slewFeroUL[i] = 0.5
        self._slewFeroDR[i] = 0.5; self._slewFeroUR[i] = 0.5
    return

# Per-pair pitch rank = fore/aft lever arm (z_eff − CG) normalized by the
# largest |lever|. Direction AND magnitude derive from the actual station,
# NOT pair index — so grouped stations (biplane decks) share a rank and a
# double-decker's two front wings deflect identically. A single pair (n=1)
# has no fore/aft differential → rank 0.
TABS.simulator._pitchGeometry = ->
    self = this
    n = self._pairCount ? 2
    A_LAT = 0.164
    cg = self._cg ? 0
    levers = []
    ranks = []
    if n <= 1
        return { ranks: [0], levers: [0] }
    maxLever = 0
    for p in [0...n]
        th = self._mountAngle[p] ? 0
        d  = self._mountDist[p]  ? 0
        rad = th * PI / 180
        zEff = d - A_LAT * Math.tan(rad)
        lever = zEff - cg
        levers[p] = lever
        maxLever = Math.max(maxLever, Math.abs(lever))
    for p in [0...n]
        ranks[p] = if maxLever < 1e-6 then 0 else levers[p] / maxLever
    { ranks: ranks, levers: levers }

# Apply a named servo arrangement: write its defaults into the mount/CG
# sliders, then re-read wing config and rebuild the 3D model.
TABS.simulator._applyArrangement = (arr) ->
    self = this
    spec = TABS.simulator.ARRANGEMENTS[arr] or TABS.simulator.ARRANGEMENTS[DEFAULT_ARRANGEMENT]
    self.cfg.arrangement = arr
    setSlider = (name, val) ->
        slider = $("input[name='#{name}']")
        if slider.length
            slider.val val
            self.cfg[name] = parseFloat(val)
            $(".val[data-for='#{name}']").text val
    setSlider 'cg_position', spec.cg
    for p in [0...4]
        setSlider 'mount_angle_' + p, spec.angles[p] ? 0
        setSlider 'mount_distance_' + p, spec.dists[p] ? 0
    self._readWingConfig()
    self._applyWingGeometry()
    return

# ═══════════════════════════════════════════════════════════════
#  INIT PARAMS — re-read DOM slider defaults (safe to call anytime)

TABS.simulator._initParams = ->
    this._readSliders()
    return

# ═══════════════════════════════════════════════════════════════
#  PRESETS — apply a named preset configuration

TABS.simulator._applyPreset = (name) ->
    self = this
    presets =
        gentle:
            roll_P: 27;  roll_I: 27; roll_D: 16
            pitch_P: 40; pitch_I: 27; pitch_D: 20
            yaw_P: 20;   yaw_I: 40;  yaw_D: 0
            cadence_gain: 40; ferocity_p_gain: 30; ferocity_d_gain: 50
            balance_gain: 15; warp_gain: 25; warp_yaw_gain: 20; warp_pitch_gain: 35
            ferocity_roll_gain: 30; ferocity_yaw_gain: 25; ssff: 25
            anchor_gain: 15; attitude_P: 2.0
            stick_fero: 8; stick_asym: 10; stick_lrdiff: 5; stick_fadiff: 5
            servo_speed: 40
        sport:
            roll_P: 67;  roll_I: 53; roll_D: 33
            pitch_P: 93; pitch_I: 67; pitch_D: 40
            yaw_P: 53;   yaw_I: 80;  yaw_D: 7
            cadence_gain: 75; ferocity_p_gain: 60; ferocity_d_gain: 90
            balance_gain: 40; warp_gain: 70; warp_yaw_gain: 60; warp_pitch_gain: 80
            ferocity_roll_gain: 75; ferocity_yaw_gain: 65; ssff: 60
            anchor_gain: 8; attitude_P: 3.5
            stick_fero: 15; stick_asym: 25; stick_lrdiff: 15; stick_fadiff: 15
            servo_speed: 80
        acro:
            roll_P: 107;  roll_I: 80; roll_D: 47
            pitch_P: 133; pitch_I: 93; pitch_D: 53
            yaw_P: 80;   yaw_I: 107;  yaw_D: 13
            cadence_gain: 100; ferocity_p_gain: 90; ferocity_d_gain: 100
            balance_gain: 70; warp_gain: 100; warp_yaw_gain: 90; warp_pitch_gain: 100
            ferocity_roll_gain: 100; ferocity_yaw_gain: 100; ssff: 80
            anchor_gain: 4; attitude_P: 4.0
            stick_fero: 25; stick_asym: 40; stick_lrdiff: 25; stick_fadiff: 25
            servo_speed: 150

    p = presets[name]
    return unless p

    # Update DOM sliders and number inputs
    for key, val of p
        slider = $("input[name='#{key}']")
        if slider.length
            slider.val val
            self.cfg[key] = val
            $(".val[data-for='#{key}']").text val
        numEl = $("input[name='#{key}_num']")
        if numEl.length then numEl.val val

    # Reset physics state so new PID takes effect cleanly
    self.gyroRoll = self.gyroPitch = self.gyroYaw = 0
    self.attRoll  = self.attPitch  = self.attYaw  = 0
    for ax in ['roll','pitch','yaw']
        self.pidState[ax].Sum = 0
        self.pidState[ax].SumF = 0
        self.pidState[ax].I = 0
        self.pidState[ax].prevErr = 0
    return

# ═══════════════════════════════════════════════════════════════
#  3D MODEL (uses Model's native waveform canvas)
# ═══════════════════════════════════════════════════════════════

TABS.simulator._initModel = ->
    self = this
    self._slew =
        freq: 0.0;      freqMod: 1.0
        amp: 0.0;       feroBase: 0.5
        feroDiffR: 0.0; feroDiffY: 0.0; feroPitchFA: 0.0
        asymBias: 0.0;  phaseYaw: 0.0;  ampYaw: 0.0

    n = self._pairCount ? 2
    # Per-wing slew arrays sized to pair count
    self._slewFeroDL = []; self._slewFeroDR = []
    self._slewFeroUL = []; self._slewFeroUR = []
    self._slewFlapCenter = []
    self._slewMountL = []; self._slewMountR = []
    for p in [0...n]
        t = self._mountAngle[p] ? 0
        self._slewMountL[p] = t
        self._slewMountR[p] = -t
    for i in [0...n * 2]
        self._slewFlapCenter[i] = 0
        self._slewFeroDL[i] = 0.5; self._slewFeroUL[i] = 0.5
        self._slewFeroDR[i] = 0.5; self._slewFeroUR[i] = 0.5

    wrapper = $('#canvas_wrapper')
    canvas = $('#canvas')
    waveEl = $('#wave_canvas')
    return unless canvas.length

    try
        self.model = new Model(wrapper, canvas, waveEl)
        yPositions = (self._mountY[p] ? 1 for p in [0...n])
        zPositions = ((self._mountDist[p] ? 0) * HALF_BODY for p in [0...n])
        self.model.setPairCount(n, yPositions, zPositions)
        # Initialize flapParams matching Model defaults
        fp = self.model.flapParams
        fp.throttle = 1500
        fp.yaw = 1500
        fp.frequency = 0.0
        fp.amplitude = 45.0
        fp.ferocityDown = 0.5
        fp.ferocityUp = 0.5
        fp.ferocityDownL = [0.5,0.5,0.5,0.5]
        fp.ferocityDownR = [0.5,0.5,0.5,0.5]
        fp.ferocityUpL   = [0.5,0.5,0.5,0.5]
        fp.ferocityUpR   = [0.5,0.5,0.5,0.5]
        fp.phaseShifts   = [0,0,0,0]
        fp.mountAngles   = [0,0,0,0]
        fp.mountAnglesL = [0,0,0,0]
        fp.mountAnglesR = [0,0,0,0]
        fp.aeroelasticCoef = 20.0
        fp.glideAeroCoef = 4.0
        fp.servoCount = n * 2
        self.model.servoAngles = [0,0,0,0,0,0,0,0]
        self.model.startAnimation()
        self._initGyroIndicator()
    catch e
        console.error 'Model init failed:', e
        self.model = null

# ═══════════════════════════════════════════════════════════════
#  GYRO INDICATOR — tiny 3D attitude ball in #gyro-indicator
# ═══════════════════════════════════════════════════════════════

TABS.simulator._initGyroIndicator = ->
    self = this
    gyroDiv = $('#gyro-indicator')
    return unless gyroDiv.length
    gyroCanvas = $('#gyro_canvas')
    return unless gyroCanvas.length

    try
        self._gyroRenderer = new THREE.WebGLRenderer
            canvas: gyroCanvas[0]
            alpha: true
            antialias: true
        self._gyroRenderer.setSize 90, 90
        self._gyroScene = new THREE.Scene

        # Ambient + directional light
        self._gyroScene.add new THREE.AmbientLight 0x404040
        dl = new THREE.DirectionalLight new THREE.Color(1,1,1), 1.2
        dl.position.set 0, 1, 2
        self._gyroScene.add dl

        # Fixed camera looking at origin
        self._gyroCamera = new THREE.PerspectiveCamera 45, 1, 0.1, 100
        self._gyroCamera.position.set 0, 0, 6
        self._gyroCamera.lookAt new THREE.Vector3 0, 0, 0
        self._gyroScene.add self._gyroCamera

        # Indicator object: a flattened cone (arrowhead shape) pointing up (Y+)
        # rotated so it points along Z+ (forward) in model space
        # Body: cone pointing forward
        # Three.js v72: CylinderGeometry(radiusTop, radiusBottom, height, radialSegments, heightSegments)
        coneGeo = new THREE.CylinderGeometry 0, 0.5, 2.5, 6, 8
        coneMat = new THREE.MeshPhongMaterial {color: 0xf0c060, specular: 0x111111, shininess: 20}
        self._gyroCone = new THREE.Mesh coneGeo, coneMat
        # Cone default points up (Y+). Rotate to point Z+ (forward)
        self._gyroCone.rotation.x = -Math.PI / 2
        self._gyroScene.add self._gyroCone

        # Horizon ring (static reference)
        ringGeo = new THREE.TorusGeometry 1.6, 0.08, 8, 32
        ringMat = new THREE.MeshPhongMaterial {color: 0x58a6ff, specular: 0x111111, shininess: 5, transparent: true, opacity: 0.6}
        self._gyroRing = new THREE.Mesh ringGeo, ringMat
        self._gyroScene.add self._gyroRing

        # Cross-hair lines on the ring plane (pitch/roll reference)
        lineMat = new THREE.LineBasicMaterial {color: 0x58a6ff, transparent: true, opacity: 0.4}
        for axis in [0, 1]
            pts = if axis == 0
                [new THREE.Vector3(-1.4,0,0), new THREE.Vector3(1.4,0,0)]
            else
                [new THREE.Vector3(0,0,-1.4), new THREE.Vector3(0,0,1.4)]
            # three.js r72 lacks BufferGeometry.setFromPoints (added in r78).
            # Use the legacy Geometry API instead.
            lineGeo = new THREE.Geometry()
            lineGeo.vertices = pts
            self._gyroScene.add new THREE.Line lineGeo, lineMat

        # Mini wing-flaps (two small flat boxes to indicate L/R)
        wingGeo = new THREE.BoxGeometry 0.8, 0.1, 0.4
        wingMat = new THREE.MeshPhongMaterial {color: 0xf0c060, specular: 0x111111, shininess: 5, transparent: true, opacity: 0.7}
        for side in [-1, 1]
            wing = new THREE.Mesh wingGeo, wingMat
            wing.position.set side * 0.8, 0, 0
            self._gyroCone.add wing

        self._gyroRenderer.render self._gyroScene, self._gyroCamera
    catch e
        console.error 'Gyro indicator init failed:', e
        self._gyroRenderer = null

TABS.simulator._updateGyroIndicator = ->
    self = this
    return unless self._gyroRenderer
    r = self.attRoll  or 0
    p = self.attPitch or 0
    y = self.attYaw   or 0
    # Apply attitude to cone: YXZ order matching modelWrapper
    self._gyroCone.rotation.order = 'YXZ'
    self._gyroCone.rotation.set -p * PI / 180, y * PI / 180, r * PI / 180
    self._gyroRenderer.render self._gyroScene, self._gyroCamera

# ═══════════════════════════════════════════════════════════════
#  PHYSICS STATE
# ═══════════════════════════════════════════════════════════════

TABS.simulator._initPhysics = ->
    self = this
    self.attRoll  = 0; self.attPitch  = 0; self.attYaw  = 0
    self.gyroRoll = 0; self.gyroPitch = 0; self.gyroYaw = 0
    self.pidState =
        roll:  {P:0, I:0, D:0, Sum:0, SumF:0, prevErr:0}
        pitch: {P:0, I:0, D:0, Sum:0, SumF:0, prevErr:0}
        yaw:   {P:0, I:0, D:0, Sum:0, SumF:0, prevErr:0}
    self.theta = 0.0
    self.telemetryEl = $('#sim-telemetry')

# ═══════════════════════════════════════════════════════════════
#  MAIN LOOP — 30 Hz
# ═══════════════════════════════════════════════════════════════

TABS.simulator._startLoop = ->
    self = this

    self._tick = ->
        self._readSticks()
        self._applyDisturbDrag()
        self._runPID()
        self._ondasModulation()
        self._computeTargets()
        self._applyServoSpeedLimit()
        self._updateModel()
        self._physicsStep()
        self._updateTelemetry()

    self._loopInterval = setInterval (-> self._tick()), DT * 1000

# ═══════════════════════════════════════════════════════════════

TABS.simulator._applyDisturbDrag = ->
    self = this
    return unless self._disturbDragging
    f = self.cfg.disturb_force * 0.05

# Transform screen drag to model-relative world-space via camera vectors
    cam = self.model?.camera
    if cam
        # Camera look direction (to origin)
        lookDir = cam.position.clone().normalize().negate()
        worldUp = new THREE.Vector3 0, 1, 0
        camRight = new THREE.Vector3().crossVectors(worldUp, lookDir).normalize()
        camUp = new THREE.Vector3().crossVectors(lookDir, camRight).normalize()

        # Project screen drag onto world-space directions
        wx = camRight.x * self._disturbDeltaX + camUp.x * self._disturbDeltaY
        wy = camRight.y * self._disturbDeltaX + camUp.y * self._disturbDeltaY
        wz = camRight.z * self._disturbDeltaX + camUp.z * self._disturbDeltaY

        # Roll = torque around model Z axis, Pitch = torque around model X axis
        # Approximate: horizontal component → roll, forward component → pitch
        self.gyroRoll  += wx * f
        self.gyroPitch += wz * f
        self.gyroYaw   += wx * f * 0.5
    else
        self.gyroRoll  += self._disturbDeltaX * f
        self.gyroPitch += self._disturbDeltaY * f
        self.gyroYaw   += self._disturbDeltaX * f * 0.5

TABS.simulator._readSticks = ->
    self = this
    # Stick → rate setpoint (deg/s): ±360 at full deflection (gentler)
    toRate = (v) -> (v - 1500) / 500 * 360
    self.setpoint =
        roll:  toRate(self.stickRoll)
        pitch: toRate(self.stickPitch)
        yaw:  -toRate(self.stickYaw)
    self.throttleNorm = Math.max(0, Math.min(1, (self.stickThrottle - 1000) / 1000))

    # Attitude stabilization: when sticks near centre, blend in
    # attitude→rate feedback so model returns to level
    normR = (self.stickRoll  - 1500) / 500
    normP = (self.stickPitch - 1500) / 500
    normY = (self.stickYaw   - 1500) / 500
    stickActive = Math.abs(normR) > 0.03 or Math.abs(normP) > 0.03 or Math.abs(normY) > 0.03
    if not stickActive
        attP = (self.cfg.attitude_P or 3.0)  # deg/s per degree of attitude error
        self.setpoint.roll  += -self.attRoll  * attP
        self.setpoint.pitch += -self.attPitch * attP
        self.setpoint.yaw   += -self.attYaw   * attP * 0.6

TABS.simulator._runPID = ->
    self = this
    axes = [
        {ax: 'roll',  gyro: self.gyroRoll,  maxI: 12}
        {ax: 'pitch', gyro: self.gyroPitch, maxI: 12}
        {ax: 'yaw',   gyro: self.gyroYaw,   maxI: 10}
    ]
    for a in axes
        s = self.pidState[a.ax]
        err = self.setpoint[a.ax] - a.gyro
        # Deadband: sub-threshold rate error is sensor noise / micro-residual —
        # it must not drive constant wing shivering at rest.
        if Math.abs(err) < 1.5
            err = 0.0
        s.P = self.cfg[a.ax + '_P'] * err * 0.00075
        s.I = Math.max(-a.maxI, Math.min(a.maxI, s.I + self.cfg[a.ax + '_I'] * err * DT * 0.00075))
        dErr = (err - (s.prevErr ? err)) / DT
        s.D = self.cfg[a.ax + '_D'] * dErr * 0.00075
        s.prevErr = err
        s.Sum = s.P + s.I + s.D
        # Clamp to the range the wing coupling can actually use (±0.4 → ±2 flap centre).
        # Without this, I/D windup saturates the flap and produces bang-bang shiver.
        s.Sum = Math.max(-5.0, Math.min(5.0, s.Sum))
        # First-order low-pass: breaks the D-term's high-frequency self-feedback loop
        # (wing torque → gyro → dErr → wing torque) that causes constant shivering.
        alpha = 0.25
        s.SumF = (s.SumF ? 0) + alpha * (s.Sum - (s.SumF ? 0))
    return

TABS.simulator._ondasModulation = ->
    self = this; ps = self.pidState; o = self.cfg

    # Phase modulation (Cadence: P→phase advance)
    # Calibrated: at pitch_P=50, err=180°/s, cadence=50 → mod ≈ 1.23
    phaseMod = 1.0
    if o.cadence_gain
        phaseMod = 1.0 + ps.pitch.P * o.cadence_gain * 0.00025
        phaseMod = Math.max(0.5, Math.min(2.0, phaseMod))

    # Common ferocity boost (Ferocity P/D + SSFF + Stick)
    # feroMod ≥ 0: center stick = 0 = feroBase 0.5 (pure sine, smoothest),
    # extreme stick or PID = 0.5 = feroBase 8.0 (aggressive square wave)
    feroMod = 0.0
    if o.ferocity_p_gain
        feroMod += Math.abs(ps.pitch.P) * o.ferocity_p_gain * 0.0006
    if o.ferocity_d_gain
        feroMod += Math.abs(ps.pitch.D) * o.ferocity_d_gain * 0.0006
    if o.ferocity_roll_gain
        feroMod += Math.min(0.4, Math.abs(ps.roll.P) * o.ferocity_roll_gain * 0.0005)
    if o.ferocity_yaw_gain
        feroMod += Math.min(0.4, Math.abs(ps.yaw.P) * o.ferocity_yaw_gain * 0.0005)
    if o.ssff
        stickSum = Math.abs(self.setpoint.roll) + Math.abs(self.setpoint.pitch) + Math.abs(self.setpoint.yaw)
        feroMod += stickSum / 2160 * o.ssff * 0.02
    feroMod = Math.max(0.0, Math.min(0.5, feroMod))

    # Asymmetry bias (Balance: I→up/down thrust ratio)
    asymBias = 0.0
    if o.balance_gain
        asymBias = ps.pitch.I * o.balance_gain * 0.0005
        asymBias = Math.max(-4.0, Math.min(4.0, asymBias))

    # P-gain feed-forward: moving P slider directly amplifies stick response.
    # Scale 1.0 at P=0, ~3.0 at P=199 — visible without needing disturbance.
    pScaleR = 1.0 + (self.cfg.roll_P  or 50) * 0.01
    pScaleP = 1.0 + (self.cfg.pitch_P or 70) * 0.01
    pScaleY = 1.0 + (self.cfg.yaw_P   or 40) * 0.01

    # Roll L/R differential — stick × P-gain + PID correction
    feroDiffR = self.setpoint.roll / 360 * 2.0 * pScaleR + ps.roll.SumF * 0.4

    # Yaw L/R flap-CENTRE differential (swept-wing proverse drag → yaw about vertical axis)
    feroDiffY = self.setpoint.yaw / 360 * 2.0 * pScaleY + ps.yaw.SumF * 0.4

    # Pitch fore/aft symmetric differential — PID→physics path
    feroPitchFA = self.setpoint.pitch / 360 * 2.0 * pScaleP + ps.pitch.SumF * 0.4

    # Direct stick feedforward — complementary to PID, scaled by user sliders
    normR = (self.stickRoll  - 1500) / 500
    normP = (self.stickPitch - 1500) / 500
    normY = (self.stickYaw   - 1500) / 500

    kFero  = (o.stick_fero  or 15) * 0.008   # 0..0.8 (gentle: center→sin, extreme→visible dwell)
    kAsym  = (o.stick_asym  or 25) * 0.06    # 0..6.0 (strong: center→symmetric, extreme→biased)

    # asymBias: stick + PID → up/down stroke bias (pitch control)
    asymBias    += normP * kAsym + ps.pitch.SumF * 0.01    # Stick + PID → up/down stroke bias
    feroMod     += Math.abs(normP) * kFero   # Pitch stick → more aggressive waveform
    feroMod     += Math.abs(normR) * kFero * 0.5  # Roll stick → ferocity boost
    feroMod     += Math.abs(normY) * kFero * 0.5  # Yaw stick  → ferocity boost

    self._phaseMod   = Math.max(0.3, Math.min(3.0, phaseMod))
    self._feroMod    = Math.max(0.0, Math.min(0.5, feroMod))
    self._asymBias   = Math.max(-4.0, Math.min(4.0, asymBias))
    self._feroDiffR  = Math.max(-2.0, Math.min(2.0, feroDiffR))
    self._feroDiffY    = Math.max(-2.0, Math.min(2.0, feroDiffY))
    self._feroPitchFA  = Math.max(-2.0, Math.min(2.0, feroPitchFA))
    # Store stick norms + slewed modulation for model amplitude paths
    self._normR = normR
    self._normY = normY
    return

TABS.simulator._computeTargets = ->
    self = this; o = self.cfg

    # Frequency: throttle × maxFreq × phaseMod
    maxFreq = o.freq_max or 3.0
    self._targetFreq = self.throttleNorm * maxFreq * (self._phaseMod or 1.0)
    self._targetFreq = Math.max(0, Math.min(6, self._targetFreq))

    # Kick-start: if target > 0.5Hz and slew is stuck at 0, jump to 0.5
    if self._targetFreq > 0.5 and self._slew.freq < 0.1
        self._slew.freq = 0.5

    # Amplitude: throttle × amp_max
    self._targetAmp = self.throttleNorm * (o.amp_max or 45)

    # Ferocity base: center stick→1.5(visible sine-with-dwell), max→8.0(square)
    self._targetFeroBase = 1.0 + (self._feroMod or 0) * 14.0
    self._targetFeroBase = Math.max(0.5, Math.min(8.0, self._targetFeroBase))

    # Bridge _ondasModulation outputs → slew/physics pipeline.
    self._targetFeroDiffR   = self._feroDiffR   or 0
    self._targetFeroDiffY   = self._feroDiffY   or 0
    self._targetFeroPitchFA = self._feroPitchFA or 0
    self._targetAsymBias    = self._asymBias    or 0

    # Yaw mixing: split the yaw command across two orthogonal mechanisms.
    #   yaw_amp_mix = 0   → pure flap-centre differential (∝ sin mount, glide-capable)
    #   yaw_amp_mix = 100 → pure L/R amplitude differential (thrust asymmetry, flapping-only)
    self._yawAmpMix = Math.max(0, Math.min(1, (self.cfg.yaw_amp_mix or 0) / 100))

    # Flap centre offset: PID controls where wing spends its time (same in glide & flapping).
    # Mount angle is STATIC — NEVER changes. It only SCALES physics authority.
    # feroPitchFA → all wings shift together (elevator). feroDiffR → L/R opposite (aileron).
    # feroDiffY → L/R flap-CENTRE differential (rudder): each swept wing holds a
    # bias angle ∝ sin(mount), producing proverse drag that yaws about vertical axis.
    # In glide (amp=0): wings hold at centre offset. In flapping: oscillation ADDED on top.
    self._targetFlapCenterPitch = (self._feroPitchFA or 0) * 15.0   # ±30° centre shift
    self._targetFlapCenterRoll  = (self._feroDiffR   or 0) * 15.0
    self._targetFlapCenterYaw   = (self._feroDiffY   or 0) * (1.0 - self._yawAmpMix) * 15.0   # ±30° L/R diff
    self._targetAmpYaw          = (self._feroDiffY   or 0) * self._yawAmpMix                 # L/R amplitude diff
    # Phase scissoring DISABLED: front/rear phase shift produces PITCH not yaw.
    # Yaw = L/R flap-centre differential ∝ sin(mount) — see applyFlapCenter yawOff.
    self._targetPhaseYaw        = 0.0
    return

TABS.simulator._applyServoSpeedLimit = ->
    self = this
    ss = self.cfg.servo_speed
    n = self._pairCount ? 2
    nServo = n * 2

    # Pitch fore/aft differential rank: +1 frontmost .. −1 rearmost,
    # derived from the actual fore/aft station (not pair index) so grouped
    # stations (biplane decks) deflect identically.
    pitchRank = (p) -> self._pitchGeometry().ranks[p] ? 0

    # Flap-centre per wing: pitch (fore/aft diff) + roll (L/R diff) + yaw (L/R × sin sweep).
    applyFlapCenter = (cPitch, cRoll, cYaw, setFn) ->
        for i in [0...nServo]
            p = i >> 1
            isRight = i % 2 == 1
            m = self._mountAngle[p] ? 0
            sinSweep = Math.sin(m * PI / 180)
            pitchOff = cPitch * pitchRank(p)
            yawOff = (if isRight then cYaw else -cYaw) * sinSweep
            cTarget = pitchOff + (if isRight then cRoll else -cRoll) + yawOff
            setFn i, cTarget
        return

    applyMount = (setFn) ->
        for p in [0...n]
            tgtL = self._mountAngle[p] ? 0
            setFn p, tgtL, -tgtL
        return

    # When servo_speed == 0, copy targets directly (no rate limiting)
    if ss <= 0
        self._slew.freq       = self._targetFreq
        self._slew.amp        = self._targetAmp
        self._slew.feroBase   = self._targetFeroBase
        self._slew.feroDiffR    = self._targetFeroDiffR
        self._slew.feroDiffY    = self._targetFeroDiffY
        self._slew.feroPitchFA  = self._targetFeroPitchFA
        self._slew.asymBias     = self._targetAsymBias
        self._slew.phaseYaw   = self._targetPhaseYaw
        self._slew.ampYaw     = self._targetAmpYaw or 0
        aB = self._targetAsymBias or 0
        fBase = Math.max(0.5, Math.min(8.0, self._targetFeroBase))
        fD = Math.max(0.5, Math.min(8.0, fBase - aB * 0.8))
        fU = Math.max(0.5, Math.min(8.0, fBase + aB * 0.8))
        for i in [0...nServo]
            self._slewFeroDL[i] = fD; self._slewFeroUL[i] = fU
            self._slewFeroDR[i] = fD; self._slewFeroUR[i] = fU
        cPitch = self._targetFlapCenterPitch or 0
        cRoll  = self._targetFlapCenterRoll  or 0
        cYaw   = self._targetFlapCenterYaw   or 0
        applyFlapCenter cPitch, cRoll, cYaw, (i, tgt) -> self._slewFlapCenter[i] = tgt
        applyMount (p, tgtL, tgtR) ->
            self._slewMountL[p] = tgtL
            self._slewMountR[p] = tgtR
        return

    maxDeg  = ss / 30.0
    maxFreq = maxDeg * 0.02
    maxAmp  = maxDeg * 0.5
    maxFero = maxDeg * 0.08
    maxPhs  = maxDeg
    maxMnt  = maxDeg * 0.5

    slew = (cur, tgt, mx) ->
        return tgt if mx <= 0 or Math.abs(tgt - cur) <= mx
        cur + Math.sign(tgt - cur) * mx

    # Scalar parameters
    self._slew.freq      = slew(self._slew.freq,      self._targetFreq,      maxFreq)
    self._slew.amp       = slew(self._slew.amp,       self._targetAmp,       maxAmp)
    self._slew.feroBase  = slew(self._slew.feroBase,  self._targetFeroBase,  maxFero)
    self._slew.feroDiffR   = slew(self._slew.feroDiffR,   self._targetFeroDiffR,   maxFero)
    self._slew.feroDiffY   = slew(self._slew.feroDiffY,   self._targetFeroDiffY,   maxFero)
    self._slew.feroPitchFA = slew(self._slew.feroPitchFA, self._targetFeroPitchFA, maxFero)
    self._slew.asymBias    = slew(self._slew.asymBias,    self._targetAsymBias,    maxFero)
    self._slew.phaseYaw  = slew(self._slew.phaseYaw,  self._targetPhaseYaw,  maxPhs)
    self._slew.ampYaw     = slew(self._slew.ampYaw,    self._targetAmpYaw or 0,   maxFero)

    # Per-wing ferocity: UNIFORM across all wings. asymBias gives up/down
    # stroke balance (pitch via thrust timing). Roll is flap centre only.
    aB = self._targetAsymBias or 0
    fBase = Math.max(0.5, Math.min(8.0, self._targetFeroBase))
    fD = Math.max(0.5, Math.min(8.0, fBase - aB * 0.8))
    fU = Math.max(0.5, Math.min(8.0, fBase + aB * 0.8))
    for i in [0...nServo]
        self._slewFeroDL[i] = slew(self._slewFeroDL[i] ? 0.5, fD, maxFero)
        self._slewFeroUL[i] = slew(self._slewFeroUL[i] ? 0.5, fU, maxFero)
        self._slewFeroDR[i] = slew(self._slewFeroDR[i] ? 0.5, fD, maxFero)
        self._slewFeroUR[i] = slew(self._slewFeroUR[i] ? 0.5, fU, maxFero)

    # Flap centre offsets: PID-controlled wing deflection (same in glide & flapping).
    cPitch = self._targetFlapCenterPitch or 0
    cRoll  = self._targetFlapCenterRoll  or 0
    cYaw   = self._targetFlapCenterYaw   or 0
    applyFlapCenter cPitch, cRoll, cYaw, (i, tgt) ->
        self._slewFlapCenter[i] = slew(self._slewFlapCenter[i] ? 0, tgt, maxMnt)

    # Mount angles: STATIC — NEVER changes during flight
    applyMount (p, tgtL, tgtR) ->
        self._slewMountL[p] = slew(self._slewMountL[p] ? tgtL, tgtL, maxMnt)
        self._slewMountR[p] = slew(self._slewMountR[p] ? tgtR, tgtR, maxMnt)
    return

TABS.simulator._updateModel = ->
    self = this
    return unless self.model
    fp = self.model.flapParams

    fp.frequency = self._slew.freq
    fp.amplitude = self._slew.amp
    fp.aeroelasticCoef = self.cfg.aeroelastic_coef
    fp.glideAeroCoef = self.cfg.glide_aero_coef
    fp.throttle  = 1000 + self.throttleNorm * 1000

    # Flap centre offsets: PID wing deflection. Same in glide (amp=0) & flapping.
    n = self._pairCount ? 2
    fp.flapCenterL = []
    fp.flapCenterR = []
    for p in [0...n]
        fp.flapCenterL[p] = self._slewFlapCenter[p * 2]     ? 0
        fp.flapCenterR[p] = self._slewFlapCenter[p * 2 + 1] ? 0

    # Yaw is split by yaw_amp_mix: flap-centre (rendered via _slewFlapCenter)
    # + L/R amplitude differential (fp.yaw). 1500 = neutral (no amp differential).
    fp.yaw = 1500 + (self._slew.ampYaw or 0) * 500
    self._lrSig = 0

    # Pitch: asymBias only (up/down stroke balance) — NO front/rear amplitude differential
    fp.amplitudeFA = 0.0
    self._normP = (self.stickPitch - 1500) / 500

    # Per-pair ferocity mapping: _slew arrays are flat [FL,FR,BL,BR] per pair.
    for pair in [0...n]
        fp.ferocityDownL[pair] = self._slewFeroDL[pair * 2] ? 0.5
        fp.ferocityDownR[pair] = self._slewFeroDR[pair * 2 + 1] ? 0.5
        fp.ferocityUpL[pair]   = self._slewFeroUL[pair * 2] ? 0.5
        fp.ferocityUpR[pair]   = self._slewFeroUR[pair * 2 + 1] ? 0.5

    # Phase shifts: disabled — all pairs in phase.
    fp.phaseShifts = []
    for p in [0...n]
        fp.phaseShifts[p] = 0

    # Per-pair mount angles
    fp.mountAnglesL = self._slewMountL
    fp.mountAnglesR = self._slewMountR
    for p in [0...n]
        fp.mountAngles[p] = (self._slewMountL[p] + self._slewMountR[p]) / 2

    # amplitudeFA is set above from slewed feroPitchFA (pitch → front/rear amplitude split)

    # Glide: amplitude=0 naturally → no flapping. Wings hold at flap centre
    # offset (PID deflection). Same mechanism as flapping — superposition.
    fp.glideAnglesL = null
    fp.glideAnglesR = null

    # FIXED: attRoll→rotation.z (roll), attPitch→rotation.x (pitch)
    unless self._viewLocked
        self.model.rotateTo -self.attPitch * PI / 180, self.attYaw * PI / 180, self.attRoll * PI / 180
    self._updateGyroIndicator()

TABS.simulator._physicsStep = ->
    self = this
    n = self._pairCount ? 2
    A_LAT = 0.164   # normalized half-width at wing root (4.5 / 27.5)
    cg = self._cg ? 0

    # ═══════════════════════════════════════════════════════════
    #  WING-DRIVEN AERODYNAMICS — the deployed wing is the ONLY
    #  source of both control moment and passive damping. Folded
    #  wings (no flap + no glide flow) give zero authority → the
    #  craft tumbles freely, exactly as a real ornithopter would.
    # ═══════════════════════════════════════════════════════════

    # Wing flap-centre deflection (deg) — the ACTUAL rendered wing
    # state, read from the same slew values that drive _slewFlapCenter.
    elevatorDeg = (self._slew.feroPitchFA or 0) * 15.0   # fore/aft diff → pitch
    aileronDeg  = (self._slew.feroDiffR   or 0) * 15.0   # L/R diff → roll
    rudderDeg   = (self._slew.feroDiffY   or 0) * 15.0   # total yaw command (deg)
    mix         = Math.max(0, Math.min(1, (self.cfg.yaw_amp_mix or 0) / 100))
    centerYawDeg = rudderDeg * (1.0 - mix)   # flap-centre (proverse drag ∝ sin² mount)
    ampYawDeg    = rudderDeg * mix           # amplitude (thrust asymmetry ∝ flapping amp)

    # ── Mount-geometry lever arms (per pair) ───────────────────
    # Effective fore/aft station = centreline crossing of the swept
    # span line:  z_eff[p] = d_p − a·tan(θ_p)
    #   θ_p = mount angle (deg, + = swept back)
    #   d_p = mount distance (normalized σ, + = nose)
    #   a   = A_LAT (normalized half-width)
    # Pitch lever = z_eff − CG ; roll ∝ cos(θ) ; yaw ∝ sin²(θ).
    geo = self._pitchGeometry()
    ranks = geo.ranks
    levers = geo.levers

    pitchSum = 0.0
    rollCos  = 0.0
    yawSin2  = 0.0
    for p in [0...n]
        th = self._mountAngle[p] ? 0
        rad = th * PI / 180
        cosT = Math.cos(rad)
        sinT = Math.sin(rad)
        lever = levers[p] ? 0
        pitchSum += (elevatorDeg * (ranks[p] ? 0)) * cosT * lever
        rollCos  += cosT
        yawSin2  += sinT * sinT
    rollCos /= n
    yawSin2 /= n

    # ── Authority = airflow present (flapping ∝ amplitude, glide ∝ coef) ──
    # Geometry (cos/sin) is handled separately; sweep no longer gates airflow.
    ampScale   = Math.max(0, Math.min(1, (self._slew.amp or 0) / (self.cfg.amp_max or 45)))
    glideScale = Math.max(0, Math.min(1, (self.cfg.glide_aero_coef or 4) / 10.0))
    authority  = Math.max(ampScale, glideScale)

    # Control moment ∝ deflection × geometry × authority.
    rollCoef  = 28.0
    pitchCoef = 28.0
    yawCoef   = 9.0
    sin30 = Math.sin(30 * PI / 180)
    yawMount = Math.max(0, Math.min(1.5, yawSin2 / (sin30 * sin30)))
    ctrlRoll  = aileronDeg  * rollCoef  * rollCos  * authority
    ctrlPitch = pitchSum    * pitchCoef * authority
    ampYawCoef = 9.0   # thrust-asymmetry authority — mount-sweep independent, flapping-gated
    ctrlYaw   = centerYawDeg * yawCoef * yawMount * authority + ampYawDeg * ampYawCoef * ampScale

    # Passive aerodynamic damping: a rotating craft presents asymmetric
    # airflow to its wings, which oppose the rotation. Scales with wing
    # authority — NOT a phantom spring. It vanishes when wings are folded.
    dampBase    = 1.3
    anchorBoost = (self.cfg.anchor_gain or 0) * 0.08
    dampRoll  = (dampBase + anchorBoost) * authority
    dampPitch = (dampBase + anchorBoost) * authority
    dampYaw   = (dampBase * 0.6 + anchorBoost) * authority

    # ── Integrate rigid-body rates ─────────────────────────────
    self.gyroRoll  += (ctrlRoll  - self.gyroRoll  * dampRoll)  * DT
    self.gyroPitch += (ctrlPitch - self.gyroPitch * dampPitch) * DT
    self.gyroYaw   += (ctrlYaw   - self.gyroYaw   * dampYaw)   * DT

    # Clamp gyro to safe range (prevents NaN cascade)
    LIMIT = 1500
    self.gyroRoll  = Math.max(-LIMIT, Math.min(LIMIT, self.gyroRoll  or 0))
    self.gyroPitch = Math.max(-LIMIT, Math.min(LIMIT, self.gyroPitch or 0))
    self.gyroYaw   = Math.max(-LIMIT, Math.min(LIMIT, self.gyroYaw   or 0))

    # Attitude integration
    self.attRoll  += self.gyroRoll  * DT
    self.attPitch += self.gyroPitch * DT
    self.attYaw   += self.gyroYaw   * DT

TABS.simulator._updateTelemetry = ->
    self = this
    return unless self.model
    sa = self.model.servoAngles
    return unless sa and sa.length >= 4

    # Update internal phase for Model's wave plotter reference
    self.theta = (self.theta or 0) + self._slew.freq * TWO_PI * DT
    self.theta %= TWO_PI

    el = self.telemetryEl
    return unless el and el.length
    fM = if self._feroMod? then self._feroMod.toFixed(3) else '?'
    aB  = if self._asymBias?  then self._asymBias.toFixed(3)  else '?'
    fDR = if self._feroDiffR? then self._feroDiffR.toFixed(3) else '?'
    fDY = if self._feroDiffY? then self._feroDiffY.toFixed(3) else '?'
    fPF = if self._feroPitchFA? then self._feroPitchFA.toFixed(3) else '?'
    lrS = if self._lrSig? then self._lrSig.toFixed(3) else '?'
    aFA = if self._ampFA? then self._ampFA.toFixed(3) else '?'
    nR = if self._normR? then self._normR.toFixed(2) else '0.00'
    nP = if self._normP? then self._normP.toFixed(2) else '0.00'
    nY = if self._normY? then self._normY.toFixed(2) else '0.00'
    el[0].style.whiteSpace = 'pre-line'
    sp = self.setpoint
    pSR = (1.0 + (self.cfg.roll_P  or 50) * 0.01).toFixed(2)
    pSP = (1.0 + (self.cfg.pitch_P or 70) * 0.01).toFixed(2)
    pSY = (1.0 + (self.cfg.yaw_P   or 40) * 0.01).toFixed(2)
    fcP = if self._slewFlapCenter? and self._slewFlapCenter[0]? then self._slewFlapCenter[0].toFixed(1) else '?'
    fcR = if self._slewFlapCenter? and self._slewFlapCenter[1]? then ((self._slewFlapCenter[1] - self._slewFlapCenter[0]) / 2).toFixed(1) else '?'
    pairs = self._pairCount ? 2
    cgS   = ((self._cg ? 0) * 100).toFixed(0)
    "v0811-31 " +
            "FLAP:#{self._slew.freq.toFixed(1)}Hz AMP:#{self._slew.amp.toFixed(0)}deg " +
            "Pairs:#{pairs} CG:#{cgS} " +
            "Servo:[#{sa[0].toFixed(0)},#{sa[1].toFixed(0)},#{sa[2].toFixed(0)},#{sa[3].toFixed(0)}] " +
            "Gyro:(#{self.gyroRoll.toFixed(1)},#{self.gyroPitch.toFixed(1)},#{self.gyroYaw.toFixed(1)}) " +
            "Att:(#{self.attRoll.toFixed(2)},#{self.attPitch.toFixed(2)},#{self.attYaw.toFixed(2)})\\\\n" +
            "SET R:#{sp.roll.toFixed(0)} P:#{sp.pitch.toFixed(0)} Y:#{sp.yaw.toFixed(0)}  " +
            "Pgain R:#{pSR} P:#{pSP} Y:#{pSY}  " +
            "DIAG fMod:#{fM} aB:#{aB} rD:#{fDR} yD:#{fDY} fc:#{fcP}(#{fcR})"

# ═══════════════════════════════════════════════════════════════
#  CLEANUP
# ═══════════════════════════════════════════════════════════════

TABS.simulator.cleanup = ->
    $(document).off 'mousemove.sim'
    $(document).off 'mouseup.sim'
    if TABS.simulator._loopInterval
        clearInterval TABS.simulator._loopInterval
    if TABS.simulator.model
        TABS.simulator.model.destroy?()
        TABS.simulator.model = null