'use strict';

var pkg = require('./package.json');
// remove gulp-appdmg from the package.json we're going to write
delete pkg.optionalDependencies['gulp-appdmg'];

const child_process = require('child_process');
const { execSync } = child_process;
const fs = require('fs');
const fse = require('fs-extra');
const https = require('https');
const path = require('path');

const zip = require('gulp-zip');
const del = require('del');
const makensis = require('makensis');
const deb = require('gulp-debian');
const buildRpm = require('rpm-builder');
const commandExistsSync = require('command-exists').sync;

const gulp = require('gulp');
const concat = require('gulp-concat');
const yarn = require("gulp-yarn");
const rename = require('gulp-rename');
const os = require('os');
const git = require('gulp-git');
const source = require('vinyl-source-stream');
const stream = require('stream');

const DIST_DIR = './dist/';
const APPS_DIR = './apps/';
const DEBUG_DIR = './debug/';
const RELEASE_DIR = './release/';

const LINUX_INSTALL_DIR = '/opt/betaflight';

// Global variable to hold the change hash from when we get it, to when we use it.
var gitChangeSetId;

var nwBuilderOptions = {
    version: '0.100.0',
    files: './dist/**/*',
    macIcns: './src/images/of_icon.icns',
    macPlist: { 'CFBundleDisplayName': 'OrniFlight Configurator'},
    winIco: './src/images/of_icon.ico',
    zip: false
};

//-----------------
//Pre tasks operations
//-----------------
const SELECTED_PLATFORMS = getInputPlatforms();

//-----------------
//Tasks
//-----------------

gulp.task('clean', gulp.parallel(clean_dist, clean_apps, clean_debug, clean_release));

gulp.task('clean-dist', clean_dist);

gulp.task('clean-docs', clean_docs);

gulp.task('clean-apps', clean_apps);

gulp.task('clean-debug', clean_debug);

gulp.task('clean-release', clean_release);

gulp.task('clean-cache', clean_cache);

// Function definitions are processed before function calls.
const getChangesetId = gulp.series(getHash, writeChangesetId);
gulp.task('get-changeset-id', getChangesetId);

// dist_yarn MUST be done after dist_src
var distBuild = gulp.series(dist_src, dist_scss, dist_coffee, dist_changelog, dist_haml, dist_yarn, dist_locale, dist_libraries, dist_resources, getChangesetId, dist_index);
var distRebuild = gulp.series(clean_dist, distBuild);
gulp.task('dist', distRebuild);

var appsBuild = gulp.series(gulp.parallel(clean_apps, distRebuild), apps, gulp.parallel(listPostBuildTasks(APPS_DIR)));
gulp.task('apps', appsBuild);

var docsBuild = gulp.series(clean_docs, distRebuild, copy_docs, bundle_vendor_docs);
gulp.task('docs', docsBuild);

var devBuild = gulp.series(clean_dist, distBuild, watch_and_serve);
gulp.task('dev', devBuild);

var debugBuild = gulp.series(distBuild, debug, gulp.parallel(listPostBuildTasks(DEBUG_DIR)), start_debug)
gulp.task('debug', debugBuild);

var releaseBuild = gulp.series(gulp.parallel(clean_release, appsBuild), gulp.parallel(listReleaseTasks()));
gulp.task('release', releaseBuild);

gulp.task('default', debugBuild);

// -----------------
// Helper functions
// -----------------

// Get platform from commandline args
// #
// # gulp <task> [<platform>]+        Run only for platform(s) (with <platform> one of --linux64, --linux32, --armv7, --osx64, --win32, --win64, or --chromeos)
// #
var gForceArm64 = false; // Set by --force-arm64 flag; overrides auto-detection
var gForceX64 = false;   // Set by --force-x64 flag; forces x64 even on Apple Silicon

function getInputPlatforms() {
    var supportedPlatforms = ['linux64', 'linux32', 'armv7', 'osx64', 'osx-arm64', 'win32','win64', 'chromeos'];
    var platforms = [];
    var regEx = /--(\w+)/;
    console.log(process.argv);
    for (var i = 3; i < process.argv.length; i++) {
        var arg = process.argv[i].match(regEx)[1];
        if (supportedPlatforms.indexOf(arg) > -1) {
            platforms.push(arg);
        } else if (arg == 'nowinicon') {
            console.log('ignoring winIco')
            delete nwBuilderOptions['winIco'];
        } else if (arg == 'force-arm64') {
            gForceArm64 = true;
        } else if (arg == 'force-x64') {
            gForceX64 = true;
        } else {
            console.log('Unknown platform: ' + arg);
            process.exit();
        }
    }

    if (platforms.length === 0) {
        var defaultPlatform = getDefaultPlatform();
        if (supportedPlatforms.indexOf(defaultPlatform) > -1) {
            platforms.push(defaultPlatform);
        } else {
            console.error(`Your current platform (${os.platform()}) is not a supported build platform. Please specify platform to build for on the command line.`);
            process.exit();
        }
    }

    if (platforms.length > 0) {
        console.log('Building for platform(s): ' + platforms + '.');
    } else {
        console.error('No suitables platforms found.');
        process.exit();
    }

    return platforms;
}

