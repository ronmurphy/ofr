# Controller support — what to do when you get back

Everything below is built and **uncommitted**. The Linux export is built and
verified; the instructions are not guesses.

## 1. Build the handheld binary

```
tools/build_linux.sh
```

**Run it yourself before you transfer anything.** I built once at 10:29 to
prove the export works, then seven source files changed underneath it — text
size, the pad-navigable menu, stretch/aspect, the hairline fix, and my own
`WALK` and panel changes. A binary from before those lands you testing the
exact problems we spent the afternoon fixing and concluding they're still
broken. If the two files in `build/linux/` are older than `src/`, they are the
wrong build.

It produces two files in `build/linux/` — `ofr.x86_64` and `ofr.pck`. The
script prints both sizes when it finishes; I've left the numbers out here
rather than record a measurement that goes stale, which is the mistake this
document already made once.

**They must travel together, in the same folder, with matching basenames.**
Copying only the executable gives "Couldn't load project data" and nothing
else. `build/` is gitignored, so these never enter a commit.

On the Legion Go S:

```
chmod +x ofr.x86_64
./ofr.x86_64
```

## 2. The controller screen

`esc` → `g`, or click **controller** in the pause menu. Both paths work —
the mouse row was dead until I wired it just now, the keyboard `g` was fine.

It asks for fourteen bindings in order:

```
move up · move down · move left · move right · wait/rest · pick up
inventory · look · shoot · swap reach/blade · close a door
ally heel/loose · the legend · menu
```

The last three were missing at first. The defaults bound them, but the
walk-through didn't offer them — so rebinding could knock close-door off its
button with no way to put it back except `r`, which throws away every other
choice too. A binding you can lose and can't restore is worse than one never
offered.

Directions come first on purpose: someone who gives up halfway still has a
controller they can walk with.

The panel's own controls are **keyboard-only, deliberately** — someone
rebinding a controller that doesn't work can't be asked to use that controller
to escape the screen:

| key | does |
|---|---|
| `backspace` | back one row |
| `r` | restore the Xbox-style defaults |
| `l` | start logging this pad |
| `esc` / `enter` | done, and save |

Saved to `user://gamepad.cfg`. It describes hardware, not a run, so it
survives death — it sits beside `settings.cfg`, not with the morgue.

One button can only mean one thing. Binding a button that's already in use
takes it off its old job rather than doubling up.

## 3. Defaults, so most people never open that screen

D-pad walks, `A` wait, `B` pick up, `X` inventory, `Y` look, `LB` shoot,
`RB` swap, `start` menu. That's the Xbox-style layout most handhelds report
as. It's right for most and wrong for someone, which is exactly why the
rebinding screen exists.

**The left stick needs no binding.** It's polled, quantised to the same eight
directions the keyboard has, with press-once-then-repeat so a held stick
doesn't fire sixty moves a second. Diagonals come from the stick — asking
someone to bind eight directions on a four-way d-pad is a poor first
experience, so the d-pad stays four-way and the stick covers the corners.

## 4. The log — this is the part I actually need from the four testers

```
./ofr.x86_64 --pad-log
```

or press `l` on the controller screen. Either writes:

```
~/.local/share/godot/app_userdata/OFR/pad_log.txt
```

It records the pad's name, its GUID, and every button index and axis touched,
flushed per line, so a force-quit still leaves a readable file. I ran it here
with no pad attached and it correctly says `NO PAD CONNECTED -- nothing will
be recorded` — so a tester whose pad Godot can't see gets a diagnostic line
rather than an empty file they can't interpret.

**Ask each of the four for that file**, plus device name. The question I can't
answer from here is whether a Steam Deck, a ROG and a Legion Go S agree about
which index is "A", and my strong guess is at least one of them doesn't. If
they disagree, the fix is a per-GUID defaults table, and the logs are what
would let me write it.

## 4b. The whole pause menu works from the pad

The second session added a **text size** row while I was working — good timing
for a handheld, and you okayed the mixed commit.

For about an hour it was unreachable. I checked the three sets rather than
guessing: the menu needed `C ESCAPE G N S T`, a default pad could send
`A C DOWN ESCAPE F G I LEFT PERIOD QUESTION RIGHT UP W X`, and the rebinding
walk-through couldn't bind `T` or `S` at all. So on a handheld with no
keyboard you could not have changed the text size that was built for
handhelds, and could not have saved your run.

**That is fixed and it is in this build.** The menu now takes **d-pad up/down
to move the highlight and the wait button (A) to choose**, so every row —
including text size and save — works from the pad with nothing rebound. The
letters still work, and the mouse still works; all three now read the same
`OPTIONS` table, so adding a row wires all three in one edit.

That last part matters more than the fix. There used to be three hand-kept
lists, which is why the controller row shipped working by letter and dead to
clicks.

## 5. Two things to know before you commit

**The suite tally is unchanged at 1334.** That is not a pass — it means
**none of the gamepad code has a test**. It's render- and node-layer code,
which the headless suite doesn't reach. What 1334/0 tells you is that I
didn't break anything that was already covered. Treat the pad code as
play-tested only, and the handheld as the first real test.

**There's a pre-existing font bug I did not fix.** The exported build logs:

```
ERROR: Cyclic font fallback.
```

`src/render/glyph_grid.gd:192` sets `ofr_icons.fallbacks = [JetBrainsMono]`,
and `src/ui/sidebar.gd:487` sets `JetBrainsMono.fallbacks = [ofr_icons]`.
`load()` returns the same cached resource instance both times, so those two
lines mutate shared objects into a cycle, and Godot **silently rejects
whichever runs second**. One of those two fallback chains isn't wired, and
which one depends on load order.

This is the same territory as the comment in `sidebar.gd` about "killed by"
being a tofu box on itch since the day it shipped. It may be the cause, or
unrelated. It's unrelated to the controller work, so I left it alone rather
than mixing two systems into one commit — but it's worth its own look.

## 6. Files in this change

```
new     src/render/gamepad.gd      joypad -> keycode translation
new     src/sim/pad_config.gd      bindings, saved to user://gamepad.cfg
new     src/ui/pad_panel.gd        the rebinding walk-through
new     tools/build_linux.sh       the handheld build
mod     src/render/main.gd         _unhandled_input, stick poll, --pad-log
mod     src/ui/menu_panel.gd       the controller row, keyboard and mouse
mod     scenes/main.tscn           PadSetup node
```

The design that makes this small: `Gamepad` turns joypad events into
**keycodes**, so all seven existing input-handling files work unchanged. No
action layer was invented. A binding is the promise that pressing this button
is exactly like typing that key — a smaller promise, and an easier one to be
sure of.
