# Star Fights online relay

A tiny server (`relay.js`, Node.js) that lets two players find each other by a
4-letter game code and passes their game messages back and forth over
WebSockets. It runs no game logic. The hosting player's game (desktop or
browser) runs the match, exactly like LAN play. One relay serves any number
of games at once.

## Try it on your own computer

```sh
cd server
npm install
npm start          # listens on ws://127.0.0.1:8080
```

The game connects to `ws://127.0.0.1:8080` until you change the address (see
below), so two copies of the game on the same machine can already play
online: one picks HOST ONLINE GAME, the other types the code and presses JOIN.

## Put it on the internet (once)

### Render (free)

1. Sign in at https://render.com with GitHub.
2. New > Blueprint, pick the `star-fight` repository, and press Apply. It reads
   `render.yaml` and starts the relay.
3. Copy the service's address, e.g. `https://star-fights-relay.onrender.com`.

A free Render service goes to sleep after about 15 minutes without players,
and takes up to a minute to wake up. The game keeps retrying for 90 seconds,
so the first game of the day just takes longer to connect. The free plan
includes 100 GB of traffic a month. One match sends about 0.7 GB an hour
through the relay (the host streams the picture at about 200 KB/s), so that is
roughly 140 hours of play a month.

### Anything else

`Dockerfile` runs the relay on any host that runs containers (Fly.io, a small
VPS...), and on a plain server `npm ci && npm start` is enough (set `PORT` to
change the port). Browsers on an `https://` page need `wss://`, so put it
behind HTTPS. Render and Fly.io do that for you.

## Point the game at it

In `project.godot`, set the address with `wss://` in front instead of `https://`:

```ini
[star_fights]

online/relay_url="wss://star-fights-relay.onrender.com"
```

(or in the Godot editor: Project Settings > Star Fights > Online > Relay Url,
with Advanced Settings on). Then export the game again. For testing without
changing it: start the game with `-- --relay=ws://...`, or in a browser add
`?relay=wss://...` to the page address.

## How it works

- `wss://<server>/host` makes a new game; the server answers
  `{"t":"room","code":"M4QT"}`.
- `wss://<server>/join/M4QT` joins it; both players get `{"t":"paired"}`.
- After that, every binary message from one player goes to the other.
- When one leaves, the other gets `{"t":"left"}`. Refusals (wrong code, game
  full) close the connection with code 4001 and the reason as text.

The game side is `scripts/relay_peer.gd`, a `MultiplayerPeerExtension`, so
the rest of the networking code is the same for LAN and online play.
