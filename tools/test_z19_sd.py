"""Disk-free tests for boot binary integrity, metadata and installation guards."""
import gzip
import hashlib
import io
from pathlib import Path
import stat
import struct
import subprocess
import tarfile
import tempfile
import unittest
import zlib

from build_z19_sd import RootArchive, elf_dependencies, safe_name, verify_fit
from z19_image_formats import Node, encode_fdt, newc_entry, parse_fdt, script_image, string


def unpack_newc(data):
    """Independent decoder used to inspect exactly what Linux will receive."""
    pos, result = 0, {}
    while pos < len(data):
        if data[pos:pos + 6] != b"070701":
            raise AssertionError("newc magic/alignment")
        fields = [int(data[pos + 6 + i * 8:pos + 14 + i * 8], 16) for i in range(13)]
        size, namesize = fields[6], fields[11]
        name = data[pos + 110:pos + 110 + namesize - 1].decode()
        assert data[pos + 110 + namesize - 1] == 0
        pos = (pos + 110 + namesize + 3) & ~3
        body = data[pos:pos + size]
        assert len(body) == size
        pos = (pos + size + 3) & ~3
        if name == "TRAILER!!!":
            assert size == 0
            return result
        result[name] = (fields, body)
    raise AssertionError("Missing trailer")


