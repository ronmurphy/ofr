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
| `band` | restrict to one floor theme -- see below. Omit for "anywhere" |

### kind: room or cave

`kind: cave` marks a CAVE VAULT: drawn in cave floor (`_`) with rock (`#` or
space) around it, no doors, at least 24 cells in one connected piece, with
`band: caves`. The vault editor grows a starting shape with its *generate
cave* button. A file with no `kind` is a room, as every vault was before.

Read by the game since 2026-10-08. What happens to one:
- **Only on cave floors** (4-6 going down, 14-16 coming up), within its
  `min_depth`/`max_depth`, read as the descent floor it mirrors.
- **It takes the caves' vault.** A cave floor has a vault about one time in
  four. While any cave vault is eligible, that vault is always a cave vault,
  and no masonry room is placed in the caverns.
- **Painted, not grown.** It replaces one of the floor's grown caves, cell for
  cell: `_` cave floor, `#` and space rock, every other letter as in a room.
  Its edge turns to cave stone like any cave's, and a tunnel joins it to the
  rest of the floor (so: no doors).
- **Peopled like a cave** -- monsters by the threat budget, animals, a bear
  and its den -- unless you put `m` or `M` in it; then those are all its
  monsters, so one ceiling is never spent twice. `r` and item markers work
  as in a room.
- **`terrain: fixed`** keeps it exactly as drawn (no stalagmites scattered,
  no fungus beds, no drip pools on its ground); `random` lets the cave
  passes decorate it.
- **Twice a run at most**, and the second time turned or mirrored
  differently. A `rotate: no` cave vault is met once a run.

Check one with `godot --headless --script res://tests/vault_lint.gd --
tools/vaults_waiting/` before moving it into `assets/vaults/`.

### place N: creatures by name

`place 1: cave bear` puts that creature wherever a `1` is drawn -- any name
from the game's bestiary, up to nine kinds a vault. The editor's creatures
tab writes these for you. Read by the game since 2026-10-08:
- **Only where the game could meet it**: on a floor at least its own
  depth, and a climb-only creature (the cave giant, the arch lich) only on
  the climb from its floor. Elsewhere the square is plain floor.
- **An animal** (rabbit, bat, wolf, cave bear) comes on top of the threat
  budget, like `r`; a wolf brings its pack.
- **A monster** spends the vault's budget like `m`, and is left out when
  it costs more than is left -- the room is under-populated, never over.
  The linter warns when a named monster is over the room ceiling at the
  vault's `min_depth`.
- The linter fails a digit with no `place` line, and a name the bestiary
  does not have.

### band: which floors it belongs to

The dungeon is themed in groups of three, and the climb out reuses the same
groups corrupted rather than replaying the descent backwards:

| band | floors going down | and climbing out |
|---|---|---|
| `upper` | 1-3 | 17-19 |
| `caves` | 4-6 | 14-16 |
| `fortress` | 7-9 | 11-13 |
| `deep` | 10 | -- |

**Write the descent floors only.** `min_depth` and `max_depth` are matched
against the *mirrored* depth -- the climb folded back onto the way down -- so a
room set to 7-9 appears on 11-13 as well, corrupted, without you having to say
so. Writing `7-13` is harmless but says nothing extra.

This used to be the other way round, and it was a trap: the range was compared
against the raw depth while the band beside it was folded, so every vault in
the library stopped at floor 10 and the last six floors of the climb had no
authored rooms at all. If you want a room on the way down, that is all you have
to say.

Omit `band` and the vault can turn up anywhere its depth range allows, which is
right for most of them. Set it when a room only makes sense in one kind of
place -- a masonry guard post reads as a mistake in a cavern.

**The fortress band leans on authored vaults**: it wants three or four a floor
against the usual nought-to-two, because "built and complex" is its whole
character and hand-drawn rooms are what built means. The cave band takes almost
none for the same reason in reverse.

This is declared here rather than inferred from the filename on purpose. A
rename should never change what the dungeon does, and `encounter_room.txt` and
`stock_rooms.txt` are general-purpose vaults whose names happen to contain
"room" -- exactly what a filename rule gets wrong.

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
| `v` | purple fungus | poisonous; walking over it is dangerous |
| `;` | red fungus | carries spores; walking over it is dangerous |
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
| `(` | a sack |
| `r` | a rabbit, wild, outside the threat budget. The only way a rabbit is found in a fortress (`the_warren.txt`) |

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

The loader is built: every file here is read when the game starts, cave
vaults and creatures by name included (2026-10-08). Run the linter after any
change: `godot --headless --script res://tests/vault_lint.gd` (or add a
folder after `--` to check one elsewhere).
