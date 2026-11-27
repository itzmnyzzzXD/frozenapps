#!/usr/bin/env python3
"""Convert the trusted local SVG icon atlas into iOS vector imagesets."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Vendor" / "SideInstaller" / "ios-app"
SOURCE = ROOT / "assets" / "vector-icons" / "icon-atlas.svg"
ASSETS = APP / "Assets.xcassets"
MAX_BYTES = 256_000
ALLOWED_TAGS = {"g", "path", "circle", "ellipse", "rect", "line", "polyline", "polygon"}
ALLOWED_ATTRS = {
    "id", "d", "cx", "cy", "r", "rx", "ry", "x", "y", "width", "height",
    "x1", "y1", "x2", "y2", "points", "transform", "fill", "stroke",
    "stroke-width", "stroke-linecap", "stroke-linejoin", "fill-rule",
    "stroke-miterlimit", "opacity"
}

def local_name(tag):
    return tag.rsplit("}", 1)[-1]

def validate_element(element):
    if local_name(element.tag) not in ALLOWED_TAGS:
        raise ValueError(f"Unsupported SVG element: {local_name(element.tag)}")
    for key, value in element.attrib.items():
        key = local_name(key)
        if key not in ALLOWED_ATTRS or key.lower().startswith("on"):
            raise ValueError(f"Unsupported SVG attribute: {key}")
        if "url(" in value.lower() or "javascript:" in value.lower():
            raise ValueError(f"Unsafe SVG attribute value: {key}")
    for child in element:
        validate_element(child)

if not SOURCE.is_file():
    raise SystemExit(f"Missing local icon atlas: {SOURCE}")
raw = SOURCE.read_bytes()
if len(raw) > MAX_BYTES:
    raise SystemExit("Icon atlas exceeds the size limit.")
upper = raw.upper()
if any(token in upper for token in (b"<!DOCTYPE", b"<!ENTITY", b"<SCRIPT", b"<FOREIGNOBJECT")):
    raise SystemExit("Icon atlas contains forbidden XML features.")

root = ET.fromstring(raw)
if local_name(root.tag) != "svg":
    raise SystemExit("Icon atlas root must be svg.")
groups = [child for child in root if local_name(child.tag) == "g"]
if not groups:
    raise SystemExit("Icon atlas contains no named icon groups.")

written = 0
for group in groups:
    name = group.attrib.get("id", "")
    if not re.fullmatch(r"[a-z0-9-]{2,40}", name):
        raise SystemExit(f"Invalid icon group name: {name!r}")
    validate_element(group)
    svg_root = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg", "width": "24", "height": "24",
        "viewBox": "0 0 24 24", "fill": "none", "stroke": "#FFFFFF",
        "stroke-width": "1.8", "stroke-linecap": "round", "stroke-linejoin": "round"
    })
    svg_root.append(group)
    svg_text = ET.tostring(svg_root, encoding="unicode")
    directory = ASSETS / f"FrozenIcon-{name}.imageset"
    directory.mkdir(parents=True, exist_ok=True)
    filename = f"FrozenIcon-{name}.svg"
    (directory / filename).write_text(svg_text + "\n", encoding="utf-8")
    manifest = {
        "images": [{"filename": filename, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {
            "preserves-vector-representation": True,
            "template-rendering-intent": "template"
        }
    }
    (directory / "Contents.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    written += 1

print(f"PASS: imported {written} local monochrome SVG icon(s) into the generated asset catalogue.")
