"""Prove homelabctl's unit gate with Z3, from the bytecode of denied_reason.

Exit 0: the promise holds for every service name and every command string.
Exit 1: the running code breaks the promise. The message is a counterexample.
Exit 2: this proof no longer describes the code (or Z3 did not decide).

The promise constants below are the property, not a second copy of the
denylist to keep in sync. Do not edit them so a failing run turns green.
Change them only when the promise itself has changed on purpose.
"""

from __future__ import annotations

import ast
import dis
import itertools
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "configurations" / "homelab" / "homelabctl"))

import homelabctl  # noqa: E402

import z3  # noqa: E402


# Promise. Independent of homelabctl's constants.
PROMISE_POWER_UNITS = frozenset({"reboot", "poweroff", "halt", "kexec"})
PROMISE_OPENCLAW_PREFIX = "openclaw"
PROMISE_GATEWAY_UNIT = "openclaw-gateway"
PROMISE_RESTART_COMMAND = "restart"
PROMISE_UNIT_PATTERN = r"^[A-Za-z0-9][A-Za-z0-9_.:@-]*$"
PROMISE_SERVICE_SUFFIX = ".service"

UNIT_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.:@-"
UNIT_FIRST = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
SOURCE_PATH = ROOT / "configurations" / "homelab" / "homelabctl" / "homelabctl.py"


class VerificationGap(Exception):
    """The proof does not describe the current functions."""


class PropertyFailed(Exception):
    """The running code breaks the promise."""


@dataclass(frozen=True)
class Unit:
    pass


@dataclass(frozen=True)
class Command:
    pass


@dataclass(frozen=True)
class Lowered:
    pass


@dataclass(frozen=True)
class Message:
    pass


@dataclass(frozen=True)
class Piece:
    pass


@dataclass(frozen=True)
class Const:
    value: object


@dataclass(frozen=True)
class Global:
    name: str
    value: object


@dataclass(frozen=True)
class Attr:
    owner: object
    name: str


@dataclass(frozen=True)
class ContainsLower:
    names: frozenset[str]


@dataclass(frozen=True)
class ContainsExact:
    names: frozenset[str]


@dataclass(frozen=True)
class StartsWithLower:
    prefix: str


@dataclass(frozen=True)
class StartsWithExact:
    prefix: str


@dataclass(frozen=True)
class EqLower:
    text: str


@dataclass(frozen=True)
class EqExact:
    text: str


@dataclass(frozen=True)
class EqCommand:
    text: str


Constraint = (
    ContainsLower
    | ContainsExact
    | StartsWithLower
    | StartsWithExact
    | EqLower
    | EqExact
    | EqCommand
)


@dataclass(frozen=True)
class Path:
    branches: tuple[tuple[bool, Constraint], ...]
    allows: bool


def promise_allows(unit: str, command: str) -> bool:
    """True when the promise says denied_reason must return None."""
    lowered = unit.lower()
    if lowered in PROMISE_POWER_UNITS:
        return False
    if lowered.startswith(PROMISE_OPENCLAW_PREFIX) and not (
        command == PROMISE_RESTART_COMMAND and lowered == PROMISE_GATEWAY_UNIT
    ):
        return False
    return True


def explain(unit: str, command: str, *, code_allows: bool) -> str:
    lowered = unit.lower()
    if code_allows:
        if lowered in PROMISE_POWER_UNITS:
            why = f"{unit!r} case-folds to the power unit {lowered!r}"
            harm = (
                "The OpenClaw agent can run homelabctl as root without a password, "
                "so it could stop or reboot the homelab."
            )
        elif lowered == PROMISE_GATEWAY_UNIT:
            why = (
                f"the verb is {command!r}, and only restart of "
                f"{PROMISE_GATEWAY_UNIT!r} is the openclaw exception"
            )
            harm = (
                "The agent could read the gateway's status or journal, which the "
                "denylist keeps closed."
            )
        elif lowered.startswith(PROMISE_OPENCLAW_PREFIX):
            why = (
                f"{unit!r} case-folds to a name that starts with "
                f"{PROMISE_OPENCLAW_PREFIX!r} and is not the gateway restart exception"
            )
            harm = (
                "The agent could status, restart, or read logs for another OpenClaw unit as root."
            )
        else:
            why = "the promise does not allow that bare name for that verb"
            harm = "The agent could operate a unit the denylist is there to block."
        return (
            f"homelabctl would allow a unit the promise forbids.\n"
            f"1. denied_reason({unit!r}, command={command!r}) returns None.\n"
            f"2. require_unit would hand that bare name to the verb.\n"
            f"3. The verb would call systemctl or journalctl on "
            f"{unit + PROMISE_SERVICE_SUFFIX!r}.\n"
            f"That breaks the promise because {why}.\n"
            f"{harm}"
        )
    if lowered == PROMISE_GATEWAY_UNIT and command == PROMISE_RESTART_COMMAND:
        why = "restart of openclaw-gateway is the one openclaw exception, so the gateway can reload its config"
        harm = "The agent could not restart openclaw-gateway, so a new openclaw.json would not load."
    else:
        why = "an ordinary service name has to stay operable"
        harm = "The agent could not status, restart, or read logs for an ordinary service."
    return (
        f"homelabctl would refuse a unit the promise allows.\n"
        f"1. denied_reason({unit!r}, command={command!r}) returns a denial.\n"
        f"2. require_unit would stop the verb before systemctl or journalctl.\n"
        f"That breaks the promise because {why}.\n"
        f"{harm}"
    )


