structure Main =
struct
  val usage = [
    "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
    "Usage: mytool init <path:PATH>"
  ]

  val docs = [
    ("serve", "Start the HTTP server"),
    ("init", "Initialize a project directory"),
    ("-v, --verbose", "Verbose logging"),
    ("--port=INT:8080", "TCP port to listen on"),
    ("--tls", "Enable TLS"),
    ("--root=PATH", "Document root for static files"),
    ("<dir:PATH>", "Application directory"),
    ("<path:PATH>", "Project directory")
  ]

  fun run () =
    let
      val argv = CommandLine.arguments ()
  val parse = Clide.fromUsageLines usage
    in
      if List.exists (fn a => a="--help" orelse a="-h") argv then
  print (Clide.helpWithDocs usage docs)
      else
        let val res = parse argv
            val {command, options, positionals, leftovers} = res
            fun p s = print (s ^ "\n")
            fun showKV (k,vs) = p (k ^ " = [" ^ String.concatWith ", " (List.rev vs) ^ "]")
            fun showPos (k,v) = p (k ^ " = " ^ v)
        in
          p ("command: "^command);
          List.app showKV options;
          List.app showPos positionals;
          case leftovers of [] => () | xs => (p "--- leftovers ---"; List.app p xs)
        end
    end
end

val _ = Main.run ()
