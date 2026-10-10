# Sprites: the 3D view's pixel look

These are the ORIGINAL art set's map cards. Press `v` in a 3D view to
switch between the icon pictures, these drawings and the other art sets
(`assets/skins/README.md`). Each press re-reads the folders, so a sprite
saved here shows on the next press without restarting the game.

- **One file per look, named after it.** `wolf.txt` is every wolf,
  `meat.txt` every haunch, `player.txt` you. The game finds a sprite by its
  file name, so a file named after anything else is never seen (the suite
  says so). `creatures/`, `items/` and `features/` are only for tidiness.
- **Terrain features** (braziers, stairs, the fungi, the web...) are drawn
  only where a file exists here; the rest keep their pictures. They never
  get starters.
- **Draw them in `tools/sprite_editor.html`.** Open a file here, draw over
  it, save it back under the same name. "From the game" starts a look from
  its icon, on its own canvas, already named.
- **Every file here was drawn by hand (2026-10-09).** For a new creature
  or item, `tools/make_starter_sprites.py` makes a STARTER from the game's
  icon, never overwriting a file. A starter's first line says so, and the
  editor drops that line when it saves, so this lists the hand-drawn ones:
  `grep -L "^# starter" -r assets/sprites`.
- **Colour still says whose side it is on.** A drawing may carry variants
  named `ally`, `corrupted` and `magic`. Without one, the game tints the
  drawing in that state's colour.
- **No `.txt` here that is not a sprite.** This note is Markdown for that
  reason. Every `.txt` here ships in the exports.
