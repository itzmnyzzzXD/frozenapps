#!/usr/bin/env python3
"""Migrate generated SwiftUI SF Symbol call sites to the shared AppIcon."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Vendor" / "SideInstaller" / "ios-app"
INTEGRATION = ROOT / "InstallerIntegration"

def matching_close(source, opening):
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = []
    quote = None
    escaped = False
    index = opening
    while index < len(source):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif source.startswith(quote, index):
                index += len(quote)
                quote = None
                continue
            index += 1
            continue
        if source.startswith("//", index):
            end = source.find("\n", index)
            index = len(source) if end < 0 else end + 1
            continue
        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            if end < 0:
                raise ValueError("Unterminated Swift block comment")
            index = end + 2
            continue
        if source.startswith('"""', index):
            quote = '"""'
            index += 3
            continue
        if char in ('"', "'"):
            quote = char
            index += 1
            continue
        if char in pairs:
            stack.append(pairs[char])
        elif stack and char == stack[-1]:
            stack.pop()
            if not stack:
                return index
        index += 1
    raise ValueError(f"Unbalanced call near offset {opening}")

def split_arguments(text):
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = []
    quote = None
    escaped = False
    start = 0
    result = []
    index = 0
    while index < len(text):
        char = text[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif text.startswith(quote, index):
                index += len(quote)
                quote = None
                continue
            index += 1
            continue
        if text.startswith("//", index):
            end = text.find("\n", index)
            index = len(text) if end < 0 else end + 1
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("Unterminated Swift block comment")
            index = end + 2
            continue
        if text.startswith('"""', index):
            quote = '"""'
            index += 3
            continue
        if char in ('"', "'"):
            quote = char
            index += 1
            continue
        if char in pairs:
            stack.append(pairs[char])
        elif stack and char == stack[-1]:
            stack.pop()
        elif char == "," and not stack:
            result.append(text[start:index].strip())
            start = index + 1
        index += 1
    result.append(text[start:].strip())
    return result

def migrate_calls(source, function_name):
    pattern = re.compile(r"\b" + re.escape(function_name) + r"\s*\(")
    edits = []
    for match in pattern.finditer(source):
        opening = source.find("(", match.start(), match.end())
        closing = matching_close(source, opening)
        args = split_arguments(source[opening + 1:closing])
        if len(args) < 2:
            continue
        title = args[0]
        symbol = next((arg.split(":", 1)[1].strip()
                       for arg in args[1:] if arg.startswith("systemImage:")), None)
        if symbol is None:
            continue
        if function_name == "Label":
            replacement = f"Label {{ Text({title}) }} icon: {{ AppIcon(name: {symbol}) }}"
            edits.append((match.start(), closing + 1, replacement))
            continue

        role = next((arg.split(":", 1)[1].strip()
                     for arg in args[1:] if arg.startswith("role:")), "nil")
        cursor = closing + 1
        while cursor < len(source) and source[cursor].isspace():
            cursor += 1
        if cursor >= len(source) or source[cursor] != "{":
            raise SystemExit(f"Button(systemImage:) requires a trailing action closure near line {source.count(chr(10), 0, match.start()) + 1}")
        action_end = matching_close(source, cursor)
        action = source[cursor + 1:action_end].strip()
        replacement = (
            f"Button(role: {role}, action: {{ {action} }}) {{ "
            f"Label {{ Text({title}) }} icon: {{ AppIcon(name: {symbol}) }} }}"
        )
        edits.append((match.start(), action_end + 1, replacement))

    for start, end, replacement in reversed(edits):
        source = source[:start] + replacement + source[end:]
    return source

changed = []
for folder in (APP, INTEGRATION):
    for path in folder.rglob("*.swift"):
        if path.name == "AppIcon.swift":
            continue
        original = path.read_text(encoding="utf-8")
        migrated = migrate_calls(original, "Button")
        migrated = migrate_calls(migrated, "Label")
        migrated = re.sub(r"Image\s*\(\s*systemName\s*:", "AppIcon(name:", migrated)
        if migrated != original:
            path.write_text(migrated, encoding="utf-8")
            changed.append(str(path.relative_to(ROOT)))

print(f"Migrated icon call sites in {len(changed)} Swift file(s).")
for path in changed:
    print("UPDATED: " + path)
