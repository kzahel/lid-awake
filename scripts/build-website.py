#!/usr/bin/env python3
"""Build a static download page from the same release pointer as Sparkle."""

import html
from pathlib import Path
import re
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
RELEASES = "https://github.com/kzahel/lid-awake/releases"


def release_values(feed):
    items = ET.fromstring(feed).findall("./channel/item")
    item = max(items, key=lambda entry: int(entry.findtext(SPARKLE + "version", "0")))
    version = item.findtext(SPARKLE + "shortVersionString", "")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a MAJOR.MINOR.PATCH release version")
    base = f"{RELEASES}/download/v{version}/LidAwake-v{version}"
    enclosure = item.find("enclosure")
    if enclosure is None or enclosure.get("url") != base + ".zip":
        raise ValueError("Appcast URL no longer matches the release packaging convention")
    minimum = item.findtext(SPARKLE + "minimumSystemVersion", "")
    if not re.fullmatch(r"\d+(?:\.\d+)*", minimum):
        raise ValueError("Missing or invalid minimum macOS version")
    return {
        "VERSION": version,
        "DOWNLOAD_URL": base + ".dmg",
        "RELEASE_URL": f"{RELEASES}/tag/v{version}",
        "MINIMUM_MACOS": minimum.removesuffix(".0"),
        # Keep in sync with the v0.0.* prerelease rule in build.yml.
        "RELEASE_KIND": "Preview release" if version.startswith("0.0.") else "Latest release",
    }


def render(template, values):
    def replace(match):
        return html.escape(values[match.group(1)], quote=True)
    return re.sub(r"\{\{([A-Z_]+)\}\}", replace, template)


def main():
    values = release_values((ROOT / "appcast.xml").read_text())
    output = ROOT / "build/website"
    output.mkdir(parents=True, exist_ok=True)
    for name in ("index.html", "styles.css"):
        (output / name).write_text(render((ROOT / "website" / name).read_text(), values))
    shutil.copyfile(ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/icon-256.png", output / "icon.png")
    (output / "download").mkdir(exist_ok=True)
    (output / "download/index.html").write_text(render('''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><meta http-equiv="refresh" content="0;url={{DOWNLOAD_URL}}">
<title>Download Lid Awake</title></head><body>
<p><a href="{{DOWNLOAD_URL}}">Download Lid Awake {{VERSION}} for macOS</a></p>
<p>If your download does not start, use the link above. <a href="../">Back to Lid Awake</a>.</p>
</body></html>''', values))
    print(f"Built {output} for {values['VERSION']} ({values['RELEASE_KIND']})")


if __name__ == "__main__":
    main()
