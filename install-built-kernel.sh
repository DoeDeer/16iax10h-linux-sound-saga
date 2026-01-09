#!/usr/bin/env bash

set -e
set -o pipefail

echo "=== Fedora Custom Kernel Installer ==="

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Re-run with: sudo $0"
    exit 1
fi

BUILD_DIR=""
read -rp "Enter absolute path to directory containing built kernel RPMS: " BUILD_DIR

BUILD_TAG=""
read -rp "Enter build tags of the new RPMS: " BUILD_TAG

# Check RPM directory
if [[ ! -d "$BUILD_DIR" ]]; then
    echo "Kernel RPM directory not found:"
    echo "  $BUILD_DIR"
    exit 1
fi

# Check build tag directory
if [[ ! -n "$BUILD_TAG" ]]; then
    echo "Can not use empty build tag."
    exit 1
fi

RPM_COUNT=$(ls "$BUILD_DIR"/*.rpm 2>/dev/null | wc -l)
if [[ "$RPM_COUNT" -eq 0 ]]; then
    echo "No RPM files found in $BUILD_DIR"
    exit 1
fi

echo "Found $RPM_COUNT kernel RPMs."

# Secure Boot check
SECURE_BOOT_STATE=$(mokutil --sb-state 2>/dev/null | grep -i enabled || true)
if [[ -n "$SECURE_BOOT_STATE" ]]; then
    echo
    echo "⚠ Secure Boot is ENABLED"
    echo "Make sure you have already enrolled your MOK certificate."
    echo
    read -rp "Continue installation anyway? [y/N]: " sb_continue
    if [[ ! "$sb_continue" =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
fi

echo
echo "Installing kernel RPMs..."
dnf install -y "$BUILD_DIR/kernel-$BUILD_TAG.fc43.x86_64.rpm" "$BUILD_DIR/kernel-core-$BUILD_TAG.fc43.x86_64.rpm" "$BUILD_DIR/kernel-modules-core-$BUILD_TAG.fc43.x86_64.rpm" "$BUILD_DIR/kernel-modules-$BUILD_TAG.fc43.x86_64.rpm" "$BUILD_DIR/kernel-modules-extra-$BUILD_TAG.fc43.x86_64.rpm" "$BUILD_DIR/kernel-devel-$BUILD_TAG.fc43.x86_64.rpm"

echo
echo "Kernel installation complete."
echo
echo "You may want now to finish kernel configuration (to use non default sound driver) and change your default boot kernel."
echo "To update kernel configuration, add 'snd_intel_dspcfg.dsp_driver=3' to the end of options line at /boot/loader/entries/<your-new-kernel-configuration>.conf"
echo "  sudo nano /boot/loader/entries/<your-new-kernel-configuration>.conf"
echo "To change the default boot kernel:"
echo "  sudo grubby --set-default /boot/vmlinuz-<your-new-kernel-configuration>"

echo
echo "Also you may want to reinstall NVIDIA drivers, because there are no nvidia headers for the new kernel."
echo "  sudo dnf remove -y nvidia-open && sudo dnf install nvidia-open"

echo
echo "And finally - re-apply sound settings."
echo "  sudo cp -f fix/ucm2/HiFi-analog.conf /usr/share/alsa/ucm2/HDA/HiFi-analog.conf"
echo "  sudo cp -f fix/ucm2/HiFi-mic.conf /usr/share/alsa/ucm2/HDA/HiFi-mic.conf"
echo "Calibrate speaker:"
echo "  alsaucm -c hw:0 reset"
echo "  alsaucm -c hw:0 reload"
echo "  systemctl --user restart pipewire pipewire-pulse wireplumber"
echo "  amixer sset -c 0 Master 100%"
echo "  amixer sset -c 0 Headphone 100%"
echo "  amixer sset -c 0 Speaker 100%"
echo "Replace 'hw:0' and '-c 0' with your actual hw id which can get from 'alsaucm listcards'"

echo
echo "Installed kernels:"
rpm -q kernel | sort -V
