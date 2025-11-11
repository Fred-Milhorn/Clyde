structure Expect =
struct
  exception Failure of string

  fun fail msg = raise Failure msg

  fun that (cond, msg) =
    if cond then () else fail msg

  fun equalWith (toString, expected, actual, label) =
    if actual = expected then ()
    else
      let
        val expectedStr = toString expected
        val actualStr = toString actual
        val details = label ^ " expected " ^ expectedStr ^ " but got " ^ actualStr
      in
        fail details
      end

  fun equalString (expected, actual, label) =
    equalWith (fn s => "\"" ^ s ^ "\"", expected, actual, label)

  fun equalStringList (expected, actual, label) =
    let
      fun show xs =
        let
          val parts = List.map (fn s => "\"" ^ s ^ "\"") xs
        in
          "[" ^ String.concatWith ", " parts ^ "]"
        end
    in
      equalWith (show, expected, actual, label)
    end

  fun raises (thunk, matches, label) =
    (thunk (); fail (label ^ " expected an exception"))
    handle ex => if matches ex then () else fail (label ^ " raised unexpected exception")
end
