# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2023 JELOS (https://github.com/JustEnoughLinuxOS)

PKG_NAME="gamesupport"
PKG_LICENSE="GPLv2"
PKG_SITE="https://rocknix.org"
PKG_SECTION="virtual"
PKG_LONGDESC="Game support software metapackage."

PKG_GAMESUPPORT="sixaxis rocknix-hotkey jstest-sdl gamecontrollerdb sdljoytest sdltouchtest control-gen sdl2text"

case ${DEVICE} in
  RK3326|S922X|SM6115|SM8250|SM8550|SM8650|SM8750)
    PKG_GAMESUPPORT+=" mangohud"
    ;;
esac

# The on-screen keyboard needs a compositor that speaks wlr-layer-shell and
# zwp_virtual_keyboard_manager_v1. sway has both; gamescope has layer-shell
# already and gets the virtual keyboard from patch 0007 in its package.
#
# Matched exactly, not by glob: RK3588 sets WINDOWMANAGER="weston swaywm-env"
# and never shipped the keyboard - a substring match would add it there, and
# its touchkeyboard.service would respawn a dying wvkbd forever on weston
# boots, which have no layer-shell.
case "${WINDOWMANAGER}" in
  swaywm-env|gamescope-env)
    PKG_GAMESUPPORT+=" rocknix-touchscreen-keyboard"
    ;;
esac

PKG_DEPENDS_TARGET="${PKG_GAMESUPPORT}"