// Gets the default platform to be used.
// On macOS, always defaults to osx64 (x86_64). Use --force-arm64 for native ARM64 builds.
function getDefaultPlatform() {
    var defaultPlatform;
    switch (os.platform()) {
    case 'darwin':
        // Apple Silicon Macs default to ARM64 native, Intel Macs to x64
        var isAppleSilicon = os.cpus().length > 0 && os.cpus()[0].model.indexOf('Apple') !== -1;
        if (gForceX64) {
            defaultPlatform = 'osx64';
        } else if (gForceArm64 || isAppleSilicon) {
            defaultPlatform = 'osx-arm64';
        } else {
            defaultPlatform = 'osx64';
        }
        break;
    case 'linux':
        defaultPlatform = 'linux64';

        break;
    case 'win32':
        defaultPlatform = 'win32';

        break;

    default:
        defaultPlatform = '';

        break;
    }
    return defaultPlatform;
}


function getPlatforms() {
    return SELECTED_PLATFORMS.slice();
}

function removeItem(platforms, item) {
    var index = platforms.indexOf(item);
    if (index >= 0) {
        platforms.splice(index, 1);
    }
}

function getRunDebugAppCommand(arch) {
    switch (arch) {
    case 'osx64':
    case 'osx-arm64':
        return 'open ' + path.join(DEBUG_DIR, pkg.name, arch, pkg.name + '.app');

        break;

    case 'linux64':
    case 'linux32':
    case 'armv7':
        return path.join(DEBUG_DIR, pkg.name, arch, pkg.name);

        break;

    case 'win32':
    case 'win64':
        return path.join(DEBUG_DIR, pkg.name, arch, pkg.name + '.exe');

        break;

    default:
        return '';

        break;
    }
}

function getReleaseFilename(platform, ext) {
    return `${pkg.name}_${pkg.version}_${platform}.${ext}`;
}

function clean_dist() {
    return del([DIST_DIR + '**'], { force: true });
}

function clean_apps() {
    return del([APPS_DIR + '**'], { force: true });
}

function clean_debug() {
    return del([DEBUG_DIR + '**'], { force: true });
}

function clean_release() {
    return del([RELEASE_DIR + '**'], { force: true });
}

function clean_docs() {
    return del(['./docs/**'], { force: true });
}

function clean_cache() {
    return del(['./cache/**'], { force: true });
}

// Real work for dist task. Done in another task to call it via
// run-sequence.
function dist_src() {
    var distSources = [
        './src/**/*',
        '!./src/**/*.haml',
        '!./src/**/*.scss',
        '!./src/**/*.sass',
        '!./src/**/*.coffee',
        '!./src/css/dropdown-lists/LICENSE',
        '!./src/css/font-awesome/css/font-awesome.css',
        '!./src/css/opensans_webfontkit/*.{txt,html}',
        '!./src/support/**'
    ];
    var packageJson = new stream.Readable;
    packageJson.push(JSON.stringify(pkg,undefined,2));
    packageJson.push(null);

    return packageJson
        .pipe(source('package.json'))
        .pipe(gulp.src(distSources, { base: 'src' }))
        .pipe(gulp.src('manifest.json', { passthrougth: true }))
        .pipe(gulp.src('yarn.lock', { passthrougth: true }))
        .pipe(gulp.dest(DIST_DIR));
}

// Compile Sass → CSS
function dist_scss(done) {
    const glob = require('glob');
    // Compile .sass (primary) + remaining .scss (vendor files)
    const sassFiles = glob.sync('src/**/*.sass');
    const remainingScss = glob.sync('src/**/*.scss');
    const allStyleFiles = [...sassFiles, ...remainingScss];
    console.log('Compiling ' + sassFiles.length + ' Sass + ' + remainingScss.length + ' SCSS files...');

    allStyleFiles.forEach(styleFile => {
        const relPath = path.relative('src', styleFile);
        const outPath = path.join(DIST_DIR, relPath.replace(/\.(sass|scss)$/, '.css'));
        const outDir = path.dirname(outPath);

        if (!fs.existsSync(outDir)) {
            fs.mkdirSync(outDir, { recursive: true });
        }

        try {
            execSync('sass --no-source-map --style=compressed "' + styleFile + '" "' + outPath + '"', { stdio: 'pipe' });
        } catch (e) {
            console.error('Sass error in ' + styleFile + ':');
            console.error(e.stderr ? e.stderr.toString() : e.message);
            throw e;
        }
    });

    console.log('  ✓ ' + allStyleFiles.length + ' stylesheets compiled');
    done();
}

