#!/usr/bin/env python3
# because nixos-rebuild --target-host is too flaky

import json
import os
import subprocess
import sys

with open(os.path.expanduser("~/var/addresses.json"), "rt") as f:
    opts = json.loads(f.read())


def main():
    args = sys.argv
    cfg = args[1]
    if "@" in cfg:
        cfg, addr = cfg.split("@")
    else:
        addr = opts["addresses"][cfg]
    build_host = opts["build_host"].get(cfg)
    act = args[2]
    assert act in ["boot", "switch", "test"]
    args = args[3:]
    args.extend(
        [
            "--option",
            "extra-builtins-file",
            os.path.dirname(__file__) + "/extra-builtins.nix",
        ]
    )
    attr_path = f".#nixosConfigurations.{cfg}.config.system.build.toplevel"
    copy_args = []
    do_copy = True
    if build_host is not None:
        build_host = addr if cfg == build_host else opts["addresses"][build_host]
        cmd = ["nix", "eval", "--json", attr_path + ".drvPath"] + args
        ret = subprocess.run(cmd, check=True, encoding="utf-8", stdout=subprocess.PIPE)
        drv = json.loads(ret.stdout)
        print('copying', drv, 'to build host')
        cmd = [
            "nix",
            "copy",
            drv,
            "--derivation",
            "--to",
            "ssh-ng://root@" + build_host,
        ] + args
        subprocess.run(cmd, check=True)
        print('building', drv)
        cmd = ["nix", "build", f"'{drv}^*'", "--no-link", "--json"] + args
        ret = subprocess.run(
            ["ssh", "root@" + build_host],
            input=" ".join(cmd) + "\n",
            check=True,
            encoding="utf-8",
            stdout=subprocess.PIPE,
        )
        if cfg == build_host:
            do_copy = False
        else:
            copy_args.extend(["--from", "ssh-ng://root@" + build_host])
    else:
        print('building', drv)
        cmd = ["nix", "build", attr_path, "--no-link", "--json"] + args
        ret = subprocess.run(cmd, check=True, encoding="utf-8", stdout=subprocess.PIPE)
    ret = json.loads(ret.stdout)[0]["outputs"]["out"]
    print(drv, 'output', ret)
    cmds = []
    if act in ["boot", "switch"]:
        cmds.append(["nix-env", "-p", "/nix/var/nix/profiles/system", "--set", ret])
    cmds.append(
        ["env", "NIXOS_INSTALL_BOOTLOADER=", ret + "/bin/switch-to-configuration", act]
    )
    if addr is None:
        for cmd in cmds:
            print('running', *cmd)
            cmd = ["sudo", "-A"] + cmd
            subprocess.run(cmd, check=True)
    else:
        if do_copy:
            print('copying', ret, 'to', addr)
            print(*(["nix", "copy", ret, "--no-check-sigs", "--to", "ssh-ng://root@" + addr] + copy_args + args))
            subprocess.run(
                ["nix", "copy", ret, "--no-check-sigs", "--to", "ssh-ng://root@" + addr]
                + copy_args
                + args,
                check=True,
            )
        print('running', *cmd)
        subprocess.run(
            ["ssh", "root@" + addr],
            input="\n".join(" ".join(cmd) for cmd in cmds) + "\n",
            check=True,
            encoding="utf-8",
        )


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError:
        sys.exit(1)
