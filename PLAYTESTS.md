# PLAYTESTS.md — what players did, said, and asked

One section per playtest, newest first. Record **what people did** as well as
what they said: a question a player asks is a place where the game failed to
explain itself. Decisions that come out of a playtest move into `BACKLOG.md`;
this file keeps the evidence behind them.

---

## 2026-09-26 — first fresh players

Brad took the Legion Go S to a friend's house. Nobody there had seen OFR before.

| Tester | Device | Build |
|---|---|---|
| Teen (17–20) | PC, keyboard and mouse | Linux binary |
| Teen (17–20) | Legion Go S | Through Steam |
| Their parents | Browser | itch web build |
| Youngest son, 10 | (watched) | — |

The teens played about three runs each. Both reached floor 2 and died at least
twice. All three builds ran without trouble.

### What Brad saw

- **Neither teen found the controls on their own.** Brad had to point out `?`
  (the legend) on both devices. After that, they worked everything out
  themselves. The sidebar's "press ? for help" line is not being read.
- **The Legion player lived in the context box** (HERE), learned from it more
  than from the legend, and then showed it to the PC player, who started using
  it too.
- **The PC player barely used the mouse** outside the pack and the trader.
  After reading the legend he switched from the arrow keys to the vi-keys
  (`hjkl`).
- **The Legion player worked out aiming and firing the sling first.**
- **Kobold slingers taught their lesson.** After dying to them, the PC player
  started peeking around room corners to bait them into melee.

### What they said

**PC teen**

- "Make the traps less obvious. If I can easily spot a trap I won't ever step
  on it; it feels wasted."
- "I can't tell that the water and mud and gravel do anything." Once Brad
  showed him that monsters take two steps while he takes one through mud, he
  tried it and got it: "OK, I see what you mean, but it feels less obvious that
  way."
- "I hate the kobold slingers. If you don't have armour or a ranged weapon,
  you'd better run."
- **Possible bug:** monsters seemed able to shoot him around a corner, but he
  couldn't shoot them back from the same spot.

**Legion teen**

- The game is fun, and they understand it's meant to look retro, but asked for
  more colour and more effects in places.
- "You play D&D, Brad. Why aren't there any wands of fireball or lightning
  bolt, or scrolls of invisibility?"
- "Isn't 19 floors a bit small?" (Brad explained the descent and the climb:
  it's about surviving each floor, not the count.)
- "I bet if this was in 3D it would look amazing."
- "I really like the idea of the uniques."
- "Why does the trader speak funny, and why does he never move while the bad
  guys move?"
- "If you and Claude keep working on it, you should put it on Steam."
- Both teens asked why the game is so dark. "It's a dungeon" satisfied them.

**Parents** (the father played the original Rogue)

- "This has that feeling of the original Rogue."
- The father raised risen bones and called it "the smartest thing I've ever
  seen in a roguelike: your previous run still helps you a bit." Once he learned
  you can gather several runs' bones in one run, he called it planning for the
  next four runs rather than this one.
- The mother loved the undertaker's shovel. She dug up a bear, enjoyed watching
  it knock things back, was sad when it died, and wanted another shovel.
- "The dead-party system will take a while to build a good party. Why not hire
  mercenaries from someone?"
- Suggested an intro or title screen: New game, Continue, Artwork viewer, How
  to play.
- "The story feels a bit sparse."

**Youngest son, 10 — the screen size and Esc:** on his 1080p laptop the game
did not fit (it is laid out at 1600 wide). Fullscreen helped, but then he asked
how to reach the menu. Esc is the menu key, and **in a browser Esc also leaves
fullscreen** — browsers reserve it and no page can override that — so the
menu took two presses and he gave up, upset. The game itself scales to any
window (`canvas_items` stretch, adaptive canvas); the fixed size is most likely
the itch embed, which on a laptop at 125–150% scaling leaves only ~1280–1536
pixels of room.

**Youngest son, 10:** "It looks not like art." Shown a screenshot of Gabe's 3D
view: "OK, make it like that and I will play it."

### What came of it

- **`?` hint:** bold and coloured on floors 1–2, back to normal after that or
  once the legend has been opened. Planned before the breathe pass.
- **Terrain status:** the sidebar's `footing` line becomes a status line with
  an icon, "wading · slowed" (the Legion teen's idea). It becomes the place
  status effects live; the miasma will be the next one. The context box says
  it too.
- **Shooting around corners:** first item for the day-7 bug hunt. If line of
  sight is not symmetric for ranged attacks, that is a fairness bug.
- **Slingers:** measure early deaths in the hunt first. Brad's option: they
  fire every other round on the first floor they appear, as a teaching floor.
- **Traps:** you may spot one within 3 squares (a chance, not a certainty); a
  trap-finding unique for the offhand adds +50%; spotting is likelier in
  torchlight.
- **An intro sequence** on new game, with a skip button, explaining the trader
  and why you are here. Later a title screen with How to play.
- **Mercenaries:** Brad's version is risen monsters from the trader's own
  floor, weaker than bone allies or lasting one floor. A design conversation.
- **Screen size and the menu:** set the itch embed smaller (for example
  1280×720) and keep itch's fullscreen button — no code. Add a clickable
  "menu" button to the sidebar and a second menu key that browsers do not
  reserve, shown in the legend. Planned for Monday morning.
- **Visuals and 3D:** the breathe pass and Gabe's 3D view, both already
  planned, are what these players asked for most.
