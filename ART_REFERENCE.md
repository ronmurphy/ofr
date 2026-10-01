# OFR art reference

Generated 2026-10-01 by `tools/art_reference.gd` from the game's own tables. Regenerate with
`godot --headless --path . -s tools/art_reference.gd`; do not edit by hand.

## How the game draws today

OFR has three looks the player switches between with the `v` key, all drawn from fonts:

- **letters** -- classic roguelike glyphs, JetBrains Mono.
- **symbols** -- the same, with terrain and items swapped for Unicode shapes; creatures stay letters.
- **pictures** -- icons from `assets/fonts/ofr_icons.ttf`, a subset of JetBrains Mono Nerd Font. Each picture
  is a Nerd Font glyph; the name beside each codepoint below is the icon's name in that set (md- = Material
  Design Icons, fa- = Font Awesome, oct- = Octicons, cod- = Codicons). Anything with no picture falls back to
  its letter in every look.

**Colour carries family, shape carries rank.** The colour of a thing is the same in all three looks
(the `fg` column); the pictures change shape, never palette. The six humanoids share three figures --
small (kobold, goblin), adult (orc, wight), heavy (ogre, troll, giant) -- and colour tells them apart
inside a class. Sprites should keep that: a kobold and a goblin are the same size and build.

**Two renderers share the tables.** The classic view is a grid of square cells, one glyph per cell,
at a cell size the player picks: 14, 16, 18, 20, 24, 28 px (default 18). The 3D view stands each picture up as a card on
its cell, fitted into a box measured in cells (the `3D box` column, width x height) -- so a rat stays small
and a dragon is taller than a door (walls are 1.35 cells high). Floors are flat tiles with a procedural
pattern; walls, rock, pillars, stalagmites, doors, chests and pits are meshes, not pictures.

**For a sprite sheet.** 64 px per cell is the size that would serve both views (32 is enough for the
classic grid alone). A creature or item sprite would be drawn at its 3D box times the cell size,
anchored bottom-centre on its cell -- e.g. a dragon at 1.60 x 1.30 cells is 102 x 83 px at 64. The
`shape` column is the current icon's ink, width to height, for the silhouette the game sizes today.
Creatures are listed smallest to largest by their standing height.

## Fonts shipped

| file | what | licence |
|---|---|---|
| `assets/fonts/JetBrainsMono-Regular.ttf`, `-Bold.ttf` | text, the letters and symbols looks | SIL OFL 1.1 |
| `assets/fonts/ofr_icons.ttf` | the pictures look: a subset of JetBrains Mono Nerd Font (Material Design Icons, Apache 2.0; Font Awesome Free, CC BY 4.0; Codicons, CC BY 4.0), built by `tools/build_icon_font.py` | see `assets/fonts/CREDITS.txt` |
| `assets/fonts/kenney_input_xbox_series.ttf` | controller button pictures in hints | CC0 |

Icons live in the font's private-use area (U+E000 and up); the game draws any such glyph 55% larger
than text, times a per-figure scale (small figure x0.56, armed small x0.74, heavy figure x1.26) so the
ladder reads small < adult < heavy inside one square cell.

## Terrain

Walls and rock have no glyph of their own: the classic view draws them from box-drawing pieces chosen
by their neighbours, the 3D view as blocks. `walk` is whether a creature can stand there, `see` whether
sight and light pass. The legend's note is what the game tells the player about it.

