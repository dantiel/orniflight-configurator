'use strict';

// OrniFlight — mixer list: only MIXER_SERVO_ORNITHOPTER (27) is supported.
// Sparse array keyed by firmware mixer enum value.
var mixerList = [];
mixerList[27] = {name: 'Ornithopter', model: 'custom', image: 'ornithopter'};

// =========================================================================
//  Waveform Engine — ported from Gralha Azul (trapezoidal flapping model)
//  È compatto ma completo: formaDoBaterDasAsas + derivata per sonificazione
// =========================================================================
var TWO_PI = 2 * Math.PI;
var PI = Math.PI;

function formaDoBaterDasAsas(anguloDoCiclo, fBater, fRetorno, limiarShared) {
    // Fast-path: ferocidade máxima → onda quadrada pura
    if (fBater >= 7.999 && fRetorno >= 7.999) {
        var theta = anguloDoCiclo % TWO_PI;
        if (theta < 0) theta += TWO_PI;
        var limiarFP = (limiarShared != null) ? limiarShared : PI;
        return (theta < limiarFP) ? 1.0 : -1.0;
    }

    var theta = anguloDoCiclo % TWO_PI;
    if (theta < 0) theta += TWO_PI;

    var fD = Math.max(0, Math.min(8, fBater));
    var fS = Math.max(0, Math.min(8, fRetorno));

    var limiar = (limiarShared != null) ? limiarShared : TWO_PI * 0.5;

    var descida = (theta < limiar);
    var t = descida ? (theta / limiar) : ((theta - limiar) / (TWO_PI - limiar));
    var ferocidade = descida ? fD : fS;
    var d = ferocidade / 8.0;
    var dh = d * 0.5;

    if (d >= 1.0) return descida ? 1.0 : -1.0;
    if (t < dh) return descida ? 1.0 : -1.0;
    if (t > 1.0 - dh) return descida ? -1.0 : 1.0;
    var ramp = Math.cos(PI * (t - dh) / (1.0 - d));
    return descida ? ramp : -ramp;
}

// =========================================================================
//  3D Ornithopter Model — procedural, no external .json needed
//  Wings flap based on live RC + ONDAS parameters.
//  Includes integrated wave plotter on optional second canvas.
// =========================================================================
var Model = function (wrapper, canvas, waveCanvas) {
    var useWebGLRenderer = this.canUseWebGLRenderer();

    this.wrapper = wrapper;
    this.canvas = canvas;
    this.waveCanvas = waveCanvas || null;
    this.waveCtx = this.waveCanvas ? this.waveCanvas.getContext('2d') : null;

    this.animationFrame = null;
    this.lastFlapTime = 0;
    this.flapAngle = 0;          // accumulatore fase di battito (rad)
    this.waveHistory = [];       // [{sin, warp, left, right}]
    this.WAVE_LEN = 200;

    // Flap state (driven externally via setFlapState)
    this.flapParams = {
        throttle: 1280,          // µs, 1000–2000
        yaw: 1500,               // µs, 1000–2000
        frequency: 6.0,          // Hz, base flap frequency
        amplitude: 30.0,         // gradi, base flap amplitude
        ferocityDown: 4.0,       // 0–8
        ferocityUp: 4.0,         // 0–8
        phaseShiftFront: 0,      // gradi, from flapping_phase_shift[0]
        phaseShiftRear: 0,       // gradi, from flapping_phase_shift[1]
        mountAngleFront: 0,      // gradi, from servo_mount_angle[0]
        mountAngleRear: 0,       // gradi, from servo_mount_angle[1]
    };

    if (useWebGLRenderer) {
        this.renderer = new THREE.WebGLRenderer({ canvas: this.canvas[0], alpha: true, antialias: true });
    } else {
        this.renderer = new THREE.CanvasRenderer({ canvas: this.canvas[0], alpha: true });
    }

    this.renderer.setSize(this.wrapper.width() * 2, this.wrapper.height() * 2);

    // Scene setup
    this.scene = new THREE.Scene();
    this.modelWrapper = new THREE.Object3D();

    this.camera = new THREE.PerspectiveCamera(60, this.wrapper.width() / this.wrapper.height(), 1, 10000);
    this.camera.position.z = 125;

    // Lighting
    var ambient = new THREE.AmbientLight(0x404040);
    var directional = new THREE.DirectionalLight(new THREE.Color(1, 1, 1), 1.5);
    directional.position.set(0, 1, 0);
    this.scene.add(ambient);
    this.scene.add(directional);
    this.scene.add(this.camera);
    this.scene.add(this.modelWrapper);

    // Detect mixer: 27 = MIXER_SERVO_ORNITHOPTER → build procedural model
    var mixer = (typeof MIXER_CONFIG !== 'undefined' && MIXER_CONFIG.mixer) ? MIXER_CONFIG.mixer : 0;

    if (mixer === 27) {
        this.buildOrnithopter();
        this.startAnimation();
    } else {
        // Legacy: load .json model for non-ornithopter mixers
        var model_file = useWebGLRenderer ? ((mixerList[mixer] || {model:'custom'}).model) : 'fallback';
        if (model_file === 'custom') { model_file = 'fallback'; }
        this.loadJSON(model_file, (function (model) {
            this.model = model;
            this.modelWrapper.add(model);
            this.scene.add(this.modelWrapper);
            this.render();
        }).bind(this));
    }
};

