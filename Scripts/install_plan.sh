# Read-only high-level preview for install.sh --plan. Sourced before any
# installer helpers; intentionally uses Bash builtins only and makes no probes.
plan_install=0 plan_restore=0 plan_services=0 plan_pre=0
plan_nvidia=1 plan_theme=1 plan_shell=0 plan_defaults=0
for plan_arg in "$@"; do
    case "$plan_arg" in
        --plan) ;;
        -i|--install) plan_install=1 ;;
        -d|--defaults) plan_install=1; plan_defaults=1 ;;
        -r|--restore) plan_restore=1 ;;
        -s|--services) plan_services=1 ;;
        -p|--pre) plan_pre=1 ;;
        -n|--no-nvidia) plan_nvidia=0 ;;
        -m|--no-theme) plan_theme=0 ;;
        -h|--shell) plan_shell=1 ;;
        *) printf 'Unsupported option in --plan: %s\nUse separate options, e.g. --plan -i -r.\n' "$plan_arg" >&2; return 2 ;;
    esac
done
if (( ! plan_install && ! plan_restore && ! plan_services && ! plan_pre )); then
    plan_install=1 plan_restore=1 plan_services=1
fi
printf '%s\n' 'AniDE install plan (read-only, high-level; no changes made)' \
    'No environment, package, GPU, service or file checks are performed.' \
    'Actual changes depend on the machine, installed packages and interactive choices.'
if (( plan_pre )); then
    printf '%s\n' 'PRE: prepare Python environment; may change pacman and bootloader configuration.' \
        'The installer exits after PRE; other requested operations will not run.'
else
    if (( plan_install && plan_restore )); then
        printf '%s\n' 'PRE: prepare Python environment; may change pacman and bootloader configuration.'
    elif (( plan_install || plan_restore )); then
        printf '%s\n' 'PRE: prepare Python environment and installer dependencies.'
    fi
    if (( plan_install )); then
        printf '%s\n' 'INSTALL: select shell/AUR helper and install packages; may require sudo.'
    fi
    if (( plan_restore )); then
        printf '%s\n' 'RESTORE: install/check dependencies, deploy dotfiles, themes and run migrations.' \
            'RESTORE means deployment, not restoration of a backup; existing configuration may change.'
    fi
    if (( plan_install && plan_restore )); then
        printf '%s\n' 'POST: may configure SDDM, default applications, shell and other desktop settings.'
    fi
    if (( plan_services )); then
        printf '%s\n' 'SERVICES: may enable or change system and user services.'
    fi
fi
if (( plan_nvidia )); then
    printf '%s\n' 'NVIDIA: actions may be selected when detected (including boot configuration).'
else
    printf '%s\n' 'NVIDIA: --no-nvidia requested; verify legacy bootloader behavior before applying.'
fi
(( plan_theme )) || printf '%s\n' 'THEME: --no-theme requested; inspect installer behavior before applying.'
(( plan_shell )) && printf '%s\n' 'SHELL: shell configuration will be re-evaluated.'
(( plan_defaults )) && printf '%s\n' 'DEFAULTS: package operations requested without confirmation.'
printf '%s\n' 'This is not an exact file/package diff, a backup, or an authorization to apply.' \
    'Review the installer and take a verified system backup before a real run.'
return 0
