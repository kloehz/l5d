#!/usr/bin/env python3
"""Install only the dependencies pinned in dependencies.lock.json."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "dependencies.lock.json").read_text())
DOWNLOADS = ROOT / ".tools" / "downloads"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_exact(path: Path, data: bytes, executable: bool = False) -> None:
    if path.exists() and path.read_bytes() != data:
        raise RuntimeError(f"Refusing to replace differing dependency: {path.relative_to(ROOT)}")
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_bytes(data)
    if executable:
        path.chmod(path.stat().st_mode | 0o111)


def safe_members(archive: zipfile.ZipFile):
    for member in archive.infolist():
        path = Path(member.filename)
        if path.is_absolute() or ".." in path.parts:
            raise RuntimeError("Unsafe dependency archive member")
        if not member.is_dir():
            yield member


def main() -> None:
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    for dependency in LOCK["downloads"]:
        path = DOWNLOADS / dependency["file"]
        if not path.exists():
            temporary = path.with_suffix(path.suffix + ".part")
            subprocess.run(["curl", "--fail", "--location", "--retry", "2", dependency["url"], "--output", str(temporary)], check=True)
            if sha256(temporary) != dependency["sha256"]:
                temporary.unlink()
                raise RuntimeError(f"Checksum mismatch: {dependency['file']}")
            temporary.rename(path)
        if sha256(path) != dependency["sha256"]:
            raise RuntimeError(f"Checksum mismatch: {dependency['file']}")
        with zipfile.ZipFile(path) as archive:
            for member in safe_members(archive):
                if dependency["purpose"] == "engine":
                    target = ROOT / ".tools" / "godot-4.7" / member.filename
                    write_exact(target, archive.read(member), bool((member.external_attr >> 16) & 0o111))
                elif dependency["purpose"] == "templates":
                    name = Path(member.filename).name
                    if name in LOCK["templates"]["files"]:
                        target = ROOT / LOCK["templates"]["directory"] / name
                        write_exact(target, archive.read(member), name.startswith("linux_"))
                elif dependency["purpose"] == "addons":
                    if member.filename.endswith(".import"):
                        continue  # Godot regenerates import metadata for the pinned engine.
                    parts = Path(member.filename).parts
                    if len(parts) < 3 or parts[1] != "addons" or parts[2] not in ("netfox", "netfox.internals"):
                        continue
                    write_exact(ROOT.joinpath(*parts[1:]), archive.read(member))
    engine = ROOT / LOCK["godot"]["binary_path"]
    engine.chmod(engine.stat().st_mode | 0o111)
    write_exact(ROOT / LOCK["godot"]["self_contained_marker"], b"")
    write_exact(ROOT / ".tools" / ".gdignore", b"")
    template_link = ROOT / ".tools/godot-4.7/editor_data/export_templates/4.7.stable"
    template_link.parent.mkdir(parents=True, exist_ok=True)
    if not template_link.exists():
        os.symlink(os.path.relpath(ROOT / LOCK["templates"]["directory"], template_link.parent), template_link)
    for relative, expected in LOCK["netfox"]["addons_manifest"].items():
        if sha256(ROOT / relative) != expected:
            raise RuntimeError(f"Addon checksum mismatch: {relative}")
    for name, expected in LOCK["templates"]["files"].items():
        if sha256(ROOT / LOCK["templates"]["directory"] / name) != expected:
            raise RuntimeError(f"Template checksum mismatch: {name}")
    subprocess.run([str(engine), "--version"], check=True)
    print("Pinned Godot, Netfox core/internals, and macOS/Linux templates verified.")


if __name__ == "__main__":
    main()
