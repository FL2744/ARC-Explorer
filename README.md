<img src="Resources/ARCExplorer.png" alt="ARC Explorer app icon" width="180" />

# ARC Explorer v0.1

**One workspace for ARC.** A native macOS front end for Virginia Tech Advanced Research Computing.

Important: this is not an official project that is supported by Virginia Tech or VT ARC. 

## Download the full app

**[Download ARC Explorer v0.1 for macOS — signed and notarized](https://github.com/FL2744/ARC-Explorer/releases/download/v0.1/ARC-Explorer-v0.1-macOS-arm64.zip)**

[Hugging Face mirror](https://huggingface.co/will-taggart/ARC-Explorer/resolve/main/downloads/ARC-Explorer-v0.1-macOS-arm64.zip?download=true) · [All release files](https://github.com/FL2744/ARC-Explorer/releases/tag/v0.1) · [Checksums](https://github.com/FL2744/ARC-Explorer/releases/download/v0.1/SHA256SUMS.txt)

Apple Silicon · macOS 15+ · approximately 1.9 MB compressed. Unzip the download, drag **ARC-Explorer.app** into Applications, and open it. The archive includes the complete native app and terminal library; no separate local Python installation or model weights are needed.

Developer ID signed, accepted by Apple's notarization service, and stapled. [Release verification](RELEASE_STATUS.md).

<div align="left">

**Technical paper:** [PDF](paper/ARC-Explorer.pdf) · [LaTeX](paper/ARC-Explorer.tex) · [Markdown](paper/TECHNICAL_PAPER.md) · [references](paper/references.bib)

</div>

## Five sections

| Section | Features |
| --- | --- |
| **01 Connection** | Saved TinkerCliffs, Falcon, Owl, and custom SSH profiles; key/agent or password + Duo authentication; native prompts; light and dark modes. |
| **02 Resources** | Live availability, allocation and quota reports, date-filtered job accounting, ARC dashboards, remote file browser, upload/download, and a lightweight UTF-8 editor. |
| **03 Jobs + software** | Explicit GPU/CPU/memory/time/account requests, editable scripts, save on Mac or ARC, Slurm submission and monitoring, logs and cancellation, GitHub/Hugging Face retrieval scripts, module discovery. |
| **04 Sessions** | Full-width interactive login-node terminal, embedded Web/Jupyter views, bookmarks, system-browser option, and loopback SSH tunnels to existing compute-node services. |
| **05 Help** | Copyable command reference and optional ARC-hosted LLM assistance, live model discovery, optional macOS Keychain API-key storage. |

## Requirements

- Apple Silicon Mac with **macOS 15 or later**. Intel binaries are not included.
- An ARC account and network access; use the VT VPN when required.
- Appropriate Slurm allocation and partition access for jobs.
- Remote Python 3 for the bounded management helper; remote Git and Git LFS for relevant repository operations.
- Optional ARC API key for LLM help.

The downloadable app uses native Apple frameworks and the system SSH client. **No separate local Python installation or external browser is required for the native workspace.** An external browser is available as a fallback for web services. No LLM weights are bundled; this Hugging Face repository distributes desktop software, not a model.

## Workflow

1. Connect with your cluster profile and complete SSH/Duo prompts.
2. Check live resources and allocation usage.
3. Set an allowed account, GPU partition, wall time, GPUs, CPUs, and memory. Review the script and submit it.
4. Inspect jobs and logs, edit small remote files, or open Sessions.
5. Use Help to inspect commands or ask an ARC-hosted model for advice.

**Login node is not for compute intensive jobs.** The built-in terminal is a real login-node shell and does not request a GPU. Use allocated compute resources for intensive work. The remote management helper runs briefly on the login host; site policy remains authoritative. See [ARC guidance](https://www.docs.arc.vt.edu/usage/abuse.html).

Saving a script never submits it. Resource settings are configured separately from saved script text. Closing the app does not cancel Slurm jobs. Closing an SSH tunnel does not stop the underlying service or allocation.

## Files, software, and data boundaries

The file editor supports ordinary owned UTF-8 files up to 1 MiB and checks for remote changes before saving. Upload/download is limited to 8 MiB per file. This is not a bulk transfer client. The editor rejects links and unsupported metadata rather than silently discarding them.

GitHub/Hugging Face controls generate reviewable retrieval scripts. They check checkout origin and local modifications and do not automatically execute a repository's setup code. Private repositories require credentials on ARC; local tokens are not copied there.

The LLM assistant sends only the typed question and a general help instruction to the selected HTTPS endpoint. Files, logs, and SSH credentials are not automatically attached. Responses never execute commands. Model availability and account permissions are determined by ARC.

## Build and test

Install Xcode command-line/build tools on an Apple Silicon Mac. The complete SwiftTerm source and its license are vendored.

```sh
bash build.sh dist/ARC-Explorer.app
python3 -m unittest discover -s Tests -p 'test_*.py' -v
swift test --build-system native -c release --filter TerminalTests
```

The ordinary build is ad hoc signed for development. For a distributable build, use your own Developer ID Application certificate and an existing notarytool Keychain profile:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-profile-name' bash scripts/release.sh
```

The script signs with hardened runtime, waits for Apple acceptance, staples the ticket, checks Gatekeeper assessment, and packages the ZIP. Credentials are never included in the source repository.

## Documentation and scope

- [Technical report and five screenshots](paper/README.md)
- [Validation and known limits](VALIDATION.md)
- [Third-party notices](THIRD_PARTY.md)
- [MIT license](LICENSE)
- [ARC documentation](https://www.docs.arc.vt.edu/)
- [ARC dashboards](https://dashboard.arc.vt.edu/dashboards?kiosk)

Experimental independent research software; not an official ARC product. The form currently supports single-node GPU jobs. Availability, policies, service compatibility, and model offerings can change. The macOS 15 deployment target has not been separately runtime-tested on every supported release.

**Author:** William Taggart · Modern and Classical Languages and Literatures · Virginia Tech · wtaggart@vt.edu.

Development and documentation were assisted by GPT-6 Astra and Codex. The full disclosure appears immediately before the technical report's references.
