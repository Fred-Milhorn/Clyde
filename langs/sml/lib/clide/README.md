# Clide (lib/clide)

Augmented POSIX Usage → argv parser for Standard ML (MLton)

Include in your MLB:

```sml
local
  $(SML_LIB)/basis/basis.mlb
  lib/clide/clide.mlb
in
  src/Main.sml
end
```

Usage in code:

```sml
val parse = Clide.fromUsageLines usage
val res = parse (CommandLine.arguments ())
```

See lib/clide/src for implementation.

Version: v0.1.0

Updated help: merged short/long flags on one line; aligned doc columns. Version: v0.1.3

Documentation update: usage specification is in ../../docs/specs/USAGE.md. Version: v0.1.4
