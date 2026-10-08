# tools/cave_vaults/ -- the holding folder

Cave vaults (`kind: cave`, made in `tools/vault_editor.html`) wait here until
the game reads that kind. The steps are in `tools/CAVE_VAULTS_GAME_SIDE.md`.

Do NOT put them in `assets/vaults/` before then: the loader ignores the
`kind:` line today, so a cave vault there would be placed as a doorless ROOM.

This folder is under `tools/`, which has a `.gdignore`, so Godot neither
imports nor exports anything here.
