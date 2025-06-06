# Unreal Dumper

Unreal Dumper is a simple app that automates the process of finding/dumping any unreal engine games offsets. It also generates a game SDK in seconds. This is a helpful tool for any game cheat developers as it allows them to update their products as soon as the game updates.

## Compatibility

This works for all Unreal Engine 4+ games. It has not been tested for older versions but it might work.

This is not an executable, this is a dll that you inject into your game of choice to dump the offsets and game sdk.

## Features

- Dump all game offsets
- Generate game SDK
- Fast Execution
- Open Source

## How to use

### Build

To use the release, download the latest version from the [releases](https://github.com/paysonism/UnrealDumper/releases/latest) tab.
Now, run the exe as administrator and then once the driver loads open your game. Now, when it injects you should see a cmd window open with the auto dumped offsets aswell as the SDK file path.

## iOS Build

An experimental iOS port is provided in the `iOS/Tweak` directory. It uses the
[Theos](https://theos.dev/) build system together with runtime and memory
utilities adapted from [iOS_UEDumper](https://github.com/MJx0/iOS_UEDumper).

To build a debian package for jailbroken or rootless devices run:

```bash
cd iOS/Tweak
make package
```

The resulting `.deb` can be installed on a device with a package manager such
as Filza or via `dpkg -i`.

## Source

To use the source, simply build the source as release. This will place a dll in the build folder. Now just inject this dll using any dll injector and your good to go!

## Credits

Made By [Payson](https://github.com/paysonism) and the [EZFN Dev Team](https://github.com/EZFNDEV)
Portions of the iOS build are based on code from [iOS_UEDumper](https://github.com/MJx0/iOS_UEDumper) licensed under the MIT License (see `iOS/LICENSE.MIT`).