def _string_atom(value: object) -> str:
    if isinstance(value, Const) and isinstance(value.value, str):
        return value.value
    if isinstance(value, Global) and isinstance(value.value, str):
        return value.value
    raise VerificationGap(f"expected a string constant or global, found {value!r}")


def _name_set(value: object) -> frozenset[str]:
    if isinstance(value, Global) and isinstance(value.value, frozenset):
        names = value.value
        if all(isinstance(name, str) for name in names):
            return frozenset(names)
    raise VerificationGap(f"expected a frozenset of unit names, found {value!r}")


def walk_denied_reason(fn: object) -> list[Path]:
    """Turn denied_reason's bytecode into path conditions. One path is one return."""
    instrs = list(dis.get_instructions(fn))
    by_offset = {ins.offset: index for index, ins in enumerate(instrs)}
    globals_ = fn.__globals__  # type: ignore[attr-defined]
    paths: list[Path] = []
    # stack items and locals are small tags. branches is the conjunction so far.
    work: list[tuple[int, list[object], dict[str, object], tuple[tuple[bool, Constraint], ...]]] = [
        (0, [], {"unit": Unit(), "command": Command()}, ())
    ]
    steps = 0
    while work:
        steps += 1
        if steps > 10000 or len(paths) > 32:
            raise VerificationGap(
                "denied_reason is too large for this interpreter. "
                "The denylist proof does not cover the new control flow."
            )
        index, stack, locs, branches = work.pop()
        if index >= len(instrs):
            raise VerificationGap("denied_reason fell off the end without returning")
        ins = instrs[index]
        op = ins.opname

        if op in {"RESUME", "CACHE", "NOP"}:
            work.append((index + 1, stack, locs, branches))
        elif op == "LOAD_FAST":
            if ins.argval not in locs:
                raise VerificationGap(f"denied_reason loads {ins.argval!r} before it is stored")
            work.append((index + 1, [*stack, locs[ins.argval]], locs, branches))
        elif op == "LOAD_CONST":
            work.append((index + 1, [*stack, Const(ins.argval)], locs, branches))
        elif op == "LOAD_GLOBAL":
            name = ins.argval
            if name not in globals_:
                raise VerificationGap(f"denied_reason loads unknown global {name!r}")
            work.append((index + 1, [*stack, Global(name, globals_[name])], locs, branches))
        elif op == "LOAD_ATTR":
            if not stack:
                raise VerificationGap("LOAD_ATTR on an empty stack in denied_reason")
            work.append((index + 1, [*stack[:-1], Attr(stack[-1], ins.argval)], locs, branches))
        elif op == "STORE_FAST":
            if not stack:
                raise VerificationGap("STORE_FAST on an empty stack in denied_reason")
            updated = dict(locs)
            updated[ins.argval] = stack[-1]
            work.append((index + 1, stack[:-1], updated, branches))
        elif op == "CALL":
            argc = ins.arg
            if argc is None or len(stack) < argc + 1:
                raise VerificationGap(f"CALL at offset {ins.offset} does not match the stack")
            args = stack[-argc:]
            callee = stack[-(argc + 1)]
            base = stack[: -(argc + 1)]
            if isinstance(callee, Attr) and callee.name == "lower" and argc == 0:
                if not isinstance(callee.owner, Unit):
                    raise VerificationGap("denied_reason calls .lower() on something other than the unit")
                result: object = Lowered()
            elif isinstance(callee, Attr) and callee.name == "startswith" and argc == 1:
                prefix = _string_atom(args[0])
                if isinstance(callee.owner, Lowered):
                    result = StartsWithLower(prefix)
                elif isinstance(callee.owner, Unit):
                    result = StartsWithExact(prefix)
                else:
                    raise VerificationGap("startswith is used on something other than the unit or its lower form")
            else:
                raise VerificationGap(
                    f"denied_reason calls {callee!r} at offset {ins.offset}, which this proof does not interpret. "
                    "Update the interpreter from the bytecode, then rerun."
                )
            work.append((index + 1, [*base, result], locs, branches))
        elif op == "CONTAINS_OP":
            if ins.arg != 0 or len(stack) < 2:
                raise VerificationGap(f"CONTAINS_OP at offset {ins.offset} is not an `in` test")
            item, container = stack[-2], stack[-1]
            names = _name_set(container)
            if isinstance(item, Lowered):
                result = ContainsLower(names)
            elif isinstance(item, Unit):
                result = ContainsExact(names)
            else:
                raise VerificationGap("the denylist membership test does not use the unit name")
            work.append((index + 1, [*stack[:-2], result], locs, branches))
        elif op == "COMPARE_OP":
            if str(ins.argval) != "==" or len(stack) < 2:
                raise VerificationGap(f"COMPARE_OP at offset {ins.offset} is not ==")
            left, right = stack[-2], stack[-1]
            if isinstance(left, Command):
                result = EqCommand(_string_atom(right))
            elif isinstance(left, Lowered):
                result = EqLower(_string_atom(right))
            elif isinstance(left, Unit):
                result = EqExact(_string_atom(right))
            else:
                raise VerificationGap(
                    f"denied_reason compares {left!r} at offset {ins.offset}, which this proof does not interpret"
                )
            work.append((index + 1, [*stack[:-2], result], locs, branches))
        elif op == "TO_BOOL":
            if not stack or not isinstance(stack[-1], Constraint):
                raise VerificationGap(f"TO_BOOL at offset {ins.offset} is not a denylist test")
            work.append((index + 1, stack, locs, branches))
        elif op == "POP_JUMP_IF_FALSE":
            if not stack or not isinstance(stack[-1], Constraint):
                raise VerificationGap(f"jump at offset {ins.offset} does not test a denylist condition")
            if ins.jump_target is None or ins.jump_target not in by_offset:
                raise VerificationGap(f"jump at offset {ins.offset} has no target")
            if by_offset[ins.jump_target] <= index:
                raise VerificationGap("denied_reason jumps backward; this proof only covers forward branches")
            constraint = stack[-1]
            rest = stack[:-1]
            work.append((index + 1, rest, locs, branches + ((True, constraint),)))
            work.append(
                (by_offset[ins.jump_target], rest, dict(locs), branches + ((False, constraint),))
            )
        elif op == "FORMAT_SIMPLE" or op == "CONVERT_VALUE":
            if not stack:
                raise VerificationGap(f"{op} on an empty stack in denied_reason")
            work.append((index + 1, [*stack[:-1], Piece()], locs, branches))
        elif op == "BUILD_STRING":
            count = ins.arg or 0
            if len(stack) < count:
                raise VerificationGap("BUILD_STRING underflows in denied_reason")
            work.append((index + 1, [*stack[:-count], Message()], locs, branches))
        elif op == "RETURN_VALUE":
            if not stack:
                raise VerificationGap("RETURN_VALUE on an empty stack in denied_reason")
            paths.append(Path(branches, _allows(stack[-1], ins.offset)))
        elif op == "RETURN_CONST":
            paths.append(Path(branches, _allows(Const(ins.argval), ins.offset)))
        else:
            raise VerificationGap(
                f"denied_reason uses {op} at offset {ins.offset}, which this proof does not interpret. "
                "Update the interpreter from the bytecode, then rerun."
            )
    if not paths:
        raise VerificationGap("denied_reason has no return path")
    return paths


