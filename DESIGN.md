# OFR — architecture and design notes

A technical description of a roguelike called **OFR** ("old fashioned
roguelike"), written to be read without access to the repository. It covers how
the game is structured, which constraints drove the structure, and where the
design is knowingly unresolved.

Written for evaluation. The last section lists what a reviewer should push on.

---

## 1. What it is

A traditional turn-based roguelike: a procedurally generated dungeon, permanent
death, one character at a time, no story branching. Drawn in an ASCII idiom but
rendered in a window with a real font and a controlled palette, not in a
terminal — the font and palette control is the reason it is not a terminal
program.

- **Engine:** Godot 4.7.2, GDScript.
- **Scale:** ~17,700 lines across 46 source files; ~10,500 lines of tests
  running 1,601 assertions; 31 tool scripts; 19 hand-authored room templates.
- **Targets:** Linux, Windows, and a browser build via WebAssembly. Also played
  on Linux handhelds (Steam Deck, Legion Go S) through Steam.
- **Authorship:** written by one developer working with an LLM (Claude) as a
  pair. This is relevant to reading the code: the comments are unusually dense
  and carry reasoning rather than description, because the working agreement was
  that a decision which cannot be reconstructed later is not finished.

The dungeon is **one-way**. You descend ten floors, take an amulet, and climb
back out through nine regenerated floors. Nothing is revisited.

---

## 2. The architectural spine: a sim/render split

The single most load-bearing structural decision.

```
src/sim/     owns no Godot nodes. Pure logic, pure data.
src/render/  owns everything visual.
src/ui/      panels, all of which read keycodes.
```

`src/sim` may not reference `src/render`. The consequence that matters: **the
entire game can run headless.** The test suite constructs a `GameState`,
generates floors, fights battles and inspects outcomes with no window, no
renderer and no frame loop. Statistical tests routinely generate 200–400 floors
per run.

This also means the simulation cannot accidentally depend on frame timing. Game
time advances only through the scheduler (section 4); Godot's `_process` drives
animation and input and never the simulation.

A concrete case where the boundary bit: a settings path was needed by both a
sim-side module and a render-side theme. Putting it on the theme would have made
sim depend on render. It went onto `GameState` instead.

---

## 3. Determinism is the hardest constraint

A seeded run must reproduce exactly. This is not a nicety — the crash log
("morgue") records a seed, and the suspend system saves RNG state so a resumed
run continues the same dungeon.

The constraint is stricter than it first appears. It is not enough that the same
seed produces the same numbers; **the same seed must consume the same number of
draws.** Anything whose draw count varies with content shifts everything
generated afterwards.

Failures encountered and fixed:

- A single `Array.shuffle()` call in one generation pass used Godot's *global*
  RNG. Every seeded level became unreproducible; seeded tests passed and failed
  on alternate runs. Replaced with Fisher–Yates through the run's own generator.
- Rolling item enchantments from the main stream made the draw count depend on
  how many items a floor happened to produce. Measured: the same seed built a
  floor with 29,269 walls before a change and 28,870 after; 135 monsters against
  149; a guaranteed floor-two item went missing on 9 seeds in 60.

The resolution is a pattern: anything whose number of draws varies with content
gets its **own** `RandomNumberGenerator`, seeded from the run but drawn
separately — currently three of them (graves, enchantments, the trader).

This constraint also shapes refactoring. A change that looks purely cosmetic can
silently alter draw order. There is a tool that fingerprints generation — hashing
the items, their rolled properties and the monster populations across 20
seed/depth combinations — so a refactor can be proven behaviour-identical rather
than assumed to be. A test suite cannot catch this class of bug: a determinism
test asserts that a seed agrees with itself, which stays true when both runs are
wrong in the same new way.

---

## 4. Time: an energy scheduler

```
ACTION_COST = 100
```

Each actor accumulates energy proportional to its speed and acts when it has
enough. Fast creatures act more often, slow ones less; nothing is special-cased.
The scheduler is bounded (it gives up after a fixed number of iterations) so a
pathological speed of zero cannot hang the game.

Difficult terrain charges *time*, not movement points — wading through water
costs a longer turn, which means the world gets more turns while you cross it.
The elapsed-time counter and the turn counter are therefore different numbers,
and the game shows elapsed time rather than turns where the distinction matters.

---

## 5. The world model: a folded depth

Ten floors down, then nine back up, for 19 "effective depths". Rather than
maintain two tables, the climb is **mirrored** onto the descent:

```
effective 1-10   → itself
effective 11-19  → 20 - effective     (so 15 answers 5)
```

Bands follow from the mirrored depth: 1–3 upper, 4–6 caves, 7–9 fortress, 10
deep, then the same names back out. Anything keyed to *what a floor is* uses the
mirrored value; anything keyed to *how far in you are* uses the raw one.

This produced a real bug worth recording: one function folded and the min/max
checks either side of it did not, so the same conditional disagreed with itself
and the last six floors of the climb silently had no authored rooms at all.

The caves band is **deliberately sparse** — fewer rooms, fewer items, fewer
authored templates, fewer drops. The intent is that players grow used to a
steady flow of loot in the room bands and then have it taken away, forcing them
to combine what they have and to hunt. The food chain (bear → rabbit → fungus)
is the intended replacement for consumables there. This has been re-reported as
a generation bug more than once; it is not one.

---

## 6. The combat model

```
raw   = attacker_power − defender_defense + random(−1, +1)
floor = ceil(attacker_power × 0.25)
damage = max(max(1, floor), raw)
```

**Nothing ever whiffs.** Every blow lands for at least a quarter of the
attacker's power. This is deliberate: binary all-or-nothing variance is
explicitly excluded from the damage model.

The consequence is that **defense saturates**. Past the point where an attacker
is already hitting the floor, more armour buys literally nothing. The equipment
tiers are tuned against that ceiling — the shield ladder was chosen so that each
tier exactly floors one more creature, and one tier above the largest was
rejected because it would have done nothing.

This produced an instructive design problem. A "blocking" enchantment that added
defense would have been a **measured no-op** against precisely the creatures
shields exist for. It was implemented instead as a subtraction applied *after*
the floor — the only thing in the game that can take a blow below the floor.
Verified by mutation: the naive version turns a 2-damage blow into 2, and takes
0 off a 10-damage blow.

Combat is loud. Attacking propagates noise from both the attacker and the
defender, which wakes creatures through stone at a fixed radius. This closed a
hole large enough to win the game through: a bowshot used to be silent where the
bow was, so an archer's corner was permanently quiet and shoot-and-retreat cost
nothing. Eight of fifteen creatures are slower than the player and can never
close, so those turns were free. A first-time playtester found the loop in one
sitting.

An emergent consequence the developer found in play and the design now protects:
**the climb is a stealth game**, because attacking draws the floor onto you.

---

## 7. Items, enchantments and a single binding table

Items are catalogue entries — declarative dictionaries of name, kind, slot,
bonuses, depth range and drop weight. About 35 of them.

Magic is modelled as one mechanism with two delivery routes: an **element** bound
to an item. It can arrive as a gem the player binds by choice, or pre-rolled on
found equipment. The gem is the better prize because it is *portable* — you
choose the host — not because its effect is rarer, so both routes share one pool.

Binding is **irreversible** and costs a consumable resource plus the remaining
heat of a fire. That irreversibility is the whole weight of the choice.

One table now declares every element, what may hold it, and which gem carries
it. Before that, adding an element touched five places — a catalogue entry, a
branch of the "what accepts what" check, a parallel list of findable
enchantments, sometimes a helper, and the effect itself. Four of those were
bookkeeping saying the same thing in four grammars.

What deliberately did **not** move into the table is the effect. Fire works
because the combat code has a branch for it; a table pretending otherwise would
be a lookup pointing at nothing. Behaviour is code. A new element is now two
places: a row, and the thing it does.

The three shield enchantments are a designed *competition*: they share one
permanent binding site and one tier table, so the decision is which of three to
commit to, not whether to take the only one on offer.

---

## 8. Content authoring

Room templates are plain text files — a grid of characters with a small header
of metadata. They are authored by the developer rather than generated, validated
by a linter that runs as part of the suite, and editable through a browser-based
tool generated from the game's own tables.

There is a deliberate chain of indirection here that looks like duplication and
is not:

```
template char  →  tile type  →  appearance id  →  glyph + colour
```

The `#` in a template file is not the character a player sees. Each arrow is a
different question with a different owner, and collapsing them would couple
authoring to rendering.

---

## 9. Persistence, and an anti-scum rule

Three separate stores:

- **A suspend slot.** Saving quits; loading **destroys the file**. You cannot
  save-scum, because there is no save to return to. RNG state is written as a
  string rather than a number, because JSON stores numbers as doubles and a
  64-bit state would silently lose its low bits — a resumed run would drift.
- **A morgue.** A human-readable log of every death: level, cause, depth, what
  was carried, turns survived, what killed you most often, and what you were
  wearing. Deliberately a text format a person can read.
- **Settings**, including input bindings, kept separate because they describe
  the player rather than the run and must survive death.

The morgue is becoming an economy rather than a record: dead characters can be
raised as temporary allies, and a design in progress has a merchant stocking the
gear of characters who were raised and then died again — permanently gone
otherwise, since the dungeon is one-way.

---

## 10. Rendering through semantic ids

Nothing in the simulation knows what anything looks like. The world is described
in semantic identifiers — `wall`, `goblin`, `brazier` — and a theme layer maps
those to appearance.

Three themes ship: letters, symbols, and an icon font. Colour lives in one table
and the alternate themes override only the character, so adding a creature means
one entry, not three.

Two rendering lessons worth recording because both were invisible locally:

- **A terminal will lie about fonts.** A glyph missing from the bundled font
  still renders correctly in a terminal, an editor and a desktop build, because
  all three silently substitute a system font. A *web* build has no system font
  and ships an empty box. Four symbols in one theme draft were absent from the
  bundled font and looked perfect everywhere they could be checked.
- **A font subset is a second font.** The map is drawn with a subsetted icon
  font; two characters used by the letters theme were not in the subset, so four
  tiles rendered as blank coloured squares for as long as that mode existed. The
  test that should have caught it was asserting against the *other* font. A test
  pointed at the wrong artefact is worse than no test, because it reads as
  coverage.

---

## 11. Input: controllers as synthetic keystrokes

Every panel in the game reads keycodes. Rather than teach seven files about
joypads, a controller layer translates joypad events into the keycodes they
stand for and feeds them through the same entry point a real keypress uses.
Nothing downstream knows a controller exists.

The alternative — engine-level input actions bound to both keys and buttons — is
the tidier long-term answer and would give keyboard rebinding for free. It was
rejected on cost: it means rewriting input handling in seven files, and the
translation layer made a handheld playable in one.

The approach has one sharp edge, which is the kind of thing worth showing an
evaluator. Because a synthetic keypress carries no modifiers, **any action that
required a modifier key was unreachable from a controller** no matter how it was
bound. Four actions — both stair directions, praying and the light source — were
impossible on a pad-only handheld; the game could not leave the first floor. The
fix had two halves: reassigning the d-pad (movement was already better served by
the analogue stick, which covers eight directions rather than four), and making
the general "interact" key contextual so that the tile decides what it means.

A related class: the config file that stores bindings *replaces* the defaults
wholesale when loaded. Every player who had ever opened the rebinding screen kept
their old bindings forever and never received the fix.

---

## 12. Testing, which is the most distinctive part

1,601 assertions, run headless, including statistical tests that generate
hundreds of floors. But the count is not the interesting claim. The working
theory is:

> **The commonest defect in a test suite is not a wrong assertion. It is one
> that never runs.**

Practices that follow from it:

- **Every block of "this is refused" checks needs one check that must succeed.**
  A block of refusal checks once all passed while aiming at a target that had
  already moved away — an early return fired and the guard under test was never
  reached.
- **Assert the precondition, not only the outcome.** A before/after comparison
  passes vacuously when there is no "before".
- **An unchanged total after adding a feature means the feature has no
  coverage.**
- **Mutation testing as routine.** After a fix, the bug is deliberately
  reintroduced to confirm the new test fails. This has repeatedly caught tests
  that could not fail, and it produces useful diagnostics: reverting one change
  printed `0 off a 10-damage blow`, which proved a design argument that had
  until then been an assertion.
- **Never let a test construct a game object by hand.** A test helper that
  duplicated a spawn function's field list drifted three separate times; each
  time the suite asserted behaviour the real game did not have. Tests call the
  game's own constructors.
- **A green total is not a pass.** A script error aborts a test function
  silently in this runtime while the suite still prints a total. One such error
  aborted eight of nine checks in a new test while the summary read
  `1419 passed, 0 failed`. Every run greps for runtime errors separately.

A recurring theme: **the author of a check is the worst person to judge whether
it can fail**, because they read it through the intent they are holding in their
head.

Alongside the suite there are ~31 measurement tools — not tests, but probes that
answer questions. They exist because the project's rule is to measure rather than
assert. Examples of findings: a softlock reproduced on 47 of 240 generated
floors; a "pity" item placement that fired on 0 of 120 floors when it was
supposed to guarantee one; healing supply that stays flat in absolute terms while
maximum health triples, a 3.6× deflation nobody had chosen.

That last one was **deliberately not fixed**. The developer had already beaten
the game with that curve and liked the shape. The measurement is recorded along
with the knob to turn if it is ever wanted.

---

## 13. Known tensions and open questions

Offered because a design document without them is advertising.

- **One file is 38% of the codebase.** The central state object has grown to
  roughly 6,700 lines. It has not been split, on the argument that splitting a
  file everything depends on, for tidiness rather than a specific seam, costs a
  week and buys nothing measurable. A reviewer may reasonably disagree.
- **Effects cannot be data.** The element table declares what may hold what, but
  every actual effect is a branch in code. A proposal to make content fully
  data-driven was rejected on the grounds that the parser is the easy part and
  the effects are the hard part — a text file can reference behaviours, not
  invent them. This is a defensible position, not an obviously correct one.
- **Adding content changes seeds.** Because draw counts depend on content, any
  new item or creature shifts every seeded run. This is the main structural
  argument against user-supplied content, and it is unresolved.
- **A statistical anomaly remains open.** Two halves of the dungeon that share a
  band and an identical eligible template set diverge from the rule's own
  probability in opposite directions, at roughly 3 sigma pooled over 150 floors.
  The finding is specifically the two halves disagreeing *with each other*. Cause
  unknown; it wants the request instrumented against what is actually placed
  rather than more samples of the outcome.
- **A post-hoc significance mistake, recorded rather than hidden.** An earlier
  version of that finding compared a pair chosen *after* looking at all 19
  depths. With that many candidate comparisons available, a post-hoc 3 sigma is
  worth far less than it sounds. The comparison was re-run at a larger sample and
  the original claim withdrawn.
- **The damage model excludes a whole design space.** Nothing ever misses, on
  purpose. That rules out evasion, accuracy, and critical hits as mechanics. It
  is a coherent choice that closes doors.

---

## 14. What a reviewer might usefully attack

- Is the sim/render split worth its indirection at this scale, or is it
  ceremony? (The counter-argument is that it is what makes 1,601 headless
  assertions possible.)
- Is the comment density excessive? The codebase carries a great deal of prose
  explaining *why*. It is the project's main defence against relitigating
  decisions, but it is also a maintenance surface — a comment that drifts out of
  date is worse than none, and this project has caught several.
- Is the determinism requirement paying for itself? It constrains refactoring,
  content and modding. What it buys is reproducible bug reports and a resumable
  save.
- Is a translation layer that turns controllers into synthetic keystrokes a
  clever solution or a deferred problem? It has already produced one class of
  bug (modifiers) that the "proper" approach would not have.
- Should one 6,700-line file be split, and along which seam?
