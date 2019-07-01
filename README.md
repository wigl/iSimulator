![Carrot: iSimulator is a GUI utility to control the Simulator](https://raw.githubusercontent.com/wigl/iSimulator/master/iSimulator/Assets.xcassets/AppIcon.appiconset/icon_128x128.png)

iSimulator is a GUI utility to control the Simulator, and manage the app installed on the simulator.

- [Features](#features)
- [Usage](#usage)
- [Build from the code](#build-from-the-code)
- [Requirements](#requirements)
- [Preview](#preview)
- [License](#license)

## Features

**Control Simulator:**

- [x] Show all simulators, including iOS, watchOS, tvOS and paired watches.
- [x] Create, erase, delete a simulator.
- [x] Pair iPhone and iWatch simulator.
- [x] Start, shutdown a simulator, and can start multiple simulators at the same time.

**Control application:**

- [x] Shows all applications installed on the simulator.
- [x] Easy to access application bundle, sandbox folder. **iSimulator will create a folder that contains the app's bundle and sandbox. This will make access app's data easier.**
- [x] Launch, terminate, uninstall application.
- [x] **Launch one application for other simulator.** Very easy to share an app to other simulators without having to rebuild.

**Auto Refresh:**

- [x] If you add, delete a simulator, or add, delete an application etc.,iSimulator will automatically refresh.

## Usage

Download [App](https://github.com/wigl/iSimulator/releases/download/3.2.2/iSimulator.zip) and run.

## Build from the code

Don't use `carthage bootstrap`, because `FBSimulatorControl` have extra scheme that carthage can not build.
 
Please run script with the following:`./carthageBootstrap.sh` to checkout and build dependencies.


## Requirements

iSimulator depends on Xcode command line tools, if you do not see the simulator you want, please change the path to the active developer directory.
You can use the following two ways:

Terminal.app: **Usage: sudo xcode-select -s <path>**

Xcode.app: **Preferences -> Locations -> Command line tools**

## Preview

**Show all simulators,Easy to access application bundle, sandbox folder.**

<img src="https://raw.githubusercontent.com/wigl/iSimulator/master/preview/app.jpg" alt="List apps" style="width: 300px;"/>


**Launch one application for other simulator. Very easy to share an app to other simulators without having to rebuild.**

<img src="https://raw.githubusercontent.com/wigl/iSimulator/master/preview/share.jpg" alt="Launch one application for other simulator." style="width: 300px;"/>


## License

iSimulator is released under the MIT license. [See LICENSE](https://github.com/wigl/iSimulator/blob/master/LICENSE) for details.