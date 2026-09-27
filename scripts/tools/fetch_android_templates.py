#!/usr/bin/env python3
"""Installs only the Android export templates for a Godot version.

The full export template archive is over a gigabyte. This reads the zip's
central directory with HTTP range requests and downloads just the Android
APK templates, which are all an Android export needs.

Usage: fetch_android_templates.py [version]   (default 4.5.1-stable)
"""
import os
import struct
import sys
import urllib.request
import zlib

VERSION = sys.argv[1] if len(sys.argv) > 1 else "4.5.1-stable"
URL = ("https://github.com/godotengine/godot/releases/download/"
       f"{VERSION}/Godot_v{VERSION}_export_templates.tpz")
WANTED = ("templates/android_debug.apk", "templates/android_release.apk", "templates/version.txt")
DEST = os.path.expanduser(
    f"~/.local/share/godot/export_templates/{VERSION.replace('-', '.')}/")


def fetch(url, start=None, end=None):
    headers = {} if start is None else {"Range": f"bytes={start}-{end}"}
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers)) as response:
        return response.read(), response


def main():
    with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD")) as head:
        final_url = head.geturl()
        size = int(head.headers["Content-Length"])

    tail, _ = fetch(final_url, size - 65536, size - 1)
    end = tail.rfind(b"PK\x05\x06")
    cd_size, cd_offset = struct.unpack("<II", tail[end + 12:end + 20])
    if cd_offset == 0xFFFFFFFF:
        end64 = tail.rfind(b"PK\x06\x06")
        cd_size, cd_offset = struct.unpack("<QQ", tail[end64 + 40:end64 + 56])
    directory, _ = fetch(final_url, cd_offset, cd_offset + cd_size - 1)

    entries = {}
    pos = 0
    while directory[pos:pos + 4] == b"PK\x01\x02":
        method, = struct.unpack("<H", directory[pos + 10:pos + 12])
        packed, unpacked = struct.unpack("<II", directory[pos + 20:pos + 28])
        name_len, extra_len, comment_len = struct.unpack("<HHH", directory[pos + 28:pos + 34])
        offset, = struct.unpack("<I", directory[pos + 42:pos + 46])
        name = directory[pos + 46:pos + 46 + name_len].decode()
        extra = directory[pos + 46 + name_len:pos + 46 + name_len + extra_len]
        # Large archives keep real sizes and offsets in the zip64 extra field.
        cursor = 0
        while cursor < len(extra):
            header_id, length = struct.unpack("<HH", extra[cursor:cursor + 4])
            body = extra[cursor + 4:cursor + 4 + length]
            if header_id == 1:
                read = 0
                if unpacked == 0xFFFFFFFF:
                    unpacked, = struct.unpack("<Q", body[read:read + 8]); read += 8
                if packed == 0xFFFFFFFF:
                    packed, = struct.unpack("<Q", body[read:read + 8]); read += 8
                if offset == 0xFFFFFFFF:
                    offset, = struct.unpack("<Q", body[read:read + 8]); read += 8
            cursor += 4 + length
        entries[name] = (method, packed, unpacked, offset)
        pos += 46 + name_len + extra_len + comment_len

    os.makedirs(DEST, exist_ok=True)
    for name in WANTED:
        method, packed, unpacked, offset = entries[name]
        local, _ = fetch(final_url, offset, offset + 29)
        name_len, extra_len = struct.unpack("<HH", local[26:30])
        start = offset + 30 + name_len + extra_len
        data, _ = fetch(final_url, start, start + packed - 1)
        if method == 8:
            data = zlib.decompress(data, -15)
        if len(data) != unpacked:
            sys.exit(f"Size mismatch for {name}")
        with open(os.path.join(DEST, os.path.basename(name)), "wb") as out:
            out.write(data)
        print(f"Installed {os.path.basename(name)} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
