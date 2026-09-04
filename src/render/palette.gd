class_name Palette
extends RefCounted

## A deliberately small, hand-picked palette.
##
## This is the single biggest reason a windowed ASCII game stops looking like a
## terminal. Terminal roguelikes look like terminals largely because they use
## the sixteen ANSI colours. Choosing your own consistent ramp -- warm stone,
## cold memory, one saturated accent per threat tier -- does more for the look
## than any shader.

const BG            := Color("0b0c10")
const STONE_LIGHT   := Color("8d8578")
const STONE_DARK    := Color("3a382f")
const FLOOR_FG      := Color("57534a")
const FLOOR_BG      := Color("17171c")
const DOOR          := Color("b4813f")
const STAIRS        := Color("d9cf9a")
## Stairs stay legible in remembered terrain. Once you have found the way down
## it is navigation information, not scenery, and hunting for it in the dim
## blue of memory is busywork rather than difficulty.
const STAIRS_KNOWN  := Color("7fe0b0")
const AMULET        := Color("ffe07a")
const BRAZIER       := Color("e0913c")
const BRAZIER_DEAD  := Color("4f4740")
const PILLAR        := Color("9a9082")
const RUBBLE        := Color("6b5b47")
const WATER         := Color("4d7f9e")
const MUD           := Color("7a6248")
const MUD_BG        := Color("241d16")
const WATER_BG      := Color("15242e")
const ROCK_LIGHT    := Color("857a69")
const ROCK_DARK     := Color("4a4238")
const CAVE_FLOOR    := Color("6d6250")
const POTION        := Color("d2607a")
const SCROLL        := Color("cfc39a")
const WEAPON        := Color("9fb3c8")
const LAUNCHER      := Color("c8b28a")
const AIM_OK        := Color("8fe0a8")
const AIM_BLOCKED   := Color("e07a6a")
const ARMOUR        := Color("a89a7c")

## Material tints, applied to terrain base colours -- deliberately NOT to the
## light.
##
## The lighting channel already carries meaning: warm means lit right now, cold
## blue means remembered. Tinting the torch for a flooded room, which is the
## obvious implementation, would collide with that read and make a lit room
## look like a recalled one. Tinting the stone instead gives the same
## atmosphere and leaves the most important signal on screen intact.
const MATERIAL_TINT := {
	Materials.STONE:   Color(1.00, 1.00, 1.00),
	Materials.FLOODED: Color(0.68, 0.95, 1.10),
	Materials.RUIN:    Color(1.12, 0.88, 0.70),
	Materials.SANCTUM: Color(1.10, 1.01, 0.76),
	Materials.CAVERN:  Color(1.05, 0.93, 0.80),
}

## Explored-but-unlit terrain. Cold and desaturated, so memory reads as memory
## and never competes with what is actually lit.
const MEMORY        := Color("2b3347")
const MEMORY_MIX    := 0.78
const MEMORY_DIM    := 0.62

const PLAYER        := Color("f2e9d8")
const UI_TEXT       := Color("c7c2b4")
const UI_DIM        := Color("6d6a60")
const UI_FRAME      := Color("42404a")
const UI_PANEL_BG   := Color("101118")

const HP_GOOD       := Color("6fa86b")
const HP_WARN       := Color("c8a24a")
const HP_BAD        := Color("bf4b45")

const SLEEP         := Color("6f7d99")
const ALERT         := Color("ffcb52")
const SHOT          := Color("ffd9a0")
const HIT_FLASH     := Color("ff9d6b")

const CURSOR        := Color("7fd4ff")
const PATH_HINT     := Color("3f6f8c")
