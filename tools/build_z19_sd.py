"""Build a recovery SD payload from the four existing senior-provided files.

Usage: python tools/build_z19_sd.py --source SOURCE --output EMPTY_NEW_DIRECTORY
No third-party modules, VM, Linux installation or disk access are required.
"""
from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import posixpath
import shutil
import stat
import struct
import tarfile

from z19_image_formats import Node, decode_string, encode_fdt, newc_entry, parse_fdt, script_image, string

EXPECTED = {
    "BOOT.BIN": "a1719b4dba5ea3520b9498e2063d557f4657e65cf8bf3ecfee72379445553b86",
    "boot.scr": "b3767ea01003c31baf90e3b1b541c7e385a5ab5db9952a9d07abbdec1b0d3eac",
    "image.ub": "e923606f9e5a428e7e76eb2b40a81415f474d041e980960220bcd2052fd978ad",
    "rootfs.tar.gz": "4f05d24af1b04d3490dde9d3526c4119b9d2e08752b2954c96cfe167f57ddf34",
}
REPO = Path(__file__).resolve().parents[1]
FIT_ADDRESS = 0x10000000
MAX_FIT_SIZE = 64 * 1024 * 1024


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def safe_name(name: str) -> str:
    if name.startswith("/") or ".." in PurePosixPath(name).parts:
        raise ValueError(f"Unsafe archive path: {name}")
    return posixpath.normpath(name).removeprefix("./")


def elf_dependencies(data: bytes) -> tuple[list[str], str | None]:
    """Read AArch64 ELF64 PT_INTERP and DT_NEEDED without executing the ELF."""
    if not data.startswith(b"\x7fELF"):
        return [], None
    if data[4:6] != b"\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 183:
        raise ValueError("Recovery program is not little-endian AArch64 ELF64")
    phoff = struct.unpack_from("<Q", data, 32)[0]
    phsize, count = struct.unpack_from("<HH", data, 54)
    headers = [struct.unpack_from("<II6Q", data, phoff + i * phsize) for i in range(count)]
    interpreter = next((data[h[2]:h[2] + h[5]].rstrip(b"\0").decode() for h in headers if h[0] == 3), None)
    tags = []
    for h in headers:
        if h[0] == 2:
            for offset in range(h[2], h[2] + h[5], 16):
                tag, value = struct.unpack_from("<qQ", data, offset)
                if tag == 0:
                    break
                tags.append((tag, value))
    address = next((v for tag, v in tags if tag == 5), None)
    needed = [v for tag, v in tags if tag == 1]
    if not needed:
        return [], interpreter
    segment = next((h for h in headers if h[0] == 1 and h[3] <= address < h[3] + h[5]), None)
    if segment is None:
        raise ValueError("ELF dynamic string table is outside loadable segments")
    start = segment[2] + address - segment[3]
    return [data[start + n:data.index(0, start + n)].decode("ascii") for n in needed], interpreter


