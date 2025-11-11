//! Clide: Augmented POSIX Usage -> argv parser for Rust
//!
//! Clide turns annotated `Usage:` lines into fully validated command-line parsers.

pub mod spec;
pub mod parser;
pub mod runtime;
pub mod help;

pub use spec::Type;
pub use runtime::{ArgError, ParseResult};
pub use parser::ParseError;

/// Main Clide API
pub struct Clide;

impl Clide {
    /// Parse usage lines and return a parser function
    pub fn from_usage_lines(usage: &[String]) -> Result<impl Fn(&[String]) -> Result<ParseResult, ArgError>, ParseError> {
        let spec = parser::from_lines(usage)?;
        Ok(move |argv: &[String]| {
            let cmd = runtime::choose_command(&spec, argv);
            runtime::parse_with(cmd, argv)
        })
    }

    /// Render help text from usage lines
    pub fn help_of(usage: &[String]) -> Result<String, ParseError> {
        let spec = parser::from_lines(usage)?;
        Ok(help::render(&spec))
    }

    /// Render help text with user-provided documentation
    pub fn help_with_docs(usage: &[String], docs: &[(String, String)]) -> Result<String, ParseError> {
        let spec = parser::from_lines(usage)?;
        Ok(help::render_with_docs(&spec, docs))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_parsing() {
        let usage = vec![
            "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>".to_string(),
            "Usage: mytool init <path:PATH>".to_string(),
        ];

        let parse = Clide::from_usage_lines(&usage).unwrap();
        let result = parse(&["serve".to_string(), "--port=9090".to_string(), "/tmp/app".to_string()]).unwrap();
        
        assert_eq!(result.command, "serve");
        assert!(result.options.iter().any(|(k, _)| k == "--port"));
    }
}
