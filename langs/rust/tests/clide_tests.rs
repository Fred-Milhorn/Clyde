//! Clide tests

use clide::{Clide, ArgError, ParseError};

#[test]
fn test_serve_parse() {
    let usage = vec![
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>".to_string(),
        "Usage: mytool init <path:PATH>".to_string(),
    ];

    let parse = Clide::from_usage_lines(&usage).unwrap();
    let result = parse(&[
        "serve".to_string(),
        "--port".to_string(),
        "9090".to_string(),
        "--tls".to_string(),
        "--root".to_string(),
        "/srv/www".to_string(),
        "-v".to_string(),
        "/app".to_string(),
        "--".to_string(),
        "leftover".to_string(),
    ]).unwrap();

    assert_eq!(result.command, "serve");
    
    let port_vals: Vec<String> = result.options.iter()
        .find(|(k, _)| k == "--port")
        .map(|(_, v)| v.clone())
        .unwrap();
    assert_eq!(port_vals, vec!["9090"]);
    
    let tls_vals: Vec<String> = result.options.iter()
        .find(|(k, _)| k == "--tls")
        .map(|(_, v)| v.clone())
        .unwrap();
    assert_eq!(tls_vals, vec!["true"]);
    
    let dir_val = result.positionals.iter()
        .find(|(k, _)| k == "dir")
        .map(|(_, v)| v.clone())
        .unwrap();
    assert_eq!(dir_val, "/app");
    
    assert_eq!(result.leftovers, vec!["leftover"]);
}

#[test]
fn test_serve_defaults() {
    let usage = vec![
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>".to_string(),
        "Usage: mytool init <path:PATH>".to_string(),
    ];

    let parse = Clide::from_usage_lines(&usage).unwrap();
    let result = parse(&["serve".to_string(), "/workdir".to_string()]).unwrap();

    let port_vals: Vec<String> = result.options.iter()
        .find(|(k, _)| k == "--port")
        .map(|(_, v)| v.clone())
        .unwrap();
    assert_eq!(port_vals, vec!["8080"]);
    
    let tls_vals: Vec<String> = result.options.iter()
        .find(|(k, _)| k == "--tls")
        .map(|(_, v)| v.clone())
        .unwrap();
    assert_eq!(tls_vals, vec!["false"]);
    
    let verbose_vals: Vec<String> = result.options.iter()
        .find(|(k, _)| k == "--verbose")
        .map(|(_, v)| v.clone())
        .unwrap();
    assert_eq!(verbose_vals, vec!["false"]);
}

#[test]
fn test_repeating_option() {
    let usage = vec![
        "Usage: build [--include=PATH+] <dir:PATH>".to_string(),
    ];
    
    let parse = Clide::from_usage_lines(&usage).unwrap();
    let result = parse(&[
        "--include".to_string(),
        "src".to_string(),
        "--include".to_string(),
        "lib".to_string(),
        "project".to_string(),
    ]).unwrap();
    
    assert_eq!(result.command, "_");
    
    let include_vals: Vec<String> = result.options.iter()
        .find(|(k, _)| k == "--include")
        .map(|(_, v)| v.clone())
        .unwrap();
    assert_eq!(include_vals, vec!["src", "lib"]);
}

#[test]
fn test_unknown_option() {
    let usage = vec![
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>".to_string(),
        "Usage: mytool init <path:PATH>".to_string(),
    ];

    let parse = Clide::from_usage_lines(&usage).unwrap();
    let result = parse(&["serve".to_string(), "--bogus".to_string(), "/app".to_string()]);
    
    assert!(result.is_err());
    if let Err(ArgError(msg)) = result {
        assert!(msg.contains("Unknown option"));
    }
}

#[test]
fn test_spec_error() {
    let result = Clide::from_usage_lines(&["Usage: tool <unterminated".to_string()]);
    assert!(result.is_err());
    if let Err(ParseError(_)) = result {
        // Expected
    } else {
        panic!("Expected ParseError");
    }
}

#[test]
fn test_help_output() {
    let usage = vec![
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>".to_string(),
        "Usage: mytool init <path:PATH>".to_string(),
    ];
    
    let docs = vec![
        ("serve".to_string(), "Start the HTTP server".to_string()),
        ("init".to_string(), "Initialize a project directory".to_string()),
        ("-v, --verbose".to_string(), "Verbose logging".to_string()),
        ("--port=INT:8080".to_string(), "TCP port".to_string()),
        ("--tls".to_string(), "Enable TLS".to_string()),
        ("--root=PATH".to_string(), "Document root".to_string()),
        ("<dir:PATH>".to_string(), "Application directory".to_string()),
        ("<path:PATH>".to_string(), "Project directory".to_string()),
    ];
    
    let help = Clide::help_with_docs(&usage, &docs).unwrap();
    assert!(help.contains("--port=INT:8080"));
    assert!(help.contains("-v"));
    assert!(help.contains("--verbose"));
    assert!(help.contains("serve"));
}
