{
  gptfdisk,
  e2fsprogs,
  util-linux,
  zstd,
  stdenvNoCC,
  btrfs-progs,
  vmTools,
  runCommand,
  kmod,

  bpiR3Stuff,
  config,
  rootfsImage,
  ...
}:

let
  imageSize = 7818182656; # emmc size
  bl2Start = 34;
  bl2End = 8191;
  envStart = 8192;
  envEnd = 9215;
  factoryStart = 9216;
  factoryEnd = 13311;
  fipStart = 13312;
  fipEnd = 17407;
  rootPartStart = fipEnd + 1;
  rootPartEnd = builtins.floor (imageSize / 512) - 100;
in

# the vm is suuuuuper slow
# so, do as much as possible outside of it
# but i still need it to create subvolumes
let
  template = vmTools.runInLinuxVM (
    runCommand "bpi-r3-fs-template"
      {
        preVM = ''
          truncate -s ${toString ((rootPartEnd - rootPartStart + 1) * 512)} ./tmp.img
          ${btrfs-progs}/bin/mkfs.btrfs \
            --label NIXOS_SD \
            --uuid "44444444-4444-4444-8888-888888888888" \
            ./tmp.img
        '';
        nativeBuildInputs = [
          btrfs-progs
          e2fsprogs
          util-linux
          kmod
        ];
        postVM = ''
          mkdir -p $out
          ${zstd}/bin/zstd tmp.img -o $out/template.btrfs.zst
        '';
        memSize = "4G";
        QEMU_OPTS = "-drive file=./tmp.img,format=raw,if=virtio,cache=unsafe,werror=report -rtc base=2000-01-01,clock=vm";
      }
      ''
        modprobe btrfs
        mkdir -p /mnt
        mount -t btrfs -o space_cache=v2 /dev/vda /mnt
        btrfs filesystem resize max /mnt
        btrfs subvolume create /mnt/@boot
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@nix
        chattr +C /mnt/@boot
      ''
  );
in

stdenvNoCC.mkDerivation {
  name = "bpi-r3-fs";
  nativeBuildInputs = [
    util-linux # sfdisk
    zstd
  ];
  # ${vmTools.qemu}/bin/qemu-img create -f raw $img 7818182656
  unpackPhase = "true";
  buildPhase = ''
    img=./result.img
    truncate -s ${toString imageSize} $img

    ${gptfdisk}/bin/sgdisk -o \
      --set-alignment=2 \
      -n 1:${toString bl2Start}:${toString bl2End} -c 1:bl2 -A 1:set:2 \
      -n 2:${toString envStart}:${toString envEnd} -c 2:u-boot-env \
      -n 3:${toString factoryStart}:${toString factoryEnd} -c 3:factory \
      -n 4:${toString fipStart}:${toString fipEnd} -c 4:fip \
      -n 5:${toString rootPartStart}:${toString rootPartEnd} -c 5:root -A 5:set:2 \
      $img
    dd conv=notrunc if=${bpiR3Stuff}/bl2.img of=$img seek=${toString bl2Start}
    dd conv=notrunc if=${bpiR3Stuff}/fip.bin of=$img seek=${toString fipStart}
  '';
  # i give up on making this work in a nix derivation, just do the rest in a script (./image.sh)
  # (i could do more in a vm but thats too slow, i could program a custom userspace utility but thats too annoying)
  installPhase = ''
    mkdir -p $out/boot
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d $out/boot -g 0
    ln -s ${rootfsImage} $out/rootfs.ext4
    cp ${template}/template.btrfs.zst $out
    zstd $img -o $out/image.img.zst
    echo ${toString rootPartStart} > $out/metadata
    echo ${toString rootPartEnd} >> $out/metadata
    ln -s ${bpiR3Stuff}/bl2.img $out/boot0.img
  '';
}
