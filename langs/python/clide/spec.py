"""Clide specification data structures"""

from enum import Enum
from typing import Optional, List, Union


class Type(Enum):
    """Type annotations for options and positionals"""
    INT = "INT"
    BOOL = "BOOL"
    STR = "STR"
    PATH = "PATH"

    @classmethod
    def from_str(cls, s: str) -> 'Type':
        """Parse a type string into a Type enum"""
        mapping = {
            "INT": cls.INT,
            "BOOL": cls.BOOL,
            "STR": cls.STR,
            "PATH": cls.PATH,
        }
        if s not in mapping:
            raise ValueError(f"Unknown type: {s}")
        return mapping[s]

    def to_string(self) -> str:
        """Convert Type enum to string"""
        return self.value


class Atom:
    """Represents an atomic element in a usage specification"""
    pass


class Lit(Atom):
    """Literal string atom"""
    def __init__(self, value: str):
        self.value = value

    def __eq__(self, other):
        return isinstance(other, Lit) and self.value == other.value

    def __repr__(self):
        return f"Lit('{self.value}')"


class OptBool(Atom):
    """Boolean option atom (flag)"""
    def __init__(self, long: Optional[str] = None, short: Optional[str] = None):
        self.long = long
        self.short = short

    def __eq__(self, other):
        return (isinstance(other, OptBool) and
                self.long == other.long and self.short == other.short)

    def __repr__(self):
        return f"OptBool(long={self.long}, short={self.short})"


class OptVal(Atom):
    """Value option atom"""
    def __init__(self, long: Optional[str] = None, short: Optional[str] = None,
                 ty: Type = Type.STR, default: Optional[str] = None,
                 allow_repeat: bool = False):
        self.long = long
        self.short = short
        self.ty = ty
        self.default = default
        self.allow_repeat = allow_repeat

    def __eq__(self, other):
        return (isinstance(other, OptVal) and
                self.long == other.long and self.short == other.short and
                self.ty == other.ty and self.default == other.default and
                self.allow_repeat == other.allow_repeat)

    def __repr__(self):
        return (f"OptVal(long={self.long}, short={self.short}, ty={self.ty}, "
                f"default={self.default}, allow_repeat={self.allow_repeat})")


class Pos(Atom):
    """Positional argument atom"""
    def __init__(self, name: str, ty: Type, default: Optional[str] = None):
        self.name = name
        self.ty = ty
        self.default = default

    def __eq__(self, other):
        return (isinstance(other, Pos) and
                self.name == other.name and self.ty == other.ty and
                self.default == other.default)

    def __repr__(self):
        return f"Pos(name={self.name}, ty={self.ty}, default={self.default})"


class Group:
    """Represents a group of atoms (single or alternative)"""
    def __init__(self, atoms: Union[Atom, List[Atom]]):
        if isinstance(atoms, Atom):
            self.atoms = [atoms]
            self.is_alt = False
        else:
            self.atoms = atoms
            self.is_alt = len(atoms) > 1

    def atoms_list(self) -> List[Atom]:
        """Get list of atoms in this group"""
        return self.atoms

    def __eq__(self, other):
        return (isinstance(other, Group) and
                self.atoms == other.atoms and self.is_alt == other.is_alt)

    def __repr__(self):
        if self.is_alt:
            return f"Group.Alt({self.atoms})"
        else:
            return f"Group.Single({self.atoms[0]})"


class Item:
    """Represents a required or optional item"""
    def __init__(self, group: Group, required: bool = True):
        self.group = group
        self.required = required

    def __eq__(self, other):
        return (isinstance(other, Item) and
                self.group == other.group and self.required == other.required)

    def __repr__(self):
        prefix = "Required" if self.required else "Optional"
        return f"{prefix}({self.group})"


class Command:
    """Represents a command specification"""
    def __init__(self, name: str, items: List[Item]):
        self.name = name
        self.items = items

    def __eq__(self, other):
        return (isinstance(other, Command) and
                self.name == other.name and self.items == other.items)

    def __repr__(self):
        return f"Command(name={self.name}, items={self.items})"


class Spec:
    """Complete specification with program name and commands"""
    def __init__(self, prog: str, commands: List[Command]):
        self.prog = prog
        self.commands = commands

    def __eq__(self, other):
        return (isinstance(other, Spec) and
                self.prog == other.prog and self.commands == other.commands)

    def __repr__(self):
        return f"Spec(prog={self.prog}, commands={self.commands})"
