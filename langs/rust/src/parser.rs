//! Clide usage string parser

use crate::spec::*;

#[derive(Debug)]
pub struct ParseError(pub String);

pub fn from_lines(lines: &[String]) -> Result<Spec, ParseError> {
    if lines.is_empty() {
        return Err(ParseError("No usage lines".to_string()));
    }

    let parsed: Result<Vec<_>, _> = lines.iter().map(|s| parse_usage_line(s)).collect();
    let parsed = parsed?;

    let prog = parsed[0].0.clone();

    let commands: Vec<Command> = parsed
        .into_iter()
        .map(|(_, items)| {
            let name = first_lit_after_prog(&items).unwrap_or("_".to_string());
            Command { name, items }
        })
        .collect();

    Ok(Spec { prog, commands })
}

fn parse_usage_line(line: &str) -> Result<(String, Vec<Item>), ParseError> {
    let words: Vec<&str> = line.split_whitespace().collect();
    
    if words.len() < 2 || words[0] != "Usage:" {
        return Err(ParseError("Line must start with 'Usage:'".to_string()));
    }

    let prog = words[1].to_string();
    let rest: Vec<&str> = words[2..].to_vec();
    let items: Result<Vec<Item>, _> = rest.iter().map(|t| parse_group_token(t)).collect();
    let items = items?;

    Ok((prog, items))
}

fn parse_group_token(token: &str) -> Result<Item, ParseError> {
    if token.starts_with('[') && token.ends_with(']') {
        let inner = &token[1..token.len() - 1];
        let alts: Vec<&str> = inner.split('|').collect();
        
        let atoms: Result<Vec<Atom>, _> = alts.iter().map(|a| atom_of(a)).collect();
        let atoms = atoms?;

        let group = if atoms.len() == 1 {
            Group::Single(atoms.into_iter().next().unwrap())
        } else {
            Group::Alt(atoms)
        };

        Ok(Item::Optional(group))
    } else {
        let atom = atom_of(token)?;
        Ok(Item::Required(Group::Single(atom)))
    }
}

fn atom_of(token: &str) -> Result<Atom, ParseError> {
    if token.starts_with('<') {
        if !token.ends_with('>') {
            return Err(ParseError(format!("Unterminated positional: {}", token)));
        }
        parse_pos(token)
    } else if is_long(token) || is_short(token) || token.contains('=') {
        parse_option(token)
    } else {
        Ok(Atom::Lit(token.to_string()))
    }
}

fn parse_option(token: &str) -> Result<Atom, ParseError> {
    let (name_part, val_part) = if let Some(pos) = token.find('=') {
        let (n, v) = token.split_at(pos);
        (n, Some(&v[1..]))
    } else {
        (token, None)
    };

    let (long_opt, short_opt) = if is_long(name_part) {
        (Some(name_part.to_string()), None)
    } else if is_short(name_part) {
        (None, Some(name_part.to_string()))
    } else {
        return Err(ParseError(format!("Bad option: {}", token)));
    };

    match val_part {
        None => Ok(Atom::OptBool {
            long: long_opt,
            short: short_opt,
        }),
        Some(v) => {
            let allow_repeat = v.ends_with('+');
            let core = if allow_repeat {
                &v[..v.len() - 1]
            } else {
                v
            };

            let (ty_str, default) = if let Some(pos) = core.find(':') {
                let (t, d) = core.split_at(pos);
                (t, Some(&d[1..]))
            } else {
                (core, None)
            };

            let ty = Type::from_str(ty_str)
                .map_err(|e| ParseError(format!("{}: {}", e, token)))?;

            Ok(Atom::OptVal {
                long: long_opt,
                short: short_opt,
                ty,
                default: default.map(|s| s.to_string()),
                allow_repeat,
            })
        }
    }
}

fn parse_pos(token: &str) -> Result<Atom, ParseError> {
    if !token.starts_with('<') || !token.ends_with('>') {
        return Err(ParseError(format!("Expected <...>: {}", token)));
    }

    let inside = &token[1..token.len() - 1];
    let parts: Vec<&str> = inside.split(':').collect();

    match parts.as_slice() {
        [nm, tys] => {
            let ty = Type::from_str(tys)
                .map_err(|e| ParseError(format!("{}: {}", e, token)))?;
            Ok(Atom::Pos {
                name: nm.to_string(),
                ty,
                default: None,
            })
        }
        [nm, tys, def] => {
            let ty = Type::from_str(tys)
                .map_err(|e| ParseError(format!("{}: {}", e, token)))?;
            Ok(Atom::Pos {
                name: nm.to_string(),
                ty,
                default: Some(def.to_string()),
            })
        }
        _ => Err(ParseError(format!("Bad positional: {}", token))),
    }
}

fn is_short(s: &str) -> bool {
    s.len() == 2 && s.starts_with('-') && !s.starts_with("--")
}

fn is_long(s: &str) -> bool {
    s.len() >= 3 && s.starts_with("--")
}

fn first_lit_after_prog(items: &[Item]) -> Option<String> {
    for item in items {
        if let Item::Required(group) = item {
            match group {
                Group::Single(Atom::Lit(s)) => return Some(s.clone()),
                Group::Alt(atoms) => {
                    if let Some(Atom::Lit(s)) = atoms.first() {
                        return Some(s.clone());
                    }
                }
                _ => {}
            }
        }
    }
    None
}
