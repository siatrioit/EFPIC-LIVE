#!/usr/bin/env python3
"""Walk TIFF/EXIF in NEF head — list exposure-related tags per IFD."""
import struct
import sys
from pathlib import Path

EXIF_SIG = b"Exif\x00\x00"
TAG_NAMES = {
    0x9204: "ExposureBiasValue",
    0x9205: "MaxApertureValue",
    0x9214: "ColorTemperature",
    0x927C: "MakerNote",
    0x8769: "ExifIFDPointer",
    0xA405: "SceneType",
}
NIKON_TAGS = {
    0x000D: "ProgramShift",
    0x000E: "ExposureDifference",
    0x0012: "FlashExposureComp",
    0x003F: "WBFineTune",
    0x004F: "ColorTemp",
    0x0097: "ColorBalance",
    0x0023: "PictureControl",
}


def u16(d, o, le):
    return struct.unpack_from("<H" if le else ">H", d, o)[0]


def u32(d, o, le):
    return struct.unpack_from("<I" if le else ">I", d, o)[0]


def s32(d, o, le):
    v = u32(d, o, le)
    return v - 0x100000000 if v & 0x80000000 else v


def type_size(t):
    return {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 7: 1, 10: 8}.get(t, 1)


def parse_rational(d, off, typ, le):
    if typ == 10:
        n, den = s32(d, off, le), s32(d, off + 4, le)
    elif typ == 5:
        n, den = u32(d, off, le), u32(d, off + 4, le)
    else:
        return None
    return None if den == 0 else n / den


def find_exif_base(data: bytes) -> int:
    i = data.find(EXIF_SIG)
    return i + 6 if i >= 0 else -1


def read_ifd(data, base, ifd_rel, le, label, depth=0):
    ifd = base + ifd_rel
    if ifd + 2 > len(data):
        return
    n = u16(data, ifd, le)
    entries = []
    for i in range(n):
        o = ifd + 2 + i * 12
        tag, typ, cnt = u16(data, o, le), u16(data, o + 2, le), u32(data, o + 4, le)
        vo = u32(data, o + 8, le)
        bie = type_size(typ) * cnt
        val_off = o + 8 if bie <= 4 else base + vo
        entries.append((tag, typ, cnt, val_off))
    print(f"\n{'  ' * depth}IFD {label} @ rel={ifd_rel} ({n} tags)")
    for tag, typ, cnt, val_off in entries:
        name = TAG_NAMES.get(tag, NIKON_TAGS.get(tag, f"0x{tag:04X}"))
        extra = ""
        if tag in (0x9204,) and typ in (5, 10) and cnt >= 1:
            v = parse_rational(data, val_off, typ, le)
            extra = f" => {v:.4f} EV" if v is not None else ""
        elif tag == 0x8769 and typ == 4:
            sub = u32(data, val_off, le)
            print(f"{'  ' * depth}  {name} -> subIFD rel={sub}")
            read_ifd(data, base, sub, le, f"{label}/Exif", depth + 1)
            continue
        elif tag == 0x927C and typ in (7, 1):
            block = data[val_off : val_off + min(cnt, 64)]
            if block[:6] == b"Nikon\x00":
                print(f"{'  ' * depth}  MakerNote ({cnt} bytes)")
                parse_nikon_mn(data, val_off, cnt, depth + 1)
            continue
        elif tag == 0x000E and typ == 7 and cnt == 4:
            vals = struct.unpack_from("<4h", data, val_off)
            if vals[2]:
                ev = vals[0] * vals[1] / vals[2]
                extra = f" => {ev:.4f} EV (a*b/c)"
        elif tag == 0x9214 and typ == 3:
            extra = f" => {u16(data, val_off, le)} K"
        print(f"{'  ' * depth}  {name}{extra}")
    next_off = ifd + 2 + n * 12
    if next_off + 4 <= len(data):
        nxt = u32(data, next_off, le)
        if nxt and nxt != ifd_rel and depth < 4:
            read_ifd(data, base, nxt, le, f"{label}+chain", depth)


def parse_nikon_mn(data, off, cnt, depth):
    mn = data[off : off + min(cnt, 512 * 1024)]
    if len(mn) < 18 or mn[:6] != b"Nikon\x00":
        return
    le = mn[6] == 0x49
    if u16(mn, 10, le) != 0x2A:
        return
    ifd0 = u32(mn, 12, le)
    ifd = 12 + ifd0
    n = u16(mn, ifd, le)
    print(f"{'  ' * depth}  Nikon IFD ({n} tags)")
    for i in range(n):
        o = ifd + 2 + i * 12
        tag, typ, c = u16(mn, o, le), u16(mn, o + 2, le), u32(mn, o + 4, le)
        vo = u32(mn, o + 8, le)
        bie = type_size(typ) * c
        val_off = o + 8 if bie <= 4 else vo
        name = NIKON_TAGS.get(tag, f"0x{tag:04X}")
        extra = ""
        if tag == 0x000E and typ == 7 and c == 4:
            vals = struct.unpack_from("<4h", mn, val_off)
            if vals[2]:
                extra = f" => {vals[0]*vals[1]/vals[2]:.4f} EV"
        elif tag == 0x004F and typ == 3:
            extra = f" => {u16(mn, val_off, le)}"
        print(f"{'  ' * depth}    {name}{extra}")


def main():
    path = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else r"D:\Dev\projects\EFPIC-LIVE\samples\EDGARSFOTO_20260530_111243_Z8E_8314.NEF"
    )
    data = path.read_bytes()[: 16 * 1024 * 1024]
    base = find_exif_base(data)
    if base < 0:
        print("No EXIF")
        return
    le = data[base : base + 2] == b"II"
    ifd0 = u32(data, base + 4, le)
    print(f"EXIF @ {base}, endian={'LE' if le else 'BE'}, IFD0 rel={ifd0}")
    read_ifd(data, base, ifd0, le, "IFD0")


if __name__ == "__main__":
    main()