// ---- Legacy model loading (non-ornithopter) ----
Model.prototype.loadJSON = function (model_file, callback) {
    var loader = new THREE.JSONLoader();
    loader.load('./resources/models/' + model_file + '.json', function (geometry, materials) {
        var modelMaterial = new THREE.MeshFaceMaterial(materials),
            model = new THREE.Mesh(geometry, modelMaterial);
        model.scale.set(15, 15, 15);
        callback(model);
    });
};

// ---- Procedural Ornithopter Builder ----
Model.prototype.buildOrnithopter = function () {
    var self = this;

    // Materials
    var matFuselage = new THREE.MeshPhongMaterial({ color: 0x2a3040, specular: 0x111111, shininess: 10, flatShading: true });
    var matWing = new THREE.MeshPhongMaterial({ color: 0xf0c060, specular: 0x111111, shininess: 5, transparent: true, opacity: 0.75, side: THREE.DoubleSide });
    var matPivot = new THREE.MeshPhongMaterial({ color: 0x5865f2, specular: 0x111111, shininess: 20 });
    var matHead = new THREE.MeshPhongMaterial({ color: 0x3a4a5a, specular: 0x111111, shininess: 10 });
    var matTail = new THREE.MeshPhongMaterial({ color: 0x2a3040, specular: 0x111111, shininess: 5, side: THREE.DoubleSide });
    var matRod = new THREE.MeshPhongMaterial({ color: 0xf0883e, specular: 0x111111, shininess: 20 });

    // Fuselage: elongated box along Z
    var fuselageGeo = new THREE.BoxGeometry(8, 10, 55);
    var fuselage = new THREE.Mesh(fuselageGeo, matFuselage);
    fuselage.position.set(0, 0, 0);
    this.modelWrapper.add(fuselage);

    // Head: cone at +Z
    var headGeo = new THREE.CylinderGeometry(0, 4.5, 12, 8);
    var head = new THREE.Mesh(headGeo, matHead);
    head.position.set(0, 2, 30);
    head.rotation.x = -PI / 2;
    this.modelWrapper.add(head);

    // Tail stabilizer
    var tailGeo = new THREE.BoxGeometry(14, 0.8, 8);
    var tail = new THREE.Mesh(tailGeo, matTail);
    tail.position.set(0, 1, -25);
    this.modelWrapper.add(tail);

    // Vertical fin
    var finGeo = new THREE.BoxGeometry(0.8, 8, 8);
    var fin = new THREE.Mesh(finGeo, matTail);
    fin.position.set(0, 4, -25);
    this.modelWrapper.add(fin);

    // Wing pivots & wings — 2 pairs
    this.wingPivots = [];
    var wingGeo = new THREE.BoxGeometry(0.8, 65, 12);

    var pairConfigs = [
        { z: 14, label: 'front' },
        { z: -8, label: 'rear' }
    ];

    for (var p = 0; p < 2; p++) {
        var cfg = pairConfigs[p];
        var wingPair = { leftPivot: null, rightPivot: null, leftWing: null, rightWing: null };

        // Left wing pivot
        var leftPivot = new THREE.Object3D();
        leftPivot.position.set(-4.5, 1, cfg.z);
        this.modelWrapper.add(leftPivot);

        var leftWing = new THREE.Mesh(wingGeo, matWing);
        leftWing.position.set(-32.5, 0, 0); // extend left
        leftPivot.add(leftWing);
        wingPair.leftPivot = leftPivot;
        wingPair.leftWing = leftWing;

        // Right wing pivot
        var rightPivot = new THREE.Object3D();
        rightPivot.position.set(4.5, 1, cfg.z);
        this.modelWrapper.add(rightPivot);

        var rightWing = new THREE.Mesh(wingGeo, matWing);
        rightWing.position.set(32.5, 0, 0); // extend right
        rightPivot.add(rightWing);
        wingPair.rightPivot = rightPivot;
        wingPair.rightWing = rightWing;

        // Pivot sphere indicators
        var sphereGeo = new THREE.SphereGeometry(2, 8, 8);
        var sphereL = new THREE.Mesh(sphereGeo, matPivot);
        sphereL.position.copy(leftPivot.position);
        this.modelWrapper.add(sphereL);

        var sphereR = new THREE.Mesh(sphereGeo, matPivot);
        sphereR.position.copy(rightPivot.position);
        this.modelWrapper.add(sphereR);

        this.wingPivots.push(wingPair);
    }

    this.scene.add(this.modelWrapper);
    this.render();
};

