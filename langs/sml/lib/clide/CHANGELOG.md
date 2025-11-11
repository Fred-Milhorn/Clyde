# Changelog

## [0.1.0] — 2025-10-09

### Added

- Initial release of **Clide** library.
- Converts Augmented POSIX `Usage:` lines into argv parsers.
- Supports boolean flags and typed options (`INT`, `BOOL`, `STR`, `PATH`), defaults via `:default`, repeatable options with `+`, alternations (`[-v|--verbose]`), typed positionals (`<dir:PATH>`), and pretty `--help` rendering.
- Includes `lib/clide/clide.mlb` and `smlpkg.toml` for integration.

## [0.1.3] — 2025-10-09

### Changed

- Help renderer now merges short/long options on one line (e.g., `-v, --verbose`).
- Two-column aligned documentation with dynamic width.
- Demo uses `helpWithDocs` to show aligned docs.

## [0.1.4] — 2025-10-09

### Documentation

- Added `docs/USAGE.md` with examples and integration notes (no code changes).
