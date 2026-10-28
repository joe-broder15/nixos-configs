---
name: homelabctl
description: Operate the homelab only through homelabctl (status, restart, journal windows, deploy). Never call sudo, systemctl, journalctl, or nixos-rebuild yourself.
---

# homelabctl

This is the only host-admin interface. Do not run `sudo`, `systemctl`,
`journalctl`, `nixos-rebuild`, or the repo `scripts/rebuild*.sh` helpers.
Call `homelabctl` as `user`; it elevates itself. Every command prints one JSON
object on stdout and nothing else.

## Commands

```sh
homelabctl status <unit>
homelabctl restart <unit>
homelabctl logs <unit> [--since <when>] [--until <when>] [--grep <pattern>]
homelabctl deploy [--pull]
```

`<unit>` is a systemd **service** name (`plex` or `plex.service`). Other unit
types (`.timer`, `.socket`, `.target`, slices, mounts) are rejected.

## Logs

There is no live follow. `--since` alone means that bound through now.
`--until` closes the window. If you omit both, `--since` defaults to
`1 hour ago`. Times are `journalctl` strings (`2026-10-25 19:00:00`,
`2 hours ago`). `--grep` is `journalctl --grep` inside that window.

## Deploy

Always rebuilds this host's `homelab` flake output from
`/home/user/nixos-configs`. You cannot choose another configuration.
`--pull` runs `git pull --ff-only` in that checkout first, then
`nixos-rebuild switch --impure`.

## Denied units

Refuse (status, restart, and logs):

- any unit whose name starts with `openclaw`, except `restart` of `openclaw-gateway`
- `reboot`, `poweroff`, `halt`, `kexec`

`homelabctl restart openclaw-gateway` is allowed. `status` and `logs` of that
unit stay denied, and so does every other `openclaw*` name. Restarting the
gateway ends the current turn; the next message runs on the new process.

## JSON

Success includes `"ok": true`. Failures still print JSON with `"ok": false`
and `"error"`, plus a short message on stderr. Logs put journal objects in
`"entries"`. Deploy includes `"stdout"`, `"stderr"`, and `"exit_code"`.

If `homelabctl` is missing from PATH, stop; do not reconstruct the same
operations with other commands.
