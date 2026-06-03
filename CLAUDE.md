# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build                          # Build the package
swift test                           # Run all tests
swift test --filter <TestClassName>  # Run a single test class
```

## Architecture

This is a Swift Package Manager library targeting iOS 17+, written in Swift 6 strict concurrency mode.

**`AutoPreviewable` protocol** (`Sources/AutoPreview/AutoPreviewable.swift`): A SwiftUI-focused protocol that decouples preview data from view construction. Conforming types provide:
- `previewData: [String: PTD]` — a keyed dictionary of typed data stubs
- `previewBuilder(_ data: PTD) -> PV` — a `@ViewBuilder` that renders a view from a stub

The default `generatePreviews()` implementation iterates `previewData` keys in sorted order and wraps each result in `.previewDisplayName("<ViewType> / <key>")`, producing named Xcode previews automatically.

## Pre-commit Hook

The hook at `.git/hooks/pre-commit` sources linter functions from `~/.vc/hook-functions/`. It runs sanity checks (email, binary files) and linters against staged (or all) files. To skip specific linters, set `git config user.pre-commit-hook.skippedLinters <name>`. To lint only staged changes, set `git config user.pre-commit-hook.lintChangesOnly true`.
