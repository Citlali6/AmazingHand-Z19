"""Small, dependency-free encoders for the Z19 recovery package.

These implement public FDT v17, Linux newc and U-Boot legacy script formats.
They do not run Linux programs or write disks on the Windows host.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import struct
import zlib


@dataclass
class Node:
    name: str
    props: dict[str, bytes] = field(default_factory=dict)
    children: list["Node"] = field(default_factory=list)

    def child(self, name: str) -> "Node":
        return next(n for n in self.children if n.name == name)


def string(value: str) -> bytes:
    return value.encode("ascii") + b"\0"


def decode_string(value: bytes) -> str:
    return value.rstrip(b"\0").decode("ascii")


def parse_fdt(data: bytes) -> tuple[Node, list[tuple[int, int]]]:
    if len(data) < 40:
        raise ValueError("Truncated FDT header")
    magic, total, off_struct, off_strings, off_res, version, compatible, _, size_strings, size_struct = struct.unpack_from(
        ">10I", data
    )
    if magic != 0xD00DFEED or version != 17 or compatible > 17 or total > len(data):
        raise ValueError("Unsupported or truncated FDT")
    if off_struct + size_struct > total or off_strings + size_strings > total:
        raise ValueError("FDT block outside file")
    reserves = []
    pos = off_res
    while pos + 16 <= total:
        address, length = struct.unpack_from(">QQ", data, pos)
        pos += 16
        if address == length == 0:
            break
        reserves.append((address, length))
    else:
        raise ValueError("Unterminated FDT reservations")
    strings = data[off_strings:off_strings + size_strings]
    pos, limit = off_struct, off_struct + size_struct
    stack: list[Node] = []
    root = None
    while pos + 4 <= limit:
        token = struct.unpack_from(">I", data, pos)[0]
        pos += 4
        if token == 1:
            end = data.index(0, pos, limit)
            node = Node(data[pos:end].decode("ascii"))
            pos = (end + 4) & ~3
            if stack:
                stack[-1].children.append(node)
            elif root is None:
                root = node
            else:
                raise ValueError("Multiple FDT roots")
            stack.append(node)
        elif token == 2:
            if not stack:
                raise ValueError("Unbalanced FDT")
            stack.pop()
        elif token == 3:
            length, name_offset = struct.unpack_from(">II", data, pos)
            pos += 8
            if not stack or pos + length > limit or name_offset >= len(strings):
                raise ValueError("Invalid FDT property")
            end = strings.index(0, name_offset)
            name = strings[name_offset:end].decode("ascii")
            stack[-1].props[name] = data[pos:pos + length]
            pos = (pos + length + 3) & ~3
        elif token == 4:
            pass
        elif token == 9:
            if stack or root is None:
                raise ValueError("Unbalanced FDT end")
            return root, reserves
        else:
            raise ValueError(f"Unknown FDT token {token}")
    raise ValueError("Missing FDT end token")


def encode_fdt(root: Node, reserves: list[tuple[int, int]] | None = None) -> bytes:
    strings, offsets, body = bytearray(), {}, bytearray()

    def emit(node: Node) -> None:
        body.extend(struct.pack(">I", 1) + string(node.name))
        body.extend(b"\0" * (-len(body) % 4))
        for name, value in node.props.items():
            if name not in offsets:
                offsets[name] = len(strings)
                strings.extend(string(name))
            body.extend(struct.pack(">III", 3, len(value), offsets[name]) + value)
            body.extend(b"\0" * (-len(body) % 4))
        for child in node.children:
            emit(child)
        body.extend(struct.pack(">I", 2))

    emit(root)
    body.extend(struct.pack(">I", 9))
    reservation = b"".join(struct.pack(">QQ", a, s) for a, s in (reserves or [])) + bytes(16)
    off_struct = 40 + len(reservation)
    off_strings = off_struct + len(body)
    header = struct.pack(">10I", 0xD00DFEED, off_strings + len(strings), off_struct,
                         off_strings, 40, 17, 16, 0, len(strings), len(body))
    return header + reservation + body + strings


def newc_entry(name: str, data: bytes, *, inode: int, mode: int,
               uid: int = 0, gid: int = 0, nlink: int = 1, mtime: int = 0,
               rmajor: int = 0, rminor: int = 0) -> bytes:
    if name.startswith("/") or ".." in name.split("/") or "\0" in name:
        raise ValueError("Unsafe CPIO path")
    encoded_name = name.encode("utf-8") + b"\0"
    fields = (inode, mode, uid, gid, nlink, mtime, len(data), 0, 0,
              rmajor, rminor, len(encoded_name), 0)
    if any(not 0 <= value <= 0xFFFFFFFF for value in fields):
        raise ValueError("CPIO field outside 32-bit range")
    header = b"070701" + b"".join(f"{v:08x}".encode("ascii") for v in fields)
    result = header + encoded_name
    result += b"\0" * (-len(result) % 4)
    result += data
    return result + b"\0" * (-len(result) % 4)


def script_image(script: str) -> bytes:
    text = script.encode("ascii")
    payload = struct.pack(">II", len(text), 0) + text
    header = struct.pack(">7I4B32s", 0x27051956, 0, 0, len(payload), 0, 0,
                         zlib.crc32(payload), 5, 22, 6, 0,
                         b"AmazingHand SD recovery")
    crc = zlib.crc32(header)
    return header[:4] + struct.pack(">I", crc) + header[8:] + payload
