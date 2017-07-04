#!/bin/sh

if [ -z $ROOTFS ]; then
    ROOTFS=/
fi
if [ -z $SHPKGDIR ]; then
    SHPKGDIR=$ROOTFS/etc/shpkg
fi
if [ -z $CONFIG ]; then
    CONFIG=$SHPKGDIR/pkg.conf
fi
if [ -z $PKGLIST ]; then
    PKGLIST=$SHPKGDIR/pkgs.list
fi
if [ -z $SHPKG ]; then
    SHPKG=shpkg
fi

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
    if [ ! -z "$CLEANFILES" ]; then
        rm -f $CLEANFILES
    fi
}
trap cleanup EXIT

installed() {
    for i in $@; do
        if [ "$i" == "$PKG" ]; then
            return 1
        fi
    done
}

load() {
    export SHPKGDIR
    echo "Loading config"
    loadconfig
    echo "Loading package list"
    loadpkglist
}

case $1 in
bootstrap)
    if [ $ROOTFS == / ]; then
        echo "ROOTFS not set. Aborting."
        exit 1
    fi
    if [ "$#" -ne 2 ]; then
        echo "I dont know where my files are!"
        exit 1
    fi
    echo "Initializing shpkg"
    CONFIG=$2/default.conf
    PKGLIST=$2/pkgs.list
    touch $PKGLIST
    load
    CONFIG=$2/tmp.conf
    CLEANFILES="$CONFIG $PKGLIST"
    echo REPO=$REPO > $CONFIG
    echo GPGDIR=~/.gnupg >> $CONFIG
    export SHPKGDIR=$2
    export ROOTFS
    export CONFIG
    export PKGLIST
    export SHPKG=$2/shpkg.sh
    chmod 700 $SHPKG
    $SHPKG install base
    mv $PKGLIST $ROOTFS/etc/shpkg/pkgs.list
    ;;
install)
    load
    if [ "$#" -ne 2 ]; then
        echo "I dont know what to install!"
        exit 1
    fi
    PKG="$2"
    installed $PKGS || { echo "$PKG is installed. Nothing to do."; exit 0; }
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
    wget "$REPO/pkgs/$2.tar.xz" -O "$TMPDIR/$2.tar" || { echo "Download error"; exit 2; }
    wget "$REPO/pkgs/$2.sig" -O "$TMPDIR/$2.sig" || { echo "Download error"; exit 2; }
    gpgv --homedir "$GPGDIR" "$TMPDIR/$2.sig" "$TMPDIR/$2.tar" || { echo "GPG verification error"; exit 3; }
    tar -xf "$TMPDIR/$2.tar" -C "$TMPDIR" ./.pkginfo || { echo "Failed to extract .pkginfo"; exit 4; }
    source "$TMPDIR/.pkginfo"
    rm "$TMPDIR/.pkginfo"
    echo "Installing dependencies for $2"
    for i in $DEPENDENCIES; do
        $SHPKG install "$i" || { echo "Failed to install $i"; exit 5; }
    done
    loadpkglist
    tar -xvf "$TMPDIR/$2.tar" -C $ROOTFS || { echo "Failed to extract package"; exit 4; }
    PKGS="$PKGS $2"
    savepkglist $PKGS
    ;;
esac