def _allows(value: object, offset: int) -> bool:
    if value is None or (isinstance(value, Const) and value.value is None):
        return True
    if isinstance(value, Message):
        return False
    raise VerificationGap(
        f"denied_reason returns {value!r} at offset {offset}. "
        "This proof only understands a denial message or None."
    )


def _holds(constraint: Constraint, unit: str, command: str) -> bool:
    lowered = unit.lower()
    if isinstance(constraint, ContainsLower):
        return lowered in constraint.names
    if isinstance(constraint, ContainsExact):
        return unit in constraint.names
    if isinstance(constraint, StartsWithLower):
        return lowered.startswith(constraint.prefix)
    if isinstance(constraint, StartsWithExact):
        return unit.startswith(constraint.prefix)
    if isinstance(constraint, EqLower):
        return lowered == constraint.text
    if isinstance(constraint, EqExact):
        return unit == constraint.text
    if isinstance(constraint, EqCommand):
        return command == constraint.text
    raise VerificationGap(f"unknown constraint {constraint!r}")


def walker_allows(paths: list[Path], unit: str, command: str) -> bool:
    matched: list[bool] = []
    for path in paths:
        if all(_holds(constraint, unit, command) is truth for truth, constraint in path.branches):
            matched.append(path.allows)
    if len(matched) != 1:
        raise VerificationGap(
            f"the path conditions for denied_reason({unit!r}, command={command!r}) "
            f"matched {len(matched)} paths, not one"
        )
    return matched[0]


def _char_eq_lower(cell: z3.SeqRef, ch: str) -> z3.BoolRef:
    """cell.lower() == ch, for one character, over the unit-name alphabet."""
    if "A" <= ch <= "Z":
        # lower() never produces an uppercase ASCII letter.
        return z3.BoolVal(False)
    if "a" <= ch <= "z":
        return z3.Or(cell == z3.StringVal(ch), cell == z3.StringVal(ch.upper()))
    return cell == z3.StringVal(ch)


def _lowered_equals(unit: z3.SeqRef, text: str) -> z3.BoolRef:
    parts: list[z3.BoolRef] = [z3.Length(unit) == z3.IntVal(len(text))]
    for index, ch in enumerate(text):
        parts.append(_char_eq_lower(z3.SubString(unit, index, 1), ch))
    return z3.And(*parts)


def _lowered_has_prefix(unit: z3.SeqRef, prefix: str) -> z3.BoolRef:
    parts: list[z3.BoolRef] = [z3.Length(unit) >= z3.IntVal(len(prefix))]
    for index, ch in enumerate(prefix):
        parts.append(_char_eq_lower(z3.SubString(unit, index, 1), ch))
    return z3.And(*parts)


def _exact_equals(unit: z3.SeqRef, text: str) -> z3.BoolRef:
    return unit == z3.StringVal(text)


def _constraint_z3(constraint: Constraint, unit: z3.SeqRef, command: z3.SeqRef) -> z3.BoolRef:
    if isinstance(constraint, ContainsLower):
        if not constraint.names:
            return z3.BoolVal(False)
        return z3.Or([_lowered_equals(unit, name) for name in sorted(constraint.names)])
    if isinstance(constraint, ContainsExact):
        if not constraint.names:
            return z3.BoolVal(False)
        return z3.Or([_exact_equals(unit, name) for name in sorted(constraint.names)])
    if isinstance(constraint, StartsWithLower):
        return _lowered_has_prefix(unit, constraint.prefix)
    if isinstance(constraint, StartsWithExact):
        return z3.And(
            z3.Length(unit) >= z3.IntVal(len(constraint.prefix)),
            z3.SubString(unit, 0, len(constraint.prefix)) == z3.StringVal(constraint.prefix),
        )
    if isinstance(constraint, EqLower):
        return _lowered_equals(unit, constraint.text)
    if isinstance(constraint, EqExact):
        return _exact_equals(unit, constraint.text)
    if isinstance(constraint, EqCommand):
        return command == z3.StringVal(constraint.text)
    raise VerificationGap(f"unknown constraint {constraint!r}")