| tile | letters | symbols | picture | shape | fg | bg | 3D | walk | see | note |
|---|---|---|---|---|---|---|---|---|---|---|
| void | (blank) | (same) | -- |  | #0b0c10 | #0b0c10 | not drawn | no | no |  |
| floor | `·` | (same) | -- |  | #57534a | #17171c | floor | yes | yes |  |
| wall | procedural (legend shows █) | (same) | -- |  | #8d8578 / #3a382f (light / dark masonry; hue-shifted per region) | #0b0c10 | mesh | no | no |  |
| door closed | `+` | ■ | U+F081B (md-door_closed) | 1.11 : 1 | #b4813f | #1c1712 | mesh | yes | no | loud to open |
| door open | `'` | □ | U+F081C (md-door_open) | 1.11 : 1 | #b4813f | #14120f | mesh | yes | yes |  |
| stairs down | `>` | ≫ | U+F12BE (md-stairs_down) | 1.04 : 1 | #d9cf9a | #1a1a20 | card 0.60 x 0.45 | yes | yes |  |
| brazier | `Ω` | ✶ | U+F0238 (md-fire) | 0.78 : 1 | #e0913c | #241408 | card 0.60 x 0.60 | no | yes | rest at it, or forge |
| pillar | procedural (legend shows ●) | (same) | -- |  | #9a9082 | #0b0c10 | mesh | no | no |  |
| rubble | `▒` | (same) | -- |  | #6b5b47 | #1a150f | floor | yes | yes | slightly slow; knaps sling stones |
| water | `~` | ≈ | U+EF30 (fa-water) | 1.50 : 1 | #4d7f9e | #15242e | card 0.50 x 0.30 | yes | yes | slow to wade |
| rock | procedural (legend shows █) | (same) | -- |  | #857a69 / #4a4238 (light / dark rock; hue-shifted per region) | #0b0c10 | mesh | no | no |  |
| cave floor | `·` | (same) | -- |  | #6d6250 | #1c1814 | floor | yes | yes |  |
| stalagmite | procedural (legend shows ▲) | (same) | -- |  | #857a69 | #241f19 | mesh | no | no |  |
| brazier spent | `Ω` | ✶ | U+F0238 (md-fire) | 0.78 : 1 | #4f4740 | #17161a | card 0.60 x 0.60 | no | yes | its embers set a gem |
| stairs up | `<` | ≪ | U+F12BD (md-stairs_up) | 1.06 : 1 | #d9cf9a | #1a1a20 | card 0.60 x 0.45 | yes | yes |  |
| shrine | `∩` | ⌂ | U+EEE6 (fa-torii_gate) | 1.00 : 1 | #c7c2b4 | #1c1826 | card 0.75 x 0.70 | yes | yes | its colour: pray, or the mirror |
| mud | `░` | (same) | -- |  | #7a6248 | #241d16 | floor | yes | yes | slow; worst for heavy things |
| bones | `,` | ∴ | U+F00B9 (md-bone) | 2.00 : 1 | #bdb69f | #1d1c19 | card 0.50 x 0.30 | yes | yes | LOUD; crumbles once crossed |
| fungus | `*` | ◌ | U+F07DF (md-mushroom) | 1.00 : 1 | #7fd9b0 | #14201b | card 0.50 x 0.40 | yes | yes | glows faintly; eat it |
| purple fungus | `*` | ◌ | U+F07DF (md-mushroom) | 1.00 : 1 | #b77be8 | #1c1424 | card 0.50 x 0.40 | yes | yes | its air poisons: 1 hp a turn |
| red fungus | `*` | ◌ | U+F07DF (md-mushroom) | 1.00 : 1 | #d8434a | #241314 | card 0.50 x 0.40 | yes | yes | claims the dead; burn or bury |
| door barred | `+` | ■ | U+F081B (md-door_closed) | 1.11 : 1 | #8d8578 | #1c1712 | mesh | yes | no | holds all but a bear |
| pit | procedural (legend shows ●) | (same) | -- |  | #5a5044 | #000000 | floor | yes | yes | drops you a floor |
| trap | `^` | ⚠ | U+F0026 (md-alert) | 1.16 : 1 | #d4674f | #2a1714 | card 0.55 x 0.40 | yes | yes | springs once |
| brazier dead | `Ω` | ✶ | U+F0238 (md-fire) | 0.78 : 1 | #3a3234 | #121013 | card 0.60 x 0.60 | no | yes | cold, until fire |
| grave | `Π` | (same) | U+F0BA2 (md-grave_stone) | 0.90 : 1 | #8d94a6 | #15161b | card 0.55 x 0.60 | yes | yes |  |
| chest | `¢` | (same) | U+F0726 (md-treasure_chest) | 1.25 : 1 | #c9953f | #1d1710 | card 0.60 x 0.45 | no | yes |  |

## Creatures, smallest to largest

Height is the 3D card's box height in cells. `who` lists every bestiary entry wearing the picture, with
the depth it first appears, its hit points and its power; `heavy` creatures shoulder doors open.

