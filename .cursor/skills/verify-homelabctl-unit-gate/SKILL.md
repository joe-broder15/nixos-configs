---
name: verify-homelabctl-unit-gate
description: >-
  Proves that homelabctl refuses reboot, poweroff, halt, kexec, and every
  openclaw* unit except restart of openclaw-gateway, for every service name
  and every command string. Use when editing
  configurations/homelab/homelabctl/homelabctl.py, the unit denylist,
  normalize_unit, denied_reason, require_unit, service_unit, emit, or the
  status, restart, and logs verbs.
---

# Verify the homelabctl unit gate

The OpenClaw agent on homelab may run `homelabctl` as root with no password. The denylist inside that program is what stops it from rebooting the machine or restarting any OpenClaw unit other than the gateway.

## Property

For every service name and every command string, `denied_reason` allows the name only when the promise allows it. `reboot`, `poweroff`, `halt`, and `kexec` are refused for every verb. Every name that case-folds to an `openclaw` prefix is refused, except `restart` of `openclaw-gateway`.

## Harm

A break lets that agent, through passwordless sudo, stop or reboot the homelab, or status, restart, or read logs for an OpenClaw unit other than the one restart the promise allows.

## Run

From the repo root:

```sh
.cursor/skills/verify-homelabctl-unit-gate/run.sh
```

The script uses Z3 from `python313Packages.z3-solver` on this flake's nixpkgs pin (`nix shell --inputs-from`). At the sync commit that pin provides Z3 5.1.0. The run takes a few seconds. Exit 0 is a pass, exit 1 is a bug, exit 2 means the proof no longer describes the code.

## How to read the result

- **Exit 0.** Z3 found no counterexample. The pass covers names matching `UNIT_NAME_RE` and the call shape below. It does not cover sudo, systemd, or deploy.
- **Exit 1.** The message is a counterexample in homelabctl's words: a unit string, a verb, what `denied_reason` returned, and the name that would be passed to systemctl or journalctl. Replay it by calling `denied_reason` in `configurations/homelab/homelabctl/homelabctl.py`. If the function does what the message says, it is a bug. Do not edit the promise constants in `check.py` to make the run pass.
- **Exit 2.** The interpreter or the shape checks do not match the current functions, so the denylist proof does not apply to systemctl until you update them from the code and rerun. If the new code can hand a forbidden unit to systemctl or journalctl, report that as a bug too. A Z3 model that the running function does not reproduce is a mistake in the interpreter, not a bug in homelabctl.

Z3 is the proof. The script also runs `denied_reason` on a finite set: every case variant of the power units, `openclaw`, and `openclaw-gateway`, plus every unit-name string of length at most 2. That sweep only checks that the interpreter still matches the function. A sweep that passes is not the proof.

## What is proved

`check.py` reads the bytecode of `denied_reason` and turns each return path into a Z3 condition: membership in `DENIED_UNITS`, `startswith` of `DENIED_PREFIX`, equality with `GATEWAY_RESTART_UNIT`, and equality of the command with the constant the bytecode compares. Z3 asks whether any string in the language of `UNIT_NAME_RE`, paired with any command string, takes a path the promise does not allow. Unsat means there is no such string.

These shape checks connect that result to the commands the agent runs. They are part of the proof only while they still match the source:

- `normalize_unit` returns only on the success jump of `UNIT_NAME_RE.fullmatch`, so every name `denied_reason` sees from `require_unit` is in the language Z3 quantified over.
- `require_unit` normalizes, calls `denied_reason` on that bare name, calls `emit_error` when the reason is not None, and otherwise returns that same name.
- `emit` ends by raising `SystemExit`, and `emit_error` calls `emit` without catching it, so a denial cannot fall through to the return.
- `service_unit` is the f-string that appends `.service` and does not branch.
- `cmd_status`, `cmd_restart`, and `cmd_logs` call `require_unit` on the raw argument before `systemctl` or `journalctl`, and they pass `service_unit` of the allowed bare name. `read_status` does the same for `systemctl show`. The raw argument is not used again.
- `run` is only called from `read_status`, `cmd_restart`, `cmd_logs`, and `cmd_deploy`. `cmd_deploy` takes `pull` and no unit. `systemctl` and `journalctl` appear as command arguments only in `read_status`, `cmd_restart`, and `cmd_logs`.

