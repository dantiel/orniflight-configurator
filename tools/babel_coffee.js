#!/usr/bin/env node
// Babel + js2coffee pipeline: ES6+ JS → ES5 → CoffeeScript
'use strict';

const fs = require('fs');
const path = require('path');
const babel = require('@babel/core');
const js2coffee = require('js2coffee');

const SRC_DIR = path.join(__dirname, '..', 'src', 'js');
const results = { success: [], fail: [] };

function walkDir(dir, callback) {
    fs.readdirSync(dir, { withFileTypes: true }).forEach(dirent => {
        const full = path.join(dir, dirent.name);
        if (dirent.isDirectory()) walkDir(full, callback);
        else if (dirent.isFile() && dirent.name.endsWith('.js')) callback(full);
    });
}

walkDir(SRC_DIR, (filePath) => {
    const relPath = path.relative(SRC_DIR, filePath);
    try {
        const jsSource = fs.readFileSync(filePath, 'utf8');
        
        // Step 1: Babel transform ES6+ → ES5
        const babelResult = babel.transformSync(jsSource, {
            presets: [['@babel/preset-env', { targets: { ie: '11' }, modules: false }]],
            filename: filePath,
            compact: false,
            comments: true
        });
        
        // Step 1.5: Fix Babel-generated try/finally that js2coffee can't handle
        let es5Code = babelResult.code;
        es5Code = es5Code.replace(
            /try\s*\{\s*a\s*\|\|\s*null\s*==\s*t\.return\s*\|\|\s*t\.return\(\s*\)\s*;?\s*\}\s*finally\s*\{\s*if\s*\(\s*u\s*\)\s*throw\s*o\s*;?\s*\}/g,
            'if (a || null == t.return || t.return()); if (u) throw o;'
        );
        
        // Step 2: js2coffee transform ES5 → CoffeeScript
        const coffeeOutput = js2coffee.build(es5Code, {
            indent: '    ',
            show_src_lineno: false
        });
        
        const outPath = filePath.replace(/\.js$/, '.coffee');
        fs.writeFileSync(outPath, coffeeOutput.code + '\n', 'utf8');
        results.success.push(relPath);
        console.log(`OK ${relPath}`);
    } catch (err) {
        results.fail.push({ file: relPath, error: err.message });
        console.log(`FAIL ${relPath}: ${err.message}`);
    }
});

console.log(`\n=== SUMMARY ===`);
console.log(`Success: ${results.success.length}`);
console.log(`Failed:  ${results.fail.length}`);
if (results.fail.length > 0) {
    console.log(`\nFailed files:`);
    results.fail.forEach(f => console.log(`  ${f.file}: ${f.error}`));
}