// ---- Animation Loop ----
Model.prototype.startAnimation = function () {
    var self = this;

    function loop(timestamp) {
        self.animationFrame = requestAnimationFrame(loop);

        if (!self.flapParams) return;

        var dt = self.lastFlapTime ? (timestamp - self.lastFlapTime) * 0.001 : 0.016;
        if (dt <= 0) dt = 0.001;
        if (dt > 0.1) dt = 0.1;
        self.lastFlapTime = timestamp;

        // Advance flap phase
        var freq = self.flapParams.frequency || 6.0;
        self.flapAngle += freq * TWO_PI * dt;
        if (self.flapAngle > TWO_PI * 10) self.flapAngle %= TWO_PI;

        // Calculate wing angles for front and rear pairs
        var throttle = self.flapParams.throttle || 1280;
        var yaw = self.flapParams.yaw || 1500;
        var amplitude = self.flapParams.amplitude || 30.0;

        // Scale amplitude by throttle (1000 = glide/idle, 2000 = full)
        var throttleFactor = Math.max(0, Math.min(1, (throttle - 1040) / 960));
        var ampDeg = amplitude * throttleFactor;

        // Yaw differential — reduces amplitude on one side
        var yawDiff = (yaw - 1500) / 500; // -1..+1
        var leftAmp = ampDeg * (1.0 - yawDiff * 0.5);
        var rightAmp = ampDeg * (1.0 + yawDiff * 0.5);

        // Clamp
        var maxAmp = 55;
        leftAmp = Math.max(0, Math.min(maxAmp, leftAmp));
        rightAmp = Math.max(0, Math.min(maxAmp, rightAmp));

        var fD = self.flapParams.ferocityDown || 4.0;
        var fU = self.flapParams.ferocityUp || 4.0;

        // Front pair
        var phaseFront = self.flapAngle + (self.flapParams.phaseShiftFront || 0) * (PI / 180);
        var mountFront = (self.flapParams.mountAngleFront || 0) * (PI / 180);
        var waveFront = formaDoBaterDasAsas(phaseFront, fD, fU, null);

        // Rear pair
        var phaseRear = self.flapAngle + (self.flapParams.phaseShiftRear || 0) * (PI / 180);
        var mountRear = (self.flapParams.mountAngleRear || 0) * (PI / 180);
        var waveRear = formaDoBaterDasAsas(phaseRear, fD, fU, null);

        // Apply to wing pivots
        if (self.wingPivots && self.wingPivots.length >= 2) {
            // Front pair
            self.wingPivots[0].leftPivot.rotation.x = mountFront + waveFront * leftAmp * (PI / 180);
            self.wingPivots[0].rightPivot.rotation.x = mountFront - waveFront * rightAmp * (PI / 180);

            // Rear pair
            self.wingPivots[1].leftPivot.rotation.x = mountRear + waveRear * leftAmp * (PI / 180);
            self.wingPivots[1].rightPivot.rotation.x = mountRear - waveRear * rightAmp * (PI / 180);
        }

        // Render 3D
        self.render();

        // Draw wave plotter
        self.drawWavePlotter(waveFront, waveRear, leftAmp, rightAmp, ampDeg);
    }

    this.animationFrame = requestAnimationFrame(loop);
};

