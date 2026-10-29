"""Builds build/CrownRush.rbxlx, a Roblox place file you can open straight in
Roblox Studio, from the scripts in src/. It follows the same layout rules as
Rojo (default.project.json), so `rojo build` gives the same result.

Usage: python3 tools/build_place.py
"""

import json
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "CrownRush.rbxlx")

SERVICES = {
    "ReplicatedStorage": "ReplicatedStorage",
    "ServerScriptService": "ServerScriptService",
    "StarterPlayer": "StarterPlayer",
    "StarterPlayerScripts": "StarterPlayerScripts",
}

_ref = 0


def next_ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def item(class_name, name, children=(), source=None):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        if "]]>" in source:
            raise ValueError(f"{name}: source contains ]]>")
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    inner = "".join(children)
    return f'<Item class="{class_name}" referent="{next_ref()}"><Properties>{props}</Properties>{inner}</Item>'


def script_class(filename):
    if filename.endswith(".server.luau"):
        return "Script", filename[: -len(".server.luau")]
    if filename.endswith(".client.luau"):
        return "LocalScript", filename[: -len(".client.luau")]
    return "ModuleScript", filename[: -len(".luau")]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def from_path(path, name):
    """Turn a file or folder into Roblox instances, Rojo style."""
    if os.path.isfile(path):
        class_name, _ = script_class(os.path.basename(path))
        return item(class_name, name, source=read(path))

    entries = sorted(os.listdir(path))
    init = next((e for e in entries if e.startswith("init.") and e.endswith(".luau")), None)
    children = []
    for entry in entries:
        if entry == init or not (entry.endswith(".luau") or os.path.isdir(os.path.join(path, entry))):
            continue
        child_path = os.path.join(path, entry)
        child_name = entry if os.path.isdir(child_path) else script_class(entry)[1]
        children.append(from_path(child_path, child_name))
    if init:
        class_name, _ = script_class(init)
        return item(class_name, name, children, source=read(os.path.join(path, init)))
    return item("Folder", name, children)


def from_tree(name, node):
    children = []
    for key, value in node.items():
        if key.startswith("$"):
            continue
        children.append(from_tree(key, value))
    if "$path" in node:
        built = from_path(os.path.join(ROOT, node["$path"]), name)
        if children:
            raise ValueError("$path nodes with extra children are not supported")
        return built
    class_name = node.get("$className") or SERVICES.get(name) or "Folder"
    return item(class_name, name, children)


def main():
    with open(os.path.join(ROOT, "default.project.json"), encoding="utf-8") as f:
        project = json.load(f)
    services = [from_tree(key, value) for key, value in project["tree"].items() if not key.startswith("$")]
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        + "".join(services)
        + "</roblox>\n"
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"Wrote {os.path.relpath(OUT, ROOT)} ({len(xml) // 1024} KB)")


if __name__ == "__main__":
    main()