def _path_z3(path: Path, unit: z3.SeqRef, command: z3.SeqRef) -> z3.BoolRef:
    parts = [
        expr if truth else z3.Not(expr)
        for truth, constraint in path.branches
        for expr in [_constraint_z3(constraint, unit, command)]
    ]
    if not parts:
        return z3.BoolVal(True)
    return z3.And(*parts)


def code_allows_z3(paths: list[Path], unit: z3.SeqRef, command: z3.SeqRef) -> z3.BoolRef:
    allowed = [_path_z3(path, unit, command) for path in paths if path.allows]
    if not allowed:
        return z3.BoolVal(False)
    return z3.Or(*allowed)


def promise_allows_z3(unit: z3.SeqRef, command: z3.SeqRef) -> z3.BoolRef:
    power = z3.Or([_lowered_equals(unit, name) for name in sorted(PROMISE_POWER_UNITS)])
    openclaw = z3.And(
        _lowered_has_prefix(unit, PROMISE_OPENCLAW_PREFIX),
        z3.Not(
            z3.And(
                command == z3.StringVal(PROMISE_RESTART_COMMAND),
                _lowered_equals(unit, PROMISE_GATEWAY_UNIT),
            )
        ),
    )
    return z3.Not(z3.Or(power, openclaw))


def unit_language() -> z3.ReRef:
    letters = z3.Union(z3.Range("A", "Z"), z3.Range("a", "z"), z3.Range("0", "9"))
    rest = z3.Union(letters, z3.Re("_"), z3.Re("."), z3.Re(":"), z3.Re("@"), z3.Re("-"))
    return z3.Concat(letters, z3.Star(rest))


def _check_sat(solver: z3.Solver, what: str) -> z3.CheckSatResult:
    result = solver.check()
    if result == z3.unknown:
        raise VerificationGap(f"Z3 returned unknown while checking {what}: {solver.reason_unknown()}")
    return result


def prove_denied_reason(paths: list[Path]) -> None:
    unit = z3.String("unit")
    command = z3.String("command")
    code_allows = code_allows_z3(paths, unit, command)
    promise = promise_allows_z3(unit, command)
    language = unit_language()

    covered = z3.Solver()
    covered.set("timeout", 60000)
    covered.add(z3.Not(z3.Or([_path_z3(path, unit, command) for path in paths])))
    if _check_sat(covered, "that the bytecode paths cover every string") != z3.unsat:
        raise VerificationGap(
            "the bytecode paths do not cover every unit and command. "
            "The interpreter dropped a return path."
        )

    def disagree(limit_to_verbs: bool) -> z3.Solver | None:
        solver = z3.Solver()
        solver.set("timeout", 60000)
        solver.add(z3.InRe(unit, language))
        solver.add(code_allows != promise)
        if limit_to_verbs:
            solver.add(
                z3.Or(
                    [
                        command == z3.StringVal(verb)
                        for verb in ("status", "restart", "logs")
                    ]
                )
            )
        if _check_sat(solver, "the denylist against the promise") == z3.unsat:
            return None
        return solver

    # A counterexample on a real verb is easier to read. The second query is every command string.
    solver = disagree(True)
    if solver is None:
        solver = disagree(False)
    if solver is None:
        return
    model = solver.model()
    found_unit = model.eval(unit, model_completion=True).as_string()
    found_command = model.eval(command, model_completion=True).as_string()
    real_allows = homelabctl.denied_reason(found_unit, command=found_command) is None
    interpreted = walker_allows(paths, found_unit, found_command)
    promised = promise_allows(found_unit, found_command)
    if real_allows == promised:
        raise VerificationGap(
            "Z3 found "
            f"denied_reason({found_unit!r}, command={found_command!r}) "
            "disagreeing with the promise, but the running function does not. "
            f"The interpreter said allows={interpreted}; the function said allows={real_allows}. "
            "The interpreter is wrong. Fix it from the bytecode. Do not change the promise."
        )
    raise PropertyFailed(explain(found_unit, found_command, code_allows=real_allows))


def conformance(paths: list[Path]) -> None:
    """The interpreter must match the running function on a finite set. This is not the proof."""
    commands = (
        PROMISE_RESTART_COMMAND,
        "status",
        "logs",
        "",
        "Restart",
        "deploy",
    )
    names: list[str] = [""]
    names.extend(UNIT_FIRST)
    names.extend(first + rest for first, rest in itertools.product(UNIT_FIRST, UNIT_ALPHABET))
    for stem in (*PROMISE_POWER_UNITS, PROMISE_OPENCLAW_PREFIX, PROMISE_GATEWAY_UNIT):
        names.extend(_case_variants(stem))
        names.extend(stem + ch for ch in UNIT_ALPHABET)
    checked = 0
    for unit, command in itertools.product(names, commands):
        real = homelabctl.denied_reason(unit, command=command) is None
        interpreted = walker_allows(paths, unit, command)
        if interpreted != real:
            raise VerificationGap(
                "the bytecode interpreter does not match denied_reason"
                f"({unit!r}, command={command!r}): interpreter allows={interpreted}, "
                f"function allows={real}. Fix the interpreter. Do not change the promise."
            )
        promised = promise_allows(unit, command)
        if real != promised and _in_unit_language(unit):
            raise PropertyFailed(explain(unit, command, code_allows=real))
        checked += 1
    if checked < 1000:
        raise VerificationGap("the conformance sweep did not run")


