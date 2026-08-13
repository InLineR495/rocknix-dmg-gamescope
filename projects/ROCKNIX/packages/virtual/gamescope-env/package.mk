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
  PKG_DEPENDS_TARGET+=" gamescope gamescope-session xwayland"

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
