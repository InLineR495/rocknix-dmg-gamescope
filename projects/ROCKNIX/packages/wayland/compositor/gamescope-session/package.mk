# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="gamescope-session"
PKG_VERSION=""
PKG_LICENSE="GPL"
PKG_SITE="https://rocknix.org"
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain gamescope xwayland"
PKG_LONGDESC="Runs gamescope as the session compositor, owning DRM directly, with EmulationStation as its client."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
    cp ${PKG_DIR}/scripts/gamescope-session.sh ${INSTALL}/usr/bin
    chmod +x ${INSTALL}/usr/bin/gamescope-session.sh

  # Stubs for two binaries that leave the image with sway but are still called
  # unconditionally from shared scripts built for every device. Installing them
  # here rather than editing those scripts keeps sway devices untouched - the
  # real tools ship from mako-osd and rocknix-screenshot, and neither package is
  # in a gamescope image, so the paths cannot collide.
    cp ${PKG_DIR}/scripts/mako-notify        ${INSTALL}/usr/bin
    cp ${PKG_DIR}/scripts/rocknix-screenshot ${INSTALL}/usr/bin
    chmod +x ${INSTALL}/usr/bin/mako-notify ${INSTALL}/usr/bin/rocknix-screenshot

  mkdir -p ${INSTALL}/usr/lib/autostart/common
    cp ${PKG_DIR}/autostart/111-gamescope-init ${INSTALL}/usr/lib/autostart/common
    chmod +x ${INSTALL}/usr/lib/autostart/common/111-gamescope-init
}