// Compile CoffeeScript → JavaScript
function dist_coffee(done) {
    const glob = require('glob');
    const coffeeFiles = glob.sync('src/**/*.coffee');
    console.log('Compiling ' + coffeeFiles.length + ' CoffeeScript files...');

    coffeeFiles.forEach(coffeeFile => {
        const relPath = path.relative('src', coffeeFile);
        const outPath = path.join(DIST_DIR, relPath.replace(/\.coffee$/, '.js'));
        const outDir = path.dirname(outPath);

        if (!fs.existsSync(outDir)) {
            fs.mkdirSync(outDir, { recursive: true });
        }

        try {
            // Compile to temp location, then move to dist
            const tmpDir = path.join(os.tmpdir(), 'orni_coffee_' + Date.now());
            if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });
            execSync('coffee -b -c -o "' + tmpDir + '" "' + coffeeFile + '"', { stdio: 'pipe' });
            const tmpJs = path.join(tmpDir, path.basename(coffeeFile, '.coffee') + '.js');
            if (fs.existsSync(tmpJs)) {
                fs.renameSync(tmpJs, outPath);
            }
            fs.rmdirSync(tmpDir, { recursive: true });
        } catch (e) {
            console.error('CoffeeScript error in ' + coffeeFile + ':');
            console.error(e.stderr ? e.stderr.toString() : e.message);
            throw e;
        }
    });

    console.log('  ✓ ' + coffeeFiles.length + ' CoffeeScript files compiled');
    done();
}

function dist_changelog(done) {
    // Compile changelog.haml → changelog.html in dist/tabs/
    const outDir = DIST_DIR + 'tabs/';
    if (!fs.existsSync(outDir)) {
        fs.mkdirSync(outDir, { recursive: true });
    }
    execSync('ruby tools/haml_compile.rb changelog.haml "' + outDir + 'changelog.html"', { stdio: 'pipe' });
    console.log('  ✓ changelog.haml compiled');
    done();
}

// Compile HAML templates to HTML in dist/
function dist_haml(done) {
    const glob = require('glob');
    const path = require('path');

    const hamlFiles = glob.sync('src/**/*.haml');
    console.log(`Compiling ${hamlFiles.length} HAML templates...`);

    hamlFiles.forEach(hamlFile => {
        const relPath = path.relative('src', hamlFile);
        const outPath = path.join(DIST_DIR, relPath.replace(/\.haml$/, '.html'));
        const outDir = path.dirname(outPath);

        if (!fs.existsSync(outDir)) {
            fs.mkdirSync(outDir, { recursive: true });
        }

        try {
            execSync('ruby tools/haml_compile.rb "' + hamlFile + '" "' + outPath + '"', { stdio: 'pipe' });
        } catch (e) {
            console.error('HAML error in ' + hamlFile + ':');
            console.error(e.stderr ? e.stderr.toString() : e.message);
            throw e;
        }
    });

    console.log('  ✓ ' + hamlFiles.length + ' HAML templates compiled');
    done();
}

// This function relies on files from the dist_src function
function dist_yarn() {
    return gulp.src(['./dist/package.json', './dist/yarn.lock'])
        .pipe(gulp.dest('./dist'))
        .pipe(yarn({
            production: true,
            ignoreEngines: true
        }));
}

function dist_locale() {
    return gulp.src('./locales/**/*', { base: 'locales'})
        .pipe(gulp.dest(DIST_DIR + '_locales'));
}

function dist_libraries() {
    return gulp.src('./libraries/**/*', { base: '.'})
        .pipe(gulp.dest(DIST_DIR + 'js'));
}

function dist_resources() {
    return gulp.src(['./resources/**/*', '!./resources/osd/**/*.png'], { base: '.'})
        .pipe(gulp.dest(DIST_DIR));
}

// Create runable app directories in ./apps
function apps(done) {
    var platforms = getPlatforms();
    removeItem(platforms, 'chromeos');

    buildNWAppsWrapper(platforms, 'normal', APPS_DIR, done);
}

function listPostBuildTasks(folder, done) {

    var platforms = getPlatforms();

    var postBuildTasks = [];

    if (platforms.indexOf('linux32') != -1) {
        postBuildTasks.push(function post_build_linux32(done) {
            return post_build('linux32', folder, done);
        });
    }

    if (platforms.indexOf('linux64') != -1) {
        postBuildTasks.push(function post_build_linux64(done) {
            return post_build('linux64', folder, done);
        });
    }

    if (platforms.indexOf('armv7') != -1) {
        postBuildTasks.push(function post_build_armv7(done) {
            return post_build('armv7', folder, done);
        });
    }

    // We need to return at least one task, if not gulp will throw an error
    if (postBuildTasks.length == 0) {
        postBuildTasks.push(function post_build_none(done) {
            done();
        });
    }
    return postBuildTasks;
}

function post_build(arch, folder, done) {

    if ((arch === 'linux32') || (arch === 'linux64')) {
        // Copy Ubuntu launcher scripts to destination dir
        var launcherDir = path.join(folder, pkg.name, arch);
        console.log('Copy Ubuntu launcher scripts to ' + launcherDir);
        return gulp.src('assets/linux/**')
                   .pipe(gulp.dest(launcherDir));
    }

    // NW.js 0.114.0 provides official linux-arm64 builds — no directory renaming needed
    return done();
}

// Create debug app directories in ./debug
function debug(done) {
    var platforms = getPlatforms();
    removeItem(platforms, 'chromeos');

    buildNWAppsWrapper(platforms, 'sdk', DEBUG_DIR, done);
}

// NW.js 0.114.0 uses official linux-arm64 builds — no third-party ARM binaries needed.
// The injectARMCache function and all ARM cache injection logic is removed.

