# Contributing

Small, focused pull requests are best.

1. Open an issue first for anything large.
2. Branch from `main`. Keep the change to one thing.
3. Use [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `docs:`, `chore:`. The release notes are built from them.
4. Run the checks:

   ```sh
   scripts/check.sh
   swift test
   ```

5. Open a PR. Fill in the short template. PRs are squash-merged.

## Rules

- Every source file starts with the SPDX header. `scripts/check.sh` enforces it.
- No raster images. Draw it or use an SF Symbol.
- No network code. No third-party runtime dependencies without a discussion first.
- Anything that deletes needs a test that proves it cannot leave the safe zones.
- Write docs in short, plain sentences.

New Clean targets are a JSON file, no Swift. See [add a Clean rule](docs/how-to/add-a-clean-rule.md).

By contributing you agree your work is released under the [MIT license](LICENSE).
