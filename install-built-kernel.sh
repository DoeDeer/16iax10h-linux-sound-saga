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
echo "Installed kernels:"
rpm -q kernel | sort -V

echo
read -rp "Install (re-isntall) NVIDIA drivers (open source)? [y/N]: " nd_continue
if [[ ! "$nd_continue" =~ ^[Yy]$ ]]; then
    dnf remove -y nvidia-open
    dnf install -y nvidia-open

    read -rp "Enable NVIDIA suspend/hibernate/resume service? [y/N]: " ns_continue
    if [[ ! "$ns_continue" =~ ^[Yy]$ ]]; then
        systemctl enable nvidia-hibernate
        systemctl enable nvidia-suspend
        systemctl enable nvidia-resume
    fi
fi
