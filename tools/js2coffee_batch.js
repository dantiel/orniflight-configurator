#!/usr/bin/env node
// Batch JS → CoffeeScript converter using js2coffee API
'use strict';

const fs = require('fs');
const path = require('path');
const js2coffee = require('js2coffee');

const SRC_DIR = path.join(__dirname, '..', 'src', 'js');
const results = { success: [], fail: [] };

function walkDir(dir, callback) {
    fs.readdirSync(dir, { withFileTypes: true }).forEach(dirent => {
        const full = path.join(dir, dirent.name);
        if (dirent.isDirectory()) {
            walkDir(full, callback);
        } else if (dirent.isFile() && dirent.name.endsWith('.js')) {
            callback(full);
        }
    });
}

walkDir(SRC_DIR, (filePath) => {
    const relPath = path.relative(SRC_DIR, filePath);
    try {
        const jsSource = fs.readFileSync(filePath, 'utf8');
        const opts = { indent: '    ', show_src_lineno: false };
        const coffeeOutput = js2coffee.build(jsSource, opts);
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
