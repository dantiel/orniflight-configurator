#!/usr/bin/env node
// Comprehensive ES6→ES5 pre-processor for js2coffee compatibility
'use strict';

const fs = require('fs');
const path = require('path');

const BASE = path.join(__dirname, '..', 'src', 'js');
const FAILING = [
    'FirmwareCache.js', 'LogoManager.js', 'jenkins_loader.js',
    'msp/MSPHelper.js', 'msp.js', 'protocols/stm32usbdfu.js',
    'serial.js', 'serial_backend.js', 'tabs/cli.js',
    'tabs/configuration.js', 'tabs/firmware_flasher.js',
    'tabs/osd.js', 'tabs/pid_tuning.js', 'tabs/power.js'
];

FAILING.forEach(relPath => {
    const filePath = path.join(BASE, relPath);
    let src = fs.readFileSync(filePath, 'utf8');
    const original = src;
    
    // 1. Arrow functions: (a) => { ... }  OR  a => { ... }  OR  () => { ... }
    //    Also: (a) => expr  OR  a => expr
    src = src.replace(/\(\s*\)\s*=>\s*\{/g, 'function() {');
    src = src.replace(/\(([^)]+)\)\s*=>\s*\{/g, 'function($1) {');
    src = src.replace(/(\w+)\s*=>\s*\{/g, 'function($1) {');
    
    // Arrow with expression body (no braces)
    src = src.replace(/\(([^)]+)\)\s*=>\s+(?!\{)([^;\n,]+)/g, 'function($1) { return $2; }');
    src = src.replace(/(\w+)\s*=>\s+(?!\{)([^;\n,]+)/g, 'function($1) { return $2; }');

    // 2. Template literals
    src = src.replace(/`([^`]*)`/g, (match, content) => {
        const parts = [];
        let last = 0;
        content.replace(/\$\{([^}]+)\}/g, (m, expr, offset) => {
            if (offset > last) parts.push(JSON.stringify(content.slice(last, offset)));
            parts.push('(' + expr + ')');
            last = offset + m.length;
            return '';
        });
        if (last < content.length) parts.push(JSON.stringify(content.slice(last)));
        return parts.length === 0 ? '""' : (parts.length === 1 ? parts[0] : parts.join(' + '));
    });

    // 3. For-of: for (let x of arr)  →  for-i
    src = src.replace(/for\s*\(\s*(?:let|const|var)\s+(\w+)\s+of\s+([^)]+)\)/g, (m, v, a) => {
        const idx = '_idx' + (Math.random()*1000|0);
        return `for (var ${idx}=0; ${idx}<${a}.length; ${idx}++) { var ${v} = ${a}[${idx}]`;
    });

    // 4. Trailing commas before ) or ]
    src = src.replace(/,\s*\n(\s*)\)/g, '\n$1)');
    src = src.replace(/,\s*\n(\s*)\]/g, '\n$1]');

    // 5. Case fall-through: add explicit break + fallthrough marker
    //    This is the trickiest part. For switch cases with fallthrough,
    //    we merge consecutive cases when they share the same body.
    //    Pattern: case X:\n  stmt;\n  case Y: → we need to merge
    
    if (src !== original) {
        fs.writeFileSync(filePath, src, 'utf8');
        console.log(`FIXED: ${relPath}`);
    } else {
        console.log(`NOOP:  ${relPath}`);
    }
});

console.log('\nDone. Now re-run: node tools/js2coffee_batch.js');
