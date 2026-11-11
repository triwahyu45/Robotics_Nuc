#!/usr/bin/env bash
# ==============================================================================
# Intel NUC Ubuntu 24.04 Setup Script for Robotics / Autonomous Vehicle
# Features:
#   1. Automatic Headless Virtual Display (1280x720p 60Hz) via Kernel DRM EDID
#   2. Seamless Touchscreen USB Input Mapping (MPI7002 / ByQDtech)
#   3. Low-Latency Remote Desktop Streaming via Sunshine (Intel VAAPI Hardware Acceleration)
#   4. Anti-Disconnect Hotplug Display Mirroring (HDMI-1 & DP-2 clone)
#   5. Bluetooth External Dongle (Realtek RTL8761BU) Firmware Setup
#   6. Task Manager / System Health Monitoring CLI Tools (btop, htop, nvme-cli)
#   7. GDM Autologin & Systemd User Service with X11 Pre-Wait Wrapper
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
# 1. System Dependencies, GPU Codecs, Firmware & Monitoring Tools
# ------------------------------------------------------------------------------
echo "[1/7] Installing dependencies, GPU drivers, Bluetooth firmware, and monitoring tools..."
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
echo "[2/7] Configuring Kernel DRM EDID override for headless 720p display..."
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
echo "[3/7] Configuring GDM3 Autologin & X11..."
GDM_CUSTOM="/etc/gdm3/custom.conf"
if [ -f "$GDM_CUSTOM" ]; then
    sed -i "s/#  AutomaticLoginEnable = true/AutomaticLoginEnable = true/" "$GDM_CUSTOM"
    sed -i "s/#  AutomaticLogin = user1/AutomaticLogin = ${TARGET_USER}/" "$GDM_CUSTOM"
    sed -i "s/#WaylandEnable=false/WaylandEnable=false/" "$GDM_CUSTOM"
fi

# Copy default monitors.xml for GNOME user and GDM (Fixed 1280x720 Mirror Mode)
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
echo "[4/7] Setting up Touchscreen Udev rules..."
if [ -f "${CONFIG_DIR}/99-touchscreen.rules" ]; then
    cp "${CONFIG_DIR}/99-touchscreen.rules" /etc/udev/rules.d/99-touchscreen.rules
    udevadm control --reload-rules && udevadm trigger
fi

# ------------------------------------------------------------------------------
# 5. Sunshine GameStream Server Setup & Wrapper Script
# ------------------------------------------------------------------------------
echo "[5/7] Configuring Sunshine streaming server & wait-for-display wrapper..."
SUNSHINE_CONF_DIR="${TARGET_HOME}/.config/sunshine"
mkdir -p "$SUNSHINE_CONF_DIR"

if [ -f "${CONFIG_DIR}/sunshine.conf" ]; then
    cp "${CONFIG_DIR}/sunshine.conf" "${SUNSHINE_CONF_DIR}/sunshine.conf"
    chown -R "${TARGET_USER}:${TARGET_USER}" "${SUNSHINE_CONF_DIR}"
fi

# Install Sunshine Wrapper
mkdir -p "${TARGET_HOME}/.local/bin"
if [ -f "${SCRIPT_DIR}/sunshine-wrapper.sh" ]; then
    cp "${SCRIPT_DIR}/sunshine-wrapper.sh" "${TARGET_HOME}/.local/bin/sunshine-wrapper.sh"
    chmod +x "${TARGET_HOME}/.local/bin/sunshine-wrapper.sh"
    chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.local/bin"
fi

# Install Sunshine Systemd User Service
SYSTEMD_USER_DIR="${TARGET_HOME}/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
if [ -f "${CONFIG_DIR}/sunshine.service" ]; then
    cp "${CONFIG_DIR}/sunshine.service" "${SYSTEMD_USER_DIR}/sunshine.service"
    chown -R "${TARGET_USER}:${TARGET_USER}" "${SYSTEMD_USER_DIR}"
fi

# Ensure user lingering is enabled for systemd user services
loginctl enable-linger "${TARGET_USER}"

# ------------------------------------------------------------------------------
# 6. Sunshine Cap Permissions & Systemd User Service Activation
# ------------------------------------------------------------------------------
echo "[6/7] Applying Sunshine capabilities and enabling service..."
setcap cap_sys_admin+p $(which sunshine 2>/dev/null || echo "/usr/bin/sunshine") 2>/dev/null || true

# Enable and start Sunshine user service as target user
su - "${TARGET_USER}" -c "systemctl --user daemon-reload && systemctl --user enable sunshine.service && systemctl --user restart sunshine.service" || true

# ------------------------------------------------------------------------------
# 7. Bluetooth External Adapter Service Setup
# ------------------------------------------------------------------------------
echo "[7/7] Enabling Bluetooth service and powering adapter..."
# Ensure Avahi mDNS broadcasts hostname across network changes
sed -i 's/#publish-workstation=no/publish-workstation=yes/' /etc/avahi/avahi-daemon.conf 2>/dev/null || true
systemctl restart avahi-daemon

systemctl enable bluetooth
systemctl restart bluetooth
bluetoothctl power on 2>/dev/null || true

echo "=========================================="
echo " Setup Finished Successfully!"
echo " All configurations (Mirror 720p, Headless, Sunshine, Bluetooth, btop) are active."
echo " Please reboot the NUC to finalize early-boot kernel display parameters:"
echo "   sudo reboot"
echo "=========================================="
