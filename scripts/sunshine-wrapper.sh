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
exec /usr/bin/sunshine /home/abhinayanuc/.config/sunshine/sunshine.conf
