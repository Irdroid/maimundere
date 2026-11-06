# maimundere - SuperTuxKart Arcade Kiosk

This project contains scripts and an IceWM configuration for a simple
coin-operated SuperTuxKart kiosk. The launcher detects a SuperTuxKart
installation, starts it fullscreen, and runs `lock.sh`. The lock script listens
for the main-row `5` or keypad `5` key on a matching input device, plays
`sfx/coin.mp3`, and displays an insert-coin prompt during the cooldown.

## Requirements

- IceWM and an X11 desktop session
- SuperTuxKart available as `supertuxkart`, or installed as the Flatpak
  `net.supertuxkart.SuperTuxKart` or Snap `supertuxkart`
- `yad`, `evtest`, `xdotool`, `xprop`, `picom`, `mpg123`, and `sudo`

On Debian/Ubuntu, install the utilities with:

```bash
sudo apt install icewm yad evtest xdotool x11-utils picom mpg123
```

`lock.sh` starts Picom with the XRender backend when no compositor is already
running. Picom is needed for the insert-coin YAD window's 80% opacity and
rounded corners. The rounding rule targets the prompt's `ArcadePrompt` title.
If Picom is already running, restart it with
`--corner-radius 16 --rounded-corners-exclude "! (name = 'ArcadePrompt')"`; the
script warns but does not change an existing compositor's settings.
The script checks for SuperTuxKart in a background watcher, so game monitoring
continues independently of input handling and the cooldown. If the game remains
stopped for five seconds, the watcher restarts the launcher.

The desktop user must be able to read the selected `/dev/input/event*` device.
On systems that assign input devices to the `input` group, add the kiosk user
to that group and start a new login session:

```bash
sudo usermod -aG input "$USER"
```

Membership in `input` grants access to keyboard and pointer events from all
input devices, so use it only for a trusted kiosk account.

Install SuperTuxKart from a package source supported by your distribution.

## Configure IceWM kiosk mode

The `icewm/` directory contains the IceWM preferences, key settings, and an
empty application menu. Install them in the active IceWM user configuration
directory (usually `~/.icewm`; some systems use `~/.config/icewm`). Back up any
existing files first, then copy the supplied files into that directory:

```bash
mkdir -p ~/.icewm
cp icewm/preferences icewm/keys icewm/menu ~/.icewm/
```

Log out and select IceWM again, or restart the window manager, to apply the
settings. They hide the taskbar and application menus, limit the session to
one workspace, and disable common window-switching and window-management
shortcuts.

## Launch and configure the kiosk

1. In `lock.sh`, set `DEVICE_NAME_KEYWORD` to text found in the target device's
   `/dev/input/by-id` name and set `PLAY_TIME` to the desired cooldown.
2. Keep `sfx/coin.mp3` in the `sfx` directory beside the scripts.
3. From the IceWM desktop session, run `./launch_tux.sh`. It launches
   SuperTuxKart fullscreen, sends Right and Enter to the game window, and then
   starts `lock.sh` as the desktop user.

The current `xinput disable` and `xinput enable` calls in `lock.sh` are
commented out, so controller and keyboard locking is not active. The IceWM
configuration reduces access to desktop controls but is not a security
boundary; it does not prevent switching to another system session or console.

## Start and stop the kiosk with a keyboard

The `udev/99-maimundere.rules` rule starts the kiosk's user service when a
Logitech keyboard is connected. The associated `udev/maimundere@.service`
runs the launcher as the desktop user on display `:1` and binds the service
to that keyboard's input device, so systemd stops it when the device is
disconnected. The desktop user must be logged in when the keyboard is
connected.

Install the rule and user service, then reload udev and the user's systemd
manager:

```bash
sudo cp udev/99-maimundere.rules /etc/udev/rules.d/
mkdir -p ~/.config/systemd/user
cp udev/maimundere@.service ~/.config/systemd/user/
systemctl --user daemon-reload
sudo udevadm control --reload-rules
```

The rules match devices whose udev keyboard property is set and whose device
name contains `Logitech`. Change `ATTRS{name}=="*Logitech*"` in the rules if
the target keyboard reports a different name. Install the user service for
the account that owns the kiosk checkout; adjust `WorkingDirectory` and
`ExecStart` if the checkout is not at `~/maimundere`, and adjust `DISPLAY`
and `XAUTHORITY` if the X11 session differs. The desktop user must have read
access to the keyboard's input event device, as described above. Unplug and
reconnect the keyboard to apply the rules.