// ---- Wave Plotter (2D canvas) ----
Model.prototype.drawWavePlotter = function (waveFront, waveRear, leftAmp, rightAmp, ampDeg) {
    if (!this.waveCtx || !this.waveCanvas) return;

    var cosVal = Math.cos(this.flapAngle);
    var warpVal = waveFront; // use front as representative
    var leftDeg = waveFront * leftAmp;
    var rightDeg = waveFront * rightAmp;

    this.waveHistory.push({
        sin: cosVal,
        warp: warpVal,
        left: leftDeg,
        right: rightDeg,
        amp: ampDeg || 30
    });
    if (this.waveHistory.length > this.WAVE_LEN) this.waveHistory.shift();

    var ctx = this.waveCtx;
    var W = this.waveCanvas.width;
    var H = this.waveCanvas.height;
    ctx.clearRect(0, 0, W, H);

    var margin = { top: 12, right: 10, bottom: 16, left: 10 };
    var pw = W - margin.left - margin.right;
    var ph = H - margin.top - margin.bottom;
    var midY = margin.top + ph / 2;
    var AMP_REF = 55;
    var ampY = ph / 2;

    // Grid lines
    ctx.strokeStyle = 'rgba(48,54,61,0.6)';
    ctx.lineWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
        var y = margin.top + (ph * i) / 4;
        ctx.beginPath();
        ctx.moveTo(margin.left, y);
        ctx.lineTo(W - margin.right, y);
        ctx.stroke();
    }
    // Zero line
    ctx.strokeStyle = '#30363d';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(margin.left, midY);
    ctx.lineTo(W - margin.right, midY);
    ctx.stroke();

    var n = this.waveHistory.length;
    if (n < 2) return;
    var xScale = pw / (n - 1);

    function drawTrace(dataKey, color, alpha) {
        ctx.strokeStyle = color;
        ctx.lineWidth = 1.5;
        ctx.globalAlpha = alpha || 1;
        ctx.beginPath();
        for (var i = 0; i < n; i++) {
            var x = margin.left + i * xScale;
            var scale = Math.max(0.1, (that.waveHistory[i].amp || 30) / AMP_REF);
            var val = that.waveHistory[i][dataKey] || 0;
            var y = midY - (val / AMP_REF) * ampY;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();
        ctx.globalAlpha = 1;
    }

    var that = this;

    // cos(θ) — blue, dimmed
    ctx.strokeStyle = '#58a6ff';
    ctx.lineWidth = 1.2;
    ctx.globalAlpha = 0.4;
    ctx.beginPath();
    for (var i = 0; i < n; i++) {
        var x = margin.left + i * xScale;
        var y = midY - that.waveHistory[i].sin * ampY;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.globalAlpha = 1;

    // formaDoBater — orange
    drawTrace('warp', '#f0883e', 1.0);

    // Left wing — green
    drawTrace('left', '#3fb950', 1.0);

    // Right wing — magenta
    drawTrace('right', '#f3f', 1.0);
};

// ---- Set flap state from external data ----
Model.prototype.setFlapState = function (params) {
    if (!this.flapParams) return;
    if (params.throttle !== undefined) this.flapParams.throttle = params.throttle;
    if (params.yaw !== undefined) this.flapParams.yaw = params.yaw;
    if (params.frequency !== undefined) this.flapParams.frequency = params.frequency;
    if (params.amplitude !== undefined) this.flapParams.amplitude = params.amplitude;
    if (params.ferocityDown !== undefined) this.flapParams.ferocityDown = params.ferocityDown;
    if (params.ferocityUp !== undefined) this.flapParams.ferocityUp = params.ferocityUp;
    if (params.phaseShiftFront !== undefined) this.flapParams.phaseShiftFront = params.phaseShiftFront;
    if (params.phaseShiftRear !== undefined) this.flapParams.phaseShiftRear = params.phaseShiftRear;
    if (params.mountAngleFront !== undefined) this.flapParams.mountAngleFront = params.mountAngleFront;
    if (params.mountAngleRear !== undefined) this.flapParams.mountAngleRear = params.mountAngleRear;
};

// ---- Rotation (stick input / attitude) ----
Model.prototype.rotateTo = function (x, y, z) {
    if (this.wingPivots) {
        this.modelWrapper.rotation.x = x;
        this.modelWrapper.rotation.y = y;
        this.modelWrapper.rotation.z = z;
    } else if (this.model) {
        this.model.rotation.x = x;
        this.modelWrapper.rotation.y = y;
        this.model.rotation.z = z;
    }
    if (!this.animationFrame) this.render();
};

Model.prototype.rotateBy = function (x, y, z) {
    if (!this.model && !this.wingPivots) { return; }
    if (this.wingPivots) {
        this.modelWrapper.rotateX(x);
        this.modelWrapper.rotateY(y);
        this.modelWrapper.rotateZ(z);
    } else {
        this.model.rotateX(x);
        this.model.rotateY(y);
        this.model.rotateZ(z);
    }
    if (!this.animationFrame) this.render();
};

// ---- Render ----
Model.prototype.render = function () {
    if (!this.model && !this.wingPivots) { return; }
    this.renderer.render(this.scene, this.camera);
};

// ---- Resize handler ----
Model.prototype.resize = function () {
    this.renderer.setSize(this.wrapper.width() * 2, this.wrapper.height() * 2);
    this.camera.aspect = this.wrapper.width() / this.wrapper.height();
    this.camera.updateProjectionMatrix();
    this.render();
};

// ---- WebGL detection ----
Model.prototype.canUseWebGLRenderer = function () {
    var detector_canvas = document.createElement('canvas');
    return window.WebGLRenderingContext && (detector_canvas.getContext('webgl') || detector_canvas.getContext('experimental-webgl'));
};

// ---- Cleanup ----
Model.prototype.dispose = function () {
    if (this.animationFrame) {
        cancelAnimationFrame(this.animationFrame);
        this.animationFrame = null;
    }
    if (this.renderer) {
        this.renderer.forceContextLoss();
        this.renderer.dispose();
    }
};