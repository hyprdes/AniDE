#!/usr/bin/env python3
"""Opt-in backup of explicitly selected regular files under HOME.

No package, service or installer integration. See docs/CONFIG-BACKUP.md.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

CHUNK = 1024 * 1024
MAX_MANIFEST = 1024 * 1024
MAX_ENTRIES = 10000


class BackupError(Exception):
    pass


def absolute(path):
    return Path(os.path.abspath(os.fspath(path)))


def check_components(path, *, allow_missing=False):
    """Reject links and non-directory ancestors. Not a concurrent-writer lock."""
    path = absolute(path)
    current = Path(path.anchor)
    for index, component in enumerate(path.parts[1:]):
        current /= component
        try:
            info = current.lstat()
        except FileNotFoundError:
            if allow_missing:
                return
            raise BackupError(f"Missing path: {current}")
        if stat.S_ISLNK(info.st_mode):
            raise BackupError(f"Symbolic links are not supported: {current}")
        if index < len(path.parts[1:]) - 1 and not stat.S_ISDIR(info.st_mode):
            raise BackupError(f"Not a directory: {current}")


def relpath(value):
    if not isinstance(value, str) or not value or value.startswith("/") or "\x00" in value:
        raise BackupError(f"Invalid HOME-relative path: {value!r}")
    if any(part in ("", ".", "..") for part in value.split("/")):
        raise BackupError(f"Invalid HOME-relative path: {value!r}")
    return Path(value)


def regular(path):
    check_components(path)
    if not stat.S_ISREG(path.lstat().st_mode):
        raise BackupError(f"Not a regular file: {path}")


def digest(path):
    regular(path)
    sha = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK), b""):
            sha.update(chunk)
            size += len(chunk)
    return sha.hexdigest(), size


def home_dir():
    value = os.environ.get("HOME", "")
    if not value or not os.path.isabs(value):
        raise BackupError("HOME must be an absolute directory")
    home = absolute(value)
    check_components(home)
    if not home.is_dir():
        raise BackupError("HOME is not a directory")
    return home


def inside(path, directory):
    return path == directory or directory in path.parents


def create(archive, names):
    home = home_dir()
    archive = absolute(archive)
    check_components(archive.parent)
    if not archive.parent.is_dir():
        raise BackupError("Backup parent must be an existing directory")
    if not names or len(names) > MAX_ENTRIES:
        raise BackupError(f"Choose between 1 and {MAX_ENTRIES} files")
    paths = [relpath(name) for name in names]
    if len(set(paths)) != len(paths):
        raise BackupError("Duplicate paths are not allowed")
    for path in paths:
        source = home / path
        if inside(source, archive) or inside(archive, source):
            raise BackupError("Backup directory overlaps a selected file")
        regular(source)
    try:
        archive.mkdir(mode=0o700)  # exclusive: never overwrite a backup
    except FileExistsError:
        raise BackupError(f"Backup path already exists: {archive}")
    try:
        data = archive / "files"
        data.mkdir(mode=0o700)
        entries = []
        for index, path in enumerate(paths):
            source = home / path
            regular(source)
            mode = stat.S_IMODE(source.stat().st_mode) & 0o777
            blob = data / f"{index:08d}"
            sha = hashlib.sha256()
            size = 0
            with source.open("rb") as src, blob.open("xb") as dst:
                os.chmod(blob, 0o600)
                for chunk in iter(lambda: src.read(CHUNK), b""):
                    dst.write(chunk)
                    sha.update(chunk)
                    size += len(chunk)
            entries.append({"path": path.as_posix(), "blob": blob.name,
                            "sha256": sha.hexdigest(), "size": size, "mode": mode})
        manifest = json.dumps({"version": 1, "files": entries}, indent=2) + "\n"
        if len(manifest.encode("utf-8")) > MAX_MANIFEST:
            raise BackupError("Manifest is too large")
        with (archive / "manifest.json").open("x", encoding="utf-8") as out:
            os.chmod(archive / "manifest.json", 0o600)
            out.write(manifest)
    except Exception:
        shutil.rmtree(archive)
        raise
    print(f"Created backup of {len(entries)} file(s): {archive}")


def load(archive):
    archive = absolute(archive)
    check_components(archive)
    if not archive.is_dir():
        raise BackupError("Backup is not a directory")
    manifest = archive / "manifest.json"
    regular(manifest)
    if manifest.stat().st_size > MAX_MANIFEST:
        raise BackupError("Manifest is too large")
    try:
        with manifest.open(encoding="utf-8") as stream:
            document = json.load(stream)
    except (ValueError, UnicodeError) as exc:
        raise BackupError(f"Invalid manifest: {exc}") from exc
    if not isinstance(document, dict) or document.get("version") != 1 or not isinstance(document.get("files"), list):
        raise BackupError("Unsupported backup manifest")
    entries = document["files"]
    if not 1 <= len(entries) <= MAX_ENTRIES:
        raise BackupError("Invalid number of backup entries")
    seen = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict) or set(entry) != {"path", "blob", "sha256", "size", "mode"}:
            raise BackupError("Invalid entry in manifest")
        path = relpath(entry["path"])
        if path in seen or entry["blob"] != f"{index:08d}":
            raise BackupError("Duplicate path or invalid blob name")
        if any(parent in seen for parent in path.parents) or any(path in other.parents for other in seen):
            raise BackupError("Overlapping file paths in manifest")
        seen.add(path)
        if (type(entry["mode"]) is not int or not 0 <= entry["mode"] <= 0o777
                or type(entry["size"]) is not int or entry["size"] < 0
                or not isinstance(entry["sha256"], str) or len(entry["sha256"]) != 64):
            raise BackupError("Invalid metadata")
        actual_hash, actual_size = digest(archive / "files" / entry["blob"])
        if actual_size != entry["size"] or actual_hash != entry["sha256"]:
            raise BackupError(f"Integrity check failed: {path}")
    return archive, entries


def restore(archive, apply, overwrite):
    home = home_dir()
    archive, entries = load(archive)
    targets = []
    conflicts = []
    for entry in entries:
        target = home / relpath(entry["path"])
        if inside(target, archive) or inside(archive, target):
            raise BackupError("Restore target overlaps backup directory")
        check_components(target, allow_missing=True)
        if target.exists():
            if not target.is_file():
                raise BackupError(f"Restore target is not a regular file: {target}")
            conflicts.append(target)
        targets.append(target)
    for entry, target in zip(entries, targets):
        print(f"{'REPLACE' if target in conflicts else 'CREATE '} {entry['path']!r}")
    print(f"Verified {len(entries)} file(s); existing files: {len(conflicts)}")
    if not apply:
        print("Preview only: no files changed. Use --apply to restore.")
        return
    if conflicts and not overwrite:
        raise BackupError("Existing files found; inspect preview and use --overwrite to replace")
    for entry, target in zip(entries, targets):
        # Recheck around creation to catch common changes since preflight. This
        # does not protect against hostile concurrent modification of directories.
        check_components(target, allow_missing=True)
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        check_components(target, allow_missing=True)
        if target.exists() and not overwrite:
            raise BackupError(f"Target appeared during restore: {target}")
        blob = archive / "files" / entry["blob"]
        if digest(blob) != (entry["sha256"], entry["size"]):
            raise BackupError(f"Integrity check failed during restore: {entry['path']}")
        fd, name = tempfile.mkstemp(prefix=".anide-restore-", dir=target.parent)
        try:
            with os.fdopen(fd, "wb") as out, blob.open("rb") as src:
                shutil.copyfileobj(src, out, CHUNK)
                os.fchmod(out.fileno(), entry["mode"])
            os.replace(name, target)
        finally:
            if os.path.exists(name):
                os.unlink(name)
    print("Restore complete; package and system changes were not restored.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    backup = commands.add_parser("create", help="back up explicitly named HOME-relative files")
    backup.add_argument("archive")
    backup.add_argument("files", nargs="+")
    recover = commands.add_parser("restore", help="verify and preview, or explicitly restore")
    recover.add_argument("archive")
    recover.add_argument("--apply", action="store_true")
    recover.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "create":
            create(args.archive, args.files)
        else:
            if args.overwrite and not args.apply:
                raise BackupError("--overwrite requires --apply")
            restore(args.archive, args.apply, args.overwrite)
    except (BackupError, OSError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
