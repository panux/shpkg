#!/bin/sh

CONFIG=/etc/shpkg/pkg.conf
PKGLIST=/etc/shpkg/pkgs.list

loadconfig() {
    source $CONFIG
}
loadpkglist() {
    PKGS=$(cat $PKGLIST | tr "\n" " ")
}

savepkglist() {
    printf '%s\n' "$@" > $PKGLIST
}

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf $TMPDIR
}

echo "Loading config"
loadconfig
echo "Loading package list"
loadpkglist

case $1 in
install)
    if [ "$#" -ne 2 ]; then
        echo "I dont know what to install!"
        exit 1
    fi
    PKG="$2"
    if [[ " ${PKGS[@]} " =~ " ${PKG} " ]]; then
        echo "$PKG already installed. Nothing to do."
    fi
    echo "Installing $2"
    if [ -z "$REPO" ]; then
        echo "REPO not set"
        exit 1
    fi
    if [ -z "$GPGDIR" ]; then
        echo "GPGDIR not set"
        exit 1
    fi
    PKGDIR="$TMPDIR"
    echo "Downloading package and sig"
    wget "$REPO/pkgs/$2.tar.xz" -O "$TMPDIR/$2.tar.xz" || { echo "Download error"; exit 2 }
    wget "$REPO/pkgs/$2.tar.xz.sig" -O "$TMPDIR/$2.tar.xz.sig" || { echo "Download error"; exit 2 }
    gpg --verify "$TMPDIR/$2.tar.xz.sig" "$TMPDIR/$2.tar.xz" --homedir "$GPGDIR" || { echo "GPG verification error"; exit 3 }
    tar -xf "$TMPDIR/$2.tar.xz" -C "$TMPDIR" .pkginfo || { echo "Failed to extract .pkginfo"; exit 4 }
    source "$TMPDIR/.pkginfo"
    rm "$TMPDIR/.pkginfo"
    echo "Installing dependencies for $2"
    for i in $DEPENDENCIES; do
        shpkg install "$i" || { echo "Failed to install $i"; exit 5 }
    done
    loadpkglist
    tar -xvf "$TMPDIR/$2.tar.xz" -C / || { echo "Failed to extract package"; exit 4 }
    PKGS+=" $2"
    savepkglist $PKGS
    ;;
esac
