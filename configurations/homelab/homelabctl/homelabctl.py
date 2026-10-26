"""Agent-only homelab admin CLI. Stdlib only; one JSON object on stdout."""

from __future__ import annotations

import argparse
import json
import os
import pwd
import re
import subprocess
import sys
from typing import Mapping, NoReturn, Sequence

# Bare names. Matched case-insensitively so a different spelling still fails closed.
DENIED_UNITS: frozenset[str] = frozenset({"reboot", "poweroff", "halt", "kexec"})
# Prefix, not an exact unit, so a future openclaw helper unit stays blocked.
DENIED_PREFIX: str = "openclaw"
# A missing window would dump the whole journal; the agent must pass a bound or get this.
DEFAULT_LOG_SINCE: str = "1 hour ago"
# Deploy cannot target thinkpad or desktop. The flake output is not an argument.
FLAKE_OUTPUT: str = "homelab"
REPO_ROOT: str = "/home/user/nixos-configs"
# The wrapped sudo, not /run/current-system/sw/bin/sudo, so NOPASSWD rules apply.
SUDO_WRAPPER: str = "/run/wrappers/bin/sudo"
# systemd unit names, including template instances (name@instance).
UNIT_NAME_RE: re.Pattern[str] = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:@-]*$")


def emit(payload: Mapping[str, object], *, ok: bool, exit_code: int) -> NoReturn:
    """Print one JSON object and stop.

    Inputs:
        payload: fields merged into the JSON object.
        ok: success flag. Written after payload so a payload key cannot override it.
        exit_code: process exit status.
    Outputs:
        Does not return. Writes one JSON line to stdout and raises SystemExit.
    """
    # ok is applied last so a payload key cannot override the tool's own flag.
    document: dict[str, object] = {**payload, "ok": ok}
    # Compact separators: the agent reads one line, not a pretty-printed document.
    json.dump(document, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    raise SystemExit(exit_code)


def emit_error(code: str, message: str, *, exit_code: int = 1) -> NoReturn:
    """Report a failure on stderr and as JSON on stdout.

    Inputs:
        code: short machine-readable error code, stored as "code".
        message: human-readable text, printed on stderr and stored as "error".
        exit_code: process exit status. Defaults to 1.
    Outputs:
        Does not return. Writes the message to stderr, one JSON line to stdout, and raises SystemExit.
    """
    # stderr is for the journal and a human glance; stdout stays machine-readable.
    print(message, file=sys.stderr)
    emit({"code": code, "error": message}, ok=False, exit_code=exit_code)


def normalize_unit(raw: str) -> str:
    """Return the bare service name, or raise ValueError if it is not a service unit.

    Inputs:
        raw: unit argument from the agent, with or without a ".service" suffix.
    Outputs:
        Bare service name, with the suffix removed. Raises ValueError when the name is empty, path-like, or not a service.
    """
    name: str = raw.strip()
    # Slashes and .. would let a name look like a unit path. Whitespace breaks argv.
    if not name or "/" in name or ".." in name or any(ch.isspace() for ch in name):
        raise ValueError("unit name is invalid")
    if "." in name:
        base: str
        ext: str
        # Only the last suffix is the unit type. "foo.service" is allowed; "foo.timer" is not.
        base, ext = name.rsplit(".", 1)
        if ext != "service":
            raise ValueError("only .service units are allowed")
        name = base
    if not name or not UNIT_NAME_RE.fullmatch(name):
        raise ValueError("unit name is invalid")
    return name


def denied_reason(unit: str) -> str | None:
    """Return a denial message, or None if this bare unit may be touched.

    Inputs:
        unit: bare service name, already normalized.
    Outputs:
        A denial string for openclaw* and reboot, poweroff, halt, and kexec. None when the unit is allowed.
    """
    lowered: str = unit.lower()
    # Case-fold the check. systemd treats unit names as case-sensitive.
    if lowered in DENIED_UNITS or lowered.startswith(DENIED_PREFIX):
        return f"unit {unit!r} is denied"
    return None


def service_unit(unit: str) -> str:
    """Add the .service suffix after the denylist has seen the bare name.

    Inputs:
        unit: bare service name.
    Outputs:
        The same name with ".service" appended, for systemctl and journalctl.
    """
    # systemctl and journalctl select on the suffixed unit, not the bare name.
    return f"{unit}.service"


def run(argv: Sequence[str]) -> subprocess.CompletedProcess[str]:
    """Run a command and capture both streams. Nonzero exits are data, not tracebacks.

    Inputs:
        argv: command and arguments. Not passed through a shell.
    Outputs:
        CompletedProcess with text stdout, stderr, and returncode. Does not raise on a nonzero exit.
    """
    # check=False: the caller turns the exit code into a JSON error.
    return subprocess.run(
        list(argv),
        check=False,
        capture_output=True,
        text=True,
    )


def parse_systemctl_show(text: str) -> dict[str, str]:
    """Parse `systemctl show` key=value lines. Values may themselves contain '='.

    Inputs:
        text: raw stdout from `systemctl show`.
    Outputs:
        Map of property name to value. Lines without '=' are skipped.
    """
    fields: dict[str, str] = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        key: str
        value: str
        # Split once so Description and similar values keep any later '='.
        key, value = line.split("=", 1)
        fields[key] = value
    return fields


def read_status(unit: str) -> dict[str, object]:
    """Read a service's systemctl show fields.

    Inputs:
        unit: bare service name, already allowed by require_unit.
    Outputs:
        Status payload with command, unit, description, load_state, active_state, sub_state, result, main_pid, n_restarts, and unit_file_state. Does not return if systemctl fails or the unit is missing.
    """
    name: str = service_unit(unit)
    completed: subprocess.CompletedProcess[str] = run(
        [
            "systemctl",
            "show",
            name,
            "--property=Id,LoadState,ActiveState,SubState,Result,MainPID,NRestarts,UnitFileState,Description",
        ]
    )
    if completed.returncode != 0:
        message: str = completed.stderr.strip() or completed.stdout.strip() or "systemctl show failed"
        emit_error("systemctl", message)
    fields: dict[str, str] = parse_systemctl_show(completed.stdout)
    # A missing unit is still exit 0. LoadState is what distinguishes it.
    if fields.get("LoadState") == "not-found":
        emit_error("not_found", f"unit {name!r} was not found")
    return {
        "command": "status",
        "unit": name,
        "description": fields.get("Description", ""),
        "load_state": fields.get("LoadState", ""),
        "active_state": fields.get("ActiveState", ""),
        "sub_state": fields.get("SubState", ""),
        "result": fields.get("Result", ""),
        "main_pid": fields.get("MainPID", ""),
        "n_restarts": fields.get("NRestarts", ""),
        "unit_file_state": fields.get("UnitFileState", ""),
    }


def require_unit(raw: str) -> str:
    """Validate and authorize a unit argument. Shared by status, restart, and logs.

    Inputs:
        raw: unit argument from the agent.
    Outputs:
        Bare service name. Does not return when the name is invalid or denylisted.
    """
    # One gate, so a verb cannot reach systemctl or journalctl without the denylist.
    try:
        unit: str = normalize_unit(raw)
    except ValueError as exc:
        emit_error("invalid_unit", str(exc))
    reason: str | None = denied_reason(unit)
    if reason is not None:
        emit_error("denied", reason)
    return unit


def cmd_status(unit_raw: str) -> NoReturn:
    """Handle `status`.

    Inputs:
        unit_raw: unit argument from the agent.
    Outputs:
        Does not return. Writes a JSON status object to stdout and raises SystemExit(0), or an error object if the unit is rejected or missing.
    """
    # require_unit runs before systemctl, so a denied unit never reaches the manager.
    emit(read_status(require_unit(unit_raw)), ok=True, exit_code=0)


def cmd_restart(unit_raw: str) -> NoReturn:
    """Handle `restart`, then emit the post-restart status snapshot.

    Inputs:
        unit_raw: unit argument from the agent.
    Outputs:
        Does not return. Writes a JSON status object with command "restart" and raises SystemExit(0), or an error object if restart fails or the unit is rejected.
    """
    unit: str = require_unit(unit_raw)
    name: str = service_unit(unit)
    completed: subprocess.CompletedProcess[str] = run(["systemctl", "restart", name])
    if completed.returncode != 0:
        message: str = completed.stderr.strip() or completed.stdout.strip() or "systemctl restart failed"
        emit_error("systemctl", message)
    # Status after the restart so the agent sees the resulting state, not only "exited 0".
    payload: dict[str, object] = read_status(unit)
    payload["command"] = "restart"
    emit(payload, ok=True, exit_code=0)


def parse_journal_entries(text: str) -> list[object]:
    """Parse journalctl JSON output. One object per line, not one JSON array.

    Inputs:
        text: raw stdout from `journalctl --output=json`.
    Outputs:
        List of decoded journal objects, in order. Does not return if a non-empty line is not JSON.
    """
    entries: list[object] = []
    for line in text.splitlines():
        stripped: str = line.strip()
        if not stripped:
            continue
        try:
            entries.append(json.loads(stripped))
        except json.JSONDecodeError:
            # A non-JSON line means the output is not the format we asked for.
            emit_error("journalctl", "journalctl returned a non-JSON line")
    return entries


def cmd_logs(unit_raw: str, since: str, until: str | None, grep: str | None) -> NoReturn:
    """Handle `logs` for a closed window, or from --since through now.

    Inputs:
        unit_raw: unit argument from the agent.
        since: journalctl time bound. The window starts here.
        until: journalctl end bound. None means through now.
        grep: journalctl --grep pattern. None means no filter.
    Outputs:
        Does not return. Writes a JSON object with command, unit, since, until, grep, and entries, then raises SystemExit(0). An empty match is success.
    """
    unit: str = require_unit(unit_raw)
    name: str = service_unit(unit)
    argv: list[str] = [
        "journalctl",
        # One JSON object per line, which parse_journal_entries collects.
        "--output=json",
        # Never hand the agent a pager. The command must exit on its own.
        "--no-pager",
        "--unit",
        name,
        # Always bounded. since defaults to the last hour when the agent omits it.
        "--since",
        since,
    ]
    # --until omitted means the window runs through now.
    if until is not None:
        argv.extend(["--until", until])
    # journalctl --grep, not a second pass, so the window is filtered before we buffer it.
    if grep is not None:
        argv.extend(["--grep", grep])
    completed: subprocess.CompletedProcess[str] = run(argv)
    # Exit 1 is an empty match (no lines in the window, or grep missed). That is success.
    if completed.returncode not in (0, 1):
        message: str = completed.stderr.strip() or "journalctl failed"
        emit_error("journalctl", message)
    emit(
        {
            "command": "logs",
            "unit": name,
            "since": since,
            "until": until,
            "grep": grep,
            "entries": parse_journal_entries(completed.stdout),
        },
        ok=True,
        exit_code=0,
    )


def git_identity() -> str:
    """Return the user who invoked homelabctl, even after the sudo re-exec.

    Inputs:
        None. Reads SUDO_USER, then the current uid.
    Outputs:
        Username string. Does not return if neither source yields a user.
    """
    # SUDO_USER is set by the re-exec. Without it, git would run as root.
    sudo_user: str | None = os.environ.get("SUDO_USER")
    if sudo_user:
        return sudo_user
    try:
        return pwd.getpwuid(os.getuid()).pw_name
    except KeyError:
        emit_error("deploy", "could not determine the invoking user for git pull")


def cmd_deploy(pull: bool) -> NoReturn:
    """Rebuild the homelab flake. With pull, fast-forward the checkout first.

    Inputs:
        pull: when True, run `git pull --ff-only` in the homelab checkout before the rebuild.
    Outputs:
        Does not return. Writes a JSON object with command, pull, flake, stdout, stderr, and exit_code. Raises SystemExit with the rebuild's exit code. A failed pull writes an error object and exits 1.
    """
    if pull:
        # Drop to the invoking user so the pull uses their SSH keys and does not
        # leave root-owned files in the checkout.
        git: subprocess.CompletedProcess[str] = run(
            [
                SUDO_WRAPPER,
                "-u",
                git_identity(),
                "--",
                "git",
                "-C",
                REPO_ROOT,
                "pull",
                "--ff-only",
            ]
        )
        if git.returncode != 0:
            message: str = git.stderr.strip() or git.stdout.strip() or "git pull failed"
            emit_error("git", message)
    # Already root here, so nixos-rebuild is not a second sudo. The output name is fixed.
    rebuild: subprocess.CompletedProcess[str] = run(
        [
            "nixos-rebuild",
            "switch",
            "--impure",
            "--flake",
            f"{REPO_ROOT}#{FLAKE_OUTPUT}",
        ]
    )
    ok: bool = rebuild.returncode == 0
    emit(
        {
            "command": "deploy",
            "pull": pull,
            "flake": f"{REPO_ROOT}#{FLAKE_OUTPUT}",
            "stdout": rebuild.stdout,
            "stderr": rebuild.stderr,
            "exit_code": rebuild.returncode,
        },
        ok=ok,
        exit_code=rebuild.returncode,
    )


def maybe_reexec_with_sudo() -> None:
    """Re-exec this binary through passwordless sudo unless already root.

    Inputs:
        None. Uses the current euid and sys.argv.
    Outputs:
        None when already root. Otherwise does not return: replaces this process with `sudo -n`, or raises SystemExit if exec fails.
    """
    if os.geteuid() == 0:
        return
    # realpath: sudoers allows the store path, not whatever relative argv[0] was.
    target: str = os.path.realpath(sys.argv[0])
    # -n fails closed. A missing NOPASSWD rule must not prompt on the agent's turn.
    argv: list[str] = [SUDO_WRAPPER, "-n", "--", target, *sys.argv[1:]]
    try:
        os.execv(SUDO_WRAPPER, argv)
    except OSError as exc:
        emit_error("sudo", f"failed to exec sudo: {exc}")


class JsonArgumentParser(argparse.ArgumentParser):
    """argparse that reports usage errors as JSON instead of plain text."""

    def error(self, message: str) -> NoReturn:
        """Exit 2 with a usage JSON object. argparse would otherwise print text and exit.

        Inputs:
            message: usage error text from argparse.
        Outputs:
            Does not return. Writes the message to stderr, one JSON error object to stdout, and raises SystemExit(2).
        """
        # Override the default so a bad invocation is still one JSON object on stdout.
        emit_error("usage", message, exit_code=2)


def build_parser() -> JsonArgumentParser:
    """Build the agent CLI. There is no human-oriented output flag.

    Inputs:
        None.
    Outputs:
        Parser for status, restart, logs, and deploy.
    """
    parser: JsonArgumentParser = JsonArgumentParser(
        prog="homelabctl",
        description="Agent-only interface for homelab service operations and deploy.",
    )
    # required=True: `homelabctl` with no verb is a usage error, not a silent success.
    subparsers = parser.add_subparsers(dest="command", required=True)

    status: argparse.ArgumentParser = subparsers.add_parser("status")
    status.add_argument("unit")

    restart: argparse.ArgumentParser = subparsers.add_parser("restart")
    restart.add_argument("unit")

    logs: argparse.ArgumentParser = subparsers.add_parser("logs")
    logs.add_argument("unit")
    # default since: the agent can pass only --until, or nothing, and still get a window.
    logs.add_argument("--since", default=DEFAULT_LOG_SINCE)
    logs.add_argument("--until", default=None)
    logs.add_argument("--grep", default=None)

    deploy: argparse.ArgumentParser = subparsers.add_parser("deploy")
    deploy.add_argument("--pull", action="store_true")
    return parser


def dispatch(args: argparse.Namespace) -> NoReturn:
    """Run the subcommand selected by build_parser.

    Inputs:
        args: parsed CLI namespace with command and that command's fields.
    Outputs:
        Does not return. The selected command writes JSON and raises SystemExit.
    """
    command: str = args.command
    if command == "status":
        cmd_status(args.unit)
    elif command == "restart":
        cmd_restart(args.unit)
    elif command == "logs":
        cmd_logs(args.unit, args.since, args.until, args.grep)
    elif command == "deploy":
        cmd_deploy(args.pull)
    else:
        # required=True makes this unreachable; keep it so a new verb fails closed.
        emit_error("usage", f"unknown command {command!r}", exit_code=2)


def main(argv: Sequence[str] | None = None) -> NoReturn:
    """Elevate, parse argv, and dispatch.

    Inputs:
        argv: arguments after the program name. None means argparse reads sys.argv.
    Outputs:
        Does not return. Re-execs through sudo when not root, otherwise writes JSON and raises SystemExit.
    """
    # Elevate before parsing so usage errors and verbs share the same root path.
    maybe_reexec_with_sudo()
    parser: JsonArgumentParser = build_parser()
    # None means argparse reads sys.argv. A sequence lets a caller pass args directly.
    args: argparse.Namespace = parser.parse_args(list(argv) if argv is not None else None)
    dispatch(args)


if __name__ == "__main__":
    main()