def _in_unit_language(unit: str) -> bool:
    return homelabctl.UNIT_NAME_RE.fullmatch(unit) is not None


def _case_variants(text: str) -> list[str]:
    letter_indexes = [index for index, ch in enumerate(text) if ch.isalpha()]
    variants: list[str] = []
    for mask in range(1 << len(letter_indexes)):
        chars = list(text)
        for bit, index in enumerate(letter_indexes):
            ch = chars[index]
            chars[index] = ch.upper() if mask & (1 << bit) else ch.lower()
        variants.append("".join(chars))
    return variants


def _ascii_lower_is_per_character() -> None:
    """ASCII lower on this alphabet is one code point per character, with no special cases."""
    for ch in UNIT_ALPHABET:
        lowered = ch.lower()
        if len(lowered) != 1:
            raise VerificationGap(
                f"{ch!r}.lower() is {lowered!r}, so the per-character case model does not apply"
            )
        if "A" <= ch <= "Z":
            expected = chr(ord(ch) + 32)
        else:
            expected = ch
        if lowered != expected:
            raise VerificationGap(
                f"{ch!r}.lower() is {lowered!r}, not {expected!r}. "
                "The Z3 case model does not match this Python."
            )
    for left, right in itertools.product(UNIT_ALPHABET, repeat=2):
        pair = left + right
        if pair.lower() != left.lower() + right.lower():
            raise VerificationGap(
                f"{pair!r}.lower() is not per character. The Z3 case model does not match this Python."
            )


def parse_module() -> dict[str, ast.FunctionDef]:
    tree = ast.parse(SOURCE_PATH.read_text(), filename=str(SOURCE_PATH))
    return {node.name: node for node in tree.body if isinstance(node, ast.FunctionDef)}


def _stmts(fn: ast.FunctionDef) -> list[ast.stmt]:
    body = fn.body
    if (
        body
        and isinstance(body[0], ast.Expr)
        and isinstance(body[0].value, ast.Constant)
        and isinstance(body[0].value.value, str)
    ):
        return body[1:]
    return body


def _binding(stmt: ast.stmt) -> tuple[str, ast.expr] | None:
    if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name) and stmt.value is not None:
        return stmt.target.id, stmt.value
    if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
        return stmt.targets[0].id, stmt.value
    return None


def _call_name(node: ast.expr) -> str | None:
    if not isinstance(node, ast.Call):
        return None
    if isinstance(node.func, ast.Name):
        return node.func.id
    if isinstance(node.func, ast.Attribute):
        return node.func.attr
    return None


def _kw(call: ast.Call, name: str) -> ast.expr | None:
    for keyword in call.keywords:
        if keyword.arg == name:
            return keyword.value
    return None


def _const_str(node: ast.expr) -> str | None:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    return None


def _enclosing_function(parents: dict[ast.AST, ast.AST], node: ast.AST) -> str | None:
    current: ast.AST | None = node
    while current is not None:
        if isinstance(current, ast.FunctionDef):
            return current.name
        current = parents.get(current)
    return None


def _parents(tree: ast.AST) -> dict[ast.AST, ast.AST]:
    parents: dict[ast.AST, ast.AST] = {}
    for node in ast.walk(tree):
        for child in ast.iter_child_nodes(node):
            parents[child] = node
    return parents


def check_service_unit() -> None:
    instrs = [ins for ins in dis.get_instructions(homelabctl.service_unit) if ins.opname != "RESUME"]
    opnames = [ins.opname for ins in instrs]
    if opnames != ["LOAD_FAST", "FORMAT_SIMPLE", "LOAD_CONST", "BUILD_STRING", "RETURN_VALUE"]:
        raise VerificationGap(
            "service_unit is no longer the f-string that appends a constant suffix. "
            "A unit that passed the denylist might be handed to systemctl under a different name. "
            "Read service_unit and update this check from the bytecode."
        )
    suffix = instrs[2].argval
    if suffix != PROMISE_SERVICE_SUFFIX:
        raise PropertyFailed(
            "service_unit appends "
            f"{suffix!r}, not {PROMISE_SERVICE_SUFFIX!r}. "
            "status, restart, and logs would ask systemd for a different unit than the bare name the denylist saw. "
            "The agent could reach a unit type the gate never checked."
        )
    if any(ins.opname.startswith("POP_JUMP") or ins.opname.startswith("JUMP") for ins in instrs):
        raise VerificationGap("service_unit branches, so appending .service is not true for every name")


