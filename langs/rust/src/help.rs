//! Clide help text generator

use crate::spec::*;

pub fn render(spec: &Spec) -> String {
    let mut result = "Usage:\n".to_string();
    
    for cmd in &spec.commands {
        result.push_str("  ");
        result.push_str(&cmd.name);
        result.push(' ');
        
        // Filter out the command literal from items when rendering
        let items_to_render: Vec<&Item> = cmd.items.iter()
            .filter(|item| {
                // Skip if this is the command literal itself
                match item {
                    Item::Required(Group::Single(Atom::Lit(s))) if s == &cmd.name => false,
                    Item::Required(Group::Alt(atoms)) => {
                        !atoms.iter().any(|a| matches!(a, Atom::Lit(s) if s == &cmd.name))
                    }
                    _ => true,
                }
            })
            .collect();
        
        for item in items_to_render {
            result.push_str(&show_item(item));
            result.push(' ');
        }
        
        result.push('\n');
    }
    
    result
}

fn show_item(item: &Item) -> String {
    match item {
        Item::Required(group) => show_group(group),
        Item::Optional(group) => format!("[{}]", show_group(group)),
    }
}

fn show_group(group: &Group) -> String {
    match group {
        Group::Single(atom) => show_atom(atom),
        Group::Alt(atoms) => {
            let parts: Vec<String> = atoms.iter().map(show_atom).collect();
            parts.join("|")
        }
    }
}

fn show_atom(atom: &Atom) -> String {
    match atom {
        Atom::Lit(s) => s.clone(),
        Atom::OptBool { long, short } => {
            match (short, long) {
                (Some(s), Some(l)) => format!("[{}|{}]", s, l),
                (Some(s), None) => format!("[{}]", s),
                (None, Some(l)) => format!("[{}]", l),
                _ => "[]".to_string(),
            }
        }
        Atom::OptVal {
            long,
            short,
            ty,
            default,
            allow_repeat,
        } => {
            let default_name = "--?".to_string();
            let name = short.as_ref().or(long.as_ref()).unwrap_or(&default_name);
            let t = ty.to_string();
            let d = default.as_ref().map(|s| format!(":{}", s)).unwrap_or_default();
            let plus = if *allow_repeat { "+" } else { "" };
            format!("[{}={}{}{}]", name, t, d, plus)
        }
        Atom::Pos { name, ty, default } => {
            let t = ty.to_string();
            let d = default.as_ref().map(|s| format!(":{}", s)).unwrap_or_default();
            format!("<{}:{}{}>", name, t, d)
        }
    }
}

pub fn key_string_of_atom(atom: &Atom) -> String {
    match atom {
        Atom::OptBool { long, short } => match (short, long) {
            (Some(s), Some(l)) => format!("{}, {}", s, l),
            (Some(s), None) => s.clone(),
            (None, Some(l)) => l.clone(),
            _ => "--?".to_string(),
        },
        Atom::OptVal {
            long,
            short,
            ty,
            default,
            allow_repeat,
        } => {
            let base = match (short, long) {
                (Some(s), Some(l)) => format!("{}, {}", s, l),
                (Some(s), None) => s.clone(),
                (None, Some(l)) => l.clone(),
                _ => "--?".to_string(),
            };
            let t = ty.to_string();
            let d = default.as_ref().map(|s| format!(":{}", s)).unwrap_or_default();
            let plus = if *allow_repeat { "+" } else { "" };
            format!("{}={}{}{}", base, t, d, plus)
        }
        Atom::Pos { name, ty, default } => {
            let t = ty.to_string();
            let d = default.as_ref().map(|s| format!(":{}", s)).unwrap_or_default();
            format!("<{}:{}{}>", name, t, d)
        }
        Atom::Lit(s) => s.clone(),
    }
}

fn synth_line(atom: &Atom) -> (String, String) {
    match atom {
        Atom::Lit(_) => (key_string_of_atom(atom), "command".to_string()),
        Atom::OptBool { .. } => (key_string_of_atom(atom), "boolean flag".to_string()),
        Atom::OptVal {
            ty,
            default,
            allow_repeat,
            ..
        } => {
            let t = ty.to_string();
            let d = default
                .as_ref()
                .map(|s| format!(" (default {})", s))
                .unwrap_or_default();
            let rep = if *allow_repeat {
                " (repeatable)".to_string()
            } else {
                String::new()
            };
            (
                key_string_of_atom(atom),
                format!("value option {}{}{}", t, d, rep),
            )
        }
        Atom::Pos { ty, default, .. } => {
            let t = ty.to_string();
            let d = default
                .as_ref()
                .map(|s| format!(" (default {})", s))
                .unwrap_or_default();
            (
                key_string_of_atom(atom),
                format!("positional {}{}", t, d),
            )
        }
    }
}

fn synth_docs(spec: &Spec) -> Vec<(String, String)> {
    let mut result: Vec<(String, String)> = vec![];

    for cmd in &spec.commands {
        // Include leading command literal if present
        if let Some(Item::Required(Group::Single(Atom::Lit(s)))) = cmd.items.first() {
            if !result.iter().any(|(k, _)| k == s) {
                result.push((s.clone(), "command".to_string()));
            }
        }

        // Collect all atoms
        let atoms: Vec<&Atom> = cmd
            .items
            .iter()
            .flat_map(|item| match item {
                Item::Required(g) | Item::Optional(g) => g.atoms(),
            })
            .collect();

        for atom in atoms {
            let (key, desc) = synth_line(atom);
            if !result.iter().any(|(k, _)| k == &key) {
                result.push((key, desc));
            }
        }
    }

    result
}

fn merge_docs(user: &[(String, String)], synth: Vec<(String, String)>) -> Vec<(String, String)> {
    synth
        .into_iter()
        .map(|(k, autov)| {
            let k_clone = k.clone();
            user.iter()
                .find(|(k2, _)| k2 == &k)
                .map(|(_, desc)| (k_clone.clone(), desc.clone()))
                .unwrap_or((k_clone, autov))
        })
        .collect()
}

fn render_docs(pairs: &[(String, String)]) -> String {
    if pairs.is_empty() {
        return String::new();
    }

    let max_len = pairs
        .iter()
        .map(|(k, _)| k.len())
        .max()
        .unwrap_or(0);

    let mut result = "Options & Arguments:\n".to_string();
    for (key, desc) in pairs {
        let padding = " ".repeat(max_len.saturating_sub(key.len()));
        result.push_str(&format!("  {}{}  -  {}\n", key, padding, desc));
    }

    result
}

pub fn render_with_docs(spec: &Spec, user_docs: &[(String, String)]) -> String {
    let usage = render(spec);
    let synth = synth_docs(spec);
    let merged = merge_docs(user_docs, synth);
    format!("{}\n{}", usage, render_docs(&merged))
}
