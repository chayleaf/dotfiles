#!/usr/bin/env bash

# this step requires either root access or access to fuse
# nix builder doesnt have access to either
# i could run this in a vm, but that's slow as fuck because i'm building this on x86_64-linux
# usage: image.sh [path to image.nix output]

set -euxo pipefail

(which zstd && which rsync) || exit 1

userspace="$(which lklfuse >/dev/null && echo -n 1 || echo -n)"
use_rsync="$(which rsync >/dev/null && echo -n 1 || echo -n)"
function Mount() {
  if [[ "$userspace" == "1" ]]; then
    if [[ "${4-}" == "ro" ]]; then
      lklfuse -o "type=$1" -o "$4" "$2" "$3"
    elif [ -n "${4-}" ]; then
      lklfuse -o "type=$1" -o "opts=$4" "$2" "$3"
    else
      lklfuse -o "type=$1" "$2" "$3"
    fi
  elif [ -n "${4-}" ]; then
    sudo -A mount -t "$1" -o "loop,$4" "$2" "$3"
  else
    sudo -A mount -t "$1" -o loop "$2" "$3"
  fi
}
function run() {
  if [[ "$userspace" == "1" ]]; then
    "$@"
  else
    sudo -A "$@"
  fi
}
function cpr() {
  if [[ "$use_rsync" == "1" ]]; then
    run rsync -a --info=progress2 "$1/" "$2/"
  else
    run cp -rv "$1"/* "$2/"
  fi
}

if [ -z "$1" ]; then
  echo "missing argument"
  exit 1
fi
rootfs="$1/rootfs.ext4"
template="$1/template.btrfs"
image="$1/image.img"
boot="$1/boot"

metadata0="$(head -n1 "$1/metadata")"
metadata1="$(head -n2 "$1/metadata" | tail -n1)"
if [ -z "$metadata0" ] || [ -z "$metadata1" ] || [[ "$metadata0" == "$metadata1" ]]; then
  echo "invalid metadata"
  exit 1
fi

tmp=$(mktemp -d)
cp "$template" "$tmp/template.btrfs"
cp "$image" "$tmp/image.img"
template="$tmp/template.btrfs"
image="$tmp/image.img"
chmod +w "$template" "$image"

function cleanup {
  run umount "$rootfs" || echo -n
  run umount "$tmp/out" || echo -n
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/rootfs" "$tmp/out"
Mount ext4 "$rootfs" "$tmp/rootfs" ro
rootfs="$tmp/rootfs"
Mount btrfs "$template" "$tmp/out"
run cp -rv "$boot"/* "$tmp/out/@boot/"
run umount "$tmp/out"
Mount btrfs "$template" "$tmp/out" "compress=zstd:15"
run cp -v "$rootfs/nix-path-registration" "$tmp/out/@/"
run ls "$boot"
cpr "$boot" "$tmp/out/@boot"
cpr "$rootfs/nix" "$tmp/out/@nix"

run umount "$rootfs"
run umount "$tmp/out"

dd conv=notrunc if="$template" of="$image" seek="$metadata0"

zstd --compress "$image"
cp "$image.zst" ./image.img.zst
