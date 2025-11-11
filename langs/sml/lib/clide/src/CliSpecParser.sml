structure CliSpecParser =
struct
  open CliSpec
  exception Parse of string

  fun isSpace c =
    c = #" " orelse c = #"\t" orelse c = #"\r" orelse c = #"\n"
  fun splitWords s =
    let
      fun loop (i, acc, cur) =
        if i >= size s then
          let val tok = String.implode (List.rev cur)
          in List.rev (if tok = "" then acc else tok::acc) end
        else
          let val ch = String.sub (s,i) in
            if isSpace ch then
              let val tok = String.implode (List.rev cur)
              in loop (i+1, if tok = "" then acc else tok::acc, []) end
            else loop (i+1, acc, ch::cur)
          end
    in loop (0, [], []) end

  fun parseTy "INT" = TInt
    | parseTy "BOOL" = TBool
    | parseTy "STR" = TStr
    | parseTy "PATH" = TPath
    | parseTy t = raise Parse ("Unknown type: "^t)

  fun trimAngles s =
  if size s >= 2 andalso String.sub (s, 0) = #"<" andalso String.sub (s, size s - 1) = #">"
  then String.extract (s, 1, SOME (size s - 2))
    else raise Parse ("Expected <...>: "^s)

  fun splitOnce (s, ch) =
    case String.fields (fn c => c = ch) s of
      [a,b] => SOME (a,b)
    | _ => NONE

  fun isShort s = size s = 2 andalso String.sub (s, 0) = #"-" andalso String.sub (s, 1) <> #"-"
  fun isLong s = size s >= 3 andalso String.sub (s, 0) = #"-" andalso String.sub (s, 1) = #"-"

  fun parseOption tok =
    let
      val (namePart, valPart) =
        case splitOnce (tok, #"=") of
          SOME (n,v) => (n, SOME v)
        | NONE => (tok, NONE)
      val (longOpt, shortOpt) =
        if isLong namePart then (SOME namePart, NONE)
        else if isShort namePart then (NONE, SOME namePart)
        else raise Parse ("Bad option: "^tok)
    in
      case valPart of
        NONE => OptBool { long = longOpt, short = shortOpt }
      | SOME v =>
          let
            val allowRepeat = size v > 0 andalso String.sub (v, size v - 1) = #"+"
            val core = if allowRepeat then String.extract (v, 0, SOME (size v - 1)) else v
            val (tys, def) =
              case splitOnce (core, #":") of
                SOME (tyS, d) => (tyS, SOME d)
              | NONE => (core, NONE)
            val ty = parseTy tys
          in
            OptVal { long = longOpt, short = shortOpt, ty = ty, default = def, allowRepeat = allowRepeat }
          end
    end

  fun parsePos tok =
    let
      val inside = trimAngles tok
      val parts = String.fields (fn c => c = #":") inside
    in
      case parts of
        [nm, tys] => Pos { name = nm, ty = parseTy tys, default = NONE }
      | [nm, tys, def] => Pos { name = nm, ty = parseTy tys, default = SOME def }
      | _ => raise Parse ("Bad positional: "^tok)
    end

  fun parseGroupToken t =
    if size t > 0 andalso String.sub (t, 0) = #"[" andalso String.sub (t, size t - 1) = #"]"
    then
      let
        val inner = String.extract (t, 1, SOME (size t - 2))
        val alts = String.fields (fn c => c = #"|") inner
        fun atomOf a =
          if size a > 0 andalso String.sub (a, 0) = #"<" then parsePos a
          else if isLong a orelse isShort a orelse Option.isSome (splitOnce (a, #"=")) then parseOption a
          else Lit a
      in
        Optional
          (if List.length alts = 1 then Single (atomOf (hd alts))
           else Alt (List.map atomOf alts))
      end
    else
      let
        val atom =
          if size t > 0 andalso String.sub (t, 0) = #"<" then parsePos t
          else if isLong t orelse isShort t orelse Option.isSome (splitOnce (t, #"=")) then parseOption t
          else Lit t
      in Required (Single atom) end

  fun parseUsageLine line =
    let
      val ws = splitWords line
      val () =
        if List.length ws >= 2 andalso hd ws = "Usage:" then ()
        else raise Parse "Line must start with 'Usage:'"
      val prog = List.nth (ws, 1)
      val rest = List.drop (ws, 2)
      val items = List.map parseGroupToken rest
    in (prog, items) end

  fun fromLines lines =
    let
      val parsed = List.map parseUsageLine lines
      val prog =
        case parsed of [] => raise Parse "No usage lines" | (p, _)::_ => p

      fun firstLitAfterProg items =
        let
          fun pick (Required (Single (Lit s))) = SOME s
            | pick (Required (Alt (Lit s :: _))) = SOME s
            | pick _ = NONE
        in
            let
              fun loop [] = NONE
                | loop (x::xs) =
                    (case pick x of
                       SOME s => SOME s
                     | NONE => loop xs)
            in
              loop items
            end
        end

      fun mkCommand (_, items) =
        Command { name = Option.getOpt (firstLitAfterProg items, "_"), items = items }

      val commands = List.map mkCommand parsed
    in Spec { prog = prog, commands = commands } end
end