def check_normalize_unit() -> None:
    if homelabctl.UNIT_NAME_RE.pattern != PROMISE_UNIT_PATTERN:
        raise VerificationGap(
            "UNIT_NAME_RE is "
            f"{homelabctl.UNIT_NAME_RE.pattern!r}, and this proof only covers "
            f"{PROMISE_UNIT_PATTERN!r}. Names the new pattern accepts are not proved. "
            "Update the Z3 alphabet from the new pattern, then rerun."
        )
    fn = homelabctl.normalize_unit
    instrs = list(dis.get_instructions(fn))
    returns = [ins for ins in instrs if ins.opname in {"RETURN_VALUE", "RETURN_CONST"}]
    if len(returns) != 1 or returns[0].opname != "RETURN_VALUE":
        raise VerificationGap(
            "normalize_unit no longer has a single returned name. "
            "A path may return a name that never matched UNIT_NAME_RE, and the denylist proof would not apply."
        )
    window: list[dis.Instruction] = []
    found = False
    for ins in instrs:
        window.append(ins)
        window = window[-6:]
        if ins.opname != "POP_JUMP_IF_TRUE":
            continue
        opnames = [item.opname for item in window]
        attrs = [item.argval for item in window if item.opname == "LOAD_ATTR"]
        if opnames[-6:] == ["LOAD_GLOBAL", "LOAD_ATTR", "LOAD_FAST", "CALL", "TO_BOOL", "POP_JUMP_IF_TRUE"] and attrs == [
            "fullmatch"
        ]:
            if window[0].argval != "UNIT_NAME_RE":
                continue
            target = ins.jump_target
            if target is None:
                continue
            after = [item for item in instrs if item.offset >= target]
            if (
                len(after) >= 2
                and after[0].opname == "LOAD_FAST"
                and after[1].opname == "RETURN_VALUE"
                and after[0].argval == window[2].argval
            ):
                found = True
                break
    if not found:
        raise VerificationGap(
            "normalize_unit's only return is not the success path of UNIT_NAME_RE.fullmatch. "
            "The denylist proof applies only to names that matched that pattern."
        )
    raised = [ins.argval for ins in instrs if ins.opname == "LOAD_GLOBAL" and ins.argval not in {"any", "UNIT_NAME_RE"}]
    if "ValueError" not in raised:
        raise VerificationGap("normalize_unit no longer raises ValueError for a rejected name")
    if any(name in {"run", "denied_reason", "subprocess"} for name in raised):
        raise VerificationGap("normalize_unit now reaches the denylist or systemctl on its own")


def check_emit(funcs: dict[str, ast.FunctionDef]) -> None:
    emit = _stmts(funcs["emit"])
    last = emit[-1]
    if not (
        isinstance(last, ast.Raise)
        and isinstance(last.exc, ast.Call)
        and _call_name(last.exc) == "SystemExit"
    ):
        raise VerificationGap(
            "emit no longer ends by raising SystemExit. require_unit calls emit_error, which calls emit. "
            "If that returns, a denied unit falls through to require_unit's return and the verb reaches systemctl. "
            "Read emit before trusting the denylist proof."
        )
    if any(isinstance(stmt, ast.Return) for stmt in ast.walk(funcs["emit"])):
        raise VerificationGap("emit contains a return, so a denial might not stop the process")
    error = _stmts(funcs["emit_error"])
    if any(isinstance(node, (ast.Try, ast.Return)) for node in ast.walk(funcs["emit_error"])):
        raise VerificationGap(
            "emit_error catches or returns. A denial might not reach emit's SystemExit, "
            "and require_unit could fall through."
        )
    calls = [_call_name(stmt.value) for stmt in error if isinstance(stmt, ast.Expr)]
    if calls[-1:] != ["emit"]:
        raise VerificationGap("emit_error no longer finishes by calling emit")


def check_require_unit(funcs: dict[str, ast.FunctionDef]) -> None:
    fn = funcs["require_unit"]
    body = _stmts(fn)
    if len(body) < 4 or not isinstance(body[0], ast.Try):
        raise VerificationGap(
            "require_unit no longer starts by trying normalize_unit. "
            "The denylist proof does not apply until the verb's unit is normalized first."
        )
    attempt = body[0]
    binding = _binding(attempt.body[0]) if len(attempt.body) == 1 else None
    if (
        binding is None
        or binding[0] != "unit"
        or not isinstance(binding[1], ast.Call)
        or _call_name(binding[1]) != "normalize_unit"
    ):
        raise VerificationGap(
            "require_unit's try block is not `unit = normalize_unit(raw)`. "
            "A raw name such as reboot.service could be judged before the .service suffix is removed, "
            "and the power-unit denylist would miss it."
        )
    if len(attempt.handlers) != 1 or attempt.orelse or attempt.finalbody:
        raise VerificationGap("require_unit's try/except around normalize_unit changed shape")
    handler = attempt.handlers[0]
    if not (isinstance(handler.type, ast.Name) and handler.type.id == "ValueError"):
        raise VerificationGap("normalize_unit's ValueError is no longer what require_unit catches")
    if not handler.body or _call_name(handler.body[0].value) != "emit_error":  # type: ignore[attr-defined]
        raise VerificationGap("an invalid unit no longer calls emit_error before require_unit continues")
    denial_binding = _binding(body[1])
    if (
        denial_binding is None
        or not isinstance(denial_binding[1], ast.Call)
        or _call_name(denial_binding[1]) != "denied_reason"
    ):
        raise VerificationGap(
            "require_unit does not call denied_reason on the normalized name before it returns. "
            "The Z3 proof of denied_reason would not be what the verb uses."
        )
    denial_call = denial_binding[1]
    assert isinstance(denial_call, ast.Call)
    if not (
        len(denial_call.args) == 1
        and isinstance(denial_call.args[0], ast.Name)
        and denial_call.args[0].id == "unit"
        and isinstance(_kw(denial_call, "command"), ast.Name)
    ):
        raise VerificationGap("denied_reason is not called as denied_reason(unit, command=command)")
    gate = body[2]
    if not isinstance(gate, ast.If):
        raise VerificationGap("require_unit no longer branches on the denial reason")
    test = gate.test
    if not (
        isinstance(test, ast.Compare)
        and isinstance(test.left, ast.Name)
        and test.left.id == denial_binding[0]
        and len(test.ops) == 1
        and isinstance(test.ops[0], ast.IsNot)
        and isinstance(test.comparators[0], ast.Constant)
        and test.comparators[0].value is None
    ):
        raise VerificationGap("require_unit does not test `reason is not None`")
    if not gate.body or not isinstance(gate.body[0], ast.Expr) or _call_name(gate.body[0].value) != "emit_error":
        raise VerificationGap("a denial no longer calls emit_error")
    if gate.orelse:
        raise VerificationGap("require_unit's denial branch has an else, so the return is not the only success path")
    returned = body[3]
    if not (isinstance(returned, ast.Return) and isinstance(returned.value, ast.Name) and returned.value.id == "unit"):
        raise VerificationGap("require_unit does not return the same bare name denied_reason just judged")
    if any(isinstance(node, ast.Call) and _call_name(node) == "run" for node in ast.walk(fn)):
        raise VerificationGap("require_unit calls run. systemctl would be inside the gate instead of behind it.")


