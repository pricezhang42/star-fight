# Star Fights (vertical version)

This is the **`vertical` branch**: the same game, but it scrolls upwards.
Luke starts at the bottom and climbs; the level keeps generating above him.
The play area is 2600 px wide with rock walls on the left and right, and the
camera fits the full width on screen. Your score is how high you climb
(furthest point, 1 point per 10 pixels) plus 100 points every time Luke stuns Darth. The best score is saved separately from the side-scrolling version
on `main`. The game starts in fullscreen.

## Controls

Two players share one keyboard and mouse: **Luke** flies the starship and
**Darth** plays the alien astronaut.

**Luke, the starship**
- **A / D:** rotate the ship
- **W:** thrust. Hold to speed up; let go and the ship coasts to a stop in
  about a second.
- **S:** brake hard.
- **Space / J:** fire lasers forward
- **B:** fire lasers backward out of the tail (same rate as the front gun;
  both can fire at once)
- **Shift:** dash forward (about +370 px over half a second). For the first
  0.4 s the ship flies straight through rocks, planets and satellites (it
  keeps passing through until it is clear, so it never gets stuck), and it
  can't lose a life, so it can also punch through a laser, comet or bullet.
  Recharges in 10 s; shown under Luke's lives. Rocks the dash passes
  through get shoved out of the way.

**Darth, the alien astronaut**
- **Health colour:** Darth is black when healthy, yellow after 1 laser hit
  from Luke and red after 2. The 3rd hit stuns Darth for 5 s (grey, spinning
  stars): no moving, throwing, items or crate pickups, and the comet recharge
  pauses. Luke gets +100. Hits during the stun and for 2 s after it don't
  count, and if Luke goes 4 s without a hit the colour steps back down one
  level.
- **Arrow keys:** run along the dashed U-shaped track: down the left edge of
  the screen, along the bottom and up the right edge (there is no top edge;
  the two top corners are dead ends). Press along the edge you're on to move.
  At a corner, press toward the next edge, or keep pressing the way you were
  going, to go round it.
- **Left click:** throw a fast green comet toward the mouse (recharges for
  4 s). Thrown comets bounce off asteroids and knock them away.
- **Crates:** item crates appear at random spots on Darth's U-shaped track every 6-8 s
  (at most 2 at once, each lasts 8 s and blinks before it vanishes). Each crate
  shows the icon and name of the item inside; run over it to collect that item.
- **Right click:** use the selected item. **Mouse wheel:** switch item.

**Both:** Enter / R restarts after Luke's ship is lost. F11 switches between
fullscreen (the default) and a window.

## Darth's items

Darth collects items from crates on the track and can hold up to 3 (shown under
Darth's line at the top of the screen; the selected one is highlighted).

| Item | Effect |
| --- | --- |
| Chaos | Luke's turning is swapped for 2 s (A and D trade places; W/S are unaffected). Luke's ship turns purple and "CONTROLS REVERSED!" shows. |
| Flash | A dark cloud covers the spot Darth clicked for 4 s, after a bright flash. |
| Hunter | A purple enemy ship spawns next to Darth, always hunts Luke (slightly faster than Luke's top speed), shoots, and dies in 3 hits. It leaves after 20 s. |
| Laser | A flashing red warning line points where Darth clicked for 1 s, then a beam fires along it and costs Luke a life if it touches him. It passes through everything and destroys every breakable rock on its line, so it can also carve tunnels. Dodge sideways during the warning. |
| Giant | Luke's ship and hitbox double in size for 3 s. |
| Slick | Oil on Luke's thrusters for 4 s: turning builds up and keeps spinning after you let go, and the ship slides along its old path instead of following its nose. The ship turns light blue and "SLIPPERY STEERING!" shows. |

Darth's HITS count comet and laser hits on Luke.

## Rules

- **Asteroids** (the rocks in belts and clumps) are physics objects: they sit
  still until something knocks them, then drift and bump into each other
  before slowing to a stop. Luke's lasers break small ones in 1 hit and big
  ones in 3. The rocks along the top and bottom edge are unbreakable.
- **Moving asteroids** drift around and bounce off everything (5 in the
  opening, 3 per stretch early on, up to 7 later).
- **Comets** fly across the screen (at most 2 random ones at once).
- **Black holes** bend comets and the hunter's bullets (not Luke's lasers or
  Darth's beam) and swallow them at the core.
- Only Darth's hunter shoots (at most 2 of its bullets in the air at once).
  Satellites, red ships and chasers are obstacles to avoid.

- You have 5 lives. Rocks, planets, satellites, aliens, alien lasers, comets
  and black hole cores each cost one and give a 3 second shield (you bounce off
  solid objects).
- Planets come in many sizes, each with a satellite circling it. Blue
  satellites are harmless, but still solid, so don't fly into them.
- A red starship flies a looping curved path (3 hits to destroy).
- In the middle: a black hole pulls your ship in. The faint ring shows how far the
  pull reaches. Touching the core costs a life and throws you well clear; for 1.6 seconds
  afterwards black holes can't pull you, so you can't get stuck.
- A planet with a red satellite (4 hits to destroy).
- Near the top: asteroid belts (clumps plus short vertical and diagonal strips).
- After that the level keeps generating forever from the same pieces. It
  starts sparse and calm (one obstacle per column at most, small clumps,
  many empty columns), stays easy until a score of about 640, then ramps up
  until a score of about 2600: more rocks,
  planets and black holes, more enemy ships and chasers, more hostile
  satellites, faster and more frequent enemy fire, stronger black holes and
  more random comets. You can fly back down a little, but not all the way.
- Red alien fighters hover around and ram you once you get close.
- Burning comets fly across the screen at random and block your lasers.

## Editing the level

Open `scenes/main.tscn` to edit the hand-made opening section. All level
content lives under the `Level` node, which is rotated 90 degrees: inside it
the level is laid out sideways (local x = height climbed, local y = 0 to 2600
across), exactly like the side-scrolling version.
Everything after it comes from `scripts/level_generator.gd`; tweak its
`chunk_width`, `ramp_distance` and the odds inside `_build_chunk` to change
how the endless part plays.

- **Planets** (`PlanetA`, `PlanetB`): set `radius` and `texture`. A child
  `Satellite` sets `orbit_radius`, `orbit_speed` and `hostile`.
- **Curved enemy path:** select `ShipPath` and drag its curve points. Ships
  under it set `speed` and their starting `progress`.
- **Asteroid belts:** `AsteroidCluster` scatters rocks in a circle (`radius`,
  `count`). `MeteorWall` makes a strip (`length`, plus an optional
  `gap_center`/`gap_size`); rotate the node for diagonals. Both rebuild live in
  the editor.
- **Chasers** have `detect_radius`, `lose_radius` and `speed`.
Black holes (under `BlackHoles`) have `pull_radius`, `core_radius` and
`strength`. Comet frequency and speed are on the `Main` node.
