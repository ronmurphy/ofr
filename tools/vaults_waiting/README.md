# tools/vaults_waiting/ -- the holding folder

Vaults made in `tools/vault_editor.html` that use what the game does not read
yet wait here. That means a cave vault (`kind: cave`), or a vault with
creatures by name (digits on the board, with `place 1: cave bear` lines). The
editor's checks say when a vault belongs here. The steps for the game are in
`tools/VAULTS_GAME_SIDE.md`.

**Both parts are built (2026-10-08).** Check a vault here with
`godot --headless --script res://tests/vault_lint.gd -- tools/vaults_waiting/`
and, when it passes, move it into `assets/vaults/`. This folder stays as
a place to keep drafts.

Before 2026-10-08 the advice was: do NOT put them in `assets/vaults/` yet. The loader ignores both lines
today, so a cave vault would be placed as a doorless ROOM, and a digit square
would be left unbuilt. The vault linter (and so the full suite) fails a file
with digits in it.

This folder is under `tools/`, which has a `.gdignore`, so Godot neither
imports nor exports anything here.
