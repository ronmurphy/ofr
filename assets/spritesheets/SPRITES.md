# The sprite sheets

Four sheets drawn by Brad's friend with an art generator on 2026-10-01, working
from `ART_REFERENCE.md` (the creatures and items are in its exact order). Not
used by the game yet: this folder is `.gdignore`d so Godot neither imports nor
ships it until a sprite look exists. `sprites.json` beside this file is the
machine-readable map -- grid, cell size, and each cell's ink bounds -- for the
renderer that will use them.

## Files

| file | grid | px per cell | size | where |
|---|---|---|---|---|
| `originals/*-sprite-sheet.png` (four) | 5x5 / 4x4 | 384 / 480 | 1920 x 1920, 3.0-4.1 MB each | the originals: git-ignored and `.gdignore`d, never committed; also copied to `/home/brad/ofr-art-originals/spritesheets/` |
| `*-128.png` (four) | the same | 128 | 640 x 640 / 512 x 512, 0.27-0.55 MB each | made from the originals (Lanczos); **the set to commit** |
| `*-256.png` | the same | 256 | 1280 / 1024, 0.9-1.7 MB each | in `/home/brad/ofr-art-originals/spritesheets/`, if a sharper set is ever wanted |

128 px per cell is twice the 64 px the reference recommends for a cell, so a
dragon card (1.6 x 1.3 cells) still has 205 x 166 px behind it. All four are
RGBA with real transparency (62-72% of each sheet is clear), so no cutting out
is needed for the billboards.

## How the cells sit

Every cell holds one sprite centred horizontally, but the BASELINES differ:
small animals sit at 0.79-0.84 of their cell, the big creatures at 1.00. So a
renderer must not place a sprite by its cell -- it anchors by the sprite's own
ink bottom (the `ink` box in `sprites.json`, as fractions of the cell:
x0, y0, x1, y1), exactly as `GlyphMetrics` does for the icon font today. The
ink is also what the 3D view fits into its box (`BillboardSizes`), so the
size ladder stays the game's and not the sheet's.

## creatures-sprite-sheet.png (5 x 5, 384 px cells)

Row-major, the reference's smallest-to-largest order. Every creature the game
has, nothing missing.

| cell | id | drawn |
|---|---|---|
| r0c0 | bat | purple bat, wings out |
| r0c1 | rat | grey rat |
| r0c2 | rabbit | tan rabbit |
| r0c3 | killer_rabbit | white rabbit, red eyes, fangs |
| r0c4 | kobold | yellow kobold, spear and shield |
| r1c0 | goblin | green goblin, knife and shield |
| r1c1 | slinger | yellow kobold with a sling |
| r1c2 | skeleton | skeleton, sword and shield |
| r1c3 | bone_ally | green skeleton, sword and shield |
| r1c4 | harpy | pink harpy |
| r2c0 | orc | red-brown orc with an axe |
| r2c1 | banshee | white ghost, wailing |
| r2c2 | wizard | blue wizard, staff and spell |
| r2c3 | wight | armoured undead, grey-blue |
| r2c4 | player | human in cream, sword and shield |
| r3c0 | shadow | purple shadow with an eye |
| r3c1 | trader | hooded figure, pack and lantern |
| r3c2 | bear | brown bear |
| r3c3 | lich | teal lich with a staff |
| r3c4 | golem | stone golem |
| r4c0 | ogre | purple ogre with a club |
| r4c1 | troll | brown troll |
| r4c2 | wyvern | red wyvern |
| r4c3 | dragon | gold dragon |
| r4c4 | giant | pale blue giant with a club |

All face the viewer or three-quarters right; nothing faces left, so a renderer
that wants a creature to face its `facing` would flip horizontally.

## items-sprite-sheet.png (4 x 4, 480 px cells)

The reference's item table, in order. One picture per kind, as the game does.

