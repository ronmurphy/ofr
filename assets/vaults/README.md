# Vaults

Hand-authored rooms the generator can stamp into a level, instead of every room
being procedurally decorated. Drop a `.txt` file in this folder and it becomes
a candidate; there is nothing to register.

Not every floor gets one. A vault is a set piece, and seeing the same one twice
in a run costs more than never seeing it at all.

## Two ways to make one

**`tools/vault_editor.html`** — open it in a browser. Paint from a palette, and
it checks itself as you draw: connectivity, doors that open onto nothing, size.
Same rules as the linter, so what passes there loads in the game. It also crops
any wasted margin, which makes the bounding box the generator reserves as small
as the room actually needs.

**A text editor** — the format below is plain enough to type. Run
`godot --headless --script res://tests/vault_lint.gd` when you are done.

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
| `terrain` | `fixed` (default) or `random` -- see below |

### terrain: fixed or random

By default a vault is **exactly what you drew**. The generator's terrain pass
skips it entirely, so a crypt you designed dry stays dry and a flooded one
stays flooded. That is the point of authoring it by hand.

Set `terrain: random` to opt back in, and the generator will lay water, mud,
bones or rubble over your plain floor the way it does anywhere else. Useful for
something like a ruined guardhouse, where you care about the walls and the
monsters but are happy for the ground to vary between runs. Anything you place
explicitly is never overwritten either way.

## Legend

Terrain:

| char | tile | notes |
|---|---|---|
| `#` | masonry wall | |
| `.` | floor | |
| `_` | cave floor | |
| `+` | closed door | |
| `'` | open door | |
| `O` | pillar | blocks movement **and** sight |
| `^` | stalagmite | same, but natural |
| `~` | water | slow to cross |
| `=` | mud | slower still; heavy things suffer worst |
| `%` | rubble | slightly slow |
| `,` | bones | slow, **loud**, and crumbles once crossed |
| `*` | fungus | glows faintly |
| `&` | brazier | lit; rest or forge at it |
| `A` | shrine | an altar; its kind is rolled per level |
| `X` | pit | walkable, but drops you a floor |
| `t` | trap | visible; springs once, hurts, and is gone |
| `>` | stairs down | |
| `<` | stairs up | |
| (space) | **not part of the vault** | leaves whatever was already there |

Contents:

| char | places |
|---|---|
| `m` | a tier-appropriate monster |
| `M` | a guardian: one tier above the current depth |
| `?` | a random item |
| `!` | a potion |
| `)` | a weapon |
| `[` | armour |
| `}` | a launcher -- sling or bow |

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
- **Terrain is a composition tool.** A colonnade with a pool between the
  columns, or a bone-strewn approach to a shrine that cannot be crossed
  quietly, says more than a room full of monsters does. `,` in front of `A` is
  a whole encounter on its own.
- **`X` is a shortcut, not a trap.** Pits are walkable and the pathfinder
  routes around them, so falling is always deliberate. A pit behind the loot
  is an escape route with a price.
- **`t` is a toll, not an ambush.** Traps are visible and routed around too, so
  the interesting placement is somewhere the player *wants* to go -- across the
  short way, or between them and the prize. A trap nobody has a reason to step
  on is scenery.

## Status

The **loader is not built yet** -- these files are inert until it is. The
format above is settled, so anything authored now will work when it lands.
