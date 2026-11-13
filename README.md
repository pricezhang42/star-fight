# Star Fights

An endless 2D top-down Godot 4 game. Your ship always drifts forward; fly as
far right as you can through asteroid belts, planets, black holes and alien
ships. Your score is the distance you reach (furthest point, 1 point per 10
pixels), and your best score is saved between runs. The camera zooms so the
whole level height fills the screen, and the window opens at about 92% of your
monitor.

## Controls

Two players share one keyboard and mouse: **Luke** flies the starship and
**Darth** plays the alien astronaut.

**Luke, the starship**
- **A / D:** rotate the ship
- **W / S:** speed up / brake (speed is kept when you let go; the ship never
  fully stops)
- **Space / J:** fire lasers forward
- **B:** fire lasers backward out of the tail (same rate as the front gun;
  both can fire at once)
- **Shift:** dash forward (about +370 px over half a second). Luke can't
  lose a life for the first 0.3 s of a dash, so it can punch through a
  laser, comet or bullet. Recharges in 10 s; shown under Luke's lives.

**Darth, the alien astronaut**
- **Arrow keys:** run along the dashed rectangle track around the edge of the
  screen. Press along the edge you're on to move. At a corner, press toward
  the next edge, or keep pressing the way you were going, to go round it.
- **Left click:** throw a green comet toward the mouse (recharges for 4 s).
- **Right click:** use the selected item. **Mouse wheel:** switch item.

**Both:** Enter / R restarts after Luke's ship is lost.

## Darth's items

Darth gets a random item every 10 seconds and can hold up to 3 (shown under
Darth's line at the top of the screen; the selected one is highlighted).

| Item | Effect |
| --- | --- |
| Chaos | Luke's controls are swapped for 2 s (A/D and W/S). Luke's ship turns purple and "CONTROLS REVERSED!" shows. |
| Flash | A dark cloud covers the spot Darth clicked for 4 s, after a bright flash. |
| Hunter | A purple enemy ship spawns next to Darth, always hunts Luke (slightly faster than Luke's top speed), shoots, and dies in 3 hits. It leaves after 20 s. |
| Laser | A flashing red warning line points where Darth clicked for 1 s, then a beam fires along it and costs Luke a life if it touches him. It passes through everything, so dodge sideways during the warning. |
| Giant | Luke's ship and hitbox double in size for 3 s. |
| Slick | Oil on Luke's thrusters for 4 s: turning builds up and keeps spinning after you let go, and the ship slides along its old path instead of following its nose. The ship turns light blue and "SLIPPERY STEERING!" shows. |

Darth's HITS count comet and laser hits on Luke.

## Rules

- You have 5 lives. Rocks, planets, satellites, aliens, alien lasers, comets
  and black hole cores each cost one and give a short shield (you bounce off
  solid objects).
- Planets come in many sizes, each with a satellite circling it. Blue
  satellites are harmless, but still solid, so don't fly into them.
- Top middle: two red starships fly a looping curved path and shoot at you
  (3 hits each to destroy).
- Middle: a black hole pulls your ship in. The faint ring shows how far the
  pull reaches. Touching the core costs a life and throws you well clear; for 1.6 seconds
  afterwards black holes can't pull you, so you can't get stuck.
- Bottom middle: a planet with an enemy satellite that orbits and shoots at
  you (4 hits to destroy).
- Right: asteroid belts (clumps plus short vertical and diagonal strips).
- After that the level keeps generating forever from the same pieces. It
  starts sparse and calm (one obstacle per column at most, small clumps,
  many empty columns), stays easy until a score of about 640, then ramps up
  until a score of about 2600: more rocks,
  planets and black holes, more enemy ships and chasers, more hostile
  satellites, faster and more frequent enemy fire, stronger black holes and
  more random comets. You can fly back a little, but not all the way.
- Red alien fighters hover around and chase you once you get close.
- Burning comets fly across the screen at random and block your lasers.

## Editing the level

Open `scenes/main.tscn` to edit the hand-made opening section (x 0 to 3400, height 1680).
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
