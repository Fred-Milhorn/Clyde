//! Clide runtime argument parser

use crate::spec::*;

#[derive(Debug)]
pub struct ArgError(pub String);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParseResult {
    pub command: String,
    pub options: Vec<(String, Vec<String>)>,
    pub positionals: Vec<(String, String)>,
    pub leftovers: Vec<String>,
}

pub fn choose_command<'a>(spec: &'a Spec, argv: &[String]) -> &'a Command {
    if argv.is_empty() {
        return &spec.commands[0];
    }

    let first_arg = &argv[0];
    
    for cmd in &spec.commands {
        if let Some(lit) = first_literal(cmd) {
            if lit == *first_arg {
                return cmd;
            }
        }
    }

    &spec.commands[0]
}

fn first_literal(cmd: &Command) -> Option<String> {
    for item in &cmd.items {
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

pub fn parse_with(cmd: &Command, argv: &[String]) -> Result<ParseResult, ArgError> {
    let seq: Vec<(bool, &Group)> = cmd
        .items
        .iter()
        .map(|item| match item {
            Item::Required(g) => (false, g),
            Item::Optional(g) => (true, g),
        })
        .collect();

    let atoms: Vec<&Atom> = seq.iter().flat_map(|(_, g)| g.atoms()).collect();

    let known_opts: Vec<String> = atoms
        .iter()
        .flat_map(|atom| match atom {
            Atom::OptBool { long, short } => {
                let mut v = vec![];
                if let Some(l) = long {
                    v.push(l.clone());
                }
                if let Some(s) = short {
                    v.push(s.clone());
                }
                v
            }
            Atom::OptVal { long, short, .. } => {
                let mut v = vec![];
                if let Some(l) = long {
                    v.push(l.clone());
                }
                if let Some(s) = short {
                    v.push(s.clone());
                }
                v
            }
            _ => vec![],
        })
        .collect();

    let pos_list: Vec<(String, Type, Option<String>)> = atoms
        .iter()
        .filter_map(|atom| match atom {
            Atom::Pos { name, ty, default } => Some((name.clone(), ty.clone(), default.clone())),
            _ => None,
        })
        .collect();

    let mut opts_map: Vec<(String, Vec<String>)> = vec![];
    let mut pos_map: Vec<(String, String)> = vec![];
    let mut seen_pos = 0;
    let mut leftovers: Vec<String> = vec![];

    let args = argv.to_vec();
    let mut i = 0;

    while i < args.len() {
        let arg = &args[i];

        if arg == "--" {
            // Handle remaining positionals
            let remaining_pos = &pos_list[seen_pos..];
            let rest = &args[i + 1..];
            
            for (j, (name, ty, default)) in remaining_pos.iter().enumerate() {
                if j < rest.len() {
                    let val = parse_val(ty, &rest[j])?;
                    pos_map.push((name.clone(), val));
                    seen_pos += 1;
                } else if let Some(d) = default {
                    let val = parse_val(ty, d)?;
                    pos_map.push((name.clone(), val));
                    seen_pos += 1;
                } else {
                    return Err(ArgError(format!("Missing positional: {}", name)));
                }
            }
            
            leftovers = rest[remaining_pos.len()..].to_vec();
            break;
        } else if arg.starts_with('-') {
            let (name_part, val_part) = if let Some(pos) = arg.find('=') {
                let (n, v) = arg.split_at(pos);
                (n.to_string(), Some(&v[1..]))
            } else {
                (arg.clone(), None)
            };

            if !known_opts.contains(&name_part) {
                return Err(ArgError(format!("Unknown option: {}", name_part)));
            }

            let opt_decl = atoms
                .iter()
                .find(|atom| match atom {
                    Atom::OptVal { long, short, .. } => {
                        Some(&name_part) == long.as_ref() || Some(&name_part) == short.as_ref()
                    }
                    Atom::OptBool { long, short } => {
                        Some(&name_part) == long.as_ref() || Some(&name_part) == short.as_ref()
                    }
                    _ => false,
                })
                .ok_or_else(|| ArgError("Unknown option declaration".to_string()))?;

            match opt_decl {
                Atom::OptBool { .. } => {
                    add_opt(&mut opts_map, &name_part, "true".to_string());
                    i += 1;
                }
                Atom::OptVal { ty, .. } => {
                    let val = match val_part {
                        Some(v) => parse_val(ty, v)?,
                        None => {
                            if i + 1 < args.len() {
                                i += 1;
                                parse_val(ty, &args[i])?
                            } else {
                                return Err(ArgError(format!("Missing value for {}", name_part)));
                            }
                        }
                    };
                    add_opt(&mut opts_map, &name_part, val);
                    i += 1;
                }
                _ => return Err(ArgError("impossible".to_string())),
            }
        } else {
            // Try to consume as literal
            let mut consumed = false;
            for (req, group) in &seq {
                if !req && matches!(group, Group::Single(Atom::Lit(_)) | Group::Alt(_)) {
                    match group {
                        Group::Single(Atom::Lit(s)) if s == arg => {
                            consumed = true;
                            break;
                        }
                        Group::Alt(alts) => {
                            if alts.iter().any(|a| matches!(a, Atom::Lit(s) if s == arg)) {
                                consumed = true;
                                break;
                            }
                        }
                        _ => {}
                    }
                }
            }

            if consumed {
                i += 1;
                continue;
            }

            // Treat as positional
            if seen_pos >= pos_list.len() {
                return Err(ArgError(format!("Unexpected argument: {}", arg)));
            }

            let (name, ty, _) = &pos_list[seen_pos];
            let val = parse_val(ty, arg)?;
            pos_map.push((name.clone(), val));
            seen_pos += 1;
            i += 1;
        }
    }

    // Add option defaults
    for atom in &atoms {
        match atom {
            Atom::OptVal {
                long,
                short,
                ty,
                default,
                ..
            } => {
                let key = long.as_ref().or(short.as_ref()).unwrap();
                if !opts_map.iter().any(|(k, _)| k == key) {
                    if let Some(d) = default {
                        let val = parse_val(ty, d)?;
                        opts_map.push((key.clone(), vec![val]));
                    }
                }
            }
            Atom::OptBool { long, short } => {
                let key = long.as_ref().or(short.as_ref()).unwrap();
                if !opts_map.iter().any(|(k, _)| k == key) {
                    opts_map.push((key.clone(), vec!["false".to_string()]));
                }
            }
            _ => {}
        }
    }

    // Add positional defaults
    for (name, ty, default) in &pos_list {
        if !pos_map.iter().any(|(k, _)| k == name) {
            if let Some(d) = default {
                let val = parse_val(ty, d)?;
                pos_map.push((name.clone(), val));
            } else {
                return Err(ArgError(format!("Missing positional: {}", name)));
            }
        }
    }

    Ok(ParseResult {
        command: cmd.name.clone(),
        options: opts_map,
        positionals: pos_map,
        leftovers,
    })
}

fn parse_val(ty: &Type, s: &str) -> Result<String, ArgError> {
    match ty {
        Type::Int => {
            s.parse::<i64>()
                .map_err(|_| ArgError(format!("Expected INT, got: {}", s)))?;
            Ok(s.to_string())
        }
        Type::Bool => {
            let lower = s.to_lowercase();
            match lower.as_str() {
                "true" | "false" => Ok(lower),
                _ => Err(ArgError(format!("Expected BOOL (true|false), got: {}", s))),
            }
        }
        Type::Str | Type::Path => Ok(s.to_string()),
    }
}

fn add_opt(opts_map: &mut Vec<(String, Vec<String>)>, key: &str, val: String) {
    if let Some((_, vals)) = opts_map.iter_mut().find(|(k, _)| k == key) {
        vals.push(val);
    } else {
        opts_map.push((key.to_string(), vec![val]));
    }
}