/**
 * Map old platform strings to nw-builder v4 {platform, arch} pairs.
 * Also returns the NW.js download URL components.
 */
function mapPlatformToV4(oldPlatform) {
    switch (oldPlatform) {
    case 'osx64':
        return { platform: 'osx', arch: 'x64' };
    case 'osx-arm64':
        return { platform: 'osx', arch: 'arm64' };
    case 'linux64':
        return { platform: 'linux', arch: 'x64' };
    case 'linux32':
        return { platform: 'linux', arch: 'ia32' };
    case 'armv7':
        return { platform: 'linux', arch: 'arm64' };
    case 'win32':
        return { platform: 'win', arch: 'ia32' };
    case 'win64':
        return { platform: 'win', arch: 'x64' };
    default:
        console.warn('Unknown platform: ' + oldPlatform + ' — defaulting to linux/x64');
        return { platform: 'linux', arch: 'x64' };
    }
}

/**
 * Get the NW.js download URL for a given version, flavor, platform, and arch.
 */
function getNwjsDownloadUrl(version, flavor, platform, arch) {
    var ext = (platform === 'linux') ? 'tar.gz' : 'zip';
    var flavorSuffix = (flavor === 'sdk') ? '-sdk' : '';
    return 'https://dl.nwjs.io/v' + version +
        '/nwjs' + flavorSuffix + '-v' + version +
        '-' + platform + '-' + arch + '.' + ext;
}

/**
 * Assemble the NW.js application manually — no nw-builder dependency needed.
 * This bypasses the nw-builder v4 ESM/Node 18 requirement.
 */
function assembleNWApp(platform, arch, flavor, outDir, done) {
    var version = nwBuilderOptions.version;
    var flavorSuffix = (flavor === 'sdk') ? '-sdk' : '';
    var cacheKey = 'nwjs' + flavorSuffix + '-v' + version + '-' + platform + '-' + arch;
    var cacheDir = path.join('./cache', cacheKey);

    console.log('Assembling NW.js app: ' + platform + '/' + arch + ' → ' + outDir);

    // Step 1: Ensure NW.js runtime is cached
    ensureNwjsCached(version, flavor, platform, arch, cacheDir, function(err) {
        if (err) {
            console.error('Failed to cache NW.js: ' + err);
            done(err);
            return;
        }

        // Step 2: Copy NW.js runtime to output
        fse.copySync(cacheDir, outDir);

        // Step 3: Inject app.nw (dist/ contents)
        if (platform === 'osx') {
            var appNwDir = path.join(outDir, 'nwjs.app', 'Contents', 'Resources', 'app.nw');
            fse.copySync('./dist/', appNwDir);

            // Customize Info.plist
            var plistPath = path.join(outDir, 'nwjs.app', 'Contents', 'Info.plist');
            customizeMacPlist(plistPath);

            // Rename .app
            var oldApp = path.join(outDir, 'nwjs.app');
            var newApp = path.join(outDir, pkg.name + '.app');
            if (fs.existsSync(newApp)) {
                fse.removeSync(newApp);
            }
            fs.renameSync(oldApp, newApp);

            // Copy icon
            if (nwBuilderOptions.macIcns && fs.existsSync(nwBuilderOptions.macIcns)) {
                var iconDest = path.join(newApp, 'Contents', 'Resources', 'app.icns');
                fse.copySync(nwBuilderOptions.macIcns, iconDest);
            }
        } else if (platform === 'linux') {
            var appNwDir = path.join(outDir, 'package.nw');
            fse.copySync('./dist/', appNwDir);
        } else if (platform === 'win') {
            var appNwDir = path.join(outDir, 'package.nw');
            fse.copySync('./dist/', appNwDir);
        }

        console.log('  ✓ Assembled: ' + outDir);
        done();
    });
}

/**
 * Download and cache NW.js runtime if not already cached.
 */
function ensureNwjsCached(version, flavor, platform, arch, cacheDir, done) {
    if (fs.existsSync(cacheDir)) {
        console.log('  NW.js runtime cached: ' + cacheDir);
        done();
        return;
    }

    console.log('  Downloading NW.js ' + version + ' ' + platform + '/' + arch + '...');

    var url = getNwjsDownloadUrl(version, flavor, platform, arch);
    var downloadDir = './cache/_dl/';
    if (!fs.existsSync(downloadDir)) {
        fs.mkdirSync(downloadDir, { recursive: true });
    }

    var ext = (platform === 'win') ? 'zip' : 'tar.gz';
    var archivePath = path.join(downloadDir, 'nwjs-' + platform + '-' + arch + '.' + ext);

    // Download
    var file = fs.createWriteStream(archivePath);
    https.get(url, function(response) {
        // Follow redirects
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
            https.get(response.headers.location, function(redirectRes) {
                redirectRes.pipe(file);
                file.on('finish', function() {
                    file.close(function() {
                        extractAndCache(archivePath, cacheDir, platform, done);
                    });
                });
            });
        } else {
            response.pipe(file);
            file.on('finish', function() {
                file.close(function() {
                    extractAndCache(archivePath, cacheDir, platform, done);
                });
            });
        }
    }).on('error', function(err) {
        done(err);
    });
}

