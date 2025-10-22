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
      val showHelp = fn () => print (Clide.helpWithDocs usage docs)
      val wantsHelp = List.exists (fn a => a = "--help" orelse a = "-h") argv
      fun emitResult {command, options, positionals, leftovers} =
        let
          fun p s = print (s ^ "\n")
          fun showKV (k, vs) = p (k ^ " = [" ^ String.concatWith ", " (List.rev vs) ^ "]")
          fun showPos (k, v) = p (k ^ " = " ^ v)
        in
          p ("command: " ^ command);
          List.app showKV options;
          List.app showPos positionals;
          (case leftovers of [] => () | xs => (p "--- leftovers ---"; List.app p xs))
        end
    in
      if wantsHelp then (
        showHelp ();
        OS.Process.exit OS.Process.success
      ) else (
        emitResult (parse argv);
        OS.Process.exit OS.Process.success
      )
    end
    handle Clide.ArgError msg => (
      print ("Error: " ^ msg ^ "\n\n");
      print (Clide.helpWithDocs usage docs);
      OS.Process.exit OS.Process.failure
    )
end

val _ = Main.run ()
