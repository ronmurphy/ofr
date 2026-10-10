# Art sets

The 3D view's pixel look can draw from more than one set of art. Press `v`
in a 3D view, or use the title's "3D art" setting: pictures, then each set
in turn, then pictures again. The choice is remembered.

## Where the art lives

| folder | what |
|---|---|
| `assets/sprites/` | **Original**: the map cards (`creatures/`, `items/`, `features/`) |
| `assets/portraits/` | **Original**: the bestiary's larger pictures (64x64) of the same designs |
| `assets/skins/<id>/` | **every other set**: a `skin.txt` and whichever folders it changes |

A set's folder holds any of `creatures/`, `items/`, `features/` and
`portraits/`, plus a `skin.txt`:

```
name: Horror
cards: portraits
```

- **`name:`** is what the game calls the set.
- **`cards: portraits`** means the set's 64x64 portraits double as its
  creatures' map cards. Without it, only its card folders are cards.
- `#` starts a comment.

## Every set is a whole game

A set only needs the drawings it changes. **Anything it lacks falls back
to Original**, so a half-made set still shows every creature and item.
For a map card, the game looks in this order:

1. the set's `creatures/`, `items/` and `features/`
2. the set's `portraits/` (with `cards: portraits`)
3. Original's `assets/portraits/` (likewise)
4. Original's `assets/sprites/`
5. the icon picture

## The sets today (2026-10-10)

| set | what it has |
|---|---|
| Original | the hand-drawn set: 28 creatures, 17 items, 2 fungus tiles; 28 portraits |
| Detailed | no files of its own: Original's portraits as the map cards, Original's items |
| Horror | 28 portraits (doubling as cards), 17 items, 2 fungus tiles |
| Cute | 28 portraits (doubling as cards), 17 items, 2 fungus tiles |

## Adding a set

Make `assets/skins/<id>/` with a `skin.txt`, put drawings in the editor's
format (see `assets/sprites/README.md`) in its folders, named after the
looks they draw, and the game finds it. The suite checks that every file is
a drawing of a real look, that no set draws a look twice, and that no set
loses a look Original draws. Every export includes `assets/skins/*.txt` and
`assets/portraits/*.txt`.
