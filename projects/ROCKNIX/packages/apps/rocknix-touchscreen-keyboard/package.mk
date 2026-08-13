# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2025-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="rocknix-touchscreen-keyboard"
PKG_VERSION="v0.17"
PKG_LICENSE="GPLv3"
PKG_SITE="https://github.com/jjsullivan5196/wvkbd"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_LONGDESC="wvkbd - On-screen keyboard for wlroots that sucks less"
# sway was never actually needed to build this: wvkbd carries its own protocol
# XML in proto/ (wlr-layer-shell, virtual-keyboard, xdg-shell, viewporter) and
# its Makefile asks pkg-config for exactly "wayland-client xkbcommon pangocairo".
# The dependency was dragging the entire compositor in behind an on-screen
# keyboard, which is what kept this package tied to sway images.
PKG_DEPENDS_TARGET="toolchain wayland pango libxkbcommon cairo"
PKG_TOOLCHAIN="make"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp -rf ${PKG_BUILD}/wvkbd-mobintl ${INSTALL}/usr/bin
  cp -rf ${PKG_DIR}/sources/* ${INSTALL}/usr/bin
  chmod 0755 ${INSTALL}/usr/bin/*
}

post_install() {
  enable_service touchkeyboard.service
}
