#!/bin/bash

# ==================== CONFIGURATION ====================
DEVICE_NAME_KEYWORD="Logitech" 
DEVICE_ID=12              # Your gamepad/keyboard xinput ID to lock
PLAY_TIME="10m"            # Play session duration
GAME_RESTART_DELAY=5       # Seconds the game must remain stopped before restarting
COIN_KEY_CODE="KEY_5"     # Restrict trigger to the "5" key
# =======================================================

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Ensure script runs as root
#if [ "$EUID" -ne 0 ]; then
#    echo "This script must run with root privileges (sudo)."
#    exit 1
#fi

# Find a matching event device that actually reports the configured key.
INPUT_WORD_BITS=$(getconf LONG_BIT)
if ! [[ "$INPUT_WORD_BITS" =~ ^[0-9]+$ ]]; then
    echo "Error: Could not determine the system input bitmap word size."
    exit 1
fi

supports_coin_key() {
    local event_dev=$1
    local key_bit word_index word_position bit_offset word
    local -a key_words

    case "$COIN_KEY_CODE" in
        KEY_5) key_bit=6 ;;
        KEY_KP5) key_bit=76 ;;
        *)
            echo "Error: Unsupported coin key code '$COIN_KEY_CODE'."
            exit 1
            ;;
    esac

    read -r -a key_words < "/sys/class/input/${event_dev##*/}/device/capabilities/key" || return 1
    word_index=$((key_bit / INPUT_WORD_BITS))
    word_position=$((${#key_words[@]} - 1 - word_index))
    (( word_position >= 0 )) || return 1
    word=${key_words[word_position]}
    bit_offset=$((key_bit % INPUT_WORD_BITS))
    (( (16#$word & (1 << bit_offset)) != 0 ))
}

get_event_dev() {
    local event_dev device_name keyword=${DEVICE_NAME_KEYWORD,,}
    local inaccessible=0

    for event_dev in /dev/input/event*; do
        [ -e "$event_dev" ] || continue
        device_name=$(cat "/sys/class/input/${event_dev##*/}/device/name" 2>/dev/null) || continue
        [[ ${device_name,,} == *"$keyword"* ]] || continue
        supports_coin_key "$event_dev" || continue
        if [ ! -r "$event_dev" ]; then
            inaccessible=1
            continue
        fi

        printf '%s\n' "$event_dev"
        return 0
    done

    if [ "$inaccessible" -eq 1 ]; then
        echo "Error: A matching keyboard supports $COIN_KEY_CODE, but the current user cannot read its event device. Add the user to the 'input' group and log in again." >&2
    else
        echo "Error: No readable '$DEVICE_NAME_KEYWORD' input device supports $COIN_KEY_CODE." >&2
    fi
    return 1
}

EVENT_DEV=$(get_event_dev) || exit 1
if [ -z "$EVENT_DEV" ]; then
    echo "Error: Could not find an input device matching '$DEVICE_NAME_KEYWORD' and '$COIN_KEY_CODE'."
    exit 1
fi

# --- DESKTOP USER AND DISPLAY DETECTION ---
REAL_USER=${SUDO_USER:-}

if [ -z "$REAL_USER" ]; then
    REAL_USER=$(who | awk '$2 ~ /^:[0-9]+([.][0-9]+)?$/ { print $1; exit }')
fi

if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
    REAL_USER=$(stat -c '%U' /dev/tty1 2>/dev/null)
fi

if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
    REAL_USER=${USER:-root}
fi

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
DISPLAY_NUMBER=${DISPLAY##*:}
DISPLAY_NUMBER=${DISPLAY_NUMBER%%.*}
if ! [[ "$DISPLAY_NUMBER" =~ ^[0-9]+$ ]] || [ ! -S "/tmp/.X11-unix/X$DISPLAY_NUMBER" ]; then
    unset DISPLAY
fi

if [ -z "${DISPLAY:-}" ]; then
    DISPLAY_SOCKET=$(find /tmp/.X11-unix -maxdepth 1 -type s -name 'X[0-9]*' -print -quit 2>/dev/null)
    if [ -n "$DISPLAY_SOCKET" ]; then
        export DISPLAY=":${DISPLAY_SOCKET##*/X}"
    fi
fi

XORG_AUTH=$(ps -C Xorg -o args= 2>/dev/null | awk '
    { for (i = 1; i < NF; i++) if ($i == "-auth") { print $(i + 1); exit } }
')
export XAUTHORITY=${XAUTHORITY:-${XORG_AUTH:-$USER_HOME/.Xauthority}}

if [ -z "${DISPLAY:-}" ]; then
    echo "Error: Could not determine the active X11 display."
    exit 1
fi
# -------------------------------------------

# Initial State: Make sure controls are locked on launch
# xinput disable $DEVICE_ID

show_insert_coin() {
    # Check if a YAD instance is already running to avoid duplicate stacked prompts
    if ! pgrep -x "yad" > /dev/null; then
        if ! pgrep -x picom >/dev/null; then
            if pgrep -x xcompmgr >/dev/null; then
                echo "Error: Stop xcompmgr; Picom is required for rounded YAD corners." >&2
                return 1
            fi
            if ! command -v picom >/dev/null 2>&1; then
                echo "Error: YAD transparency and rounded corners require Picom. Install it and try again." >&2
                return 1
            fi
            if ! picom --backend xrender --corner-radius 16 \
                --rounded-corners-exclude "! (name = 'ArcadePrompt')" --daemon; then
                echo "Error: Could not start Picom; YAD transparency and rounded corners will not work." >&2
                return 1
            fi
        else
            echo "Warning: Picom is already running; restart it with --corner-radius 16 and --rounded-corners-exclude \"! (name = 'ArcadePrompt')\" to round the YAD prompt." >&2
        fi

        yad --title="ArcadePrompt" \
            --text="<span foreground='red' font='28'><b>СЛОЖИ МОНЕТА ЗА ИГРА\n(15 МИНУТИ)</b></span>" \
            --width=600 --height=120 \
            --on-top \
            --center \
            --undecorated \
            --fixed \
            --skip-taskbar \
            --no-buttons \
            --text-align=center \
            &

        if ! command -v xprop >/dev/null 2>&1; then
            echo "Error: xprop is required to set YAD window transparency." >&2
            return 1
        fi

        local attempt
        local window_id
        for attempt in {1..20}; do
            window_id=$(xdotool search --onlyvisible --name '^ArcadePrompt$' 2>/dev/null | head -n 1)
            if [[ "$window_id" =~ ^[0-9]+$ ]] &&
                xprop -id "$window_id" -f _NET_WM_WINDOW_OPACITY 32c \
                    -set _NET_WM_WINDOW_OPACITY 0xCCCCCCCC >/dev/null 2>&1; then
                return 0
            fi
            sleep 0.1
        done

        echo "Error: Could not apply transparency to the YAD window." >&2
    fi
}

echo "Listening for $COIN_KEY_CODE on $EVENT_DEV ($(cat "/sys/class/input/${EVENT_DEV##*/}/device/name"))."

# Launch the initial visual message
show_insert_coin

restart_launcher() {
    echo "SuperTuxKart is not running; restarting the launcher."
    killall yad 2>/dev/null
    if [ -n "${COOLDOWN_PID:-}" ]; then
        kill "$COOLDOWN_PID" 2>/dev/null || true
        wait "$COOLDOWN_PID" 2>/dev/null || true
    fi
    kill "$GAME_MONITOR_PID" 2>/dev/null || true
    wait "$GAME_MONITOR_PID" 2>/dev/null || true
    kill "$EVTEST_PID" 2>/dev/null || true
    wait "$EVTEST_PID" 2>/dev/null || true
    exec "$SCRIPT_DIR/launch_tux.sh"
}

monitor_game() {
    while true; do
        sleep 1
        if ! pgrep -x supertuxkart >/dev/null; then
            echo "SuperTuxKart is not running; waiting ${GAME_RESTART_DELAY}s before confirming."
            sleep "$GAME_RESTART_DELAY"
            if pgrep -x supertuxkart >/dev/null; then
                continue
            fi
            kill -USR1 "$MAIN_PID" 2>/dev/null || true
            return
        fi
    done
}

# Keep game monitoring independent of input and cooldown handling.
MAIN_PID=$$
trap 'restart_launcher' USR1
monitor_game &
GAME_MONITOR_PID=$!

coproc EVTEST { evtest "$EVENT_DEV"; }
while true; do
    if IFS= read -r -t 1 -u "${EVTEST[0]}" line; then
        # Trigger ONLY when the specific ($COIN_KEY_CODE) transitions to 'pressed state' (value 1)
        if echo "$line" | grep -q "($COIN_KEY_CODE), value 1"; then
            # 1. Close the "Insert Coin" prompt window safely
            killall yad 2>/dev/null

            # 2. Open up user controls for SuperTuxKart
            # xinput enable $DEVICE_ID

            # 3. Play the coin sound effect
            mpg123 -q "$SCRIPT_DIR/sfx/coin.mp3"

            # 4. Enforce the playground cooldown countdown timer
            sleep "$PLAY_TIME" &
            COOLDOWN_PID=$!
            while kill -0 "$COOLDOWN_PID" 2>/dev/null; do
                sleep 1
                if ! pgrep -x supertuxkart >/dev/null; then
                    echo "SuperTuxKart stopped during play time; waiting ${GAME_RESTART_DELAY}s before confirming."
                    sleep "$GAME_RESTART_DELAY"
                    if ! pgrep -x supertuxkart >/dev/null; then
                        restart_launcher
                    fi
                fi
            done
            wait "$COOLDOWN_PID"
            COOLDOWN_PID=""

            # 5. Lock controls down again & re-render the blocking splash screen
            # xinput disable $DEVICE_ID
            killall yad 2>/dev/null

            show_insert_coin
        fi
    fi
done
