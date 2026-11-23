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
