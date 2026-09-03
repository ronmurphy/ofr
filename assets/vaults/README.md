# Vaults

Hand-authored rooms the generator can stamp into a level, instead of every room
being procedurally decorated. Drop a `.txt` file in this folder and it becomes
a candidate; there is nothing to register.

Not every floor gets one. A vault is a set piece, and seeing the same one twice
in a run costs more than never seeing it at all.

## File format

Metadata lines first, then `LAYOUT`, then the drawing. Blank lines and lines
starting with `#` **before** `LAYOUT` are comments -- after `LAYOUT`, `#` is a
wall, so keep comments up top.

    name: shrine of the drowned
    weight: 10
    min_depth: 2
    max_depth: 8
    rotate: yes
    LAYOUT
    #########
    #...O...#
    ...

| key | meaning |
|---|---|
| `name` | for the log and for debugging; not shown to the player |
| `weight` | relative chance of being picked against other eligible vaults |
| `min_depth` / `max_depth` | tier gating, same idea as monsters and items |
| `rotate` | `yes` to allow 90° rotations and mirroring, `no` if it only reads correctly one way up |

## Legend

Terrain:

| char | tile |
|---|---|
| `#` | masonry wall |
| `.` | floor |
| `,` | cave floor |
| `+` | closed door |
| `'` | open door |
| `O` | pillar (blocks movement **and** sight) |
| `^` | stalagmite |
| `~` | water |
| `%` | rubble |
| `*` | brazier (lit, rest at it) |
| `>` | stairs down |
| (space) | **not part of the vault** -- leaves whatever was already there |

Contents:

| char | places |
|---|---|
| `m` | a tier-appropriate monster |
| `M` | a guardian: one tier above the current depth |
| `?` | a random item |
| `!` | a potion |
| `)` | a weapon |
| `[` | armour |

Everything is optional. A vault made only of terrain is perfectly good -- an
interesting shape is content.

## Rules of thumb

- **Keep them small.** 7x7 to 13x13. Big vaults are hard to place and eat the
  floor. The generator reserves space for them like it does for caves, so a
  large one crowds everything else out.
- **Leave a way in.** Put doors (`+`) or plain floor (`.`) on the edge. A vault
  sealed by `#` on all sides will be connected by a corridor punched through
  the wall, which usually looks worse than a door you placed deliberately.
- **Spaces are transparent, not empty.** Use them to make a non-rectangular
  vault -- a cross, an L, a ragged cave mouth.
- **Guard the good stuff.** A `M` next to a `)` reads as a decision. A `)` on
  its own reads as a handout.
- **Watch the threat.** `m` and `M` count against a vault threat ceiling, so an
  over-stuffed vault will simply drop the monsters it cannot afford. Better to
  place two deliberate ones than eight hopeful ones.

## Status

The **loader is not built yet** -- these files are inert until it is. The
format above is settled, so anything authored now will work when it lands.
