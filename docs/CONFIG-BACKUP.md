# Opt-in configuration file backup

`Scripts/config_backup.py` backs up **explicitly selected regular files under
HOME**. It is separate from the installer and does not change the meaning of
`install.sh -r`. It does not automatically select files, take system snapshots,
restore packages, services, bootloaders, ownership, ACLs, extended attributes,
hard links, timestamps or complete directories.

From the repo root, for example (replace the file names with files that exist):

```sh
# The parent of the destination must exist; the destination must not exist.
python3 Scripts/config_backup.py create "$HOME/anide-backup-1" \
  .config/hypr/hyprland.lua .config/hyde/config.toml

# Verify hashes and preview every create/replace operation; no writes to HOME.
python3 Scripts/config_backup.py restore "$HOME/anide-backup-1"

# Only after reviewing the preview: create missing files and replace existing ones.
python3 Scripts/config_backup.py restore "$HOME/anide-backup-1" --apply --overwrite
```

Without `--overwrite`, `--apply` refuses the entire operation if any target
already exists. With `--overwrite`, the explicitly listed files are replaced.
Preflight validates all paths and checks SHA-256 and size of every backup file
before writing. Files are replaced individually using a temporary file and
rename; **the overall restore is not transactional**. A later I/O error can
leave an earlier file restored. Keep a separate independent backup and examine
errors. Restored permissions are limited to ordinary mode bits.

Archives have a JSON manifest and numbered data files, created in a new private
0700 directory. Their contents are **not encrypted** and may contain secrets;
store them securely. Hashes detect accidental corruption, not a maliciously
modified archive: someone who changes both the data and the manifest can create
valid hashes. Only restore a backup from a trusted source, and review its paths.

Symlinks in source, backup and target paths and path traversal are rejected.
The tool performs pathname checks but is **not safe against a malicious or
concurrent process changing directories or files between checks and operations**;
run it as the owning user in a trusted, quiescent environment. Files being
actively modified during backup may be captured in an inconsistent state.
Test restoration in a disposable HOME before relying on a backup. No system
configuration outside HOME is supported.
