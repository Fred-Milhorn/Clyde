structure CliHelp =
struct
  open CliSpec

  (* --- pretty back into Usage-ish strings --- *)
  fun showAtom (Lit s) = s
    | showAtom (OptBool {long,short}) =
        (case (short,long) of
           (SOME s, SOME l) => "["^s^"|"^l^"]"
         | (SOME s, NONE) => "["^s^"]"
         | (NONE, SOME l) => "["^l^"]"
         | _ => "[]")
    | showAtom (OptVal {long,short,ty,default,allowRepeat}) =
        let
          val name = case (short,long) of
                       (SOME s, _) => s
                     | (_, SOME l) => l
                     | _ => "--?"
          val t = CliSpec.tyToString ty
          val d = case default of SOME s => ":"^s | NONE => ""
          val plus = if allowRepeat then "+" else ""
        in "["^name^"="^t^d^plus^"]" end
    | showAtom (Pos {name,ty,default}) =
        let val t = CliSpec.tyToString ty
            val d = case default of SOME s => ":"^s | NONE => ""
        in "<"^name^":"^t^d^">" end

  fun showGroup (Single a) = showAtom a
    | showGroup (Alt xs) = "[" ^ String.concatWith "|" (List.map showAtom xs) ^ "]"

  fun showItem (Required g) = showGroup g
    | showItem (Optional g) = "[" ^ showGroup g ^ "]"

  (* Render Usage block *)
  fun render (Spec {commands, ...}) =
    let
      fun lineOf (Command {name, items}) =
        "  " ^ name ^ " " ^ String.concatWith " " (List.map showItem items) ^ "\n"
    in
      "Usage:\n" ^ String.concat (List.map lineOf commands)
    end

  (* ------- Docs section ------- *)

  (* Merge short/long into a single display key; include type/default inline *)
  fun keyStringOfAtom (OptBool {long, short}) =
        (case (short, long) of
           (SOME s, SOME l) => s ^ ", " ^ l
         | (SOME s, NONE) => s
         | (NONE, SOME l) => l
         | _ => "--?")
    | keyStringOfAtom (OptVal {long, short, ty, default, allowRepeat}) =
        let
          val base =
            (case (short, long) of
               (SOME s, SOME l) => s ^ ", " ^ l
             | (SOME s, NONE) => s
             | (NONE, SOME l) => l
             | _ => "--?")
          val t = CliSpec.tyToString ty
          val d = (case default of SOME s => ":" ^ s | NONE => "")
          val plus = if allowRepeat then "+" else ""
        in base ^ "=" ^ t ^ d ^ plus end
    | keyStringOfAtom (Pos {name, ty, default}) =
        let
          val t = CliSpec.tyToString ty
          val d = (case default of SOME s => ":" ^ s | NONE => "")
        in "<" ^ name ^ ":" ^ t ^ d ^ ">" end
    | keyStringOfAtom (Lit s) = s

  fun atomsOfGroup (Single a) = [a]
    | atomsOfGroup (Alt xs) = xs
  fun atomsOfItem (Required g) = atomsOfGroup g
    | atomsOfItem (Optional g) = atomsOfGroup g

  fun synthLine a =
    case a of
      Lit _ => (keyStringOfAtom a, "command")
    | OptBool _ => (keyStringOfAtom a, "boolean flag")
    | OptVal {ty, default, allowRepeat, ...} =>
        let
          val t = CliSpec.tyToString ty
          val d = (case default of SOME s => " (default " ^ s ^ ")" | NONE => "")
          val rep = if allowRepeat then " (repeatable)" else ""
        in (keyStringOfAtom a, "value option " ^ t ^ d ^ rep) end
    | Pos {ty, default, ...} =>
        let
          val t = CliSpec.tyToString ty
          val d = (case default of SOME s => " (default " ^ s ^ ")" | NONE => "")
        in (keyStringOfAtom a, "positional " ^ t ^ d) end

  fun nodup ((k,v), acc) =
    if List.exists (fn (k',_) => k'=k) acc then acc else (k,v)::acc

  (* Synthesize doc entries from the spec *)
  fun synthDocs (Spec {commands,...}) =
    let
      fun accCmd (Command {items,...}, acc) =
        let
          val atoms = List.concat (List.map atomsOfItem items)
          val lines = List.map synthLine atoms
          (* Include leading command literal if present *)
          val acc1 =
            case items of
              (Required (Single (Lit s)))::_ => nodup ((s, "command"), acc)
            | _ => acc
        in List.foldl nodup acc1 lines end
    in List.foldl accCmd [] commands end

  (* Merge user docs over synthesized ones. User keys should match keyStringOfAtom or command literals. *)
  fun mergeDocs user synth =
    let
      fun lookup k = List.find (fn (k',_) => k'=k) user
      fun choose (k,autov) =
        case lookup k of SOME (_,desc) => (k, desc) | NONE => (k, autov)
    in List.map choose synth end

  (* Column-aligned rendering *)
  fun renderDocs pairs =
    case pairs of
      [] => ""
    | _ =>
        let
          val maxLen = List.foldl (fn ((k,_), acc) => Int.max (String.size k, acc)) 0 pairs
          fun padRight s =
            let val n = String.size s
            in if n >= maxLen then s else s ^ String.implode (List.tabulate (maxLen - n, fn _ => #" ")) end
          fun line (k,v) = "  " ^ padRight k ^ "  -  " ^ v ^ "\n"
        in
          "Options & Arguments:\n" ^
          String.concat (List.map line pairs)
        end

  fun renderWithDocs (spec, userDocs:(string*string) list) =
    let
      val usage = render spec
      val synth = synthDocs spec
      val merged = mergeDocs userDocs synth
    in usage ^ "\n" ^ renderDocs merged end
end
