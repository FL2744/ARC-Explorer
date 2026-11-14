# ARC Explorer v0.1 validation

Release test date: November 13, 2026 (America/New_York).

- Release build completed for arm64 with macOS 15.0 deployment target.
- `python3 -m unittest discover -s Tests -p 'test_*.py' -v`: 28 passed.
- `swift test --build-system native -c release --filter TerminalTests`: 2 passed.
- Real local pseudo-terminal test: input, 42 × 140 window dimensions, and process exit.
- Developer ID signatures on the main application and native askpass helper verified with strict recursive verification.
- Six actual UI screenshots included in `paper/figures`; all were captured from the signed release build. Screenshots are offline and do not constitute live cluster or API tests.

The current macOS host is newer than macOS 15. Compatibility is targeted by the deployment setting; this release has not been runtime-tested on every supported OS, every ARC cluster, all SSO/Jupyter flows, or every model API. No performance benchmark or independent security audit is claimed.

The Swift package toolchain warns that `--build-system native` is deprecated. It is currently used because the default build path requires additional Metal tooling. Two upstream SwiftTerm unused-result compiler warnings do not fail the build.

See `RELEASE_STATUS.md` for notarization and publication status. Signing alone is not notarization.