function extractAndCache(archivePath, cacheDir, platform, done) {
    console.log('  Extracting to: ' + cacheDir);

    var tmpExtract = cacheDir + '_tmp/';
    if (fs.existsSync(tmpExtract)) {
        fse.removeSync(tmpExtract);
    }
    fs.mkdirSync(tmpExtract, { recursive: true });

    if (archivePath.endsWith('.tar.gz')) {
        // Use tar command
        child_process.exec('tar -xzf "' + archivePath + '" -C "' + tmpExtract + '"', function(err) {
            if (err) { done(err); return; }
            finalizeExtract(tmpExtract, cacheDir, done);
        });
    } else if (archivePath.endsWith('.zip')) {
        child_process.exec('unzip -qo "' + archivePath + '" -d "' + tmpExtract + '"', function(err) {
            if (err) { done(err); return; }
            finalizeExtract(tmpExtract, cacheDir, done);
        });
    } else {
        done(new Error('Unknown archive format: ' + ext));
    }
}

function finalizeExtract(tmpExtract, cacheDir, done) {
    // NW.js extracts to a single subdirectory — move contents up
    var entries = fs.readdirSync(tmpExtract);
    var srcDir = path.join(tmpExtract, entries[0]);
    if (fs.existsSync(cacheDir)) {
        fse.removeSync(cacheDir);
    }
    fs.renameSync(srcDir, cacheDir);
    fse.removeSync(tmpExtract);
    console.log('  Cached: ' + cacheDir);
    done();
}

function customizeMacPlist(plistPath) {
    if (!fs.existsSync(plistPath)) return;
    var content = fs.readFileSync(plistPath, 'utf8');
    // Replace nwjs-specific entries with OrniFlight branding
    content = content.replace(/<key>CFBundleDisplayName<\/key>\s*\n\s*<string>[^<]*<\/string>/,
        '<key>CFBundleDisplayName</key>\n\t<string>OrniFlight Configurator</string>');
    content = content.replace(/<key>CFBundleName<\/key>\s*\n\s*<string>[^<]*<\/string>/,
        '<key>CFBundleName</key>\n\t<string>OrniFlight Configurator</string>');
    content = content.replace(/<key>CFBundleIdentifier<\/key>\s*\n\s*<string>[^<]*<\/string>/,
        '<key>CFBundleIdentifier</key>\n\t<string>com.orniflight.configurator</string>');
    fs.writeFileSync(plistPath, content);
}

function buildNWAppsWrapper(platforms, flavor, dir, done) {
    buildNWApps(platforms, flavor, dir, done);
}

function buildNWApps(platforms, flavor, dir, done) {
    if (platforms.length > 0) {
        var pending = platforms.length;
        var hasError = false;

        platforms.forEach(function(p) {
            var v4 = mapPlatformToV4(p);
            var outDir = path.join(dir, pkg.name, p);

            // Clean existing output
            if (fs.existsSync(outDir)) {
                fse.removeSync(outDir);
            }
            fs.mkdirSync(outDir, { recursive: true });

            console.log('Building NW app: ' + p + ' → ' + v4.platform + '/' + v4.arch);
            assembleNWApp(v4.platform, v4.arch, flavor, outDir, function(err) {
                if (err && !hasError) {
                    hasError = true;
                    console.log('Error building NW apps: ' + err);
                    clean_debug();
                    done(err);
                    return;
                }
                pending--;
                if (pending === 0 && !hasError) {
                    done();
                }
            });
        });
    } else {
        console.log('No platform suitable for NW Build');
        done();
    }
}

function getHash(cb) {
    git.revParse({args: '--short HEAD'}, function (err, hash) {
        if (err) {
            gitChangeSetId = 'unsupported';
        } else {
            gitChangeSetId = hash;
        }
        cb();
    });
}

function writeChangesetId() {
    var versionJson = new stream.Readable;
    versionJson.push(JSON.stringify({
        gitChangesetId: gitChangeSetId,
        version: pkg.version
        }, undefined, 2));
    versionJson.push(null);
    return versionJson
        .pipe(source('version.json'))
        .pipe(gulp.dest(DIST_DIR))
}

function start_debug(done) {

    var platforms = getPlatforms();

    var exec = require('child_process').exec;
    if (platforms.length === 1) {
        var run = getRunDebugAppCommand(platforms[0]);
        console.log('Starting debug app (' + run + ')...');
        exec(run);
    } else {
        console.log('More than one platform specified, not starting debug app');
    }
    done();
}

// Create installer package for windows platforms
function release_win(arch, done) {

    // Check if makensis exists
    if (!commandExistsSync('makensis')) {
        console.warn('makensis command not found, not generating win package for ' + arch);
        return done();
    }

    // The makensis does not generate the folder correctly, manually
    createDirIfNotExists(RELEASE_DIR);

    // Parameters passed to the installer script
    const options = {
            verbose: 2,
            define: {
                'VERSION': pkg.version,
                'PLATFORM': arch,
                'DEST_FOLDER': RELEASE_DIR
            }
        }

    var output = makensis.compileSync('./assets/windows/installer.nsi', options);

    if (output.status !== 0) {
        console.error('Installer for platform ' + arch + ' finished with error ' + output.status + ': ' + output.stderr);
    }

    done();
}

