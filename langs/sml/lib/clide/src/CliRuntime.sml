structure CliRuntime =
struct
  open CliSpec
  exception ArgError of string

  fun parseVal TInt s =
        (case Int.fromString s of SOME _ => s | NONE => raise ArgError ("Expected INT, got: "^s))
    | parseVal TBool s =
        (case String.map Char.toLower s of
           "true" => "true" | "false" => "false"
         | _ => raise ArgError ("Expected BOOL (true|false), got: "^s))
    | parseVal TStr s = s
    | parseVal TPath s = s

  type result = {
    command : string,
    options : (string * string list) list,
    positionals : (string * string) list,
    leftovers : string list
  }

  fun addOpt (k, v, m) =
    let
      fun go [] = [(k, [v])]
        | go ((k',vs)::xs) =
            if k'=k then (k', v::vs)::xs else (k',vs)::go xs
    in go m end

  fun setPos (k, v, m) = (k, v)::m

  fun parseWith (Command { name, items }) argv =
    let
      val seq : (bool * group) list =
        List.map (fn item => case item of Required g => (false, g) | Optional g => (true, g)) items

      fun atomsOf (Single a) = [a] | atomsOf (Alt as_) = as_
      val atoms = List.concat (List.map (fn (_,g) => atomsOf g) seq)

      val knownOpts =
        let
          fun add (OptBool {long, short}, acc) =
                let
                  val acc1 = (case long of SOME l => l :: acc | NONE => acc)
                in
                  (case short of SOME s => s :: acc1 | NONE => acc1)
                end
            | add (OptVal {long, short, ...}, acc) =
                let
                  val acc1 = (case long of SOME l => l :: acc | NONE => acc)
                in
                  (case short of SOME s => s :: acc1 | NONE => acc1)
                end
            | add (_, acc) = acc
        in
          List.foldl add [] atoms
        end

      val posList : { default : string option, name : string, ty : CliSpec.ty } list =
        List.mapPartial
          (fn Pos { default = posDefault, name = posName, ty = posTy, ... } =>
                SOME { default = posDefault, name = posName, ty = posTy }
            | _ => NONE)
          atoms

      fun loop (args, optsMap, posMap, seenPos) =
        case args of
          [] => (optsMap, posMap, seenPos, [])
        | ("--"::rest) =>
            let
              fun assignPos ([], pm, sp, rem) = (optsMap, pm, sp, rem)
                | assignPos (r::rs, pm, sp, rem) =
                    case rem of
                      [] =>
                        (case #default r of
                           SOME d => assignPos (rs, setPos (#name r, d, pm), sp + 1, [])
                         | NONE => raise ArgError ("Missing positional: " ^ (#name r)))
                    | x::xs => assignPos (rs, setPos (#name r, parseVal (#ty r) x, pm), sp + 1, xs)
            in assignPos (List.drop (posList, seenPos), posMap, seenPos, rest) end
        | (a::rest) =>
            if size a > 0 andalso String.sub (a, 0) = #"-" then
              let
                val (namePart, valPart) =
                  case String.fields (fn c => c = #"=") a of
                    [n,v] => (n, SOME v)
                  | _ => (a, NONE)
                val () = if List.exists (fn k => k = namePart) knownOpts
                         then () else raise ArgError ("Unknown option: "^namePart)
                val optDecl =
                  case List.find (fn opt =>
                                      case opt of
                                        OptVal {long, short, ...} =>
                                          (SOME namePart = long) orelse (SOME namePart = short)
                                      | OptBool {long, short} =>
                                          (SOME namePart = long) orelse (SOME namePart = short)
                                      | _ => false) atoms of
                    SOME opt => opt
                  | NONE => raise ArgError "Unknown option declaration"
              in
                case optDecl of
                  OptBool _ =>
                    loop (rest, addOpt (namePart, "true", optsMap), posMap, seenPos)
                | OptVal {ty, ...} =>
                    (case valPart of
                       SOME v => loop (rest, addOpt (namePart, parseVal ty v, optsMap), posMap, seenPos)
                     | NONE =>
                         (case rest of
                            v::rest' => loop (rest', addOpt (namePart, parseVal ty v, optsMap), posMap, seenPos)
                          | [] => raise ArgError ("Missing value for "^namePart)))
                | _ => raise ArgError "impossible"
              end
            else
              let
                fun consumeLit [] = NONE
                  | consumeLit ((_, g)::xs) =
                      (case g of
                         Single (Lit s) => if a = s then SOME xs else consumeLit xs
                       | Alt alts =>
                           let val ms = List.filter (fn at => case at of Lit s => s = a | _ => false) alts
                           in case ms of [] => consumeLit xs | _ => SOME xs end
                       | _ => consumeLit xs)
              in
                case consumeLit seq of
                  SOME _ => loop (rest, optsMap, posMap, seenPos)
                | NONE =>
                    let
                      val r =
                        (List.nth (posList, seenPos)
                         handle _ => raise ArgError ("Unexpected argument: " ^ a))
                    in
                      loop (rest, optsMap, setPos (#name r, parseVal (#ty r) a, posMap), seenPos + 1)
                    end
              end
  val (optsMap, posMap, _, leftovers) = loop (argv, [], [], 0)

      fun addOptDefault (OptVal {long, short, ty, default, ...}, acc) =
            let
              val key = case long of SOME k => k | NONE => valOf short
            in
              case default of
                NONE => acc
              | SOME d =>
                  if List.exists (fn (k, _) => k = key) acc then acc
                  else (key, [parseVal ty d]) :: acc
            end
        | addOptDefault (OptBool {long, short}, acc) =
            let
              val key = case long of SOME k => k | NONE => valOf short
            in
              if List.exists (fn (k, _) => k = key) acc then acc
              else (key, ["false"]) :: acc
            end
        | addOptDefault (_, acc) = acc

      val optsWithDefaults = List.foldl addOptDefault optsMap atoms

      fun addPosDefault (Pos {name = posName, ty, default}, acc) =
            if List.exists (fn (k, _) => k = posName) acc then acc
            else
              (case default of
                 SOME d => (posName, parseVal ty d) :: acc
               | NONE => raise ArgError ("Missing positional: " ^ posName))
        | addPosDefault (_, acc) = acc

      val posComplete =
        List.foldl addPosDefault posMap atoms

    in { command = name, options = optsWithDefaults, positionals = posComplete, leftovers = leftovers } end

  fun chooseCommand (Spec {commands, ...}) argv =
    let
      fun firstLiteral (Command {items, ...}) =
        let
          fun loop [] = NONE
            | loop (Required (Single (Lit s)) :: _) = SOME s
            | loop (Required (Alt (Lit s :: _)) :: _) = SOME s
            | loop (_ :: xs) = loop xs
        in
          loop items
        end

      fun matchesCommand (Command {items, ...}) arg =
        case firstLiteral (Command {name = "_", items = items}) of
          SOME lit => lit = arg
        | NONE => false
    in
      case argv of
        [] => List.hd commands
      | arg :: _ =>
          (case List.find (fn cmd => matchesCommand cmd arg) commands of
             SOME cmd => cmd
           | NONE => List.hd commands)
    end
end
