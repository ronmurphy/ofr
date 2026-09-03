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
const BRAZIER       := Color("e0913c")
const POTION        := Color("d2607a")
const SCROLL        := Color("cfc39a")
const WEAPON        := Color("9fb3c8")
const ARMOUR        := Color("a89a7c")

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

const CURSOR        := Color("7fd4ff")
const PATH_HINT     := Color("3f6f8c")