| cell | id | drawn | items that wear it |
|---|---|---|---|
| r0c0 | scroll | rolled scroll, red seal | scroll of blink, scroll of light |
| r0c1 | shovel | shovel | undertaker's shovel |
| r0c2 | amulet | red stone on a chain | Amulet of the Deep |
| r0c3 | shield | kite shield with a skull | buckler, kite shield, tower shield |
| r1c0 | armour | fur-collared plate | leather, chain, plate |
| r1c1 | ammo | one arrow | spent arrows |
| r1c2 | launcher | bow | short bow, sling, war bow |
| r1c3 | axe | axe | war axe |
| r2c0 | mace | spiked mace | mace |
| r2c1 | weapon | sword | dagger, short sword |
| r2c2 | potion | red flask with a skull | potion of healing |
| r2c3 | meat | haunch | haunch of bear, haunch of rabbit |
| r3c0 | ring | gold ring, skull and red stone | ring of the rat |
| r3c1 | gem | red cut stone | every gem (nine) |
| r3c2 | sack | tied sack | sack |
| r3c3 | bone | bone | knucklebone |

Note the gem is red: the game tints every gem the same pale colour and names
the element; a red stone will read as "fire" unless the sprite is desaturated
and tinted per element, or drawn grey.

## terrain-details-sprite-sheet.png (4 x 4, 480 px cells)

The standing features, grouped by hand. The flat ground -- floor, cave floor,
mud, water as a surface, walls and rock -- is a tileset still to come.

| cell | id | drawn |
|---|---|---|
| r0c0 | door_closed | arched stone frame, shut wooden door |
| r0c1 | door_open | the same, door swung open |
| r0c2 | stairs_down | stairs going down into dark |
| r0c3 | stairs_up | stairs going up |
| r1c0 | brazier | iron bowl on skull feet, burning |
| r1c1 | brazier_spent | the same, embers |
| r1c2 | brazier_dead | the same, cold coals |
| r1c3 | shrine | hooded statue in a niche, two candles |
| r2c0 | water | a pool (a feature, not a tile) |
| r2c1 | rubble | a pile of stone blocks |
| r2c2 | fungus | pale mushrooms |
| r2c3 | purple_fungus | purple mushrooms |
| r3c0 | red_fungus | red mushrooms |
| r3c1 | bones | skull and bones on the floor |
| r3c2 | trap | a spiked plate, bloodied |
| r3c3 | chest | banded chest with a skull clasp |

**Not drawn yet:** grave (headstone), pit, pillar, stalagmite, door_barred (the
shut door with a stone beam across it, new today), and every flat tile. The
shrine comes in one colour; the game colours shrines per run, so the sprite
would need a tintable part or a grey master.

## effects-sprite-sheet.png (4 x 4, 480 px cells)

No reference existed for these; the ids below are this file's names for them,
with the game event each could stand for. Several are the same idea twice.

| cell | id | drawn | could be |
|---|---|---|---|
| r0c0 | fx_torch | a burning torch | the torch, lit |
| r0c1 | fx_brazier_fire | a brazier in full flame | a lit brazier's fire |
| r0c2 | fx_ember_burst | sparks and embers bursting | the forge; a fire hit |
| r0c3 | fx_smoke | grey smoke | a scorched fungus; a doused torch |
| r1c0 | fx_flash | white starburst | the flare; the scroll of light |
| r1c1 | fx_arrow | an arrow in flight | arrows (ranged events) |
| r1c2 | fx_sling_stone | a stone in flight with a dust trail | sling stones |
| r1c3 | fx_sparkle | purple sparkle | the blink; a gem set |
| r2c0 | fx_fire_bolt | a fireball streaking | a fire blade's hit; burning fungus |
| r2c1 | fx_frost_burst | ice crystals bursting | a frost hit; the frozen room |
| r2c2 | fx_green_swirl | green vapour | the miasma -- which the game draws PURPLE |
| r2c3 | fx_wail | a teal screaming face in vapour | the banshee's wail; the noise event |
| r3c0 | fx_blood | a blood splash | wounds, the blood wash |
| r3c1 | fx_dust | a dust cloud with stones | a door shouldered; rubble knapped |
| r3c2 | fx_vortex | a purple spiral | the recall; the blink |
| r3c3 | fx_halo | a gold ring of light | healing; the level-up; a prayer |

## What using them would take

Both renderers ask a theme for `appearance(id)` and draw a character. A fourth
look -- "sprites" -- would answer with a texture region instead (an
`AtlasTexture` over the sheet, from `sprites.json`), the classic grid drawing
it into the cell and the 3D view putting it on the card quad with alpha
scissor, anchored by ink bottom. The size ladder, the colours-by-family rule
and the marks over creatures all stay the game's. The flat-ground tileset is
the larger piece of work, since walls are drawn from their neighbours today.