| picture id | letters | picture | shape | fg | 3D box (w x h cells) | classic figure scale | who |
|---|---|---|---|---|---|---|---|
| bat | `b` | U+F0B5F (md-bat) | 2.08 : 1 | #8e6fa8 | 0.75 x 0.36 | x1.55 | cave bat (depth 2+, hp 5, power 3) |
| rat | `r` | U+F1327 (md-rodent) | 1.11 : 1 | #8a7f6a | 0.60 x 0.40 | x1.55 | giant rat (depth 1+, hp 4, power 2) |
| rabbit | `u` | U+F1A61 (md-rabbit_variant) | 0.72 : 1 | #e0a05c | 0.55 x 0.45 | x1.55 | rabbit (depth 1+, hp 6, power 0) |
| killer rabbit | `U` | U+F1A61 (md-rabbit_variant) | 0.72 : 1 | #fff2f2 | 0.60 x 0.50 | x1.55 | the killer rabbit |
| kobold | `k` | U+F02E7 (md-human_child) | 0.60 : 1 | #e8d9a0 | 0.60 x 0.60 | x0.87 | kobold (depth 1+, hp 6, power 3) |
| goblin | `g` | U+F02E7 (md-human_child) | 0.60 : 1 | #2f6b4f | 0.60 x 0.62 | x0.87 | goblin (depth 2+, hp 9, power 4) |
| slinger | `K` | U+F082C (md-karate) | 0.86 : 1 | #d8a04a | 0.62 x 0.62 | x1.15 | kobold slinger (depth 2+, hp 5, power 3) |
| skeleton | `s` | U+F068C (md-skull) | 0.90 : 1 | #d6d2c4 | 0.70 x 0.66 | x1.55 | skeleton (depth 3+, hp 12, power 5) |
| bone ally | `s` | U+F068C (md-skull) | 0.90 : 1 | #7fd69a | 0.70 x 0.66 | x1.55 | your bone ally (summoned) |
| harpy | `H` | U+F15C6 (md-bird) | 1.23 : 1 | #d08fc0 | 0.90 x 0.70 | x1.55 | harpy (depth 5+, hp 16, power 7) |
| orc | `o` | U+F02E6 (md-human) | 0.90 : 1 | #b5643c | 0.80 x 0.80 | x1.55 | orc (depth 4+, hp 16, power 6) |
| banshee | `h` | U+F165D (md-ghost_outline) | 0.90 : 1 | #f2f4ff | 0.80 x 0.80 | x1.55 | banshee (depth 3+, hp 8, power 0) |
| wizard | `l` | U+F02E6 (md-human) | 0.90 : 1 | #3d6ee8 | 0.80 x 0.82 | x1.55 | wizard (depth 8+, hp 18, power 11) |
| wight | `w` | U+F02E6 (md-human) | 0.90 : 1 | #b8c4d8 | 0.80 x 0.82 | x1.55 | wight (depth 7+, hp 24, power 10) |
| player | `@` | U+EA67 (cod-person) | 0.50 : 1 | #f2e9d8 | 0.60 x 0.85 | x1.55 | you |
| shadow | `S` | U+F02A0 (md-ghost) | 0.90 : 1 | #8a63c4 | 0.80 x 0.85 | x1.55 | shadow (depth 9+, hp 20, power 13) |
| trader | `&` | U+F4CA (oct-feed_person) | 1.00 : 1 | #e8b76a | 0.80 x 0.85 | x1.55 | the trader (neutral) |
| bear | `B` | U+F03E9 (md-paw) | 1.11 : 1 | #b5763d | 1.00 x 0.85 | x1.55 | cave bear (depth 5+, hp 34, power 9, heavy) |
| lich | `L` | U+EE6F (fa-monument) | 0.75 : 1 | #7cf0d8 | 0.90 x 0.90 | x1.55 | arch lich (depth 10+, hp 40, power 15) |
| golem | `G` | U+F06A9 (md-robot) | 1.10 : 1 | #9aa0a8 | 0.95 x 1.00 | x1.55 | stone golem (depth 8+, hp 42, power 10, heavy) |
| ogre | `O` | U+F115D (md-weight_lifter) | 0.91 : 1 | #9a7fb8 | 0.95 x 1.05 | x1.95 | ogre (depth 5+, hp 26, power 9, heavy) |
| troll | `T` | U+F115D (md-weight_lifter) | 0.91 : 1 | #6b4a2a | 1.00 x 1.10 | x1.95 | cave troll (depth 6+, hp 30, power 8, heavy) |
| wyvern | `W` | U+EEF8 (fa-dragon) | 1.25 : 1 | #c05a3a | 1.40 x 1.10 | x1.55 | wyvern (depth 7+, hp 32, power 11) |
| dragon | `D` | U+EEF8 (fa-dragon) | 1.25 : 1 | #e8c33c | 1.60 x 1.30 | x1.55 | young dragon (depth 10+, hp 55, power 14) |
| giant | `C` | U+F115D (md-weight_lifter) | 0.91 : 1 | #c6d8e2 | 1.20 x 1.40 | x1.95 | cave giant (depth 10+, hp 48, power 13, heavy) |

