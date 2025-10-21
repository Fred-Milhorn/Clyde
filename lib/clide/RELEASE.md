# Release Process

1. Update version in `lib/clide/smlpkg.toml` and `CHANGELOG.md`.
2. Commit and tag:

   ```bash
   git add -A
   git commit -m "Release v0.1.0"
   git tag -a v0.1.0 -m "Clide v0.1.0"
   git push origin main --tags
   ```

3. (Optional) Publish to smlpkg registry:

   ```bash
   smlpkg publish --registry https://registry.smlpkg.io
   ```

4. Consumers can depend on the tag:

   ```toml
   [dependencies]
   clide = { git = "https://github.com/yourname/clide", tag = "v0.1.0" }
   ```