class RootArchive:
    def __init__(self, path: Path):
        self.tar = tarfile.open(path, "r:gz")
        self.members = {}
        for member in self.tar.getmembers():
            name = safe_name(member.name)
            if name in self.members:
                raise ValueError(f"Duplicate root archive member: {name}")
            if member.islnk():
                safe_name(member.linkname)
            self.members[name] = member
        self.selected: set[str] = set()
        self.cache: dict[str, bytes] = {}

    def resolve(self, name: str, *, select: bool = False, depth: int = 0) -> str:
        if depth > 40:
            raise ValueError(f"Link loop: {name}")
        name = safe_name(posixpath.normpath(name.lstrip("/")))
        parts = name.split("/")
        for i in range(len(parts)):
            prefix = "/".join(parts[:i + 1])
            member = self.members.get(prefix)
            if member is None:
                raise ValueError(f"Missing root archive member: {prefix}")
            if select:
                self.selected.add(prefix)
            if member.issym() or member.islnk():
                target = member.linkname
                if member.issym() and not target.startswith("/"):
                    target = posixpath.join(posixpath.dirname(prefix), target)
                target = posixpath.join(target.lstrip("/"), *parts[i + 1:])
                return self.resolve(target, select=select, depth=depth + 1)
        return name

    def read(self, name: str) -> bytes:
        resolved = self.resolve(name)
        if resolved in self.cache:
            return self.cache[resolved]
        member = self.members[resolved]
        stream = self.tar.extractfile(member)
        if stream is None:
            raise ValueError(f"Not a regular file: {name}")
        data = stream.read()
        self.cache[resolved] = data
        return data

    def include_program(self, name: str) -> None:
        pending = [name]
        scanned = set()
        while pending:
            resolved = self.resolve(pending.pop(), select=True)
            if resolved in scanned:
                continue
            scanned.add(resolved)
            dependencies, interpreter = elf_dependencies(self.read(resolved))
            if interpreter:
                pending.append(interpreter)
            for library in dependencies:
                candidate = next((f"{d}/{library}" for d in ("lib", "usr/lib", "lib64", "usr/lib64")
                                  if f"{d}/{library}" in self.members), None)
                if candidate is None:
                    raise ValueError(f"Missing dynamic dependency {library} for {resolved}")
                pending.append(candidate)

    def recovery_cpio(self) -> bytes:
        for name in ("bin/busybox", "bin/tar.tar", "bin/gzip.gzip", "sbin/mkfs.ext4", "sbin/blkid.util-linux", "sbin/fsck.ext4"):
            self.include_program(name)
        for name in ("etc/mke2fs.conf", "etc/ld.so.conf", "etc/ld.so.cache"):
            if name in self.members:
                self.resolve(name, select=True)
        entries: dict[str, dict] = {}
        groups: dict[str, list[str]] = {}
        for name in sorted(self.selected):
            member = self.members[name]
            kind = stat.S_IFDIR if member.isdir() else stat.S_IFLNK if member.issym() else stat.S_IFREG
            if not (member.isdir() or member.issym() or member.isreg() or member.islnk()):
                raise ValueError(f"Unsupported selected archive member: {name}")
            data = member.linkname.encode() if member.issym() else b"" if member.isdir() else self.read(name)
            entries[name] = dict(data=data, mode=kind | member.mode, uid=member.uid, gid=member.gid, mtime=int(member.mtime))
            if kind == stat.S_IFREG:
                key = self.resolve(name) if member.islnk() else name
                groups.setdefault(key, []).append(name)
        # Additional files are only in the temporary RAM root, never in the source archive.
        for name in ("dev", "proc", "sys", "run", "tmp", "boot", "target", "bin", "sbin", "etc"):
            if name not in entries:
                entries[name] = dict(data=b"", mode=stat.S_IFDIR | (0o1777 if name == "tmp" else 0o755))
        for name, target in {"bin/sh": "busybox", "bin/tar": "tar.tar", "bin/gzip": "gzip.gzip", "sbin/blkid": "blkid.util-linux"}.items():
            entries[name] = dict(data=target.encode(), mode=stat.S_IFLNK | 0o777)
        entries["etc/mtab"] = dict(data=b"/proc/mounts", mode=stat.S_IFLNK | 0o777)
        for applet in ("mount", "umount", "mkdir", "cat", "awk", "grep", "sed", "readlink", "sleep", "sync", "sha256sum", "wc", "chmod", "mv", "cp", "touch", "reboot", "dmesg", "ls", "stat", "chroot", "uname", "date"):
            entries[f"bin/{applet}"] = dict(data=b"busybox", mode=stat.S_IFLNK | 0o777)
        for name, source in {"init": "host/scripts/z19_recovery_init.sh", "install-z19-root.sh": "host/scripts/install_z19_root.sh"}.items():
            entries[name] = dict(data=(REPO / source).read_bytes().replace(b"\r\n", b"\n"), mode=stat.S_IFREG | 0o755)
        entries["dev/console"] = dict(data=b"", mode=stat.S_IFCHR | 0o600, rmajor=5, rminor=1)
        entries["dev/null"] = dict(data=b"", mode=stat.S_IFCHR | 0o666, rmajor=1, rminor=3)
        ordered = sorted(entries, key=lambda n: (not stat.S_ISDIR(entries[n]["mode"]), n.count("/"), n))
        inodes = {n: i + 1 for i, n in enumerate(ordered)}
        for names in groups.values():
            for n in names:
                inodes[n] = inodes[names[0]]
                entries[n]["nlink"] = len(names)
                if n != names[0]:
                    entries[n]["data"] = b""
        return b"".join(newc_entry(n, inode=inodes[n], **entries[n]) for n in ordered) + newc_entry("TRAILER!!!", b"", inode=0, mode=0)


