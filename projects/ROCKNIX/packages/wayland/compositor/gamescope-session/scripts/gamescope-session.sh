#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 ROCKNIX (https://github.com/ROCKNIX)
#
# gamescope as the session compositor: it owns DRM directly, and the UI client
# (EmulationStation) runs inside it. This is deliberately NOT the nested layout
# ROCKNIX uses for Steam and Heroic, where sway stays the DRM owner - the whole
# point is to take sway out of the path to the display controller.
#
# Modelled on ArmadaOS gamescope-session-plus, which runs this exact
# configuration on this exact SoC. The splash/Steam-specific parts are dropped.

. /etc/profile

RUNDIR=/var/run/gamescope
LOGFILE=/var/log/gamescope.log
TRACKER=${RUNDIR}/short-sessions

### A session that dies faster than this counts as "did not come up".
SHORT_SESSION_SECONDS=60
SHORT_SESSION_LIMIT=5

mkdir -p "${RUNDIR}"
exec >>"${LOGFILE}" 2>&1
echo "=== gamescope session starting $(date)"

################################################################################
# Brick guard.
#
# The unit runs Restart=always, exactly as sway.service did. Without this a
# single mistake in the session leaves the device in an unbreakable restart loop
# with no UI and no way in. Five consecutive sessions shorter than a minute mean
# the session is not coming up, so stop trying and leave the box reachable.
################################################################################
short_session_recover() {
    echo "gamescope session failed ${SHORT_SESSION_LIMIT} times in a row, giving up"
    ### Make sure there is a way back in before we stop restarting.
    set_setting ssh.enabled 1
    systemctl start sshd 2>/dev/null
    echo "gamescope session failed to start. SSH has been enabled." >/dev/console
}

### Note the tracker is NOT cleared here. Clearing it would reset the count and
### put the device straight back into the restart loop this guard exists to
### prevent. The marker lives in /var/run, so a reboot is what clears it, and
### StartLimitBurst in the unit stops systemd retrying within seconds.
if [ -f "${RUNDIR}/gave-up" ]; then
    echo "session previously gave up, not starting (reboot to retry)"
    exit 1
fi

if [ -f "${TRACKER}" ]; then
    short_session_count=$(wc -l <"${TRACKER}")
    if [ "${short_session_count}" -ge "${SHORT_SESSION_LIMIT}" ]; then
        short_session_recover
        touch "${RUNDIR}/gave-up"
        exit 1
    fi
fi

################################################################################
# Hardware passport, written each boot by 111-gamescope-init.
################################################################################
### autostart writes the passport before `systemctl start ${UI_SERVICE}`, so
### normally it is already there. The short wait covers a race on the first
### start; a passport that never shows up is a real failure and is treated as
### one below rather than silently starting gamescope with no output, no
### geometry and no rotation - that is a black screen with nothing in the log.
passport_wait=15
while [ ! -s "${RUNDIR}/device-env" ] && [ "${passport_wait}" -gt 0 ]; do
    sleep 1
    passport_wait=$(( passport_wait - 1 ))
done
[ -s "${RUNDIR}/device-env" ] && . "${RUNDIR}/device-env"

### On-device A/B without a rebuild: anything set here wins over the passport.
### The first candidate to try on real hardware is GS_ROTATION_SHADER=0 -
### Armada relies on DRM plane rotation autodetect instead of the shader, and
### which path the DMG panel actually supports can only be measured there.
[ -f /storage/.config/gamescope/device-env ] && . /storage/.config/gamescope/device-env

: "${GS_CONNECTOR:=}"
: "${GS_OUTPUTS:=${GS_CONNECTOR}}"
: "${GS_WIDTH:=}"
: "${GS_HEIGHT:=}"
: "${GS_ORIENTATION:=normal}"
: "${GS_ROTATION_SHADER:=0}"
: "${GS_REFRESH:=}"
: "${GS_FAKE_OUTPUT_MM:=}"

if [ -z "${GS_CONNECTOR}" ]; then
    echo "no display passport (${RUNDIR}/device-env missing or empty), refusing to start blind"
    echo "$(date +%s)" >>"${TRACKER}"
    exit 1
fi

### The client. Kept as a variable so a second session (desktop, a different
### frontend) is a one-line change rather than a fork of this script.
: "${GS_CLIENT:=/usr/bin/start_es.sh}"

