// Star Fights online relay.
//
// Pairs two players by a short room code and forwards their game messages
// back and forth. It runs no game logic: the hosting player's game (desktop
// or browser) runs the match, exactly like LAN play. Any number of rooms can
// run at once.
//
//   wss://<server>/host          -> {"t":"room","code":"M4QT"}
//   wss://<server>/join/M4QT     -> both sides get {"t":"paired"}
//
// After pairing, every binary frame from one player goes to the other.
// When either side leaves, the other gets {"t":"left"} and is closed.
// Text frames are control messages; players never send any.
//
// Run: npm install && npm start   (PORT env var, default 8080)

const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT) || 8080;
// Only letters and digits that can't be mixed up, read out loud or in the
// game's font (which draws K like H, V like U, Z like 2, S like 5...).
const CODE_CHARS = "ACDEFGHJMNPQRTUWY34679";
const CODE_LENGTH = 4;
const MAX_ROOMS = 500;
// A host waiting for someone to join gives up after this long.
const WAIT_LIMIT_MS = 30 * 60 * 1000;
// Messages bigger than this are refused (the game's largest are ~1-2 KB).
const MAX_MESSAGE = 1 << 20;

/** code -> { host, guest, created } */
const rooms = new Map();

function newCode() {
  for (let tries = 0; tries < 1000; tries++) {
    let code = "";
    for (let i = 0; i < CODE_LENGTH; i++) {
      code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    }
    if (!rooms.has(code)) return code;
  }
  return null;
}

function send(ws, obj) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

// Close code for "refused, see the reason". The reason is also sent as an
// error message first, but a client that is still connecting may only see
// the close reason (it must stay under 123 bytes).
const CLOSE_REFUSED = 4001;

function refuse(ws, msg) {
  send(ws, { t: "error", msg });
  ws.close(CLOSE_REFUSED, msg);
}

function closeRoom(code, leaver) {
  const room = rooms.get(code);
  if (!room) return;
  rooms.delete(code);
  for (const ws of [room.host, room.guest]) {
    if (ws && ws !== leaver && ws.readyState === ws.OPEN) {
      send(ws, { t: "left" });
      ws.close(1000);
    }
  }
}

function link(ws, code) {
  ws.on("message", (data, isBinary) => {
    const room = rooms.get(code);
    if (!room || !isBinary) return;
    const other = ws === room.host ? room.guest : room.host;
    if (other && other.readyState === other.OPEN) other.send(data, { binary: true });
  });
  ws.on("close", () => closeRoom(code, ws));
  ws.on("error", () => closeRoom(code, ws));
}

const server = http.createServer((req, res) => {
  // Plain HTTP: a health check for the hosting service.
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`Star Fights relay is running. Rooms open: ${rooms.size}\n`);
});

const wss = new WebSocketServer({ server, maxPayload: MAX_MESSAGE });

wss.on("connection", (ws, req) => {
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));
  const path = (req.url || "/").split("?")[0].replace(/\/+$/, "");
  if (path === "/host") {
    if (rooms.size >= MAX_ROOMS) return refuse(ws, "The game server is full. Try again in a few minutes.");
    const code = newCode();
    if (!code) return refuse(ws, "The game server is full. Try again in a few minutes.");
    rooms.set(code, { host: ws, guest: null, created: Date.now() });
    link(ws, code);
    send(ws, { t: "room", code });
    return;
  }
  const m = path.match(/^\/join\/([A-Za-z0-9]{1,12})$/);
  if (m) {
    const code = m[1].toUpperCase();
    const room = rooms.get(code);
    if (!room) return refuse(ws, `No game with the code ${code}. Check the code with the host.`);
    if (room.guest) return refuse(ws, `Game ${code} already has two players.`);
    room.guest = ws;
    link(ws, code);
    send(room.host, { t: "paired" });
    send(ws, { t: "paired" });
    return;
  }
  refuse(ws, "Unknown request.");
});

// Keep connections alive through proxies, drop dead ones, and close rooms
// nobody joined.
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    ws.ping();
  }
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (!room.guest && now - room.created > WAIT_LIMIT_MS) {
      if (room.host) refuse(room.host, "Nobody joined for 30 minutes, so the game was closed.");
      rooms.delete(code);
    }
  }
}, 20000);

server.listen(PORT, () => console.log(`Star Fights relay listening on port ${PORT}`));
