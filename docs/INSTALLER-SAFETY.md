# Installer preview and safety

`bash Scripts/install.sh --plan` is a read-only, high-level preview of the
installer's possible operation categories. It returns before the installer
sources its helpers or runs detection. It neither probes the machine nor
predicts exact packages, files, prompts or service changes. It is not a backup,
rollback, full dry-run or a substitute for reviewing the installer.

Examples (run from the repository root):

```sh
bash Scripts/install.sh --plan
bash Scripts/install.sh --plan -r
bash Scripts/install.sh --plan -i -r -n
bash Scripts/install.sh --plan -p
```

The preview accepts the installer's individual operation and modifier flags;
pass short options separately. `-p` takes precedence, as in the installer.
Unsupported options, including `-t`, fail rather than silently running the
installer. `--plan` never proceeds to apply changes.

The existing `-t`/`--test` path is **not guaranteed read-only**: among other
things it can create log and temporary files. Although several known mutation
paths have been guarded, the whole path has not been proven read-only. `-r` deploys dotfiles and runs related operations; it does not restore
a backup. Review changes, verify an independent backup, and test in a disposable
VM before applying. The plan does not guarantee that `--no-nvidia` prevents
every bootloader-related action in existing installer paths.

For an opt-in backup of selected HOME files, see [configuration file backup](CONFIG-BACKUP.md). It is not a full system snapshot or an installer rollback.

## Legacy manifest handling

`restore_cfg.sh` accepts `.psv` and `.lst` manifests. For actionable rows it
checks all destination paths and target names before deployment. Paths may use
`${HOME}` or `$HOME` at the beginning, or an absolute path under HOME; target
names must be single path components. Shell expansion, command substitution and
`..` components are rejected. Custom manifests relying on arbitrary environment
variables or shell expressions need to be rewritten using these supported paths.

This is lexical validation, not a filesystem sandbox: symlinks and concurrent
changes can still redirect legacy deployment. Use only trusted manifests and
source trees, and test changes in a disposable VM. This script is a legacy path;
the main installer also uses deez-dots and is not protected by this validation.

## Migration failure handling

Legacy `--test` now reports migrations without executing them or creating their
state file. In an actual restore, pre-deploy migration failures are retried after
deployment. The migration runner continues through remaining migrations, records
only successful ones and returns failure if any remain unsuccessful; the
installer then exits nonzero before a reboot prompt. These are not transactional
operations: individual migrations can make changes before failing. Inspect the
logs and verify backups before retrying. This does not make the rest of `--test`
read-only.

### Hyprland Lua configuration

`restore_cfg.sh` is a legacy deployer. It no longer queries or replaces
`hyprland.conf` using the removed HyDE template or installs `hyprquery` for
that check. It leaves existing user `.conf` and `.lua` configurations untouched
by the hook. If the user Lua entry point (`$XDG_CONFIG_HOME/hypr/hyprland.lua`)
or managed entry point (`$XDG_DATA_HOME/hypr/hyde.lua`) is missing, it warns;
the hook does not create either file. XDG directories default to `~/.config`
and `~/.local/share` when unset or empty.

The supported full dotfile deployment is `bash Scripts/install.sh -r` from the
repository root. Review its plan and back up your configuration first: it is a
deployment, not a backup restore, and may change user configuration. Hyprland
prefers `hyprland.lua` over `hyprland.conf`, so review how this affects an
existing custom configuration before deploying or migrating it. The warning
alone does not prove a complete or working Hyprland installation.
