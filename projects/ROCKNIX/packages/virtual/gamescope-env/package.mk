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
fi