def _require_call(node: ast.expr, raw_name: str, command: str) -> bool:
    if not isinstance(node, ast.Call) or _call_name(node) != "require_unit":
        return False
    if len(node.args) != 1 or not isinstance(node.args[0], ast.Name) or node.args[0].id != raw_name:
        return False
    verb = _kw(node, "command")
    return isinstance(verb, ast.Constant) and verb.value == command


def _only_raw_use_is_require(fn: ast.FunctionDef, raw_name: str) -> None:
    parents = _parents(fn)
    for node in ast.walk(fn):
        if not (isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id == raw_name):
            continue
        call = parents.get(node)
        if not (isinstance(call, ast.Call) and _call_name(call) == "require_unit" and node in call.args):
            raise VerificationGap(
                f"{fn.name} uses the raw unit {raw_name!r} outside require_unit. "
                "systemctl or journalctl could see a name the denylist did not judge."
            )


def check_read_status(funcs: dict[str, ast.FunctionDef]) -> None:
    fn = funcs["read_status"]
    body = _stmts(fn)
    name_binding = _binding(body[0]) if body else None
    if (
        name_binding is None
        or name_binding[0] != "name"
        or not isinstance(name_binding[1], ast.Call)
        or _call_name(name_binding[1]) != "service_unit"
        or not name_binding[1].args
        or not isinstance(name_binding[1].args[0], ast.Name)
        or name_binding[1].args[0].id != "unit"
    ):
        raise VerificationGap("read_status no longer starts with name = service_unit(unit)")
    run_call = _first_run(fn)
    argv = _run_list(run_call)
    if [_const_str(argv[0]), _const_str(argv[1])] != ["systemctl", "show"] or not isinstance(argv[2], ast.Name):
        raise VerificationGap("read_status does not call systemctl show on the service_unit name")
    if argv[2].id != "name":
        raise VerificationGap("read_status passes something other than service_unit(unit) to systemctl show")


def _first_run(fn: ast.FunctionDef) -> ast.Call:
    for node in ast.walk(fn):
        if isinstance(node, ast.Call) and _call_name(node) == "run":
            return node
    raise VerificationGap(f"{fn.name} no longer calls run")


def _run_list(call: ast.Call) -> list[ast.expr]:
    if len(call.args) != 1 or not isinstance(call.args[0], ast.List):
        raise VerificationGap("a systemctl or journalctl run is not a list literal, so this check cannot see its arguments")
    return call.args[0].elts


