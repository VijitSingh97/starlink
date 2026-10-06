#!/bin/sh
# Build patched grpcurl binaries from checksum-verified Go module source.
set -eu
cd "$(dirname "$0")/.."
version=1.9.4
revision=2
crypto_version=v0.57.0
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}
export SOURCE_DATE_EPOCH CGO_ENABLED=0 GOTOOLCHAIN=go1.27.1
export GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p dist

go mod download "github.com/fullstorydev/grpcurl@v$version"
module_dir="$(go env GOMODCACHE)/github.com/fullstorydev/grpcurl@v$version"
source_dir="$work/grpcurl-$version"
cp -R "$module_dir" "$source_dir"
chmod -R u+w "$source_dir"
(
    cd "$source_dir"
    go get "golang.org/x/crypto@$crypto_version"
    go mod verify
    go mod vendor
)
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 \
    --numeric-owner --format=gnu -cf "$work/source.tar" -C "$work" \
    "grpcurl-$version"
gzip -n -c "$work/source.tar" > "dist/grpcurl_${version}-${revision}_source.tar.gz"

build() {
    architecture=$1
    package="$work/package-$architecture"
    mkdir -p "$package/DEBIAN" "$package/usr/bin" \
        "$package/usr/share/doc/grpcurl"
    (
        cd "$source_dir"
        GOOS=linux GOARCH="$architecture" go build -mod=vendor -trimpath \
            -buildvcs=false \
            -ldflags "-X main.version=v$version" \
            -o "$package/usr/bin/grpcurl" ./cmd/grpcurl
    )
    install -m 644 "$source_dir/LICENSE" "$package/usr/share/doc/grpcurl/copyright"
    cat > "$package/DEBIAN/control" <<CONTROL
Package: grpcurl
Version: $version-$revision
Section: net
Priority: optional
Architecture: $architecture
Maintainer: Vijit Singh <VijitSingh97@users.noreply.github.com>
Homepage: https://github.com/fullstorydev/grpcurl
Description: Command-line client for gRPC services
 grpcurl v$version built from source with patched Go dependencies.
CONTROL
    dpkg-deb --root-owner-group --build "$package" \
        "dist/grpcurl_${version}-${revision}_${architecture}.deb"
}

build amd64
build arm64
