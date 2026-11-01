# maimundere - Linux Coin-Operated Arcade Kiosk for SuperTuxKart

This project converts a standard Linux PC (Ubuntu, antiX, etc.) running **IceWM** into a dedicated, locked-down arcade cabinet. It interfaces directly with a USB hardware coin acceptor (sending keyboard inputs like `KEY_5`) to manage game time and controls.

## Features
- **Strict Key Filter:** Listens directly to `/dev/input/` events to catch coin signals via `evtest`.
- **Automatic Game Control Toggling:** Automatically blocks/unblocks gamepads/keyboards.
- **Kiosk Interface:** Uses centered `yad` overlay prompts that stay above all windows without bringing up system taskbars.
- **Ultra Lightweight:** Tailored for IceWM to maximize game performance.

## Prerequisites
Ensure your system has the following utilities installed:
```bash
sudo apt install icewm yad evtest xdotool mpg123 xinput
```

## Setup
1. Configure IceWM into kiosk mode using the included configuration files.
2. Edit the configuration block at the top of `arcade_lock.sh` to match your input device keywords and preferred play timing.
3. Set `arcade_lock.sh` to execute automatically on system startup.

