"""Clide help text generator"""

from typing import List, Tuple
from .spec import Spec, Command, Item, Group, Atom, Lit, OptBool, OptVal, Pos, Type


def render(spec: Spec) -> str:
    """Render basic help text from a spec"""
    result = "Usage:\n"

    for cmd in spec.commands:
        result += f"  {cmd.name} "

        # Filter out the command literal from items when rendering
        items_to_render: List[Item] = []
        for item in cmd.items:
            # Skip if this is the command literal itself
            if item.required:
                atoms = item.group.atoms_list()
                if len(atoms) == 1 and isinstance(atoms[0], Lit) and atoms[0].value == cmd.name:
                    continue
                elif len(atoms) > 1:
                    if any(isinstance(a, Lit) and a.value == cmd.name for a in atoms):
                        continue
            items_to_render.append(item)

        for item in items_to_render:
            result += show_item(item) + " "

        result += "\n"

    return result


def show_item(item: Item) -> str:
    """Convert an Item to a string representation"""
    group_str = show_group(item.group)
    if item.required:
        return group_str
    else:
        return f"[{group_str}]"


def show_group(group: Group) -> str:
    """Convert a Group to a string representation"""
    atoms = group.atoms_list()
    if len(atoms) == 1:
        return show_atom(atoms[0])
    else:
        parts = [show_atom(atom) for atom in atoms]
        return "|".join(parts)


def show_atom(atom: Atom) -> str:
    """Convert an Atom to a string representation"""
    if isinstance(atom, Lit):
        return atom.value
    elif isinstance(atom, OptBool):
        if atom.short and atom.long:
            return f"{atom.short}|{atom.long}"
        elif atom.short:
            return atom.short
        elif atom.long:
            return atom.long
        else:
            return "--?"
    elif isinstance(atom, OptVal):
        name = atom.short or atom.long or "--?"
        t = atom.ty.to_string()
        d = f":{atom.default}" if atom.default else ""
        plus = "+" if atom.allow_repeat else ""
        return f"{name}={t}{d}{plus}"
    elif isinstance(atom, Pos):
        t = atom.ty.to_string()
        d = f":{atom.default}" if atom.default else ""
        return f"<{atom.name}:{t}{d}>"
    else:
        return "?"


def key_string_of_atom(atom: Atom) -> str:
    """Get the key string for an atom (for documentation)"""
    if isinstance(atom, OptBool):
        if atom.short and atom.long:
            return f"{atom.short}, {atom.long}"
        elif atom.short:
            return atom.short
        elif atom.long:
            return atom.long
        else:
            return "--?"
    elif isinstance(atom, OptVal):
        base = ""
        if atom.short and atom.long:
            base = f"{atom.short}, {atom.long}"
        elif atom.short:
            base = atom.short
        elif atom.long:
            base = atom.long
        else:
            base = "--?"
        t = atom.ty.to_string()
        d = f":{atom.default}" if atom.default else ""
        plus = "+" if atom.allow_repeat else ""
        return f"{base}={t}{d}{plus}"
    elif isinstance(atom, Pos):
        t = atom.ty.to_string()
        d = f":{atom.default}" if atom.default else ""
        return f"<{atom.name}:{t}{d}>"
    elif isinstance(atom, Lit):
        return atom.value
    else:
        return "?"


def synth_line(atom: Atom) -> Tuple[str, str]:
    """Synthesize a documentation line for an atom"""
    if isinstance(atom, Lit):
        return (key_string_of_atom(atom), "command")
    elif isinstance(atom, OptBool):
        return (key_string_of_atom(atom), "boolean flag")
    elif isinstance(atom, OptVal):
        t = atom.ty.to_string()
        d = f" (default {atom.default})" if atom.default else ""
        rep = " (repeatable)" if atom.allow_repeat else ""
        return (key_string_of_atom(atom), f"value option {t}{d}{rep}")
    elif isinstance(atom, Pos):
        t = atom.ty.to_string()
        d = f" (default {atom.default})" if atom.default else ""
        return (key_string_of_atom(atom), f"positional {t}{d}")
    else:
        return ("?", "unknown")


def synth_docs(spec: Spec) -> List[Tuple[str, str]]:
    """Synthesize documentation from a spec"""
    result: List[Tuple[str, str]] = []

    for cmd in spec.commands:
        # Include leading command literal if present
        if cmd.items:
            first_item = cmd.items[0]
            if first_item.required:
                atoms = first_item.group.atoms_list()
                if len(atoms) == 1 and isinstance(atoms[0], Lit):
                    s = atoms[0].value
                    if not any(k == s for k, _ in result):
                        result.append((s, "command"))

        # Collect all atoms
        atoms: List[Atom] = []
        for item in cmd.items:
            atoms.extend(item.group.atoms_list())

        for atom in atoms:
            key, desc = synth_line(atom)
            if not any(k == key for k, _ in result):
                result.append((key, desc))

    return result


def merge_docs(user: List[Tuple[str, str]], synth: List[Tuple[str, str]]) -> List[Tuple[str, str]]:
    """Merge user documentation with synthesized documentation"""
    result: List[Tuple[str, str]] = []
    user_dict = dict(user)

    for k, autov in synth:
        if k in user_dict:
            result.append((k, user_dict[k]))
        else:
            result.append((k, autov))

    return result


def render_docs(pairs: List[Tuple[str, str]]) -> str:
    """Render documentation pairs in aligned format"""
    if not pairs:
        return ""

    max_len = max(len(k) for k, _ in pairs) if pairs else 0

    result = "Options & Arguments:\n"
    for key, desc in pairs:
        padding = " " * (max_len - len(key))
        result += f"  {key}{padding}  -  {desc}\n"

    return result


def render_with_docs(spec: Spec, user_docs: List[Tuple[str, str]]) -> str:
    """Render help text with user-provided documentation"""
    usage = render(spec)
    synth = synth_docs(spec)
    merged = merge_docs(user_docs, synth)
    return f"{usage}\n{render_docs(merged)}"
