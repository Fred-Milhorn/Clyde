structure TestMain =
struct
  open Expect

  fun runTest (name, thunk) =
    (thunk (); (name, NONE))
    handle Failure msg => (name, SOME msg)
         | ex => (name, SOME ("Unexpected exception: " ^ General.exnMessage ex))

  fun summarize results =
    let
      fun showResult (name, NONE) = "[PASS] " ^ name ^ "\n"
        | showResult (name, SOME msg) = "[FAIL] " ^ name ^ ": " ^ msg ^ "\n"
      val report = String.concat (List.map showResult results)
      val _ = TextIO.print report
      val failures = List.filter (fn (_, outcome) => Option.isSome outcome) results
    in
      if List.null failures then OS.Process.success else OS.Process.failure
    end

  fun main () =
    let
      val results = List.map runTest ClideTests.tests
      val status = summarize results
    in
      OS.Process.exit status
    end
end

val _ = TestMain.main ()
