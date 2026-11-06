#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# 1. Launch SuperTuxKart in fullscreen kiosk/demo mode
/home/georgi/SuperTuxKart-1.5-linux-x86_64/run_game.sh &

# 2. Wait for the window to actually open in the Linux display manager
STK_WIN=""
while [ -z "$STK_WIN" ]; do
    STK_WIN=$(xdotool search --onlyvisible --class "supertuxkart" | head -n 1)
    sleep 0.5
done

# 3. Give the main title menu 6 seconds to completely finish its loading animations
# (If your PC is slower, increase this value to 8 or 10 seconds)
sleep 2

# 4. Force the OS focus directly onto the SuperTuxKart window
xdotool windowraise "$STK_WIN"
xdotool windowactivate --sync $STK_WIN
sleep 0.5

# 5. Automatically press Enter to select "Single Player"
xdotool key --window $STK_WIN Right
xdotool key --window $STK_WIN Return

"$SCRIPT_DIR/lock.sh"
