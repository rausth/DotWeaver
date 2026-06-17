# DotWeaver CLI Reference

The `dw` executable is bundled inside `DotWeaver.app/Contents/MacOS/dw` and can be installed from Settings.

## Files

```bash
dw add <file> [--group <name>] [--tag <tag>] [--strategy <lastModifiedWins|localWins|remoteWins|manual>]
dw remove <file>
dw list [--all]
dw status
dw vault <file>
dw monitor <file> <on|off>
dw metadata <file> [--group <name>] [--tag <tag>] [--pre-hook <script>] [--post-hook <script>] [--strategy <strategy>]
dw cat <file>
dw edit <file>
```

## Sync And Providers

```bash
dw sync
dw provider list
dw provider set <provider>
dw provider folder <path>
dw provider transport <provider> <folder|native>
dw native config <provider> --endpoint <url> [--username <user>]
```

Providers:

```text
git
icloud
onedrive
googledrive
dropbox
webdav
sftp
ftps
s3
```

## Git

```bash
dw git config [--path <repo>] [--remote <url>] [--branch <branch>] [--ssh-key <path>] [--host <name>]
dw git pull
dw git push
dw git status
```

`dw sync` writes provider data into the configured repository. Folder-backed providers store files by machine under `.dotweaver/files/machines/<machine-id>/`. `dw git push` stages `.dotweaver`, creates a sync commit if needed, and pushes to `origin <branch>`.

## Snapshots And Conflicts

```bash
dw snapshot machines
dw snapshot list [--machine <id-or-hostname>]
dw snapshot create <name>
dw snapshot restore <id-or-name> [--machine <id-or-hostname>] [--file <path>]
dw snapshot delete <id-or-name>
dw conflicts list
dw conflicts resolve <file> <local|stored|newest>
```

`--machine` selects source machine for provider-hosted snapshots. ID match wins; hostname must be unique.

```bash
dw snapshot machines
dw snapshot list --machine intel1
dw snapshot restore before-shell-change --machine intel1 --file ~/.zshrc
```

## Versions

```bash
dw versions <file>
dw versions restore <file> <version-id>
```

## Templates

```bash
dw templates list
dw templates apply <oh-my-zsh|starship|vim>
```

## Interop

```bash
dw interop mackup import <config-file> [--dry-run]
dw interop chezmoi import <source-dir> [--dry-run]
dw interop chezmoi export <source-dir> [--force]
```

Mackup import reads common INI sections such as `configuration_files`, `xdg_configuration_files`, `library_files`, and `application_support_files`.

chezmoi import/export supports common source-state paths such as `dot_zshrc` and `dot_config/starship.toml`. Advanced chezmoi templates/scripts are intentionally imported as monitored target paths, not executed.

## System

```bash
dw doctor
dw hooks <on|off>
dw machine
```

## Validation

```bash
swift test
script/smoke_provider_matrix.sh
script/validate_release_local.sh
script/smoke_app_ui.sh
```
