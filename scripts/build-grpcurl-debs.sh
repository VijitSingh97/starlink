#!/bin/sh
# Repackage pinned upstream static binaries so APT can satisfy starlink's dependency.
set -eu
cd "$(dirname "$0")/.."
version=1.9.4
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}
export SOURCE_DATE_EPOCH
base="https://github.com/fullstorydev/grpcurl/releases/download/v$version"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p dist

build() {
    architecture=$1
    upstream_architecture=$2
    checksum=$3
    archive="grpcurl_${version}_linux_${upstream_architecture}.tar.gz"
    curl -fL --retry 3 --output "$work/$archive" "$base/$archive"
    printf '%s  %s\n' "$checksum" "$work/$archive" | sha256sum -c -
    source_dir="$work/source-$architecture"
    package="$work/package-$architecture"
    mkdir -p "$source_dir" "$package/DEBIAN" \
        "$package/usr/bin" "$package/usr/share/doc/grpcurl"
    tar -xzf "$work/$archive" -C "$source_dir"
    install -m 755 "$source_dir/grpcurl" "$package/usr/bin/grpcurl"
    install -m 644 "$source_dir/LICENSE" "$package/usr/share/doc/grpcurl/copyright"
    cat > "$package/DEBIAN/control" <<CONTROL
Package: grpcurl
Version: $version-1
Section: net
Priority: optional
Architecture: $architecture
Maintainer: Vijit Singh <VijitSingh97@users.noreply.github.com>
Homepage: https://github.com/fullstorydev/grpcurl
Description: Command-line client for gRPC services
 Official grpcurl v$version static binary repackaged for this signed APT feed.
CONTROL
    dpkg-deb --root-owner-group --build "$package" \
        "dist/grpcurl_${version}-1_${architecture}.deb"
}

# SHA-256 values from the official v1.9.4 GitHub release checksum asset.
build amd64 x86_64 97e13d58d2733a0e62cd2571d1d5f0c02823f0d25282f08bddedf1ad9c5d1736
build arm64 arm64 ad66227d90631da5428b4a5ccf28d63846f0f15649d8b2367df044a59edbb617