## Items

One picture per kind of thing, not per item: every gem is the same stone, every sword the same
sword, and the name (read with the look key) says which. `3D box` is the card lying on the floor.

| picture id | letters | symbols | picture | shape | fg | 3D box | items that wear it |
|---|---|---|---|---|---|---|---|
| scroll | `?` | ≡ | U+F0BC2 (md-script_text) | 1.00 : 1 | #cfc39a | 0.50 x 0.36 | scroll of blink, scroll of light |
| shovel | `|` | Γ | U+F0710 (md-shovel) | 1.00 : 1 | #7fd69a | 0.50 x 0.36 | undertaker's shovel |
| amulet | `"` | ◎ | U+F0F0B (md-necklace) | 1.27 : 1 | #ffe07a | 0.40 x 0.34 | Amulet of the Deep |
| shield | `(` | ▽ | U+F0498 (md-shield) | 0.82 : 1 | #a89a7c | 0.50 x 0.36 | buckler, kite shield, tower shield |
| armour | `[` | ◫ | U+F0A7B (md-tshirt_crew) | 1.20 : 1 | #a89a7c | 0.50 x 0.36 | chain mail, leather armour, plate mail |
| ammo | `\` | ➜ | U+F1840 (md-arrow_projectile) | 1.00 : 1 | #c8b28a | 0.50 x 0.30 | spent arrows |
| launcher | `}` | ➜ | U+F1841 (md-bow_arrow) | 1.00 : 1 | #c8b28a | 0.50 x 0.36 | short bow, sling, war bow |
| axe | `)` | † | U+F1842 (md-axe_battle) | 1.00 : 1 | #9fb3c8 | 0.50 x 0.36 | war axe |
| mace | `)` | † | U+F1843 (md-mace) | 1.00 : 1 | #9fb3c8 | 0.50 x 0.36 | mace |
| weapon | `)` | † | U+F04E5 (md-sword) | 1.00 : 1 | #9fb3c8 | 0.50 x 0.36 | dagger, short sword |
| potion | `!` | ◔ | U+F0093 (md-flask) | 0.90 : 1 | #d2607a | 0.50 x 0.36 | potion of healing |
| meat | `%` | (same) | U+F146A (md-food_steak) | 0.70 : 1 | #c46b5a | 0.50 x 0.36 | haunch of bear, haunch of rabbit |
| ring | `=` | (same) | U+F07EB (md-ring) | 0.80 : 1 | #b98cd6 | 0.36 x 0.30 | ring of the rat |
| gem | `$` | (same) | U+F01C8 (md-diamond_stone) | 1.00 : 1 | #dfe4ea | 0.40 x 0.30 | gem of fire, gem of frost, gem of returning, gem of the boss, gem of the bulwark, gem of the crag, gem of the mirror, gem of the road, gem of thirst |
| sack | `¤` | (same) | U+F0D2E (md-sack) | 0.91 : 1 | #8a5a3c | 0.50 x 0.36 | sack |
| bone | `/` | ∵ | U+F00B9 (md-bone) | 2.00 : 1 | #7fd69a | 0.50 x 0.36 | knucklebone |

## Drawn without a glyph

- **Walls and rock**: box-drawing corners and runs in the classic view (`GlyphGrid.BOX`), chosen from
  the neighbours; masonry or rough rock blocks in 3D, with the region's stone colour.
- **Doors**: a frame of posts and a header, and a leaf that swings; a barred door adds a stone beam.
- **Pits**: a dark hole; **floor dots**: the `.` of empty floor is one batch of small dots in 3D.
- **Light**: the sim's light map tints every surface; braziers and fungus glow; the torch follows you.
- **Marks over creatures** (text, both views): `z`/`zZ`/`zzZ` asleep, `?` suspicious, `.`/`..`/`...`
  on patrol, `<<` fleeing, `!` hunting (in the sidebar list), `✶N` frozen for N turns.
- **The sidebar's skull** (killed by): U+F068C (md-skull).
- **Effects**: hit flashes, arrows and sling stones in flight, embers, miasma, blood washes -- drawn
  by each renderer from the same event list, no sprites involved.

## What a sprite sheet would change

Both renderers ask a theme `appearance(id)` for a character and a colour and draw text. A sheet would
add a fourth look where that call returns a region of a texture instead: the classic grid blits it
into the cell, the 3D view puts it on the card. Everything keyed by the `picture id` column above
stays as it is; the sheet needs one region per id (tiles, creatures, items), drawn to the sizes here.

