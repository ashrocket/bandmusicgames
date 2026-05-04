// ─── Lobby dial controller ─────────────────────────────────────────

const canvas  = document.getElementById('dial-canvas');
const ctx     = canvas.getContext('2d');
const infoTitle  = document.getElementById('song-title');
const infoArtist = document.getElementById('song-artist');
const infoGame   = document.getElementById('game-name');
const enterHint  = document.getElementById('enter-hint');

const N = SONGS.length;

// Layout constants
const W = canvas.width  = 900;
const H = canvas.height = 520;
const CX = W / 2;
const CY = H / 2 - 10;

const R_RIM  = 220;
const R_RING = 182;
const R_DISK = 118;
const R_DOT  = 14;

// State
let selectedIdx   = 0;
let targetAngle   = 0;   // radians, where 0 = first song at 12 o'clock
let currentAngle  = 0;
let hovered       = false;
let clickFlash    = 0;

// Map index → angle at 12 o'clock
function idxToAngle(i) {
  return -(i / N) * Math.PI * 2;
}

// Recalculate which song is at top after scroll
function angleToIdx(a) {
  const norm = ((-a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
  return Math.round(norm / (Math.PI * 2) * N) % N;
}

// ─── Input ─────────────────────────────────────────────────────────

window.addEventListener('wheel', e => {
  e.preventDefault();
  if (e.deltaY > 0) {
    selectedIdx = (selectedIdx + 1) % N;
  } else {
    selectedIdx = (selectedIdx - 1 + N) % N;
  }
  targetAngle = idxToAngle(selectedIdx);
  updateInfo();
}, { passive: false });

canvas.addEventListener('click', () => {
  if (!LobbyAuth.isConnected()) return;
  const song = SONGS[selectedIdx];
  if (!song.unlocked || !song.gameUrl) {
    // Flash "LOCKED" pulse
    clickFlash = 12;
    return;
  }
  clickFlash = 8;
  setTimeout(() => { window.location.href = song.gameUrl; }, 280);
});

canvas.addEventListener('mousemove', () => { hovered = true; });
canvas.addEventListener('mouseleave', () => { hovered = false; });

// ─── Info panel ────────────────────────────────────────────────────

function updateInfo() {
  const s = SONGS[selectedIdx];
  if (!s.unlocked) {
    infoTitle.textContent  = '???';
    infoArtist.textContent = '';
    infoGame.textContent   = 'COMING SOON';
    enterHint.textContent  = '';
    return;
  }
  infoTitle.textContent  = s.title;
  infoArtist.textContent = s.artist;
  infoGame.textContent   = s.gameName;
  enterHint.textContent  = LobbyAuth.isConnected() ? 'PUSH TO ENTER' : 'CONNECT SPOTIFY FIRST';
}

// ─── Draw ──────────────────────────────────────────────────────────

function drawFrame() {
  // Lerp angle
  let diff = targetAngle - currentAngle;
  // Shortest path wrap
  while (diff >  Math.PI) diff -= Math.PI * 2;
  while (diff < -Math.PI) diff += Math.PI * 2;
  currentAngle += diff * 0.14;

  ctx.clearRect(0, 0, W, H);

  // CRT scanline overlay
  for (let y = 0; y < H; y += 3) {
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.fillRect(0, y, W, 1);
  }

  drawRim();
  drawSongs();
  drawDisk();
  drawIndicator();

  if (clickFlash > 0) {
    ctx.globalAlpha = clickFlash / 12 * 0.45;
    ctx.fillStyle   = '#fff';
    ctx.fillRect(0, 0, W, H);
    ctx.globalAlpha = 1;
    clickFlash--;
  }

  requestAnimationFrame(drawFrame);
}

function drawRim() {
  // Outer glow ring
  const grad = ctx.createRadialGradient(CX, CY, R_RIM - 18, CX, CY, R_RIM + 18);
  grad.addColorStop(0,   'rgba(180,120,0,0.0)');
  grad.addColorStop(0.4, 'rgba(255,165,0,0.55)');
  grad.addColorStop(1,   'rgba(180,120,0,0.0)');
  ctx.beginPath();
  ctx.arc(CX, CY, R_RIM, 0, Math.PI * 2);
  ctx.strokeStyle = grad;
  ctx.lineWidth   = 36;
  ctx.stroke();

  // Hard rim
  ctx.beginPath();
  ctx.arc(CX, CY, R_RIM, 0, Math.PI * 2);
  ctx.strokeStyle = '#a06010';
  ctx.lineWidth   = 4;
  ctx.stroke();

  // Inner track
  ctx.beginPath();
  ctx.arc(CX, CY, R_RING, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(255,165,0,0.18)';
  ctx.lineWidth   = 2;
  ctx.stroke();
}

function drawSongs() {
  for (let i = 0; i < N; i++) {
    const song  = SONGS[i];
    const angle = currentAngle + (i / N) * Math.PI * 2 - Math.PI / 2;
    const x     = CX + Math.cos(angle) * R_RING;
    const y     = CY + Math.sin(angle) * R_RING;
    const isSelected = i === selectedIdx;

    // Dot glow
    if (isSelected && song.unlocked) {
      const grd = ctx.createRadialGradient(x, y, 0, x, y, R_DOT * 3.5);
      grd.addColorStop(0, song.color + 'bb');
      grd.addColorStop(1, 'transparent');
      ctx.beginPath();
      ctx.arc(x, y, R_DOT * 3.5, 0, Math.PI * 2);
      ctx.fillStyle = grd;
      ctx.fill();
    }

    // Dot body
    ctx.beginPath();
    ctx.arc(x, y, isSelected ? R_DOT + 4 : R_DOT, 0, Math.PI * 2);
    ctx.fillStyle = song.unlocked
      ? (isSelected ? song.color : _dimColor(song.color, 0.45))
      : '#2a2a2a';
    ctx.fill();
    ctx.strokeStyle = song.unlocked ? (isSelected ? '#fff' : 'rgba(255,255,255,0.3)') : '#3a3a3a';
    ctx.lineWidth   = isSelected ? 2.5 : 1;
    ctx.stroke();

    // Short label arc text
    if (song.unlocked) {
      ctx.save();
      ctx.translate(x, y);
      ctx.font      = `bold ${isSelected ? 11 : 9}px monospace`;
      ctx.fillStyle = isSelected ? '#fff' : 'rgba(255,255,255,0.5)';
      ctx.textAlign = 'center';
      // nudge label outward from center
      const lx = Math.cos(angle) * (R_DOT + 18);
      const ly = Math.sin(angle) * (R_DOT + 18);
      ctx.fillText(song.id.toUpperCase(), lx, ly + 4);
      ctx.restore();
    }
  }
}

function drawDisk() {
  // Center disk background
  const diskGrad = ctx.createRadialGradient(CX, CY, 0, CX, CY, R_DISK);
  diskGrad.addColorStop(0,   '#1a1200');
  diskGrad.addColorStop(0.7, '#0d0d00');
  diskGrad.addColorStop(1,   '#050500');
  ctx.beginPath();
  ctx.arc(CX, CY, R_DISK, 0, Math.PI * 2);
  ctx.fillStyle = diskGrad;
  ctx.fill();
  ctx.strokeStyle = '#4a3800';
  ctx.lineWidth   = 2;
  ctx.stroke();

  // Center text
  const song = SONGS[selectedIdx];
  ctx.save();
  ctx.textAlign = 'center';

  if (!LobbyAuth.isConnected()) {
    ctx.font      = 'bold 13px monospace';
    ctx.fillStyle = '#ff6600';
    ctx.fillText('CONNECT', CX, CY - 10);
    ctx.fillText('SPOTIFY', CX, CY + 8);
    ctx.font      = '10px monospace';
    ctx.fillStyle = '#884400';
    ctx.fillText('TO PLAY', CX, CY + 28);
  } else if (!song.unlocked) {
    ctx.font      = 'bold 14px monospace';
    ctx.fillStyle = '#444';
    ctx.fillText('LOCKED', CX, CY + 5);
  } else {
    // Pulsing "ENTER" indicator
    const pulse = 0.75 + 0.25 * Math.sin(Date.now() / 400);
    ctx.globalAlpha = hovered ? pulse : 0.7;
    ctx.font        = `bold 15px monospace`;
    ctx.fillStyle   = song.color;
    ctx.fillText('ENTER', CX, CY - 8);
    ctx.globalAlpha = 1;
    ctx.font        = '10px monospace';
    ctx.fillStyle   = 'rgba(255,200,0,0.5)';
    ctx.fillText('PUSH', CX, CY + 12);
  }
  ctx.restore();
}

function drawIndicator() {
  // Amber triangle pointer at top of ring
  const tipY = CY - R_RING + 2;
  ctx.beginPath();
  ctx.moveTo(CX,      tipY + 2);
  ctx.lineTo(CX - 10, tipY - 14);
  ctx.lineTo(CX + 10, tipY - 14);
  ctx.closePath();
  ctx.fillStyle   = '#ffaa00';
  ctx.fill();
  ctx.strokeStyle = '#fff8';
  ctx.lineWidth   = 1;
  ctx.stroke();

  // Glow behind indicator
  const g = ctx.createRadialGradient(CX, tipY - 6, 0, CX, tipY - 6, 22);
  g.addColorStop(0, 'rgba(255,170,0,0.4)');
  g.addColorStop(1, 'transparent');
  ctx.beginPath();
  ctx.arc(CX, tipY - 6, 22, 0, Math.PI * 2);
  ctx.fillStyle = g;
  ctx.fill();
}

function _dimColor(hex, alpha) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}

// ─── Overlay wiring ────────────────────────────────────────────────

const overlay    = document.getElementById('spotify-overlay');
const btnConnect = document.getElementById('btn-connect');
const btnSkip    = document.getElementById('btn-skip');

function dismissOverlay() {
  overlay.classList.add('hidden');
  updateInfo();
}

btnConnect.addEventListener('click', () => {
  if (LOBBY_CONFIG.spotifyClientId === 'YOUR_CLIENT_ID_HERE') {
    alert('Set your Spotify Client ID in config.js first.');
    return;
  }
  LobbyAuth.login();
});

btnSkip.addEventListener('click', () => {
  sessionStorage.setItem('lobby_skip', '1');
  dismissOverlay();
});

// ─── Bootstrap ─────────────────────────────────────────────────────

(async function bootstrap() {
  if (LobbyAuth.isConnected()) {
    dismissOverlay();
  }

  updateInfo();
  requestAnimationFrame(drawFrame);
})();

// Also start draw loop immediately (overlay may be on top)
requestAnimationFrame(drawFrame);
