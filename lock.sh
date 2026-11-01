#!/bin/bash

# ==================== CONFIGURATION ====================
DEVICE_NAME_KEYWORD="Logitech" 
DEVICE_ID=11              # Your gamepad/keyboard xinput ID to lock
PLAY_TIME="1m"            # Play session duration
COIN_KEY_CODE="KEY_5"     # Restrict trigger to the "5" key
# =======================================================

# Ensure script runs as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must run with root privileges (sudo)."
    exit 1
fi

# Function to dynamically find the unified receiver event path
get_event_dev() {
    local match=$(ls /dev/input/by-id/*event* 2>/dev/null | grep -i "$DEVICE_NAME_KEYWORD" | head -n 1)
    if [ -n "$match" ]; then
        readlink -f "$match"
        return 0
    fi
    return 1
}

EVENT_DEV=$(get_event_dev)
if [ -z "$EVENT_DEV" ]; then
    echo "Error: Could not find any input device matching '$DEVICE_NAME_KEYWORD'"
    exit 1
fi

# --- BULLETPROOF DESKTOP USER DETECTION ---
REAL_USER=$(who | grep -E '\(:[0-9]\)' | awk '{print $1}' | head -n 1)

if [ -z "$REAL_USER" ]; then
    REAL_USER=$(stat -c '%U' /dev/tty1 2>/dev/null)
fi

if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
    REAL_USER=${SUDO_USER:-$USER}
fi

export DISPLAY=:0
export XAUTHORITY=/home/$REAL_USER/.Xauthority
# ------------------------------------------

# Initial State: Make sure controls are locked on launch
# xinput disable $DEVICE_ID

show_insert_coin() {
    # Check if a YAD instance is already running to avoid duplicate stacked prompts
    if ! pgrep -x "yad" > /dev/null; then
        # Replacing --type=splash with --window-type=notification forces an 
        # override-redirect layer, locking the taskbar completely underneath.
        yad --title="ArcadePrompt" \
            --text="<span foreground='red' font='28'><b>СЛОЖИ МОНЕТА ЗА ИГРА\n(15 МИНУТИ)</b></span>" \
            --width=600 --height=120 \
            --window-type=notification \
            --on-top \
            --center \
            --undecorated \
            --fixed \
            --skip-taskbar \
            --no-buttons \
            --text-align=center \
            2>/dev/null &
    fi
}


# Launch the initial visual message
show_insert_coin

# Main non-interactive background loop listening directly to the hardware kernel state
evtest "$EVENT_DEV" | while read -r line; do
    # Trigger ONLY when the specific ($COIN_KEY_CODE) transitions to 'pressed state' (value 1)
    if echo "$line" | grep -q "($COIN_KEY_CODE), value 1"; then
        
        # 1. Close the "Insert Coin" prompt window safely
        killall yad 2>/dev/null
        
        # 2. Open up user controls for SuperTuxKart
        # xinput enable $DEVICE_ID
        
        # 3. Play the coin sound effect
        mpg123 /home/ji4ka/maimundere/coin.mp3
        
        # 4. Enforce the playground cooldown countdown timer
        sleep $PLAY_TIME
        
        # 5. Lock controls down again & re-render the blocking splash screen
        # xinput disable $DEVICE_ID
        killall yad 2>/dev/null
        show_insert_coin
    fi
done