def verify_fit(root: Node) -> None:
    for node in root.child("images").children:
        data = node.props["data"]
        hashes = [n for n in node.children if n.name.startswith("hash")]
        if not hashes:
            raise ValueError(f"FIT image {node.name} has no hash")
        for check in hashes:
            if decode_string(check.props["algo"]) != "sha256" or check.props["value"] != hashlib.sha256(data).digest():
                raise ValueError(f"FIT hash mismatch for {node.name}")


def bootstrap_device_tree(data: bytes) -> tuple[bytes, list[str]]:
    root, reserves = parse_fdt(data)
    disabled = []
    # Only known senior-specific PL and reserved buffers are disabled. PS stays intact.
    names = {"amba_pl@0", "pl_allocator@1", "xib_kmm@2"}
    for node in root.children:
        if node.name in names:
            node.props["status"] = string("disabled")
            disabled.append("/" + node.name)
    reserved = root.child("reserved-memory")
    for node in reserved.children:
        if node.name in {"buffer@0x60000000", "buffer@0x1000000000", "buffer@0x105F000000"}:
            node.props["status"] = string("disabled")
            disabled.append("/reserved-memory/" + node.name)
        else:
            raise ValueError("Unexpected reserved-memory node; hardware review required")
    root.child("chosen").props["bootargs"] = string("earlycon console=ttyPS0,115200 clk_ignore_unused rdinit=/init")
    memory = root.child("memory").props["reg"]
    if len(memory) % 16 or struct.unpack_from(">QQ", memory) != (0, 0x60000000):
        raise ValueError("Unexpected low DDR layout; do not choose boot addresses automatically")
    return encode_fdt(root, reserves), disabled


BOOT_SCRIPT = """# RAM recovery is the default until the installer writes installed.env.
if test "${devtype}" != "mmc"; then echo SD-only package; exit; fi
if test -z "${devnum}"; then echo Missing MMC device number; exit; fi
setenv ah_installed
setenv ah_root_partuuid
setenv ah_boot_partuuid
if fatload mmc ${devnum}:1 0x08000000 deployment.env; then
    if env import -t 0x08000000 ${filesize}; then
        if test -n "${ah_boot_partuuid}"; then
            if test "${ah_recovery}" != "1"; then
                if fatload mmc ${devnum}:1 0x08000000 installed.env; then
                    env import -t 0x08000000 ${filesize}
                fi
            fi
            setenv bootargs earlycon console=ttyPS0,115200 clk_ignore_unused amazinghand.boot_partuuid=${ah_boot_partuuid}
            if test "${ah_installed}" = "1"; then
                setenv bootargs ${bootargs} root=PARTUUID=${ah_root_partuuid} rw rootwait
                if fatload mmc ${devnum}:1 0x10000000 image-normal.ub; then
                    bootm 0x10000000
                fi
                echo Normal boot failed; trying recovery
            fi
            setenv bootargs earlycon console=ttyPS0,115200 clk_ignore_unused rdinit=/init amazinghand.boot_partuuid=${ah_boot_partuuid}
            if fatload mmc ${devnum}:1 0x10000000 image-recovery.ub; then
                bootm 0x10000000
            fi
        fi
    fi
fi
echo AmazingHand boot failed; stop at U-Boot and inspect serial log
"""


