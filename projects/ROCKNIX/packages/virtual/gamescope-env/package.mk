# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="gamescope-env"
PKG_VERSION=""
PKG_LICENSE="GPL"
PKG_SITE="https://rocknix.org"
PKG_URL=""
PKG_SECTION="virtual"
PKG_LONGDESC="gamescope-env: gamescope session compositor environment"

if [ ! "${BASE_ONLY}" = "true" ]
then
  # gamescope owns DRM here, so it is a hard dependency rather than something
  # Steam drags in. xwayland is listed explicitly: sway used to be the only
  # package pulling it in, and gamescope spawns the Xwayland binary at runtime
  # without declaring a build-time dependency on it.
  #
  # xkbcomp travels with xwayland and is NOT optional, however small it looks.
  # Xwayland 24.1 is built here without -Dxkb_bin_dir, so it shells out to
  # /usr/bin/xkbcomp while setting up its virtual core keyboard - before it ever
  # touches Wayland. Miss it and InitCoreDevices reaches
  # FatalError("Failed to activate virtual core keyboard"), Xwayland dies before
  # writing its display name, gamescope blocks forever in wlserver_init waiting
  # for xwayland-ready, the -R handshake is never written, and the session times
  # out and restarts until the guard gives up. A black screen on every boot,
  # recoverable only over SSH. sway listed xwayland and xkbcomp side by side for
  # exactly this reason.
  PKG_DEPENDS_TARGET+=" gamescope gamescope-session xwayland xkbcomp"

  # Inherited from swaywm-env because dropping them would break things far away
  # from the compositor:
  #   foot       the only terminal in the image, and it arrived solely as a sway
  #              dependency. scripts/run and the RUNCOMMAND path for text-mode
  #              content both exec it.
  #   wlr-randr  ships set_refresh_rate() in profile.d, which runemu.sh calls on
  #              every launch. gamescope does not speak wlr-output-management so
  #              the call is inert, but the function has to exist or the emulator
  #              wrapper dies on "command not found".
  PKG_DEPENDS_TARGET+=" foot wlr-randr"

  # rocknix-screenshot is NOT inherited: it is grim plus swaymsg, and gamescope
  # implements neither wlr-screencopy nor sway's IPC.
fi
