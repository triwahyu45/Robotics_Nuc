#!/bin/bash
# Wait until X11 display :0 is up and responding
for i in $(seq 1 30); do
    if xset q -display :0 >/dev/null 2>&1; then
        echo "Display :0 is ready!"
        break
    fi
    sleep 1
done

export DISPLAY=:0
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# Cek apakah layar fisik HDMI terpasang/aktif
# Jika HDMI-1 terhubung, jadikan satu-satunya output utama (1280x720) dan matikan DP-2 agar tidak ada layar ganda/beda ukuran
if xrandr | grep "^HDMI-1 connected" >/dev/null 2>&1; then
    xrandr --output DP-2 --off --output HDMI-1 --mode 1280x720 --primary 2>/dev/null || true
else
    # Jika TANPA layar HDMI (murni Headless), aktifkan virtual display DP-2 di 1280x720
    xrandr --newmode "1280x720_60.00" 74.50 1280 1344 1472 1664 720 723 728 748 -hsync +vsync 2>/dev/null || true
    xrandr --addmode DP-2 1280x720_60.00 2>/dev/null || true
    xrandr --output DP-2 --mode 1280x720_60.00 --primary 2>/dev/null || \
    xrandr --output DP-2 --mode 1024x600 --scale-from 1280x720 --primary 2>/dev/null || true
fi

exec /usr/bin/sunshine /home/abhinayanuc/.config/sunshine/sunshine.conf
