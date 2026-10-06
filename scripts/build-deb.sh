#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
version=$(cat VERSION)
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}
export SOURCE_DATE_EPOCH
package=$(mktemp -d)
trap 'rm -rf "$package"' EXIT
make install DESTDIR="$package" PREFIX=/usr \
    ZSH_COMPLETION_DIR=/usr/share/zsh/vendor-completions
install -d "$package/DEBIAN" "$package/usr/share/doc/starlink"
install -m 644 LICENSE "$package/usr/share/doc/starlink/copyright"
cat > "$package/DEBIAN/control" <<CONTROL
Package: starlink
Version: $version
Section: net
Priority: optional
Architecture: all
Maintainer: Vijit Singh <VijitSingh97@users.noreply.github.com>
Depends: bash, jq, grpcurl (>= 1.9.4-2)
Homepage: https://github.com/VijitSingh97/starlink
Description: List clients connected to a Starlink router
 A read-only command that prints router clients as a table or normalized JSON.
CONTROL
mkdir -p dist
dpkg-deb --root-owner-group --build "$package" "dist/starlink_${version}_all.deb"
