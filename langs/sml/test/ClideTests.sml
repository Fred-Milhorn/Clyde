structure ClideTests =
struct
  open Expect

  val baseUsage = [
    "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
    "Usage: mytool init <path:PATH>"
  ]

  val docs = [
    ("serve", "Start the HTTP server"),
    ("init", "Initialize a project directory"),
    ("-v, --verbose", "Verbose logging"),
    ("--port=INT:8080", "TCP port"),
    ("--tls", "Enable TLS"),
    ("--root=PATH", "Document root"),
    ("<dir:PATH>", "Application directory"),
    ("<path:PATH>", "Project directory")
  ]

  fun lookupOption key opts =
    case List.find (fn (k, _) => k = key) opts of
      SOME (_, vs) => vs
    | NONE => Expect.fail ("Missing option " ^ key)

  fun lookupPos key pos =
    case List.find (fn (k, _) => k = key) pos of
      SOME (_, v) => v
    | NONE => Expect.fail ("Missing positional " ^ key)

  fun testServeParse () =
    let
      val parse = Clide.fromUsageLines baseUsage
      val result = parse [
        "serve",
        "--port", "9090",
        "--tls",
        "--root", "/srv/www",
        "-v",
        "/app",
        "--",
        "leftover"
      ]
      val _ = equalString ("serve", #command result, "command")
      val portVals = lookupOption "--port" (#options result)
      val _ = equalStringList (["9090"], List.rev portVals, "port option")
      val tlsVals = lookupOption "--tls" (#options result)
      val _ = equalStringList (["true"], List.rev tlsVals, "tls option")
      val dirVal = lookupPos "dir" (#positionals result)
      val _ = equalString ("/app", dirVal, "dir positional")
      val leftovers = #leftovers result
      val _ = equalStringList (["leftover"], leftovers, "leftovers")
    in
      ()
    end

  fun testServeDefaults () =
    let
      val parse = Clide.fromUsageLines baseUsage
      val result = parse ["serve", "/workdir"]
      val portVals = lookupOption "--port" (#options result)
      val _ = equalStringList (["8080"], List.rev portVals, "default port")
      val tlsVals = lookupOption "--tls" (#options result)
      val _ = equalStringList (["false"], List.rev tlsVals, "default tls")
      val verboseVals = lookupOption "--verbose" (#options result)
      val _ = equalStringList (["false"], List.rev verboseVals, "default verbose")
    in
      ()
    end

  fun testRepeatingOption () =
    let
      val usage = [
        "Usage: build [--include=PATH+] <dir:PATH>"
      ]
      val parse = Clide.fromUsageLines usage
      val result = parse [
        "--include", "src",
        "--include", "lib",
        "project"
      ]
      val _ = equalString ("_", #command result, "default command name")
      val includeVals = lookupOption "--include" (#options result)
      val _ = equalStringList (["src", "lib"], List.rev includeVals, "repeating include")
    in
      ()
    end

  fun testUnknownOption () =
    let
      val parse = Clide.fromUsageLines baseUsage
      val _ = raises (
        fn () => parse ["serve", "--bogus", "/app"],
        (fn Clide.ArgError _ => true | _ => false),
        "unknown option"
      )
    in
      ()
    end

  fun testSpecError () =
    raises (
      (fn () => Clide.fromUsageLines ["Usage: tool <unterminated"]),
      (fn Clide.SpecError _ => true | _ => false),
      "spec error"
    )

  fun testHelpOutput () =
    let
  val help = Clide.helpWithDocs baseUsage docs
  val _ = that (String.isSubstring "--port=INT:8080" help, "help includes port docs")
  val _ = that (String.isSubstring "-v" help, "help includes short verbose flag")
  val _ = that (String.isSubstring "--verbose" help, "help includes long verbose flag")
      val _ = that (String.isSubstring "serve" help, "help includes serve line")
    in
      ()
    end

  val tests : (string * (unit -> unit)) list = [
    ("parse serve", testServeParse),
    ("defaults", testServeDefaults),
    ("repeating option", testRepeatingOption),
    ("unknown option", testUnknownOption),
    ("spec error", testSpecError),
    ("help output", testHelpOutput)
  ]
end
