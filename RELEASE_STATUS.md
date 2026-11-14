# ARC Explorer v0.1 release verification

- Version: 0.1.0 (build 4); release name **ARC Explorer v0.1**.
- Architecture: Apple Silicon (arm64).
- Minimum deployment target: macOS 15.0.
- Developer ID Application: William Taggart (HQSX3AJ8U7).
- Hardened runtime and secure timestamp enabled for the app and askpass helper.
- Apple notarization: **Accepted**.
- Submission ID: `71081a1c-3a09-4922-9705-f325413bf6d5`.
- Ticket stapled; `stapler validate` passed.
- Strict recursive code-signature verification passed.
- Gatekeeper assessment: accepted, source Notarized Developer ID.
- Release test suite: 28 Python tests and 2 native terminal tests passed.

The public release is [ARC Explorer v0.1 on GitHub](https://github.com/FL2744/ARC-Explorer/releases/tag/v0.1), mirrored on [Hugging Face](https://huggingface.co/will-taggart/ARC-Explorer). Checksums accompany the downloads. Apple notarization is not a functional certification of ARC workflows.
