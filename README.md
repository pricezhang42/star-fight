# Star Fights (vertical versus)

Two starships, one blue and one red, climb the same endless, upward-scrolling
level and try to outlast each other. Each ship has 5 lives; **the last ship
still flying wins**. There is no score.

After a 3 second GET READY countdown the screen scrolls up on its own, starting
at 60 px/s and speeding up by 8 px/s per 1000 px climbed (up to 260 px/s; shown
as SCROLL xN at the top). Falling below the bottom edge costs a life and
bumps the ship back onto the screen (a red glow warns when you get close).
Flying into the top third makes the screen speed up to keep that ship in view,
which also drags the bottom edge up toward the other ship.
The play area is 2600 px wide with rock walls on the left and right, and the
camera fits the full width on screen. The game starts in fullscreen.

## Playing

The game opens on a title screen:

- **Solo practice:** fly the blue ship alone through the level.
- **Host LAN game (blue ship):** this computer runs the game. The screen
  shows its network address(es). The game starts as soon as the other player
  joins.
- **Join (red ship):** type the host's address and press Join, or click a game
  listed under "Games found on your network" (hosts are found automatically).

Each player needs their own computer, keyboard and mouse. The host computer
runs everything; the joining computer just shows the same picture (with black
bars if the screens are a different shape) and sends its keys and mouse to the
host. Both computers need the same version of the game, on the same network.
The first time you host, macOS asks whether to allow incoming connections:
allow it. Either player can press Enter to restart after the match ends. Esc
goes back to the title screen (and leaves a LAN game; the other player is sent
back to the title screen too).

**If the network won't let the two computers talk** (common on school and
office Wi-Fi, which often blocks devices from reaching each other):

1. **Phone hotspot (easiest):** turn on a phone's personal hotspot and join it
   with both computers, then host and join as usual. Only game traffic flows
   between the two computers, so it uses almost no phone data.
2. **Cable:** connect the two Macs with a Thunderbolt / USB-C cable (or an
   Ethernet cable with adapters). macOS sets up a "Thunderbolt Bridge"
   network automatically; the host screen shows a 169.254.x.x address to join.
3. **Tailscale or ZeroTier (free VPN):** install it on both computers and sign
   in to the same account; it connects them even through strict networks and
   from different places. Join the host's 100.x.x.x address. (Check that your
   school allows installing it.)

For testing on one machine you can also start the game from the command line
with `-- --host` or `-- --join=127.0.0.1`.

To make a double-clickable Mac app, install Godot's export templates
(Editor > Manage Export Templates > Download and Install), then use
Project > Export with the included "macOS" preset.

## Controls

Both players use the same controls, each on their own computer:

- **A / D:** rotate the ship
- **W:** thrust. Hold to speed up; let go and the ship coasts to a stop in
  about a second.
- **S:** brake hard.
- **Mouse:** aim the laser. The turret on top of the ship swivels to point
  at the cursor and fires that way, whichever way the ship's nose points.
- **Left click:** fire one heavy laser shot, then it recharges for 5 s
  (shown under each ship's dash). The shot works like the comets Darth used
  to throw: it flies fast, bounces off asteroids and knocks them away, flies
  over planets, satellites, walls and comets, is bent by black holes, and
  costs the other ship a life if it hits. One shot also destroys the other
  ship's missile or rocket, and any NPC ship (red ships, chasers); red
  satellites take two.
- **Shift (hold):** boost. Top speed goes from 340 to about 545 and the ship
  speeds up faster, even without W. It uses stamina (the bar under each
  ship's HUD): a full bar lasts about 3 s. Stamina refills by itself (about
  5.5 s from empty) once you let go; if it runs dry you have to wait for a
  quarter of the bar before boosting again.
- **Space:** dash forward (about +370 px over half a second). For the first
  0.4 s the ship flies straight through rocks, planets and satellites (it
  keeps passing through until it is clear, so it never gets stuck), and it
  can't lose a life, so it can also punch through a laser bolt or comet.
  Recharges in 10 s; shown under each ship's lives. Rocks the dash passes
  through get shoved out of the way.
- **Enter / R:** restart after the match ends. **F11:** switch between
  fullscreen (the default) and a window.

## Ship against ship

- A hit from the other ship's laser costs a life and gives the usual
  3 second shield. Your own bolts can't hurt you.
- Blue fires blue shots, red fires red ones.
- When the ships touch they bounce off each other a short way. Neither
  loses a life.
- When a ship runs out of lives the other ship wins.

## Power-ups

Glowing capsules float at random spots in open space: 3 in the opening section
and 1-2 in every new stretch of the level. Each shows its item's icon and name.
Fly through one to take it; whoever touches it first gets it. Each ship holds
up to **2** power-ups (shown under its lives, dash and laser); if both slots
are full the capsule stays where it is.

- **Right click:** use the selected power-up (aimed ones go where the turret
  points / toward the mouse).
- **Tab:** switch between your two power-ups.

| Power-up | Effect |
| --- | --- |
| Laser | A flashing warning line along your turret for 1 s, then a wide beam that costs the other ship a life if it crosses it and destroys rocks on its line. It can't hurt you. |
| Shrink | Your own ship shrinks to 60% size for 8 s: harder to hit, fits through tighter gaps. |
| Missile | A homing missile that chases the other ship (450 px/s, up to 7 s). It explodes on rocks, planets, satellites and walls; a hit costs a life. The other ship can shoot it down with its laser or dash through it. |
| Chaos | The other ship's A and D are swapped for 3 s. |
| Grenade | Thrown toward the mouse (up to 900 px); explodes where you clicked and pushes everything within about 450 px outward: ships, rocks, comets, missiles and shots. No damage. |
| Shield | A bubble in your ship's colour absorbs the next hit of any kind (no life lost), then pops. Lasts up to 10 s. |

**Weapon capsules** (red, tagged "WEAPON", about 1 in 4 capsules) don't use a
slot: they change your basic laser the moment you fly through them, for 20 s.
Picking up another weapon replaces the current one and restarts the 20 s. The laser line
in the HUD shows the weapon in use (and any Shield time left).

| Weapon | Effect |
| --- | --- |
| Rapid laser | The same shot, but it recharges in 2.5 s instead of 5 s. |
| Rocket | Left click fires a slower rocket (450 px/s) instead. It explodes on anything solid, a ship or an NPC, or after about 1,200 px. The blast (about 220 px) costs any ship in it a life, **including your own**, destroys rocks, damages NPCs and pushes things outward. |

## Rules

- **Asteroids** (the rocks in belts and clumps) are physics objects: they sit
  still until something knocks them, then drift and bump into each other
  before slowing to a stop. Lasers break small ones in 1 hit and big
  ones in 3. The rocks along the top and bottom edge are unbreakable.
- **Moving asteroids** drift around and bounce off everything (5 in the
  opening, 3 per stretch early on, up to 7 later).
- **Comets** fly across the screen (at most 2 random ones at once).
- **Black holes** bend comets (not the ships' lasers) and swallow them at the core.
- Satellites, red enemy ships and chasers don't shoot; they are obstacles to avoid.

- Each ship has 5 lives. Rocks, planets, satellites, aliens, comets, black
  hole cores and the other ship's lasers each cost one and give a 3 second shield (you bounce off
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
  many empty columns), stays easy for the first 3000 px after the opening, then ramps up
  over the next 20000 px: more rocks,
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