## Coverage

- File: `configurations/homelab/homelabctl/homelabctl.py`
- Functions: `normalize_unit`, `denied_reason`, `require_unit`, `service_unit`, `emit`, `emit_error`, `read_status`, `cmd_status`, `cmd_restart`, `cmd_logs`, and `cmd_deploy` (the last only to see that it takes no unit)
- Sync commit: `846bc09c2a716df94654816690dd6938fa4cbb95`
- Confirmed against that commit on 2026-10-31. `homelabctl.py` at that commit is the file this proof describes. The promise constants are `PROMISE_POWER_UNITS`, `PROMISE_OPENCLAW_PREFIX`, `PROMISE_GATEWAY_UNIT`, and `PROMISE_RESTART_COMMAND` in `.cursor/skills/verify-homelabctl-unit-gate/check.py`.

Move the sync commit forward only after you have run this check on the code at the new commit and confirmed that the interpreter and the shape checks still describe that code. A green run does not qualify if you have not looked. If you changed the proof because the code changed shape, say what changed. If you changed the promise constants, cite the evidence that the promise changed on purpose: the comment on `denied_reason`, the homelabctl skill, or the commit message. Do not move the sync commit while the check exits 2.

## When the covered code changes

Diff `configurations/homelab/homelabctl/homelabctl.py` from the sync commit.

- A change that does not touch the functions above can keep the proof. Run the check if you are not sure the edit stayed clear of them.
- A change inside `denied_reason` is already what Z3 reads from the bytecode. Run the check. Exit 1 is a bug unless the promise was meant to change. Exit 2 means the new bytecode uses an operation the interpreter does not know. Extend the interpreter from the new bytecode, rerun, and break the new check on purpose (restore a removed refusal, confirm exit 1, then put the refusal back) before you trust a green run.
- A change to the order of `normalize_unit`, `denied_reason`, `emit_error`, or the verbs is a shape failure until you update the shape checks from the new source. Keep the requirement that the denylist sees the bare name before systemctl. Then rerun.
- Changing `DENIED_UNITS`, `DENIED_PREFIX`, or `GATEWAY_RESTART_UNIT` without changing the promise makes the check fail. That is the point. Update the promise constants only when the project meant the new rule.

## Assumptions

- The names in the proof are those matching `^[A-Za-z0-9][A-Za-z0-9_.:@-]*$`, which is `UNIT_NAME_RE`. `normalize_unit` rejects every other string before the denylist. The proof does not re-prove CPython's `re.fullmatch`. It checks that the only return sits on that call's success jump.
- Case folding on that alphabet is ASCII and per character. The script checks every character and every pair against this Python, and assumes longer strings fold the same way. That holds here because none of these characters is a special Unicode case.
- The decision is case-insensitive because `denied_reason` lowercases the name. systemd unit names are case-sensitive, so restart of `OpenClaw-Gateway` is the same exception as `openclaw-gateway` and asks systemd for `OpenClaw-Gateway.service`. That is the rule this proof checks.
- `cmd_deploy` is not proved, except that it does not take a unit. The locked `#homelab` flake target is a separate promise.

## Not covered

sudoers, the sudo re-exec, what systemd does with a unit that passed the gate, journal filtering, the deploy flake output, and any unit name `normalize_unit` rejects.

Z3 is the tool because the question is whether every name is allowed, not whether steps can happen in a bad order. CrossHair 0.0.112 executes this Python but does not finish: `str.lower` is explored one character at a time, and a short run stops at "not confirmed" before it reaches `openclaw-gateway`.

After edits that landed without this check, use `/maintain-formal-verification-skill`.
