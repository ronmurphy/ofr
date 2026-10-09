# Sprites: the 3D view's pixel look

Press `v` in a 3D view to switch the cards between the icon pictures and
these drawings. Each press re-reads this folder, so a sprite saved here
shows on the next press without restarting the game.

- **One file per look, named after it.** `wolf.txt` is every wolf,
  `meat.txt` every haunch, `player.txt` you. The game finds a sprite by its
  file name, so a file named after anything else is never seen (the suite
  says so). `creatures/` and `items/` are only for tidiness.
- **Draw them in `tools/sprite_editor.html`.** Open a file here, draw over
  it, save it back under the same name. "From the game" starts a look from
  its icon, on its own canvas, already named.
- **The starters** are the game's icons drawn onto the grid by
  `tools/make_starter_sprites.py`. Each one's first line says so. The
  editor drops that line when it saves, so this lists the hand-drawn ones:
  `grep -L "^# starter" -r assets/sprites`. The script never overwrites a
  file.
- **Colour still says whose side it is on.** A drawing may carry variants
  named `ally`, `corrupted` and `magic`. Without one, the game tints the
  drawing in that state's colour.
- **No `.txt` here that is not a sprite.** This note is Markdown for that
  reason. Every `.txt` here ships in the exports.