def check_verbs(funcs: dict[str, ast.FunctionDef]) -> None:
    status = _stmts(funcs["cmd_status"])
    if len(status) != 1 or not isinstance(status[0], ast.Expr):
        raise VerificationGap("cmd_status is no longer a single call. Trace where systemctl is reached.")
    emit_call = status[0].value
    if not isinstance(emit_call, ast.Call) or _call_name(emit_call) != "emit" or not emit_call.args:
        raise VerificationGap("cmd_status does not emit the status payload")
    read_call = emit_call.args[0]
    if not isinstance(read_call, ast.Call) or _call_name(read_call) != "read_status" or not read_call.args:
        raise VerificationGap("cmd_status does not pass require_unit straight into read_status")
    if not _require_call(read_call.args[0], "unit_raw", "status"):
        raise VerificationGap("cmd_status does not call require_unit(unit_raw, command='status') before systemctl")
    _only_raw_use_is_require(funcs["cmd_status"], "unit_raw")

    restart = _stmts(funcs["cmd_restart"])
    first = _binding(restart[0]) if restart else None
    second = _binding(restart[1]) if len(restart) > 1 else None
    if first is None or not _require_call(first[1], "unit_raw", "restart") or first[0] != "unit":
        raise VerificationGap("cmd_restart does not start with unit = require_unit(unit_raw, command='restart')")
    if (
        second is None
        or second[0] != "name"
        or not isinstance(second[1], ast.Call)
        or _call_name(second[1]) != "service_unit"
        or not second[1].args
        or not isinstance(second[1].args[0], ast.Name)
        or second[1].args[0].id != "unit"
    ):
        raise VerificationGap("cmd_restart does not set name = service_unit(unit) before systemctl")
    argv = _run_list(_first_run(funcs["cmd_restart"]))
    if [_const_str(argv[0]), _const_str(argv[1])] != ["systemctl", "restart"] or not isinstance(argv[2], ast.Name) or argv[2].id != "name":
        raise VerificationGap("cmd_restart does not call systemctl restart on service_unit(unit)")
    _only_raw_use_is_require(funcs["cmd_restart"], "unit_raw")
    read_sites = [
        node
        for node in ast.walk(funcs["cmd_restart"])
        if isinstance(node, ast.Call) and _call_name(node) == "read_status"
    ]
    if len(read_sites) != 1 or not read_sites[0].args or not isinstance(read_sites[0].args[0], ast.Name) or read_sites[0].args[0].id != "unit":
        raise VerificationGap("cmd_restart's post-restart status does not use the unit require_unit returned")

    logs = _stmts(funcs["cmd_logs"])
    log_unit = _binding(logs[0]) if logs else None
    log_name = _binding(logs[1]) if len(logs) > 1 else None
    if log_unit is None or not _require_call(log_unit[1], "unit_raw", "logs") or log_unit[0] != "unit":
        raise VerificationGap("cmd_logs does not start with unit = require_unit(unit_raw, command='logs')")
    if (
        log_name is None
        or log_name[0] != "name"
        or not isinstance(log_name[1], ast.Call)
        or _call_name(log_name[1]) != "service_unit"
    ):
        raise VerificationGap("cmd_logs does not set name = service_unit(unit) before journalctl")
    argv_binding = _binding(logs[2]) if len(logs) > 2 else None
    if argv_binding is None or argv_binding[0] != "argv" or not isinstance(argv_binding[1], ast.List):
        raise VerificationGap("cmd_logs does not build the journalctl argument list after the gate")
    elements = argv_binding[1].elts
    if not elements or _const_str(elements[0]) != "journalctl":
        raise VerificationGap("cmd_logs does not start its command with journalctl")
    if not any(isinstance(elt, ast.Name) and elt.id == "name" for elt in elements):
        raise VerificationGap("cmd_logs does not pass service_unit(unit) to journalctl --unit")
    run_calls = [node for node in ast.walk(funcs["cmd_logs"]) if isinstance(node, ast.Call) and _call_name(node) == "run"]
    if len(run_calls) != 1 or not run_calls[0].args or not isinstance(run_calls[0].args[0], ast.Name) or run_calls[0].args[0].id != "argv":
        raise VerificationGap("cmd_logs does not run the argv list it built after require_unit")
    _only_raw_use_is_require(funcs["cmd_logs"], "unit_raw")

    tree = ast.parse(SOURCE_PATH.read_text(), filename=str(SOURCE_PATH))
    parents = _parents(tree)
    run_funcs: set[str] = set()
    systemctl_funcs: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "run":
            name = _enclosing_function(parents, node)
            if name is not None:
                run_funcs.add(name)
        if isinstance(node, ast.Constant) and node.value in {"systemctl", "journalctl"}:
            # Error codes and messages also contain these words. Only an argument list can start a command.
            if not isinstance(parents.get(node), ast.List):
                continue
            name = _enclosing_function(parents, node)
            if name is not None:
                systemctl_funcs.add(name)
    if run_funcs != {"read_status", "cmd_restart", "cmd_logs", "cmd_deploy"}:
        raise VerificationGap(
            "run() is now called from "
            f"{sorted(run_funcs)}. The proof only puts systemctl and journalctl behind the gate in "
            "read_status, cmd_restart, and cmd_logs. cmd_deploy is the rebuild path and takes no unit."
        )
    if systemctl_funcs != {"read_status", "cmd_restart", "cmd_logs"}:
        raise VerificationGap(
            "systemctl or journalctl is named in "
            f"{sorted(systemctl_funcs)}. The proof only covers read_status, cmd_restart, and cmd_logs."
        )
    deploy_args = [arg.arg for arg in funcs["cmd_deploy"].args.args]
    if deploy_args != ["pull"]:
        raise VerificationGap(
            f"cmd_deploy parameters are {deploy_args}, not just pull. "
            "A new unit argument would be outside this proof."
        )


def check_lower_assumption() -> None:
    _ascii_lower_is_per_character()


def main() -> int:
    try:
        if not SOURCE_PATH.is_file():
            raise VerificationGap(f"missing {SOURCE_PATH}")
        check_lower_assumption()
        funcs = parse_module()
        for name in (
            "normalize_unit",
            "denied_reason",
            "require_unit",
            "service_unit",
            "emit",
            "emit_error",
            "read_status",
            "cmd_status",
            "cmd_restart",
            "cmd_logs",
            "cmd_deploy",
        ):
            if name not in funcs:
                raise VerificationGap(f"{SOURCE_PATH.name} no longer defines {name}")
        check_service_unit()
        check_normalize_unit()
        check_emit(funcs)
        check_require_unit(funcs)
        check_read_status(funcs)
        check_verbs(funcs)
        paths = walk_denied_reason(homelabctl.denied_reason)
        conformance(paths)
        prove_denied_reason(paths)
    except VerificationGap as exc:
        print(
            "stopped: the homelabctl unit-gate proof does not describe the current code.\n"
            f"{exc}\n"
            "Update the verification from the code, then run it again. "
            "A refusal here is not a passing gate. If the new code can hand a forbidden unit to "
            "systemctl or journalctl, that is a bug in homelabctl; do not weaken the promise to hide it.",
            file=sys.stderr,
        )
        return 2
    except PropertyFailed as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(
        "pass: homelabctl's unit gate holds.\n"
        f"Z3 {z3.get_version_string()} found no service name matching {PROMISE_UNIT_PATTERN} "
        "and no command string for which denied_reason disagrees with the promise: "
        "reboot, poweroff, halt, and kexec are refused for every verb; "
        f"every name that case-folds to a {PROMISE_OPENCLAW_PREFIX!r} prefix is refused "
        f"except restart of {PROMISE_GATEWAY_UNIT!r}.\n"
        "normalize_unit only returns a name that matched that pattern. "
        "require_unit judges that bare name and emit raises SystemExit on a refusal, "
        "before status, restart, or logs can call systemctl or journalctl. "
        "service_unit appends .service on that same bare name."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
