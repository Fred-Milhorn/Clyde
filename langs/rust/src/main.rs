//! Clide demo application

use clide::Clide;

fn main() {
    let usage = vec![
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>".to_string(),
        "Usage: mytool init <path:PATH>".to_string(),
    ];

    let docs = vec![
        ("serve".to_string(), "Start the HTTP server".to_string()),
        ("init".to_string(), "Initialize a project directory".to_string()),
        ("-v, --verbose".to_string(), "Verbose logging".to_string()),
        ("--port=INT:8080".to_string(), "TCP port to listen on".to_string()),
        ("--tls".to_string(), "Enable TLS".to_string()),
        ("--root=PATH".to_string(), "Document root for static files".to_string()),
        ("<dir:PATH>".to_string(), "Application directory".to_string()),
        ("<path:PATH>".to_string(), "Project directory".to_string()),
    ];

    let args: Vec<String> = std::env::args().skip(1).collect();
    
    let wants_help = args.iter().any(|a| a == "--help" || a == "-h");

    if wants_help {
        match Clide::help_with_docs(&usage, &docs) {
            Ok(help_text) => {
                println!("{}", help_text);
                std::process::exit(0);
            }
            Err(e) => {
                eprintln!("Error parsing usage: {}", e.0);
                std::process::exit(1);
            }
        }
    }

    match Clide::from_usage_lines(&usage) {
        Ok(parse) => {
            match parse(&args) {
                Ok(result) => {
                    println!("command: {}", result.command);
                    
                    for (key, values) in &result.options {
                        println!("{} = [{:?}]", key, values);
                    }
                    
                    for (key, value) in &result.positionals {
                        println!("{} = {}", key, value);
                    }
                    
                    if !result.leftovers.is_empty() {
                        println!("--- leftovers ---");
                        for arg in &result.leftovers {
                            println!("{}", arg);
                        }
                    }
                    
                    std::process::exit(0);
                }
                Err(e) => {
                    eprintln!("Error: {}\n", e.0);
                    match Clide::help_with_docs(&usage, &docs) {
                        Ok(help_text) => println!("{}", help_text),
                        Err(_) => {}
                    }
                    std::process::exit(1);
                }
            }
        }
        Err(e) => {
            eprintln!("Error parsing usage: {}", e.0);
            std::process::exit(1);
        }
    }
}
