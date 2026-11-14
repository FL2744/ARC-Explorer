# Third-party software

ARC Explorer includes SwiftTerm, version 1.20.0, commit `5d14406844143538cd8f8851d2d8a67c1fe443e5`.

- Upstream: https://github.com/migueldeicaza/SwiftTerm/tree/v1.20.0
- License: MIT; full notice in `Vendor/SwiftTerm/LICENSE` and in the distributed app's Resources folder.
- Local change: remote clipboard-read requests return no clipboard contents in `MacLocalTerminalView.swift`. User-initiated paste remains available.
- The complete vendored tree is included without its development Git metadata. Swift package dependency resolutions are retained.

The application also uses Apple system frameworks and the macOS SSH executable, supplied by the operating system. The remote helper uses the Python standard library on the remote host. Slurm, Git, Git LFS, site modules, and ARC services are remote prerequisites, not bundled software.

The technical report uses the ACM `acmart` class and ACM reference style, resolved by the TeX toolchain. Using this format does not imply ACM publication or endorsement.