################################################################################
# Environment.
#
# Copied wholesale from Armada - these were arrived at by trial there, not
# reasoned out from first principles, so they are kept together and annotated
# rather than trimmed.
################################################################################
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
export HOME=/storage

### Reported upstream as giving better frame limiting.
export ENABLE_GAMESCOPE_WSI=1

### Directly relevant to why this fork exists: on ROCKNIX it was asynchronous
### page flips (sway's `allow_tearing yes`) that the DSI panel rejected with
### EBUSY, losing roughly a frame a second. Valve hit the same wall and disabled
### async flips as a stopgap. Do not turn this off without re-measuring
### `journalctl -b | grep -c "atomic commit failed"`.
export GAMESCOPE_DISABLE_ASYNC_FLIPS=1

### Do not make the client wait for buffer idle.
export vk_xwayland_wait_ready=false
export mesa_glthread=true

### Remember the chosen mode between runs.
export GAMESCOPE_MODE_SAVE_FILE="/storage/.config/gamescope/modes.cfg"
mkdir -p "$(dirname "${GAMESCOPE_MODE_SAVE_FILE}")"

### seatd hands out the DRM master lease.
export LIBSEAT_BACKEND="${LIBSEAT_BACKEND:-seatd}"

### Every client in this session is SDL2 (ES and the emulators). Without this
### SDL minimizes on focus loss, which inside a one-fullscreen-window
### compositor reads as the UI vanishing to a black screen.
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0

### Qt applications in the image (qterminal, FEXConfig) go through Xwayland,
### matching Armada's session.
export QT_QPA_PLATFORM=xcb

### gamescope rewrites the panel EDID when rotating (WritePatchedEdid) so
### clients see width/height swapped to match; it needs somewhere to put it.
export GAMESCOPE_PATCHED_EDID_FILE="${RUNDIR}/edid.bin"
touch "${GAMESCOPE_PATCHED_EDID_FILE}"

### The DMG panel reports its physical size as 0x0 mm (see the panel driver
### patch, 0052-gpu-panel-add-Pocket-DMG-panel-driver), which makes gamescope
### compute a nonsense DPI. Patch 0004 exists precisely to override it, and
### start_steam.sh already relies on this value on this device.
[ -n "${GS_FAKE_OUTPUT_MM}" ] && export GAMESCOPE_FAKE_OUTPUT_MM="${GS_FAKE_OUTPUT_MM}"

if [ ! -S "${XDG_RUNTIME_DIR}/bus" ]; then
    dbus-daemon --session --address="unix:path=${XDG_RUNTIME_DIR}/bus" &
fi

################################################################################
# Command line.
################################################################################
GAMESCOPE_ARGS="--backend drm"

### Native resolution of the panel, before rotation.
[ -n "${GS_WIDTH}" ]  && GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -W ${GS_WIDTH}"
[ -n "${GS_HEIGHT}" ] && GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -H ${GS_HEIGHT}"
[ -n "${GS_REFRESH}" ] && GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -r ${GS_REFRESH}"
[ -n "${GS_OUTPUTS}" ] && GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --prefer-output ${GS_OUTPUTS}"

### Rotation replaces sway's `output <con> transform <angle>`.
if [ "${GS_ORIENTATION}" != "normal" ]; then
    GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --force-orientation ${GS_ORIENTATION}"
    [ "${GS_ROTATION_SHADER}" = "1" ] && GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --use-rotation-shader"
fi

### EmulationStation is an SDL2 application, and ROCKNIX builds SDL2 with
### -DVIDEO_X11=OFF. It therefore CANNOT go through Xwayland and has to reach
### gamescope's own compositor - which is what --expose-wayland turns on
### (usage text: "support wayland clients using xdg-shell"). Removing this flag
### leaves the device with a black screen and no obvious reason why.
GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --expose-wayland"

### Two Xwayland servers, matching Armada: one for the client, one for games.
### Kept even though ES itself is a Wayland client, because Steam/Heroic/Proton
### running inside this session do use X11.
GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --xwayland-count 2"

### Touch behaves as a passthrough pointing device, cursor hides on idle.
GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --default-touch-mode 4 --hide-cursor-delay 3000 --fade-out-duration 200"

