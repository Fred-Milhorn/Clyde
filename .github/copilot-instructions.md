# Clide AI Guide
## Architecture
- `lib/clide/src` houses the library; `src/Main.sml` demonstrates wiring usage lines, docs, and `Clide.fromUsageLines`.
- `lib/clide/src/Clide.sml` seals `structure Clide` under `signature CLI_DERIVE`, funnelling parse errors to `SpecError` and runtime issues to `ArgError`.
- Specs flow: Usage lines → `CliSpecParser.fromLines` → `CliSpec.Spec`, then `CliRuntime.chooseCommand`/`parseWith` turns argv into `{command, options, positionals, leftovers}`.
- Help generation reuses the spec via `CliHelp.renderWithDocs`, which aligns keys and merges user docs.

## Parsing & Spec Semantics
- Usage lines must start with `Usage:` and share the same program token; see `docs/USAGE.md` and `src/Main.sml`.
- `CliSpecParser` interprets `[optional]`, `<name:TYPE>`, `-s|--long`, `:default`, and `+` repeaters; unsupported tokens raise `SpecError`.
- Option atoms become `OptBool` or `OptVal`, with long/short names preserved for later display.
- Commands are inferred from the first required literal after the program name; missing literals default to `_`.

## Runtime Behaviour
- `CliRuntime.chooseCommand` picks a command whose leading literal matches `argv`, otherwise falls back to the first command.
- `CliRuntime.parseWith` validates option/positional types immediately (`INT`, `BOOL`, `STR`, `PATH`) and accumulates option values as `(string * string list)` to support repeats.
- Boolean flags default to `"false"`; value options and positionals respect defaults declared in the usage string.
- `--` forces remaining args into `leftovers`; unknown options or arity mismatches raise `ArgError`.

## Help & Docs
- `CliHelp.render` regenerates Usage output; `renderWithDocs` merges synthesized descriptions with caller-provided docs keyed exactly like `CliHelp.keyStringOfAtom`.
- Demo docs in `src/Main.sml` show canonical keys (`"-v, --verbose"`, `"serve"`, `<dir:PATH>`); mismatched keys fall back to synthesized copy.
- Keep `docs/USAGE.md` in sync with real usage lines so reference documentation stays accurate.

## Build & Tooling
- `Project.toml` drives build configuration; `tools/toml2mk.py` emits `build/vars.mk` consumed by `Makefile`.
- `make dev|prod` compiles profiles configured in `Project.toml`; `make run BIN=clide-demo PROFILE=dev ARGS='--help'` executes a chosen binary.
- MLB files under `mlb/` wrap Basis first, then `lib/clide/clide.mlb`, then local sources; new modules belong in the library MLB if they should ship with the shared code.
- `millet.toml` points Millet at `mlb/clide-demo-prod.mlb` for static checks; rerun Millet after editing MLB topology.

## Dependency Notes
- `lib/clide/smlpkg.toml` advertises the shared library; update `sources` if files move so `smlpkg` consumers stay current.
- External Python dependency is `tomli`/`tomllib` for the build script; ensure it is available when running `make`.
- Maintain ASCII in generated help to avoid layout drift in `CliHelp.renderDocs`.