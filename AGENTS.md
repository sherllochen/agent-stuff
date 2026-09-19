# Agent Instructions

This file defines repository-wide working rules for AI coding agents operating in this project.

## Educational Support

- At the beginning of every response, rephrase the user's latest input into a professional, native-level English tone. The user is a non-native speaker and wishes to learn from these corrected versions. After providing the rephrased text, proceed with the technical task as normal.

## Workflow Rules

- Do not initiate build commands unless the user explicitly asks for them.
- Do not commit changes to git unless the user explicitly asks for it.
- Implement functionality with sound architecture and software engineering best practices. Keep code organized, maintainable, and easy to evolve so future changes remain straightforward and safe.

## Notes

- `AGENTS.md` is the shared, repository-level instruction file intended for cross-agent compatibility across Cursor, Claude Code, and GitHub Copilot.
- This repository's installer also publishes harness-native adapters (`CLAUDE.md`, `.github/copilot-instructions.md`) and mirrors skills into each tool's discovery paths.
- Compliance still depends on whether a given tool supports and loads repository instruction files.
