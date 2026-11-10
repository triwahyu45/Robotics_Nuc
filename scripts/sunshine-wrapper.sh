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

# Kunci resolusi mirror 1280x720p permanen untuk kedua display (HDMI-1 & DP-2)
xrandr --output HDMI-1 --mode 1280x720 --primary 2>/dev/null || true
xrandr --output DP-2 --mode 1280x720 --same-as HDMI-1 2>/dev/null || true

exec /usr/bin/sunshine /home/abhinayanuc/.config/sunshine/sunshine.conf
