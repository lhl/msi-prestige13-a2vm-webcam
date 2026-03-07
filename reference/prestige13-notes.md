# MSI Prestige 13 AI+ Evo A2VMG-029US
Purchased from Costco.com Nov 25 2024 for $1,199.99. Amazon has the variant
with 2TB SSD for $1,399.99. I don't think it's soldered, so it shouldn't cost
that much to upgrade it later if I need more storage.

# BIOS
https://us.msi.com/Business-Productivity/Prestige-13-AI-plus-Evo-A2VM/support?sku_id=95244#bios

Updated to `E13Q3IMS.10C` with the image from the MSI website. You need to
unzip the files before putting them on the USB stick.

The BIOS release notes refer to this device as `MS-13Q3`, which also shows up
in DMI.

Needed to disable CPU C-states to fix stuttering (see below)

Disabled Secure Boot for the Debian installer and custom kernel. Could re-enable if a signed Debian release kernel that works is available.

# Debian
Installed from `debian-12.8.0-amd64-DVD-1.iso` (bookworm) on a USB stick. No
networking available in the installer... Missing both firmware and an updated
iwlwifi kernel driver.

Wayland/Gnome worked slowly with the bookworm 6.1 kernel, in 800x600 VGA mode
with no acceleration. After updating the kernel, gdm3 failed to start. Mashed
combos of Ctrl+Alt+Shift+Fn+F2 until I got a login shell on VT.

Used a very old and slow Realtek USB wifi adapter to get new iwlwifi firmware
and kernel loaded from the trixie repository after install. Switched to a USB-C
gigabit ethernet adapter and dist-upgraded all the way to trixie.

# Kernel 
Debian trixie kernel did not have the Intel Xe DRM driver enabled, so we need a
custom kernel. Lots of other things seem to be improved with the newer kernel
too.

Mainline 6.12.0 kernel (28eb75e178d389d325f1666e422bc13bbbb9804c)
- Started with Debian trixie 6.11.9-1 config
- `yes "" | make oldconfig`
- Enabled `CONFIG_DRM_XE` and associated flags

# Firmware
Debian firmware packages were all outdated by a couple months. Intel merged
most of the LNL (Lunar Lake) artifacts we need starting in September 2024.

    firmware-intel-graphics
    firmware-sof-signed
    firmware-iwlwifi

## Wifi
latest iwlwifi "bz" firmware (d12506ffda7a36b484ca4e440abacf16f6f32068)
git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git

## Graphics
drm-xe firmware from the drm-firmware intel-staging branch (d12506ffda7a36b484ca4e440abacf16f6f32068)
https://gitlab.com/kernel-firmware/drm-firmware/-/tree/intel-staging?ref_type=heads

`CONFIG_INTEL_MEI_GSC_PROXY` - the Xe2 GSC (Graphics Security Controller) needs to talk to the ME (Management Engine) using this proxy driver for DRM playback. Still fails with this enabled, but it gets a bit further:
```
xe 0000:00:02.0: [drm] *ERROR* GT1: GSC proxy component not bound!
```

## Audio
rsync v2.11.x sof firmware on top of the firmware-sof-signed directories.
`/lib/firmware/intel/sof-ipc4-lib` didn't exist, needed to be created.

# Stuttering
The system seemed to stutter for about a second fairly often. It misses
keyboard events during this period.

~~Disabling CPU C-states in the BIOS fixes the stuttering, so I guess it has
something to do with one of the low power states.~~

The C3 low power state is what causes the stuttering, disable it with:
    
    apt install linux-cpupower
    cpupower idle-set -d 3

# Intel Sensor Hub
This is a little microcontroller with UART, SPI, I2C, GPIO for accessing things
like accelerometers and gyros. The OEM builds firmware for it using an Intel
provided SDK.

`intel_ish_ipc` throws some errors in dmesg after loading firmware. I
downloaded the Windows ISH driver from the MSI website and found two .bin files
inside it. One of them is very close in size to the firmware file from Debian,
so I dropped that in and reloaded the kernel module. No change in behavior.
Same thing with the other .bin file.

Zephyr Project supports ISH as a build target, so maybe we can develop an open firmware for it!

# Camera

## TPS68470
This is a power management IC. The kernel driver has some hardcoded voltage
limits depending on the device we're running. Looks like it only has
definitions for the Microsoft Surface Go devices
(`drivers/platform/x86/intel/int3472/tps68470_board_data.c`).

I'm pretty sure this regulator powers the camera module and flash, but I don't know how it's wired up and what voltages need to be configured. It might be the same as the Surface Go in the existing driver, but I'm not brave enough to just try it... Don't want to blow up my camera with out of range voltages. The Windows camera driver package from MSI contains `iactrllogic64` which I'm pretty sure configures this PMIC. Maybe we can reverse engineer the settings from that.

Once the camera power management is sorted, the [ipu7-drivers](https://github.com/intel/ipu7-drivers) kernel module needs to be built and installed along with it's firmware and userspace.

# NVMe probe failure?
There's a traceback in dmesg that looks like it happens during NVMe PCI
probing. It seems to recover from this and I've had no issues with NVMe.

# ACPI messages
A bunch of ACPI errors during boot. Some of these might be related to our
C-states issues.

# EC firmware driver

    msi_ec: Firmware version is not supported: '13Q3EMS1.109'

It looks like MSI EC firmwares support different functionality. We'll need to
figure out what this firmware expects to get fan control, enable the camera,
set LEDs, and read temperature sensors. I don't know if this is something we
can derive from the Windows driver or if it's just a guessing game based on
similar devices.

# WMI events
`msi_wmi` driver reports unknown events when you press the function keys
(Volume Up/Down, Brightness, etc). These keys already seem to be bound properly
so I don't think we even need this driver?