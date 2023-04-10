# ArduCam 16MP IMX519 Autofocus Camera on Mainsail

> :warning: This is NOT A GUIDE to get ArduCam working on Mainsail. Solutions used in this writeup employs pre-release software, potentially breaking changes to system configuration files, and modified libcamera binaries from ArduCam. There's a high chance something may break in the future. Use these solutions at your own discretion.

## Overview

The [ArduCam 16MP IMX519 Autofocus Camera](https://www.arducam.com/16mp-autofocus-camera-for-raspberry-pi/) is a great camera for Raspberry Pi projects. It has the same dimensions as the official Raspberry Pi cameras while being very affordable, includes autofocus, and is capable of smooth 1080p30 video streaming. 

This makes it perfect for 3D printer applications. A Raspberry Pi or similar SBC is just capable enough to encode 1080p streams, while the small size makes it a perfect choice for mounting close to the bed/nozzle. 

## Issues
The ArduCam 16MP camera is not plug-and-play. You will need to choose between either using ArduCam binaries that aren't open-sourced yet (potential security issues), or making a small patch and live without continuous autofocus or phase detection autofocus.

### Option 1: ArduCam Binary Drivers
If you trust ArduCam with their binaries and want to avoid troubleshooting hassles, you could follow their [guide](https://docs.arducam.com/Raspberry-Pi-Camera/Native-camera/Quick-Start-Guide/#imx519-cameras) to use their pivariety drivers and apps. However, they do have [plans](https://forum.arducam.com/t/install-pivariety-pkgs-sh-update-and-faq/3060/43?u=mgrl) to push their changes to mainline `libcamera`. 

```sh
wget -O install_pivariety_pkgs.sh https://github.com/ArduCAM/Arducam-Pivariety-V4L2-Driver/releases/download/install_script/install_pivariety_pkgs.sh
chmod +x install_pivariety_pkgs.sh
./install_pivariety_pkgs.sh -p libcamera_dev
./install_pivariety_pkgs.sh -p libcamera_apps
```

You will also need to add the following lines to `/boot/config.txt` to enable the imx519 camera:
```
[all]
dtoverlay=imx519
```

### Option 2: Native Drivers
If you don't feel comfortable with the ArduCam drivers, You will need a kernel that supports the IMX519 sensor and the AK7375 motor that drives the autofocus system. Fortunately, the `6.1` kernels already includes both drivers. However, if you run `libcamera-hello` with the `6.1` kernel, you will still encounter an error about no autofocus algorithm. You will need to make a patch to add a simple contrast autofocus algorithm to the configuration json file for IMX519. This workaround was proposed in this [forum post](https://forums.raspberrypi.com/viewtopic.php?t=346667).

This workaround modifies system configuration for the IMX519 sensor and could break things down the line. Use this solution at your own discretion. 

This repository provides an easy way to do it that also stores the original file at `/usr/share/libcamera/ipa/raspberrypi/imx519.json.orig`:
```sh
sh patch.sh
```

If the automatic patching doesn't work for you, you can try manually patching the "/usr/share/libcamera/ipa/raspberrypi/imx519.json" file by adding the following to the end of "algorithms":
```
        {
            "rpi.focus": { }
        },
        {
            "rpi.af":
            {
                "ranges":
                {
                    "normal":
                    {
                        "min": 0.0,
                        "max": 12.0,
                        "default": 1.0
                    },
                    "macro":
                    {
                        "min": 3.0,
                        "max": 15.0,
                        "default": 4.0
                    }
                },
                "speeds":
                {
                    "normal":
                    {
                        "step_coarse": 1.0,
                        "step_fine": 0.25,
                        "contrast_ratio": 0.75,
                        "pdaf_gain": -0.02,
                        "pdaf_squelch": 0.125,
                        "max_slew": 2.0,
                        "pdaf_frames": 20,
                        "dropout_frames": 6,
                        "step_frames": 4
                    }
                },
                "conf_epsilon": 8,
                "conf_thresh": 16,
                "conf_clip": 512,
                "skip_frames": 5,
                "map": [ 0.0, 0, 15.0, 4095 ]
            }
        }
```

Just like with using the ArduCam drivers, you will need to add the following lines to `/boot/config.txt`:
```
[all]
dtoverlay=imx519
```

The native driver does not handle autofocus well. The camera would only do contrast detection autofocus (slow) at the beginning, and autofocus will not work after it first acquires focus. This should pose little issue to a 3D printing application, as your subjects usually don't move that much.

If you need faster autofocus speeds (phase detection autofocus) or continuous autofocus, you will need to use the ArduCam libcamera binaries. 

## Crowsnest

Another issue you will face is with crowsnest with ustreamer not currently supporting libcamera cameras (including many ArduCam cameras and the Pi Camera 3). However, the developers of crowsnest is working on adding support for the camera through `camera-streamer` in the `develop` branch. You can switch to this branch with `git checkout --track origin/develop`. If you want to have moonraker automatically update crowsnest (**NOT RECOMMENDED**), you will also need to change the `moonraker.conf`:

```
[update_manager crowsnest]
type: git_repo
path: ~/crowsnest
origin: https://github.com/mainsail-crew/crowsnest.git
managed_services: crowsnest
install_script: tools/install.sh
primary_branch: develop
```

You will also need to set up the camera in `crowsnest.conf`:
```
[cam ArduCam16MP]
mode: multi                                # mjpg/multi - Multi uses webrtc, mjpg and snapshots at the same time
enable_rtsp: false                         # If multi is used, this enables also usage of an rtsp server
rtsp_port: 8554                            # Set different ports for each device!
port: 8080                                 # HTTP/MJPG Stream/Snapshot Port
device: /base/soc/i2c0mux/i2c@1/imx519@1a  # See Log for available ...
resolution: 1920x1080                      # widthxheight format
max_fps: 30                                # If Hardware Supports this it will be forced, otherwise ignored/coerced.
# Autofocus works out of the box with ArduCam's modified libcamera
custom_flags: -camera-type=libcamera -camera-format=YUYV -camera-width=1920 -camera-height=1080 -camera-snapshot.height=1080 -camera-stream.height=720
# v4l2ctl:                                 # Add v4l2-ctl parameters to setup your camera, see Log what your cam is capable of.

[cam ArduCam16MPNative]
mode: multi                                # mjpg/multi - Multi uses webrtc, mjpg and snapshots at the same time
enable_rtsp: false                         # If multi is used, this enables also usage of an rtsp server
rtsp_port: 8554                            # Set different ports for each device!
port: 8080                                 # HTTP/MJPG Stream/Snapshot Port
device: /base/soc/i2c0mux/i2c@1/imx519@1a  # See Log for available ...
resolution: 1920x1080                      # widthxheight format
max_fps: 30                                # If Hardware Supports this it will be forced, otherwise ignored/coerced.
# You need these extra settings for AF without ArduCam's pivariety libcamera binaries.
custom_flags: -camera-type=libcamera -camera-format=YUYV -camera-width=1920 -camera-height=1080 -camera-snapshot.height=1080 -camera-stream.height=720 -camera-options=AfMode=2 -camera-options=AfRange=2
# v4l2ctl:                                 # Add v4l2-ctl parameters to setup your camera, see Log what your cam is capable of.
```