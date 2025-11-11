signature CLI_DERIVE =
sig
  exception SpecError of string
  exception ArgError of string

  datatype ty = TInt | TBool | TStr | TPath

  type result = {
    command : string,
    options : (string * string list) list,
    positionals : (string * string) list,
    leftovers : string list
  }

  (* Given usage lines, return an argv -> result parser *)
  val fromUsageLines : string list -> (string list -> result)

  (* Render help from usage lines *)
  val helpOf : string list -> string
  val helpWithDocs  : string list -> (string * string) list -> string
end

structure Clide :> CLI_DERIVE =
struct
  structure S = CliSpec
  structure P = CliSpecParser
  structure R = CliRuntime
  structure H = CliHelp

  exception SpecError of string
  exception ArgError = R.ArgError

  datatype ty = datatype S.ty
  type result = R.result

  fun parseSpec lines =
    P.fromLines lines
    handle P.Parse msg => raise SpecError msg

  fun fromUsageLines lines =
    let
      val spec = parseSpec lines
    in
      fn argv =>
        let
          val cmd = R.chooseCommand spec argv
        in
          R.parseWith cmd argv
        end
    end

  fun helpOf lines =
    let
      val spec = parseSpec lines
    in
      H.render spec
    end

  fun helpWithDocs lines docs =
    let
      val spec = parseSpec lines
    in
      H.renderWithDocs (spec, docs)
    end
end
