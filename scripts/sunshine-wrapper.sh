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

# Configure resolution and auto-mirroring
# If HDMI-1 is connected, ensure 1280x720 primary
if xrandr | grep -q "HDMI-1 connected"; then
    xrandr --output HDMI-1 --mode 1280x720 --primary 2>/dev/null || true
fi

# If DP-2 is connected (virtual or physical)
if xrandr | grep -q "DP-2 connected"; then
    if xrandr | grep -q "HDMI-1 connected"; then
        # Mirror DP-2 to HDMI-1 with hardware scaling
        xrandr --output DP-2 --mode 1024x600 --scale-from 1280x720 --same-as HDMI-1 2>/dev/null || true
    else
        # Pure headless: Set DP-2 as standalone 1280x720
        xrandr --output DP-2 --mode 1024x600 --scale-from 1280x720 --primary 2>/dev/null || true
    fi
fi

exec /usr/bin/sunshine /home/abhinayanuc/.config/sunshine/sunshine.conf