// Create distribution package (zip) for windows and linux platforms
function release_zip(arch) {
    var src = path.join(APPS_DIR, pkg.name, arch, '**');
    var output = getReleaseFilename(arch, 'zip');
    var base = path.join(APPS_DIR, pkg.name, arch);

    return compressFiles(src, base, output, 'Betaflight Configurator');
}

// Create distribution package for chromeos platform
function release_chromeos() {
    var src = path.join(DIST_DIR, '**');
    var output = getReleaseFilename('chromeos', 'zip');
    var base = DIST_DIR;

    return compressFiles(src, base, output, '.');
}

// Compress files from srcPath, using basePath, to outputFile in the RELEASE_DIR
function compressFiles(srcPath, basePath, outputFile, zipFolder) {
    return gulp.src(srcPath, { base: basePath })
               .pipe(rename(function(actualPath) {
                   actualPath.dirname = path.join(zipFolder, actualPath.dirname);
               }))
               .pipe(zip(outputFile))
               .pipe(gulp.dest(RELEASE_DIR));
}

function release_deb(arch, done) {

    // Check if dpkg-deb exists
    if (!commandExistsSync('dpkg-deb')) {
        console.warn('dpkg-deb command not found, not generating deb package for ' + arch);
        return done();
    }

    return gulp.src([path.join(APPS_DIR, pkg.name, arch, '*')])
        .pipe(deb({
             package: pkg.name,
             version: pkg.version,
             section: 'base',
             priority: 'optional',
             architecture: getLinuxPackageArch('deb', arch),
             maintainer: pkg.author,
             description: pkg.description,
             preinst: [`rm -rf ${LINUX_INSTALL_DIR}/${pkg.name}`],
             postinst: [`chown root:root ${LINUX_INSTALL_DIR}`, `chown -R root:root ${LINUX_INSTALL_DIR}/${pkg.name}`, `xdg-desktop-menu install ${LINUX_INSTALL_DIR}/${pkg.name}/${pkg.name}.desktop`],
             prerm: [`xdg-desktop-menu uninstall ${pkg.name}.desktop`],
             depends: 'libgconf-2-4',
             changelog: [],
             _target: `${LINUX_INSTALL_DIR}/${pkg.name}`,
             _out: RELEASE_DIR,
             _copyright: 'assets/linux/copyright',
             _clean: true
    }));
}

function release_rpm(arch, done) {

    // Check if dpkg-deb exists
    if (!commandExistsSync('rpmbuild')) {
        console.warn('rpmbuild command not found, not generating rpm package for ' + arch);
        return done();
    }

    // The buildRpm does not generate the folder correctly, manually
    createDirIfNotExists(RELEASE_DIR);

    var regex = /-/g;

    var options = {
             name: pkg.name,
             version: pkg.version.replace(regex, '_'), // RPM does not like release candidate versions
             buildArch: getLinuxPackageArch('rpm', arch),
             vendor: pkg.author,
             summary: pkg.description,
             license: 'GNU General Public License v3.0',
             requires: 'libgconf-2-4',
             prefix: '/opt',
             files:
                 [ { cwd: path.join(APPS_DIR, pkg.name, arch),
                     src: '*',
                     dest: `${LINUX_INSTALL_DIR}/${pkg.name}` } ],
             postInstallScript: [`xdg-desktop-menu install ${LINUX_INSTALL_DIR}/${pkg.name}/${pkg.name}.desktop`],
             preUninstallScript: [`xdg-desktop-menu uninstall ${pkg.name}.desktop`],
             tempDir: path.join(RELEASE_DIR,'tmp-rpm-build-' + arch),
             keepTemp: false,
             verbose: false,
             rpmDest: RELEASE_DIR,
             execOpts: { maxBuffer: 1024 * 1024 * 16 },
    };

    buildRpm(options, function(err, rpm) {
        if (err) {
          console.error("Error generating rpm package: " + err);
        }
        done();
    });
}

function getLinuxPackageArch(type, arch) {
    var packArch;

    switch (arch) {
    case 'linux32':
        packArch = 'i386';
        break;
    case 'linux64':
        if (type == 'rpm') {
            packArch = 'x86_64';
        } else {
            packArch = 'amd64';
        }
        break;
    default:
        console.error("Package error, arch: " + arch);
        process.exit(1);
        break;
    }

    return packArch;
}
// Create distribution package for macOS platform
function release_osx64() {
    var appdmg = require('gulp-appdmg');

    // The appdmg does not generate the folder correctly, manually
    createDirIfNotExists(RELEASE_DIR);

    // The src pipe is not used
    return gulp.src(['.'])
        .pipe(appdmg({
            target: path.join(RELEASE_DIR, getReleaseFilename('macOS', 'dmg')),
            basepath: path.join(APPS_DIR, pkg.name, 'osx64'),
            specification: {
                title: 'OrniFlight Configurator',
                contents: [
                    { 'x': 448, 'y': 342, 'type': 'link', 'path': '/Applications' },
                    { 'x': 192, 'y': 344, 'type': 'file', 'path': pkg.name + '.app', 'name': 'OrniFlight Configurator.app' }
                ],
                background: path.join(__dirname, 'assets/osx/dmg-background.png'),
                format: 'UDZO',
                window: {
                    size: {
                        width: 638,
                        height: 479
                    }
                }
            },
        })
    );
}

