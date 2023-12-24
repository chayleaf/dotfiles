#!/usr/bin/env bash

# this step requires either root access or access to fuse
# nix builder doesnt have access to either
# i could run this in a vm, but that's slow as fuck because i'm building this on x86_64-linux
# usage: image.sh [path to image.nix output]

set -euxo pipefail

which zstd || exit 1

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
template="$1/template.btrfs.zst"
image="$1/image.img.zst"
boot="$1/boot"

metadata0="$(head -n1 "$1/metadata")"
metadata1="$(head -n2 "$1/metadata" | tail -n1)"
if [ -z "$metadata0" ] || [ -z "$metadata1" ] || [[ "$metadata0" == "$metadata1" ]]; then
  echo "invalid metadata"
  exit 1
fi

tmp=$(mktemp -d)
cp "$template" "$tmp/template.btrfs.zst"
cp "$image" "$tmp/image.img.zst"
template="$tmp/template.btrfs"
image="$tmp/image.img"
unzstd --rm "$template.zst"
unzstd --rm "$image.zst"
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
cpr "$boot" "$tmp/out/@boot"
run umount "$tmp/out"
Mount btrfs "$template" "$tmp/out" "compress=zstd:15"
run cp -v "$rootfs/nix-path-registration" "$tmp/out/@/"
# those two are the only dirs needed for impermanence in boot stage 1
run mkdir -p "$tmp/out/@/var/lib/nixos"
run mkdir -p "$tmp/out/@/var/log"

# secrets, we don't want to pass them via the store
run mkdir -p "$tmp/out/@/secrets"
run cp -v /secrets/nixos/wireguard-key "$tmp/out/@/secrets/"
run chmod -R 000 "$tmp/out/@/secrets"

cpr "$rootfs/nix" "$tmp/out/@nix"

run umount "$rootfs"
run umount "$tmp/out"

dd conv=notrunc if="$template" of="$image" seek="$metadata0"

zstd -f --rm --compress "$image" -o ./image.img.zst 
