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

  mkdir -p ${INSTALL}/usr/lib/autostart/common
    cp ${PKG_DIR}/autostart/111-gamescope-init ${INSTALL}/usr/lib/autostart/common
    chmod +x ${INSTALL}/usr/lib/autostart/common/111-gamescope-init
}