function release_osx_arm64() {
    var appdmg = require('gulp-appdmg');

    createDirIfNotExists(RELEASE_DIR);

    return gulp.src(['.'])
        .pipe(appdmg({
            target: path.join(RELEASE_DIR, getReleaseFilename('macOS-ARM64', 'dmg')),
            basepath: path.join(APPS_DIR, pkg.name, 'osx-arm64'),
            specification: {
                title: 'OrniFlight Configurator',
                contents: [
                    { 'x': 448, 'y': 342, 'type': 'link', 'path': '/Applications' },
                    { 'x': 192, 'y': 344, 'type': 'file', 'path': pkg.name + '.app', 'name': 'OrniFlight Configurator.app' }
                ],
                background: path.join(__dirname, 'assets/osx/dmg-background.png'),
                format: 'UDZO',
                window: {
                    size: {
                        width: 638,
                        height: 479
                    }
                }
            },
        })
    );
}

// Create the dir directory, with write permissions
function createDirIfNotExists(dir) {
    fs.mkdir(dir, '0775', function(err) {
        if (err) {
            if (err.code !== 'EEXIST') {
                throw err;
            }
        }
    });
}

// Create a list of the gulp tasks to execute for release
function listReleaseTasks(done) {

    var platforms = getPlatforms();

    var releaseTasks = [];

    if (platforms.indexOf('chromeos') !== -1) {
        releaseTasks.push(release_chromeos);
    }

    if (platforms.indexOf('linux64') !== -1) {
        releaseTasks.push(function release_linux64_zip() {
            return release_zip('linux64');
        });
        releaseTasks.push(function release_linux64_deb(done) {
            return release_deb('linux64', done);
        });
        releaseTasks.push(function release_linux64_rpm(done) {
            return release_rpm('linux64', done);
        });
    }

    if (platforms.indexOf('linux32') !== -1) {
        releaseTasks.push(function release_linux32_zip() {
            return release_zip('linux32');
        });
        releaseTasks.push(function release_linux32_deb(done) {
            return release_deb('linux32', done);
        });
        releaseTasks.push(function release_linux32_rpm(done) {
            return release_rpm('linux32', done);
        });
    }

    if (platforms.indexOf('armv7') !== -1) {
        releaseTasks.push(function release_armv7_zip() {
            return release_zip('armv7');
        });
    }

    if (platforms.indexOf('osx64') !== -1 || platforms.indexOf('osx-arm64') !== -1) {
        releaseTasks.push(platforms.indexOf('osx-arm64') !== -1 ? release_osx_arm64 : release_osx64);
    }

    if (platforms.indexOf('win32') !== -1) {
        releaseTasks.push(function release_win32(done) {
            return release_win('win32', done);
        });
    }

    if (platforms.indexOf('win64') !== -1) {
        releaseTasks.push(function release_win64(done) {
            return release_win('win64', done);
        });
    }

    return releaseTasks;
}

// -----------------
//  Docs — GitHub Pages deployment
// -----------------

function copy_docs(done) {
    var fse = require('fs-extra');
    var path = require('path');
    var DOCS_DIR = './docs/';

    console.log('Copying dist/ → docs/ for GitHub Pages...');

    // Copy entire dist, then remove NW.js-specific files
    fse.copySync('./dist/', DOCS_DIR);

    // Remove NW.js-only files that don't belong in browser
    var removeFiles = ['main_nwjs.html', 'manifest.json', 'package.json', 'yarn.lock'];
    removeFiles.forEach(function(f) {
        var fp = path.join(DOCS_DIR, f);
        if (fs.existsSync(fp)) fs.unlinkSync(fp);
    });

    // Create index.html from main.html (GitHub Pages entry point)
    var mainPath = path.join(DOCS_DIR, 'main.html');
    var indexPath = path.join(DOCS_DIR, 'index.html');
    if (fs.existsSync(mainPath)) {
        fs.copyFileSync(mainPath, indexPath);
        console.log('  ✓ ' + indexPath + ' created');
    }

    console.log('  ✓ docs/ ready for GitHub Pages');
    done();
}

