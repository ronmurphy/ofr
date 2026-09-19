# Controller support

For Brad and the four itch testers running OFR on a handheld.

Everything here is committed, the suite is green at HEAD, and the instructions
are checked against the build scripts as they actually stand rather than
remembered.

**If you read one thing, read section 2.** Launching the game directly instead
of through Steam is the single reason a controller appears not to work, and it
is not a bug in the game.

## 1. Get the build

```
tools/build_linux.sh
```

It produces **one file** — `ofr.x86_64`, with the `.pck` embedded — and packs
it as `build/ofr-linux-x86_64.tar.gz`. The script prints the sizes when it
finishes. They are deliberately not written down here, because a recorded
measurement goes stale.

It used to be two files that had to travel together, and copying only the
executable gave "Couldn't load project data" and nothing else. Embedding makes
that mistake impossible.

**Build it fresh before sending it anywhere.** A binary from before a fix lands
someone testing a problem that's already solved and reporting it as still
broken. The check that needs nobody's word: if `build/linux/ofr.x86_64` is
older than `src/`, it is the wrong build.

**Unpack with `tar`, not a zip tool.** tar records the executable bit, zip
discards it:

```
tar -xzf ofr-linux-x86_64.tar.gz
./ofr.x86_64
```

If the binary arrived some other way and refuses to start, `chmod +x
ofr.x86_64` is the missing step. Copying to a FAT32 USB stick strips that bit,
so chmod on the handheld rather than before.

## 2. Launch it through Steam. This is not optional.

**Add `ofr.x86_64` to Steam as a non-Steam game and launch it from there.**
Desktop mode or gaming mode — either works, once Steam is in the chain.

**Run `./ofr.x86_64` directly and the controller will do nothing, and the
rebinding screen will capture nothing.** This cost a two-hour diagnosis before
it was understood.

Why, because "just use Steam" is not an answer anyone can act on:

Steam Input takes **exclusive** ownership of a handheld's built-in controller,
so games can't receive doubled input, and it blanks the real device node to
enforce that. On a Legion Go S, `/proc/bus/input/devices` lists both pads and
the permissions tell the whole story:

```
/dev/input/event4    c---------   real "Legion Go S"        mode 0000, unopenable
/dev/input/event14   crw-rw----@  virtual "X-Box 360 pad"   readable via ACL
```

Outside Steam the game can see neither: the physical pad is locked away, and
the virtual one that would replace it doesn't exist yet. Nothing is wrong with
the bindings, the defaults or the input code — **the pad is hidden at the OS
level before OFR gets a say.**

This is not Valve-specific, and not about desktop versus gaming mode. Both were
early guesses and both were wrong. **The variable is whether Steam is in the
launch chain at all.**

### If a controller does nothing, ask this before anything about bindings

```
cat /proc/bus/input/devices     # does the OS list a pad at all?
./ofr.x86_64 --pad-log          # did the game receive it?
```

- **Neither sees a pad** → it's the launch path, not OFR.
- **The OS sees one, the game doesn't** → then it's ours, and the log says why.

## 3. Defaults, so most people never open the rebinding screen

D-pad walks · `A` wait · `B` pick up · `X` inventory · `Y` look · `LB` shoot ·
`RB` swap reach/blade · `Start` menu.

That's the Xbox-style layout most handhelds report as. Right for most, wrong
for someone — which is why rebinding exists.

A binding is a promise that pressing that button is exactly like typing that
key. So `Y` really is the `x` key, and that's correct rather than a mismatch.

**The left stick needs no binding.** It's polled, quantised to the same eight
directions the keyboard has, with press-once-then-repeat so a held stick
doesn't fire sixty moves a second. **Diagonals come from the stick** — asking
anyone to bind eight directions on a four-way d-pad is a poor first
experience, so the d-pad stays four-way and the stick covers the corners.

## 4. The pause menu works entirely from the pad

`Start` opens it. **D-pad up/down moves the highlight, the wait button chooses.**
Every row — continue, controller, text size, save, abandon — is reachable with
nothing rebound.

The printed letters still work, and so does the mouse. All three read the same
table, so a new row is wired for all three at once.

**Text size lives here**, which matters most on a handheld: it cycles the cell
size and the map redraws behind the menu as you go.

## 5. The rebinding screen

`Esc` → `g`, or click **controller** in the pause menu.

It asks for fourteen bindings in order:

```
move up · move down · move left · move right · wait/rest · pick up
inventory · look · shoot · swap reach/blade · close a door
ally heel/loose · the legend · menu
```

Directions come first on purpose: anyone who gives up halfway still has a
controller they can walk with.

Every key the defaults hand out appears in that list, so any binding can be
restored. A binding you can lose and can't put back is worse than one never
offered.

The panel's own controls are **keyboard-only, deliberately** — someone
rebinding a controller that doesn't work can't be asked to use that controller
to escape the screen:

| key | does |
|---|---|
| `backspace` | back one row |
| `r` | restore the defaults |
| `l` | start logging this pad |
| `esc` / `enter` | done, and save |

One button means one thing. Binding a button that's already in use takes it off
its old job rather than doubling up.

Saved to `user://gamepad.cfg`. It describes hardware rather than a run, so it
survives death — it sits beside `settings.cfg`, not with the morgue.

## 6. The log — this is what we need back from testers

```
./ofr.x86_64 --pad-log
```

or press `l` on the rebinding screen. Either writes:

```
~/.local/share/godot/app_userdata/OFR/pad_log.txt
```

It records the pad's name, its GUID, and every button index and axis touched,
flushed line by line, so a force-quit still leaves a readable file. With no pad
attached it says `NO PAD CONNECTED -- nothing will be recorded`, so an empty
result is still a diagnosis.

**Please send that file, plus the device name.** The open question is whether a
Steam Deck, a ROG and a Legion Go S agree about which button index is "A". If
they don't, the fix is a per-device defaults table, and the logs are what make
it writable.

## 7. What the tests cover, and what they can't

The suite is at **1368 and green**, and almost none of it covers the
controller. Pad code is render- and node-layer, which a headless suite doesn't
reach, and **no test has ever seen a gamepad.** What the checks guard is
layout, dispatch and the binding table: that a menu row answers to its letter,
the mouse and the pad alike, and that every key the defaults hand out is one
the rebinding screen can hand back.

That limit is exactly where it bit. The controller failed its first contact
with real hardware and a green suite could never have caught it, because Steam
Input was hiding the pad before the game got a say.

**A hardware feature can be entirely correct and entirely non-functional at the
same time.** The handheld is the real test; the log is how it reports.

## 8. The files

```
src/render/gamepad.gd      joypad -> keycode translation
src/sim/pad_config.gd      bindings, saved to user://gamepad.cfg
src/ui/pad_panel.gd        the rebinding walk-through
src/render/main.gd         _unhandled_input, stick poll, --pad-log
src/ui/menu_panel.gd       the controller row; d-pad + wait navigate it
scenes/main.tscn           PadSetup node

tools/build_linux.sh       single-file build, packed as .tar.gz
tools/build_windows.sh     single-file OFR.exe
tools/optimize_art.sh      imagemagick + oxipng, for assets/art
```

The design that keeps this small: `Gamepad` turns joypad events into
**keycodes**, so every existing input-handling file works unchanged. No action
layer was invented. A binding is the promise that pressing this button is
exactly like typing that key — a smaller promise, and an easier one to be sure
of.
