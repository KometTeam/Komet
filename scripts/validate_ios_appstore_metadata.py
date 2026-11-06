#!/usr/bin/env python3
"""Validate App Store metadata that Apple checks after upload."""

from pathlib import Path
import plistlib
import struct

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "ios" / "Runner"
PLIST = RUNNER / "Info.plist"
PROJECT = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"

PURPOSE_KEYS = (
    "NSLocationAlwaysAndWhenInUseUsageDescription",
    "NSSpeechRecognitionUsageDescription",
)
IPAD_ALTERNATE_ICONS = {
    "MinimalIcon-76@2x.png": (152, 152),
    "MinimalIcon-83.5@2x.png": (167, 167),
}


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as image:
        signature = image.read(24)
    if signature[:8] != b"\x89PNG\r\n\x1a\n" or signature[12:16] != b"IHDR":
        raise AssertionError(f"{path} is not a PNG with an IHDR header")
    return struct.unpack(">II", signature[16:24])


def main() -> None:
    with PLIST.open("rb") as source:
        plist = plistlib.load(source)

    for key in PURPOSE_KEYS:
        value = plist.get(key)
        assert isinstance(value, str) and value.strip(), f"missing {key}"

    ipad_icons = plist.get("CFBundleIcons~ipad", {})
    alternate = ipad_icons.get("CFBundleAlternateIcons", {}).get("MinimalIcon", {})
    declared = set(alternate.get("CFBundleIconFiles", []))
    expected_names = {Path(name).stem.split("@", 1)[0] for name in IPAD_ALTERNATE_ICONS}
    assert expected_names <= declared, (
        f"CFBundleIcons~ipad.MinimalIcon must declare {sorted(expected_names)}"
    )

    project = PROJECT.read_text()
    for filename, expected_size in IPAD_ALTERNATE_ICONS.items():
        path = RUNNER / filename
        assert path.is_file(), f"missing {path}"
        assert png_size(path) == expected_size, (
            f"{path} is {png_size(path)}, expected {expected_size}"
        )
        assert project.count(filename) >= 4, f"{filename} is not bundled by Runner"

    print("App Store metadata is complete")


if __name__ == "__main__":
    main()