// Bundle the node_modules/ vendor files that dist/index.html references via
// ./node_modules/<pkg>/<file>. dist_yarn installs them into dist/node_modules,
// but node_modules/ is gitignored, so GitHub Pages would 404 them. Copy the
// referenced packages into a tracked docs/js/libraries/vendor/ location and
// rewrite the HTML references to match.
function bundle_vendor_docs(done) {
    var fse = require('fs-extra');
    var path = require('path');
    var DOCS_DIR = './docs/';

    console.log('Bundling node_modules vendor files into docs/...');

    // Every package referenced by ./node_modules/ in the served HTML.
    var vendorPackages = [
        'jbox',
        'lru_map',
        'i18next',
        'i18next-xhr-backend',
        'marked',
        'universal-ga',
        'short-unique-id',
        'object-hash',
        'jquery',
        'jquery-ui-npm',
        'bluebird',
        'inflection',
        'jquery-textcomplete'
    ];

    var vendorDest = path.join(DOCS_DIR, 'js', 'libraries', 'vendor');
    fse.ensureDirSync(vendorDest);

    vendorPackages.forEach(function(pkg) {
        // Prefer the yarn-installed dist copy (exact version dist/index.html
        // was built against), fall back to the root node_modules.
        var src = path.join('./dist/node_modules', pkg);
        if (!fs.existsSync(src)) src = path.join('./node_modules', pkg);

        if (fs.existsSync(src)) {
            fse.copySync(src, path.join(vendorDest, pkg));
        } else {
            console.log('  WARN: vendor package not found, skipping: ' + pkg);
        }
    });

    // Rewrite ./node_modules/ -> ./js/libraries/vendor/ in the served HTML.
    ['index.html', 'main.html'].forEach(function(f) {
        var fp = path.join(DOCS_DIR, f);
        if (!fs.existsSync(fp)) return;

        var content = fs.readFileSync(fp, 'utf8');
        var replaced = content.split('./node_modules/').join('./js/libraries/vendor/');
        if (replaced !== content) {
            fs.writeFileSync(fp, replaced);
            console.log('  ✓ ' + f + ' vendor paths rewritten');
        }
    });

    console.log('  ✓ vendor bundle ready for GitHub Pages');
    done();
}

// -----------------
//  index.html for dist/ (browser convenience)
// -----------------

function dist_index(done) {
    var path = require('path');
    var mainPath = path.join(DIST_DIR, 'main.html');
    var indexPath = path.join(DIST_DIR, 'index.html');
    if (fs.existsSync(mainPath)) {
        fs.copyFileSync(mainPath, indexPath);
        console.log('  ✓ dist/index.html created');
    }
    done();
}

// -----------------
//  Dev — watch + HTTP server for browser development
// -----------------

function watch_and_serve(done) {
    var http = require('http');
    var fs = require('fs');
    var path = require('path');
    var execSync = require('child_process').execSync;
    var glob = require('glob');

    var PORT = 3000;
    var DIST_DIR = path.resolve('./dist/');

    // ---- Watch for source changes ----
    console.log('Watching for changes...');
    var watchFn = function() {
        var sassFiles = glob.sync('src/**/*.sass');
        var scssFiles = glob.sync('src/**/*.scss');
        var coffeeFiles = glob.sync('src/**/*.coffee');
        var hamlFiles = glob.sync('src/**/*.haml');
        var allSrc = [].concat(sassFiles, scssFiles, coffeeFiles, hamlFiles);

        allSrc.forEach(function(f) {
            fs.watchFile(f, { interval: 500 }, function(curr, prev) {
                if (curr.mtime !== prev.mtime) {
                    var rel = path.relative('src', f);
                    console.log('  Changed: ' + rel);
                    try {
                        if (f.match(/\.sass$/)) {
                            var out = path.join(DIST_DIR, rel.replace(/\.sass$/, '.css'));
                            execSync('sass --no-source-map --style=compressed "' + f + '" "' + out + '"', { stdio: 'pipe' });
                        } else if (f.match(/\.coffee$/)) {
                            var out = path.join(DIST_DIR, rel.replace(/\.coffee$/, '.js'));
                            execSync('npx coffee -b -c -p "' + f + '" > "' + out + '"', { stdio: 'pipe' });
                        } else if (f.match(/\.haml$/)) {
                            var out = path.join(DIST_DIR, rel.replace(/\.haml$/, '.html'));
                            execSync('ruby tools/haml_compile.rb "' + f + '" "' + out + '"', { stdio: 'pipe' });
                        }
                    } catch(e) {
                        console.error('  ✗ ' + (e.stderr ? e.stderr.toString() : e.message));
                    }
                }
            });
        });
    };
    watchFn();

    // ---- HTTP server ----
    var mimeTypes = {
        '.html': 'text/html',
        '.js': 'application/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
        '.png': 'image/png',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon',
        '.woff': 'font/woff',
        '.woff2': 'font/woff2'
    };

    var server = http.createServer(function(req, res) {
        var urlPath = req.url.split('?')[0];
        if (urlPath === '/') urlPath = '/main.html';
        var filePath = path.join(DIST_DIR, urlPath);
        var ext = path.extname(filePath);

        fs.readFile(filePath, function(err, data) {
            if (err) {
                res.writeHead(404, { 'Content-Type': 'text/plain' });
                res.end('Not found: ' + urlPath);
                return;
            }
            res.writeHead(200, {
                'Content-Type': mimeTypes[ext] || 'application/octet-stream',
                'Access-Control-Allow-Origin': '*'
            });
            res.end(data);
        });
    });

    server.listen(PORT, function() {
        console.log('  ✓ Dev server: http://localhost:' + PORT + '  (Ctrl+C to stop)');
        console.log('  ✓ Watching ' + glob.sync('src/**/*.{sass,scss,coffee,haml}').length + ' source files');
    });

    done();
}