# OFR: gameplay and renderer ideas, from reading the source

Read-only. I cloned the repo locally to read it. Nothing was committed or pushed, the clone's push URL is disabled, and this file lives outside the repo. Ideas are marked **[chain]** where they connect systems you already have, DF-style, and **[solo]** where they stand alone. Both are welcome. Each one names the decision it gives the player.

## Already built (so none of this repeats it)
Door swing, latched pen gate, barred doors, living light with memory fade, guards that shut doors behind them, braziers with the kindle race, nothing wrong growing within 2 squares of a lit brazier, 8 shrines with hues, `z/zZ/zzZ` and `?` marks, the 0.35 s fade from black on a new floor, volumetric fog on Forward+, the fungus/body/rise web, noise that draws blind risen, and the house plan.

## Chains

### 1. Doors that muffle: door -> noise -> risen -> guards [chain]
Your risen hunt by sound, and noise already travels to a room "through a door". Let a **closed** door cut a noise ring's reach (say by half) and a **barred** door stop it. The renderer already knows a door's state and already swings it, so it only needs a small "muffled" tick on the noise ring.
- *Decision:* fight in the doorway, where the noise carries, or step back and shut the door to keep a stirring room next door asleep. Barring a door becomes a way to quarantine a red-fungus room.

### 2. Damp: water and mud -> fungus table -> brazier [chain]
Fungus rolls come from `MapGen.FUNGUS_TABLE` by depth. Add a small modifier from the terrain next to the roll: squares near water or mud lean to purple and green, dry floor leans to red. Nothing changes about the tables, only the dice near wet tiles.
- *Decision:* camp in a damp room for green food and risk purple, or in a dry room and risk the red rise. Together with the brazier's 2-square ward, a lit brazier in a wet room becomes worth the kindle race.

### 3. Darkness creatures refuse light: lit braziers -> shadow, banshee, wight [chain]
Make `shadow` (and perhaps `banshee`) unwilling to enter squares lit by a **kindled** brazier or by your torch at its brightest, the way CAREFUL pathing already routes round fungus. The light map is already computed for the renderer.
- *Decision:* spend turns kindling a brazier to make a refuge, or run. Also makes the house (lamp light, hearth) a natural place where those creatures can never follow, and it connects to the sleep and wandering-monster check.

### 4. Light you leak: open door -> lit room -> sight [chain]
In 3D an open door onto a lit room throws a visible wedge of light into the dark corridor (a SpotLight3D into the fog on Forward+; a flat additive card on the web build). It uses the same `Fx` door-swing event you already queue.
- *Decision:* close the door behind you (guards already do it) or leave it open to flee. Only worth doing if the sim really treats lit squares as easier to notice; I did not trace whether `_can_see` uses the light map.

### 5. Gravestones that your fighters remember: legends -> house -> bone ally [chain]
Your plan already removes a buried hero from the dungeon's grave pool. Extend it by one hop: a bone ally raised from a grave you buried yourself has that hero's name and keeps one of their stats (a floor-1 echo, not a full copy).
- *Decision:* bury a hero at home (safe, sentimental) or leave the grave to be raised in the dungeon as a fighter for the next run.

## Solo features

### 6. Three kinds of descent [solo, one real tell]
Give each way down its own arrival, using the `ScreenFx` fade you have: the stairs / gate arrive in a warm white bloom (as in the video), a pit fall is a hard cut with the red edge and camera jolt (matches "pit -> next floor, wounded and vengeful"), and the house portal gets its own cool colour, which answers your "portal's colour" open question.
- *Decision:* none, except that the pit tell lets the player read their own situation at a glance.

### 7. Art sets as swappable skins [solo]
`PixelSprites` already loads one file per appearance id, falls back to icons, and tints the `ally / corrupted / magic` states. A `user://sprites/<set>/` folder searched first, a settings row "art set", and a check in the style of `tools/check_palette.py` that every set has every id gives you the horror, cute and any future sets.
- *Decision:* player taste only.

### 8. Bestiary pages with portraits [solo]
`BestiaryLog` already tracks which creatures have been met. A page could show the 64x64 portrait of a met creature, a black silhouette for an unmet one, and the existing facts (careful, wail, and so on) beside it.
- *Decision:* reading an entry teaches how to handle that creature, which fits the HERE-box-as-teacher idea.

## Not recommended
- **A burning-out torch.** `light.gd` has a radius but no fuel. Fuel would compete with the kindle race and flares. Only worth it if the decision were "stoke a brazier or press on".
- **Anything from the house coming back as gear.** Your rule is right.
