//! Clide specification data structures

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Type {
    Int,
    Bool,
    Str,
    Path,
}

impl Type {
    pub fn from_str(s: &str) -> Result<Self, String> {
        match s {
            "INT" => Ok(Type::Int),
            "BOOL" => Ok(Type::Bool),
            "STR" => Ok(Type::Str),
            "PATH" => Ok(Type::Path),
            _ => Err(format!("Unknown type: {}", s)),
        }
    }

    pub fn to_string(&self) -> &'static str {
        match self {
            Type::Int => "INT",
            Type::Bool => "BOOL",
            Type::Str => "STR",
            Type::Path => "PATH",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Atom {
    Lit(String),
    OptBool {
        long: Option<String>,
        short: Option<String>,
    },
    OptVal {
        long: Option<String>,
        short: Option<String>,
        ty: Type,
        default: Option<String>,
        allow_repeat: bool,
    },
    Pos {
        name: String,
        ty: Type,
        default: Option<String>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Group {
    Single(Atom),
    Alt(Vec<Atom>),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Item {
    Required(Group),
    Optional(Group),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Command {
    pub name: String,
    pub items: Vec<Item>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Spec {
    pub prog: String,
    pub commands: Vec<Command>,
}

impl Group {
    pub fn atoms(&self) -> Vec<&Atom> {
        match self {
            Group::Single(a) => vec![a],
            Group::Alt(atoms) => atoms.iter().collect(),
        }
    }
}
