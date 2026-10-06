#!/bin/sh
# Requires apt-utils, GnuPG, and the repository signing key in GNUPGHOME.
set -eu
cd "$(dirname "$0")/.."
version=$(cat VERSION)
rm -rf public
mkdir public
cp "dist/starlink_${version}_all.deb" \
    dist/grpcurl_1.9.4-1_amd64.deb dist/grpcurl_1.9.4-1_arm64.deb public/
cd public
gpg --batch --armor --export > starlink.asc
apt-ftparchive packages . > Packages
gzip -n -k -f Packages
apt-ftparchive -o APT::FTPArchive::Release::Origin=starlink \
    -o APT::FTPArchive::Release::Label=starlink \
    -o 'APT::FTPArchive::Release::Architectures=amd64 arm64 all' \
    release . > Release
gpg --batch --yes --armor --detach-sign --output Release.gpg Release
gpg --batch --yes --clearsign --output InRelease Release
