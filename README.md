# OrniFlight Configurator

![Betaflight](of_logo.jpg)

OrniFlight Configurator is a crossplatform configuration tool for the OrniFlight flight control system.

It runs as an app within Google Chrome and allows you to configure the OrniFlight software running on any [supported OrniFlight target](https://github.com/dantiel/orniflight/tree/master/src/main/target).

There is also now a standalone version available, since Google Chrome Apps are getting deprecated on platforms that aren't Chrome OS. [Downloads are available in Releases.](https://github.com/dantiel/orniflight-configurator/releases)

Various types of flapping aircraft are supported by the tool and by OrniFlight, e.g. twin flapters, quad flapters, etc.

## Authors

OrniFlight Configurator is a [fork](#credits) of the Betaflight Configurator with support for OrniFlight instead of Betaflight.

This configurator is the only configurator with support for OrniFlight specific features. It will likely require that you run the latest firmware on the flight controller.
If you are experiencing any problems please make sure you are running the [latest firmware version](https://github.com/dantiel/orniflight/releases/).

## Installation

### Standalone

**This is the default installation method, and at some point in the future this will become the only way available for most platforms. Please use this method whenever possible.**

Download the installer from [Releases.](https://github.com/dantiel/orniflight-configurator/releases)

#### Note for MacOS X users

Changes to the security model used in the latest versions of MacOS X 10.14 (Mojave) and 10.15 (Catalina) mean that the operating system will show an error message ('"OrniFlight Configurator.app" is damaged and can’t be opened. You should move it to the Trash.') when trying to install the application. To work around this, run the following command in a terminal before installing: `sudo spctl --master-disable`. Then install OrniFlight configurator, and after verifying that the installation has worked, run `sudo spctl --master-enable`.

## Native app build via NW.js

### Development

1. Install node.js (version 10 required)
2. Install yarn: `npm install yarn -g`
3. Change to project folder and run `yarn install`.
4. Run `yarn start`.

### Running tests

`yarn test`

### App build and release

The tasks are defined in `gulpfile.js` and can be run with through yarn:
```
yarn gulp <taskname> [[platform] [platform] ...]
```

List of possible values of `<task-name>`:
* **dist** copies all the JS and CSS files in the `./dist` folder.
* **apps** builds the apps in the `./apps` folder [1].
* **debug** builds debug version of the apps in the `./debug` folder [1].
* **release** zips up the apps into individual archives in the `./release` folder [1]. 

[1] Running this task on macOS or Linux requires Wine, since it's needed to set the icon for the Windows app (build for specific platform to avoid errors).

#### Build or release app for one specific platform
To build or release only for one specific platform you can append the plaform after the `task-name`.
If no platform is provided, all the platforms will be done in sequence.

* **MacOS X** use `yarn gulp <task-name> --osx64`
* **Linux** use `yarn gulp <task-name> --linux64`
* **Windows** use `yarn gulp <task-name> --win32`
* **ChromeOS** use `yarn gulp <task-name> --chromeos`

You can also use multiple platforms e.g. `yarn gulp <taskname> --osx64 --linux64`.

## Notes

### WebGL

Make sure Settings -> System -> "User hardware acceleration when available" is checked to achieve the best performance

### Linux users

Dont forget to add your user into dialout group "sudo usermod -aG dialout YOUR_USERNAME" for serial access

### Linux / MacOS X users

If you have 3D model animation problems, enable "Override software rendering list" in Chrome flags chrome://flags/#ignore-gpu-blacklist

## Support

### Issue trackers

For OrniFlight configurator issues raise them here

https://github.com/dantiel/orniflight-configurator/issues

For OrniFlight firmware issues raise them here

https://github.com/dantiel/orniflight/issues

## Technical details

The configurator is based on chrome.serial API running on Google Chrome/Chromium core.

## Developers

We accept clean and reasonable patches, submit them!

## Credits

Betaflight squad - based on Betaflight 4.0.6 and Betaflight configurator 10.6.0

ctn - primary author and maintainer of Baseflight Configurator from which Cleanflight Configurator project was forked.

Hydra -  author and maintainer of Cleanflight Configurator from which this project was forked.
