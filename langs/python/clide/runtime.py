"""Clide runtime argument parser"""

from typing import List, Tuple, Dict
from .spec import Spec, Command, Item, Group, Atom, Lit, OptBool, OptVal, Pos, Type


class ArgError(Exception):
    """Error during argument parsing"""
    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)


class ParseResult:
    """Result of parsing command-line arguments"""
    def __init__(self, command: str, options: List[Tuple[str, List[str]]],
                 positionals: List[Tuple[str, str]], leftovers: List[str]):
        self.command = command
        self.options = options
        self.positionals = positionals
        self.leftovers = leftovers

    def __eq__(self, other):
        return (isinstance(other, ParseResult) and
                self.command == other.command and
                self.options == other.options and
                self.positionals == other.positionals and
                self.leftovers == other.leftovers)

    def __repr__(self):
        return (f"ParseResult(command={self.command}, options={self.options}, "
                f"positionals={self.positionals}, leftovers={self.leftovers})")


def choose_command(spec: Spec, argv: List[str]) -> Command:
    """Choose which command to use based on argv"""
    if not argv:
        return spec.commands[0]

    first_arg = argv[0]

    for cmd in spec.commands:
        lit = first_literal(cmd)
        if lit == first_arg:
            return cmd

    return spec.commands[0]


def first_literal(cmd: Command) -> str:
    """Get the first literal atom from a command"""
    for item in cmd.items:
        if item.required:
            atoms = item.group.atoms_list()
            if len(atoms) == 1 and isinstance(atoms[0], Lit):
                return atoms[0].value
            elif len(atoms) > 1:
                for atom in atoms:
                    if isinstance(atom, Lit):
                        return atom.value
    return None


def parse_with(cmd: Command, argv: List[str]) -> ParseResult:
    """Parse arguments according to a command specification"""
    seq: List[Tuple[bool, Group]] = []
    for item in cmd.items:
        seq.append((not item.required, item.group))

    atoms: List[Atom] = []
    for _, group in seq:
        atoms.extend(group.atoms_list())

    # Build list of known options
    known_opts: List[str] = []
    for atom in atoms:
        if isinstance(atom, OptBool):
            if atom.long:
                known_opts.append(atom.long)
            if atom.short:
                known_opts.append(atom.short)
        elif isinstance(atom, OptVal):
            if atom.long:
                known_opts.append(atom.long)
            if atom.short:
                known_opts.append(atom.short)

    # Build list of positionals
    pos_list: List[Tuple[str, Type, str]] = []
    for atom in atoms:
        if isinstance(atom, Pos):
            pos_list.append((atom.name, atom.ty, atom.default))

    opts_map: List[Tuple[str, List[str]]] = []
    pos_map: List[Tuple[str, str]] = []
    seen_pos = 0
    leftovers: List[str] = []

    args = argv[:]
    i = 0

    while i < len(args):
        arg = args[i]

        if arg == "--":
            # Handle remaining positionals
            remaining_pos = pos_list[seen_pos:]
            rest = args[i + 1:]

            for j, (name, ty, default) in enumerate(remaining_pos):
                if j < len(rest):
                    val = parse_val(ty, rest[j])
                    pos_map.append((name, val))
                    seen_pos += 1
                elif default is not None:
                    val = parse_val(ty, default)
                    pos_map.append((name, val))
                    seen_pos += 1
                else:
                    raise ArgError(f"Missing positional: {name}")

            leftovers = rest[len(remaining_pos):]
            break
        elif arg.startswith('-'):
            if '=' in arg:
                pos = arg.find('=')
                name_part = arg[:pos]
                val_part = arg[pos + 1:]
            else:
                name_part = arg
                val_part = None

            if name_part not in known_opts:
                raise ArgError(f"Unknown option: {name_part}")

            # Find the option declaration
            opt_decl = None
            for atom in atoms:
                if isinstance(atom, OptVal):
                    if atom.long == name_part or atom.short == name_part:
                        opt_decl = atom
                        break
                elif isinstance(atom, OptBool):
                    if atom.long == name_part or atom.short == name_part:
                        opt_decl = atom
                        break

            if opt_decl is None:
                raise ArgError("Unknown option declaration")

            if isinstance(opt_decl, OptBool):
                add_opt(opts_map, name_part, "true")
                i += 1
            elif isinstance(opt_decl, OptVal):
                if val_part is not None:
                    val = parse_val(opt_decl.ty, val_part)
                else:
                    if i + 1 < len(args):
                        i += 1
                        val = parse_val(opt_decl.ty, args[i])
                    else:
                        raise ArgError(f"Missing value for {name_part}")
                add_opt(opts_map, name_part, val)
                i += 1
        else:
            # Try to consume as literal
            consumed = False
            for req, group in seq:
                if not req:  # optional
                    atoms_list = group.atoms_list()
                    if len(atoms_list) == 1 and isinstance(atoms_list[0], Lit):
                        if atoms_list[0].value == arg:
                            consumed = True
                            break
                    elif len(atoms_list) > 1:
                        if any(isinstance(a, Lit) and a.value == arg for a in atoms_list):
                            consumed = True
                            break

            if consumed:
                i += 1
                continue

            # Treat as positional
            if seen_pos >= len(pos_list):
                raise ArgError(f"Unexpected argument: {arg}")

            name, ty, _ = pos_list[seen_pos]
            val = parse_val(ty, arg)
            pos_map.append((name, val))
            seen_pos += 1
            i += 1

    # Add option defaults
    for atom in atoms:
        if isinstance(atom, OptVal):
            key = atom.long or atom.short
            if key and not any(k == key for k, _ in opts_map):
                if atom.default is not None:
                    val = parse_val(atom.ty, atom.default)
                    opts_map.append((key, [val]))
        elif isinstance(atom, OptBool):
            key = atom.long or atom.short
            if key and not any(k == key for k, _ in opts_map):
                opts_map.append((key, ["false"]))

    # Add positional defaults
    for name, ty, default in pos_list:
        if not any(k == name for k, _ in pos_map):
            if default is not None:
                val = parse_val(ty, default)
                pos_map.append((name, val))
            else:
                raise ArgError(f"Missing positional: {name}")

    return ParseResult(
        command=cmd.name,
        options=opts_map,
        positionals=pos_map,
        leftovers=leftovers
    )


def parse_val(ty: Type, s: str) -> str:
    """Parse a string value according to type"""
    if ty == Type.INT:
        try:
            int(s)
        except ValueError:
            raise ArgError(f"Expected INT, got: {s}")
        return s
    elif ty == Type.BOOL:
        lower = s.lower()
        if lower in ("true", "false"):
            return lower
        else:
            raise ArgError(f"Expected BOOL (true|false), got: {s}")
    elif ty in (Type.STR, Type.PATH):
        return s
    else:
        raise ArgError(f"Unknown type: {ty}")


def add_opt(opts_map: List[Tuple[str, List[str]]], key: str, val: str):
    """Add an option value to the options map"""
    for i, (k, vals) in enumerate(opts_map):
        if k == key:
            vals.append(val)
            return
    opts_map.append((key, [val]))
