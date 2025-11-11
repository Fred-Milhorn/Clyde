"""Clide usage string parser"""

from typing import List, Tuple, Optional
from .spec import Spec, Command, Item, Group, Atom, Lit, OptBool, OptVal, Pos, Type


class ParseError(Exception):
    """Error during usage string parsing"""
    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)


def from_lines(lines: List[str]) -> Spec:
    """Parse a list of usage lines into a Spec"""
    if not lines:
        raise ParseError("No usage lines")

    parsed: List[Tuple[str, List[Item]]] = []
    for line in lines:
        parsed.append(parse_usage_line(line))

    prog = parsed[0][0]

    commands: List[Command] = []
    for _, items in parsed:
        name = first_lit_after_prog(items) or "_"
        commands.append(Command(name=name, items=items))

    return Spec(prog=prog, commands=commands)


def parse_usage_line(line: str) -> Tuple[str, List[Item]]:
    """Parse a single usage line"""
    words = line.split()

    if len(words) < 2 or words[0] != "Usage:":
        raise ParseError("Line must start with 'Usage:'")

    prog = words[1]
    rest = words[2:]
    items: List[Item] = []
    for token in rest:
        items.append(parse_group_token(token))

    return (prog, items)


def parse_group_token(token: str) -> Item:
    """Parse a token into an Item (required or optional)"""
    if token.startswith('[') and token.endswith(']'):
        inner = token[1:-1]
        alts = inner.split('|')

        atoms: List[Atom] = []
        for alt in alts:
            atoms.append(atom_of(alt))

        if len(atoms) == 1:
            group = Group(atoms[0])
        else:
            group = Group(atoms)

        return Item(group=group, required=False)
    else:
        atom = atom_of(token)
        return Item(group=Group(atom), required=True)


def atom_of(token: str) -> Atom:
    """Parse a token into an Atom"""
    if token.startswith('<'):
        if not token.endswith('>'):
            raise ParseError(f"Unterminated positional: {token}")
        return parse_pos(token)
    elif is_long(token) or is_short(token) or '=' in token:
        return parse_option(token)
    else:
        return Lit(token)


def parse_option(token: str) -> Atom:
    """Parse an option token"""
    if '=' in token:
        pos = token.find('=')
        name_part = token[:pos]
        val_part = token[pos + 1:]
    else:
        name_part = token
        val_part = None

    if is_long(name_part):
        long_opt = name_part
        short_opt = None
    elif is_short(name_part):
        long_opt = None
        short_opt = name_part
    else:
        raise ParseError(f"Bad option: {token}")

    if val_part is None:
        return OptBool(long=long_opt, short=short_opt)
    else:
        allow_repeat = val_part.endswith('+')
        core = val_part[:-1] if allow_repeat else val_part

        if ':' in core:
            pos = core.find(':')
            ty_str = core[:pos]
            default = core[pos + 1:]
        else:
            ty_str = core
            default = None

        try:
            ty = Type.from_str(ty_str)
        except ValueError as e:
            raise ParseError(f"{e}: {token}")

        return OptVal(
            long=long_opt,
            short=short_opt,
            ty=ty,
            default=default,
            allow_repeat=allow_repeat
        )


def parse_pos(token: str) -> Atom:
    """Parse a positional argument token"""
    if not token.startswith('<') or not token.endswith('>'):
        raise ParseError(f"Expected <...>: {token}")

    inside = token[1:-1]
    parts = inside.split(':')

    if len(parts) == 2:
        name, ty_str = parts
        try:
            ty = Type.from_str(ty_str)
        except ValueError as e:
            raise ParseError(f"{e}: {token}")
        return Pos(name=name, ty=ty, default=None)
    elif len(parts) == 3:
        name, ty_str, default = parts
        try:
            ty = Type.from_str(ty_str)
        except ValueError as e:
            raise ParseError(f"{e}: {token}")
        return Pos(name=name, ty=ty, default=default)
    else:
        raise ParseError(f"Bad positional: {token}")


def is_short(s: str) -> bool:
    """Check if a string is a short option (-x)"""
    return len(s) == 2 and s.startswith('-') and not s.startswith("--")


def is_long(s: str) -> bool:
    """Check if a string is a long option (--option)"""
    return len(s) >= 3 and s.startswith("--")


def first_lit_after_prog(items: List[Item]) -> Optional[str]:
    """Find the first literal atom after the program name"""
    for item in items:
        if item.required:
            atoms = item.group.atoms_list()
            if len(atoms) == 1 and isinstance(atoms[0], Lit):
                return atoms[0].value
            elif len(atoms) > 1:
                for atom in atoms:
                    if isinstance(atom, Lit):
                        return atom.value
    return None
