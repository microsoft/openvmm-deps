#!/bin/sh

set -e

# Add custom init script
install -m755 "$PKGDIR"/init "$SYSROOT"/init

# Add udhcpc script from Alpine
install -m755 -D "$PKGDIR"/default.script "$SYSROOT"/usr/share/udhcpc/default.script