def build(source: Path, output: Path) -> dict:
    source, output = source.resolve(), output.resolve()
    if output.exists():
        raise ValueError("Output directory already exists; choose a new destination")
    for name, expected in EXPECTED.items():
        if sha256(source / name) != expected:
            raise ValueError(f"Senior source checksum changed: {name}; stop for review")
    root, _ = parse_fdt((source / "image.ub").read_bytes())
    verify_fit(root)
    images = root.child("images")
    configuration = root.child("configurations").child(decode_string(root.child("configurations").props["default"]))
    kernel = images.child(decode_string(configuration.props["kernel"]))
    if kernel.props.get("load") != struct.pack(">I", 0x80000) or kernel.props.get("compression") != string("gzip"):
        raise ValueError("Unexpected kernel load or compression")
    unpacked_kernel = gzip.decompress(kernel.props["data"])
    if len(unpacked_kernel) + 0x80000 > 0x08000000:
        raise ValueError("Kernel could overlap boot environment/FIT staging")
    dt = images.child(decode_string(configuration.props["fdt"]))
    device_tree, disabled = bootstrap_device_tree(dt.props["data"])
    dt.props["data"] = device_tree
    dt.children = [Node("hash@1", {"algo": string("sha256"), "value": hashlib.sha256(device_tree).digest()})]
    # No configuration signatures are synthesized or carried over after mutation.
    configuration.children = []
    archive = RootArchive(source / "rootfs.tar.gz")
    try:
        config = archive.read("lib/modules/5.4.0-xilinx-v2020.2/build/.config")
        for option in ("CONFIG_BLK_DEV_INITRD", "CONFIG_RD_GZIP", "CONFIG_DEVTMPFS", "CONFIG_MMC", "CONFIG_MMC_SDHCI_OF_ARASAN", "CONFIG_EXT4_FS", "CONFIG_VFAT_FS"):
            if f"{option}=y\n".encode() not in config:
                raise ValueError(f"Required built-in kernel option absent: {option}")
        cpio = archive.recovery_cpio()
        selected = sorted(archive.selected)
    finally:
        archive.tar.close()
    ramdisk = gzip.compress(cpio, mtime=0)
    normal = encode_fdt(root)
    recovery = copy.deepcopy(root)
    recovery.child("images").children.append(Node("ramdisk@1", {
        "description": string("AmazingHand guarded SD installer"), "data": ramdisk,
        "type": string("ramdisk"), "arch": string("arm64"), "os": string("linux"),
        "compression": string("none"),
    }, [Node("hash@1", {"algo": string("sha256"), "value": hashlib.sha256(ramdisk).digest()})]))
    recovery.child("configurations").child(configuration.name).props["ramdisk"] = string("ramdisk@1")
    encoded_recovery = encode_fdt(recovery)
    if len(encoded_recovery) > MAX_FIT_SIZE or len(cpio) > 64 * 1024 * 1024:
        raise ValueError("Recovery image exceeds reviewed 64 MiB bounds")
    verify_fit(parse_fdt(encoded_recovery)[0])
    output.mkdir(parents=True)
    for name in ("BOOT.BIN", "rootfs.tar.gz"):
        shutil.copyfile(source / name, output / name)
    (output / "image-normal.ub").write_bytes(normal)
    (output / "image-recovery.ub").write_bytes(encoded_recovery)
    (output / "recovery.cpio.gz").write_bytes(ramdisk)
    (output / "boot.cmd").write_text(BOOT_SCRIPT, encoding="ascii", newline="\n")
    (output / "boot.scr").write_bytes(script_image(BOOT_SCRIPT))
    shutil.copyfile(REPO / "host/scripts/probe_z19_linux.sh", output / "probe_z19_linux.sh")
    manifest = {
        "schema": 1, "status": "PC_BUILT_NOT_BOARD_VALIDATED", "source_sha256": EXPECTED,
        "boot_bin": "Unmodified senior FSBL/PMU/PL/ATF/U-Boot; PS/DDR and boot compatibility require board validation",
        "disabled_dt_nodes": disabled, "kernel_uncompressed_bytes": len(unpacked_kernel),
        "recovery_cpio_bytes": len(cpio), "recovery_gzip_bytes": len(ramdisk),
        "recovery_archive_members": selected, "fit_stage_address": FIT_ADDRESS,
        "fit_max_bytes": MAX_FIT_SIZE, "sd_serial": "121220160204", "sd_bytes": 31268536320,
        "files": {p.name: {"bytes": p.stat().st_size, "sha256": sha256(p)} for p in output.iterdir() if p.is_file()},
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = build(args.source, args.output)
    print(json.dumps({k: result[k] for k in ("status", "recovery_cpio_bytes", "recovery_gzip_bytes", "disabled_dt_nodes")}, indent=2))