### Per-device escape hatch, no image rebuild required.
[ -f /storage/.config/gamescope/args ] && \
    GAMESCOPE_ARGS="${GAMESCOPE_ARGS} $(cat /storage/.config/gamescope/args)"

################################################################################
# Start gamescope and complete the handshake.
#
# gamescope opens the -R path O_WRONLY, which blocks on a fifo until somebody
# opens the read end, and writes "<x-display> <wayland-display>" once the
# compositor is actually up. Reading it with <> (read-write) instead of <
# avoids a deadlock where both sides wait for the other to open.
#
# Without this step the client has no way to find the compositor.
################################################################################
socket="${RUNDIR}/ready.fifo"
stats="${RUNDIR}/stats.fifo"
rm -f "${socket}" "${stats}"
mkfifo -- "${socket}" "${stats}"

### mangoapp and gamescopectl locate the stats fifo through this.
export GAMESCOPE_STATS="${stats}"

session_start=$(date +%s)

### Three variables are stripped from gamescope's own environment, and only
### from gamescope's - the client below still needs all three:
###
###   WAYLAND_DISPLAY   present => gamescope comes up NESTED instead of taking
###                     DRM, which is the exact failure this whole change exists
###                     to avoid. start_steam.sh guards against it the same way.
###   DISPLAY           same story for the X11 path.
###   MESA_LOADER_DRIVER_OVERRIDE
###                     the SM8550 quirk pins this to zink. gamescope talks to
###                     Turnip directly and start_steam.sh unsets it before
###                     launching gamescope for the same reason.
echo "gamescope ${GAMESCOPE_ARGS} -R ${socket} -T ${stats}"
env -u WAYLAND_DISPLAY -u DISPLAY -u MESA_LOADER_DRIVER_OVERRIDE \
    /usr/bin/gamescope ${GAMESCOPE_ARGS} -R "${socket}" -T "${stats}" &
gamescope_pid=$!

if read -r -t 30 response_x_display response_wl_display <>"${socket}"; then
    export DISPLAY="${response_x_display}"
    export GAMESCOPE_WAYLAND_DISPLAY="${response_wl_display}"
    export WAYLAND_DISPLAY="${response_wl_display}"
    echo "gamescope ready: DISPLAY=${DISPLAY} WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
else
    echo "gamescope did not report ready within 30s, aborting"
    kill -9 "${gamescope_pid}" 2>/dev/null
    echo "$(date +%s)" >>"${TRACKER}"
    exit 1
fi

### Publish the handshake so anything started later in the session (screenshot
### helper, output monitor, a shell over SSH) can reach the compositor too.
{
    echo "DISPLAY=${DISPLAY}"
    echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
    echo "GAMESCOPE_WAYLAND_DISPLAY=${GAMESCOPE_WAYLAND_DISPLAY}"
    echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
} >"${RUNDIR}/env"

################################################################################
# Run the client in the foreground. When it exits, so does the session.
################################################################################
cleanup() {
    kill "${gamescope_pid}" 2>/dev/null
    wait "${gamescope_pid}" 2>/dev/null
    rm -f "${socket}" "${stats}" "${RUNDIR}/env"
}
trap cleanup EXIT INT TERM

echo "starting client: ${GS_CLIENT}"
"${GS_CLIENT}"
client_status=$?

session_end=$(date +%s)
session_length=$(( session_end - session_start ))
echo "=== session ended after ${session_length}s, client exit ${client_status}"

### Only consecutive short sessions matter: one good long run clears the count.
### A short session counts as a failure only when it looks like one: the client
### died with an error, or the compositor is gone. A clean ES exit seconds
### after start is somebody restarting the UI from the settings menu - five of
### those in a row must not walk a healthy device into the gave-up state.
### (The gamescope check runs before the EXIT trap kills it, so a live pid here
### really means the compositor survived the whole session.)
if [ "${session_length}" -lt "${SHORT_SESSION_SECONDS}" ]; then
    if [ "${client_status}" -ne 0 ] || ! kill -0 "${gamescope_pid}" 2>/dev/null; then
        echo "${session_end}" >>"${TRACKER}"
    fi
else
    rm -f "${TRACKER}"
fi

exit "${client_status}"
