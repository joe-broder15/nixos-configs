from __future__ import annotations

import argparse
import json
import os
import pwd
import re
import subprocess
import sys
from typing import Mapping, NoReturn, Sequence

DENIED_UNITS: frozenset[str] = frozenset({"reboot", "poweroff", "halt", "kexec"})
DENIED_PREFIX: str = "openclaw"
DEFAULT_LOG_SINCE: str = "1 hour ago"
FLAKE_OUTPUT: str = "homelab"
REPO_ROOT: str = "/home/user/nixos-configs"
SUDO_WRAPPER: str = "/run/wrappers/bin/sudo"
UNIT_NAME_RE: re.Pattern[str] = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:@-]*$")


def emit(payload: Mapping[str, object], *, ok: bool, exit_code: int) -> NoReturn:
    document: dict[str, object] = {"ok": ok, **payload}
    json.dump(document, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    raise SystemExit(exit_code)


def emit_error(code: str, message: str, *, exit_code: int = 1) -> NoReturn:
    print(message, file=sys.stderr)
    emit({"code": code, "error": message}, ok=False, exit_code=exit_code)


def normalize_unit(raw: str) -> str:
    name: str = raw.strip()
    if not name or "/" in name or ".." in name or any(ch.isspace() for ch in name):
        raise ValueError("unit name is invalid")
    if "." in name:
        base: str
        ext: str
        base, ext = name.rsplit(".", 1)
        if ext != "service":
            raise ValueError("only .service units are allowed")
        name = base
    if not name or not UNIT_NAME_RE.fullmatch(name):
        raise ValueError("unit name is invalid")
    return name


def denied_reason(unit: str) -> str | None:
    lowered: str = unit.lower()
    if lowered in DENIED_UNITS or lowered.startswith(DENIED_PREFIX):
        return f"unit {unit!r} is denied"
    return None


def service_unit(unit: str) -> str:
    return f"{unit}.service"


def run(argv: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(argv),
        check=False,
        capture_output=True,
        text=True,
    )


def parse_systemctl_show(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        key: str
        value: str
        key, value = line.split("=", 1)
        fields[key] = value
    return fields


def read_status(unit: str) -> dict[str, object]:
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
    try:
        unit: str = normalize_unit(raw)
    except ValueError as exc:
        emit_error("invalid_unit", str(exc))
    reason: str | None = denied_reason(unit)
    if reason is not None:
        emit_error("denied", reason)
    return unit


def cmd_status(unit_raw: str) -> NoReturn:
    emit(read_status(require_unit(unit_raw)), ok=True, exit_code=0)


def cmd_restart(unit_raw: str) -> NoReturn:
    unit: str = require_unit(unit_raw)
    name: str = service_unit(unit)
    completed: subprocess.CompletedProcess[str] = run(["systemctl", "restart", name])
    if completed.returncode != 0:
        message: str = completed.stderr.strip() or completed.stdout.strip() or "systemctl restart failed"
        emit_error("systemctl", message)
    payload: dict[str, object] = read_status(unit)
    payload["command"] = "restart"
    emit(payload, ok=True, exit_code=0)


def parse_journal_entries(text: str) -> list[object]:
    entries: list[object] = []
    for line in text.splitlines():
        stripped: str = line.strip()
        if not stripped:
            continue
        try:
            entries.append(json.loads(stripped))
        except json.JSONDecodeError:
            emit_error("journalctl", "journalctl returned a non-JSON line")
    return entries


def cmd_logs(unit_raw: str, since: str, until: str | None, grep: str | None) -> NoReturn:
    unit: str = require_unit(unit_raw)
    name: str = service_unit(unit)
    argv: list[str] = [
        "journalctl",
        "--output=json",
        "--no-pager",
        "--unit",
        name,
        "--since",
        since,
    ]
    if until is not None:
        argv.extend(["--until", until])
    if grep is not None:
        argv.extend(["--grep", grep])
    completed: subprocess.CompletedProcess[str] = run(argv)
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
    sudo_user: str | None = os.environ.get("SUDO_USER")
    if sudo_user:
        return sudo_user
    try:
        return pwd.getpwuid(os.getuid()).pw_name
    except KeyError:
        emit_error("deploy", "could not determine the invoking user for git pull")


def cmd_deploy(pull: bool) -> NoReturn:
    if pull:
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
    if os.geteuid() == 0:
        return
    target: str = os.path.realpath(sys.argv[0])
    argv: list[str] = [SUDO_WRAPPER, "-n", "--", target, *sys.argv[1:]]
    try:
        os.execv(SUDO_WRAPPER, argv)
    except OSError as exc:
        emit_error("sudo", f"failed to exec sudo: {exc}")


class JsonArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        emit_error("usage", message, exit_code=2)


def build_parser() -> JsonArgumentParser:
    parser: JsonArgumentParser = JsonArgumentParser(
        prog="homelabctl",
        description="Agent-only interface for homelab service operations and deploy.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    status: argparse.ArgumentParser = subparsers.add_parser("status")
    status.add_argument("unit")

    restart: argparse.ArgumentParser = subparsers.add_parser("restart")
    restart.add_argument("unit")

    logs: argparse.ArgumentParser = subparsers.add_parser("logs")
    logs.add_argument("unit")
    logs.add_argument("--since", default=DEFAULT_LOG_SINCE)
    logs.add_argument("--until", default=None)
    logs.add_argument("--grep", default=None)

    deploy: argparse.ArgumentParser = subparsers.add_parser("deploy")
    deploy.add_argument("--pull", action="store_true")
    return parser


def dispatch(args: argparse.Namespace) -> NoReturn:
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
        emit_error("usage", f"unknown command {command!r}", exit_code=2)


def main(argv: Sequence[str] | None = None) -> NoReturn:
    maybe_reexec_with_sudo()
    parser: JsonArgumentParser = build_parser()
    args: argparse.Namespace = parser.parse_args(list(argv) if argv is not None else None)
    dispatch(args)


if __name__ == "__main__":
    main()