class FormatsTest(unittest.TestCase):
    def test_fdt_preserves_64_bit_reservations_and_binary_properties(self):
        root = Node("", {"#address-cells": struct.pack(">I", 2)}, [Node("chosen", {"bootargs": string("console=ttyPS0")}), Node("memory", {"reg": struct.pack(">QQ", 0x800000000, 0x180000000)})])
        encoded = encode_fdt(root, [(0x105F000000, 0x1000000)])
        decoded, reservations = parse_fdt(encoded)
        self.assertEqual(decoded, root)
        self.assertEqual(reservations, [(0x105F000000, 0x1000000)])
        with self.assertRaises(ValueError):
            parse_fdt(encoded[:-1])

    def test_newc_keeps_uid_permissions_symlinks_and_device_nodes(self):
        archive = newc_entry("etc", b"", inode=1, mode=stat.S_IFDIR | 0o755)
        archive += newc_entry("etc/tool", b"abcde", inode=2, mode=stat.S_IFREG | 0o4750, uid=2001, gid=2002, nlink=2)
        archive += newc_entry("etc/link", b"", inode=2, mode=stat.S_IFREG | 0o4750, uid=2001, gid=2002, nlink=2)
        archive += newc_entry("sh", b"/bin/busybox", inode=3, mode=stat.S_IFLNK | 0o777)
        archive += newc_entry("console", b"", inode=4, mode=stat.S_IFCHR | 0o600, rmajor=5, rminor=1)
        archive += newc_entry("TRAILER!!!", b"", inode=0, mode=0)
        entries = unpack_newc(gzip.decompress(gzip.compress(archive)))
        header, body = entries["etc/tool"]
        self.assertEqual(header[:5], [2, stat.S_IFREG | 0o4750, 2001, 2002, 2])
        self.assertEqual(body, b"abcde")
        self.assertEqual(entries["etc/link"][0][0], header[0])
        self.assertEqual(entries["sh"][1], b"/bin/busybox")
        self.assertEqual(entries["console"][0][9:11], [5, 1])

    def test_script_header_and_payload_crcs(self):
        image = script_image("echo recovery\n")
        values = struct.unpack(">7I4B32s", image[:64])
        self.assertEqual(values[0], 0x27051956)
        self.assertEqual(values[1], zlib.crc32(image[:4] + bytes(4) + image[8:64]))
        self.assertEqual(values[3], len(image) - 64)
        self.assertEqual(values[6], zlib.crc32(image[64:]))
        self.assertEqual(values[7:11], (5, 22, 6, 0))
        self.assertEqual(struct.unpack(">II", image[64:72]), (14, 0))

    def test_fit_tampering_is_rejected(self):
        node = Node("kernel@1", {"data": b"kernel"}, [Node("hash@1", {"algo": string("sha256"), "value": hashlib.sha256(b"kernel").digest()})])
        root = Node("", children=[Node("images", children=[node])])
        verify_fit(root)
        node.props["data"] = b"tampered"
        with self.assertRaises(ValueError):
            verify_fit(root)

    def test_archive_escape_is_rejected(self):
        for name in ("/etc/passwd", "../etc", "usr/../../etc"):
            with self.assertRaises(ValueError):
                safe_name(name)

    def test_tar_link_resolution_keeps_parent_directories(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "rootfs.tar.gz"
            with tarfile.open(path, "w:gz") as target:
                for name in (".", "lib", "bin"):
                    info = tarfile.TarInfo(name); info.type = tarfile.DIRTYPE
                    target.addfile(info)
                info = tarfile.TarInfo("lib/real.so"); info.size = 3
                target.addfile(info, io.BytesIO(b"abc"))
                info = tarfile.TarInfo("lib/libtest.so"); info.type = tarfile.SYMTYPE; info.linkname = "real.so"
                target.addfile(info)
                info = tarfile.TarInfo("bin/hard"); info.type = tarfile.LNKTYPE; info.linkname = "./lib/real.so"
                target.addfile(info)
                info = tarfile.TarInfo("bin/relative"); info.type = tarfile.SYMTYPE; info.linkname = "../lib/real.so"
                target.addfile(info)
            root = RootArchive(path)
            try:
                self.assertEqual(root.resolve("lib/libtest.so", select=True), "lib/real.so")
                self.assertEqual(root.read("bin/hard"), b"abc")
                self.assertEqual(root.read("bin/relative"), b"abc")
                self.assertTrue({"lib", "lib/libtest.so", "lib/real.so"} <= root.selected)
            finally:
                root.tar.close()

    def test_foreign_elf_rejected(self):
        foreign = bytearray(64); foreign[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<H", foreign, 18, 62)
        with self.assertRaises(ValueError):
            elf_dependencies(bytes(foreign))

    def test_aarch64_elf_dynamic_dependency_and_interpreter(self):
        data = bytearray(512); data[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<H", data, 18, 183)
        struct.pack_into("<Q", data, 32, 64)
        struct.pack_into("<HH", data, 54, 56, 3)
        struct.pack_into("<II6Q", data, 64, 1, 5, 0, 0x400000, 0, 512, 512, 4096)
        interpreter = b"/lib/ld-linux-aarch64.so.1\0"
        struct.pack_into("<II6Q", data, 120, 3, 4, 256, 0, 0, len(interpreter), len(interpreter), 1)
        data[256:256 + len(interpreter)] = interpreter
        struct.pack_into("<II6Q", data, 176, 2, 4, 320, 0, 0, 48, 48, 8)
        struct.pack_into("<qQqQqQ", data, 320, 1, 1, 5, 0x400000 + 450, 0, 0)
        data[450:461] = b"\0libc.so.6\0"
        self.assertEqual(elf_dependencies(bytes(data)), (["libc.so.6"], "/lib/ld-linux-aarch64.so.1"))

    def test_installer_refuses_execution_on_pc(self):
        bash = Path("C:/Program Files/Git/bin/bash.exe")
        if not bash.exists():
            self.skipTest("Requires Git Bash on the Windows development host")
        script = Path(__file__).resolve().parents[1] / "host/scripts/install_z19_root.sh"
        for operation in ("--install", "--finish"):
            with self.subTest(operation=operation):
                run = subprocess.run([str(bash), str(script), operation, "12345678-02"], capture_output=True, text=True)
                self.assertNotEqual(run.returncode, 0)
                self.assertIn("Not running in the RAM recovery environment", run.stderr)


if __name__ == "__main__":
    unittest.main()
