#!/usr/bin/env bash
# ==============================================================================
# Intel NUC Ubuntu 24.04 Setup Script for Robotics / Autonomous Vehicle
# Features:
#   1. Automatic Headless Virtual Display (1280x720p 60Hz) via Kernel DRM EDID
#   2. Seamless Touchscreen USB Input Mapping (MPI7002 / ByQDtech)
#   3. Low-Latency Remote Desktop Streaming via Sunshine (Intel VAAPI Hardware Acceleration)
#   4. Network, SSH, and GDM Autologin Configuration
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../configs"

echo "=========================================="
echo " Starting Intel NUC Robotics Environment Setup"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run this script with sudo: sudo ./setup_nuc.sh"
    exit 1
fi

TARGET_USER="${SUDO_USER:-abhinayanuc}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "[+] Target User: ${TARGET_USER} (${TARGET_HOME})"

# ------------------------------------------------------------------------------
# 1. System Dependencies & Hardware Codecs
# ------------------------------------------------------------------------------
echo "[1/6] Installing dependencies, GPU drivers, Bluetooth firmware, and monitoring tools..."
apt-get update
apt-get install -y \
    curl \
    wget \
    git \
    openssh-server \
    x11-utils \
    xdotool \
    imagemagick \
    feh \
    bluez \
    bluez-tools \
    linux-firmware-realtek \
    btop \
    htop \
    iotop \
    smartmontools \
    nvme-cli \
    vainfo \
    intel-media-va-driver-non-free \
    libva-drm2 \
    libva2

# ------------------------------------------------------------------------------
# 2. Kernel DRM EDID & Headless Display Emulation (1280x720p 60Hz)
# ------------------------------------------------------------------------------
echo "[2/6] Configuring Kernel DRM EDID override for headless 720p display..."
mkdir -p /lib/firmware/edid
if [ -f "${CONFIG_DIR}/edid-720p.bin" ]; then
    cp "${CONFIG_DIR}/edid-720p.bin" /lib/firmware/edid/edid-720p.bin
    chmod 644 /lib/firmware/edid/edid-720p.bin
else
    echo "[!] Warning: edid-720p.bin not found in ${CONFIG_DIR}!"
fi

# Update initramfs to bundle custom EDID into kernel early boot
update-initramfs -u

# Configure GRUB parameters to force DP-2 and HDMI-A-1 to 1280x720 60Hz
GRUB_PARAM="drm.edid_firmware=DP-2:edid/edid-720p.bin,HDMI-A-1:edid/edid-720p.bin video=DP-2:1280x720@60e video=HDMI-A-1:1280x720@60e"
if ! grep -q "drm.edid_firmware" /etc/default/grub; then
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash ${GRUB_PARAM}\"/" /etc/default/grub
    update-grub
    echo "[+] GRUB command line updated with DRM EDID override."
fi

# ------------------------------------------------------------------------------
# 3. GDM Autologin & X11 Force Enable
# ------------------------------------------------------------------------------
echo "[3/6] Configuring GDM3 Autologin & X11..."
GDM_CUSTOM="/etc/gdm3/custom.conf"
if [ -f "$GDM_CUSTOM" ]; then
    sed -i "s/#  AutomaticLoginEnable = true/AutomaticLoginEnable = true/" "$GDM_CUSTOM"
    sed -i "s/#  AutomaticLogin = user1/AutomaticLogin = ${TARGET_USER}/" "$GDM_CUSTOM"
    sed -i "s/#WaylandEnable=false/WaylandEnable=false/" "$GDM_CUSTOM"
fi

# Copy default monitors.xml for GNOME user and GDM
if [ -f "${CONFIG_DIR}/monitors.xml" ]; then
    mkdir -p "${TARGET_HOME}/.config"
    cp "${CONFIG_DIR}/monitors.xml" "${TARGET_HOME}/.config/monitors.xml"
    chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config/monitors.xml"
    
    mkdir -p /var/lib/gdm3/.config
    cp "${CONFIG_DIR}/monitors.xml" /var/lib/gdm3/.config/monitors.xml
    chown gdm:gdm /var/lib/gdm3/.config/monitors.xml
fi

# ------------------------------------------------------------------------------
# 4. Touchscreen USB Mapping Udev Rule
# ------------------------------------------------------------------------------
echo "[4/6] Setting up Touchscreen Udev rules..."
if [ -f "${CONFIG_DIR}/99-touchscreen.rules" ]; then
    cp "${CONFIG_DIR}/99-touchscreen.rules" /etc/udev/rules.d/99-touchscreen.rules
    udevadm control --reload-rules && udevadm trigger
fi

# ------------------------------------------------------------------------------
# 5. Sunshine GameStream Server Setup
# ------------------------------------------------------------------------------
echo "[5/6] Configuring Sunshine streaming server..."
SUNSHINE_CONF_DIR="${TARGET_HOME}/.config/sunshine"
mkdir -p "$SUNSHINE_CONF_DIR"

if [ -f "${CONFIG_DIR}/sunshine.conf" ]; then
    cp "${CONFIG_DIR}/sunshine.conf" "${SUNSHINE_CONF_DIR}/sunshine.conf"
    chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config/sunshine"
fi

# Ensure user lingering is enabled for systemd user services
loginctl enable-linger "${TARGET_USER}"

# ------------------------------------------------------------------------------
# 6. Sunshine Cap Permissions & Udev
# ------------------------------------------------------------------------------
echo "[6/6] Applying Sunshine permissions..."
setcap cap_sys_admin+p $(which sunshine 2>/dev/null || echo "/usr/bin/sunshine") 2>/dev/null || true

echo "=========================================="
echo " Setup Finished Successfully!"
echo " Please reboot the NUC to apply kernel display parameters:"
echo "   sudo reboot"
echo "=========================================="
