// ─── Lobby dial controller ─────────────────────────────────────────

const canvas     = document.getElementById('dial-canvas');
const ctx        = canvas.getContext('2d');
const infoTitle  = document.getElementById('song-title');
const infoArtist = document.getElementById('song-artist');
const infoGame   = document.getElementById('game-name');
const enterHint  = document.getElementById('enter-hint');

const N = SONGS.length;

// Layout constants
const W  = canvas.width  = 900;
const H  = canvas.height = 520;
const CX = W / 2;
const CY = H / 2 - 10;

const R_RIM  = 220;
const R_RING = 182;
const R_DISK = 118;
const R_DOT  = 14;

// State
let selectedIdx  = 0;
let targetAngle  = 0;
let currentAngle = 0;
let hovered      = false;
let clickFlash   = 0;

function idxToAngle(i) {
  return -(i / N) * Math.PI * 2;
}

function angleToIdx(a) {
  const norm = ((-a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
  return Math.round(norm / (Math.PI * 2) * N) % N;
}

// ─── Input ─────────────────────────────────────────────────────────

let _scrollCooldown = false;
window.addEventListener('wheel', e => {
  e.preventDefault();
  if (_scrollCooldown) return;
  if (e.deltaY > 0) {
    selectedIdx = (selectedIdx + 1) % N;
  } else {
    selectedIdx = (selectedIdx - 1 + N) % N;
  }
  targetAngle = idxToAngle(selectedIdx);
  updateInfo();
  Haptic.select();
  _scrollCooldown = true;
  setTimeout(() => { _scrollCooldown = false; }, 420);
}, { passive: false });

canvas.addEventListener('click', () => {
  if (!LobbyAuth.isConnected()) return;
  const song = SONGS[selectedIdx];
  if (!song.unlocked || !song.gameUrl) {
    Haptic.error();
    clickFlash = 12;
    return;
  }
  Haptic.medium();
  clickFlash = 8;
  setTimeout(() => { window.location.href = song.gameUrl; }, 280);
});

// Circular click-wheel touch gesture
let _wheelActive  = false;
let _wheelLastAng = 0;
let _wheelAccum   = 0;
let _tapStart     = { x: 0, y: 0 };
let _tapMoved     = false;
const STEP_ANGLE  = (Math.PI * 2) / N;

function touchToCanvas(touch) {
  const rect  = canvas.getBoundingClientRect();
  const scaleX = canvas.width  / rect.width;
  const scaleY = canvas.height / rect.height;
  return {
    x: (touch.clientX - rect.left) * scaleX,
    y: (touch.clientY - rect.top)  * scaleY,
  };
}

canvas.addEventListener('touchstart', e => {
  const { x, y } = touchToCanvas(e.touches[0]);
  _tapStart  = { x: e.touches[0].clientX, y: e.touches[0].clientY };
  _tapMoved  = false;
  const dist = Math.sqrt((x - CX) * (x - CX) + (y - CY) * (y - CY));
  _wheelActive = dist > R_DISK - 30 && dist < R_RIM + 20;
  if (_wheelActive) {
    _wheelLastAng = Math.atan2(y - CY, x - CX);
    _wheelAccum   = 0;
  }
}, { passive: true });

canvas.addEventListener('touchmove', e => {
  e.preventDefault();
  const touch = e.touches[0];
  const ddx = touch.clientX - _tapStart.x;
  const ddy = touch.clientY - _tapStart.y;
  if (ddx * ddx + ddy * ddy > 64) _tapMoved = true;
  if (!_wheelActive) return;
  const { x, y } = touchToCanvas(touch);
  const angle = Math.atan2(y - CY, x - CX);
  let delta = angle - _wheelLastAng;
  if (delta >  Math.PI) delta -= Math.PI * 2;
  if (delta < -Math.PI) delta += Math.PI * 2;
  _wheelAccum   += delta;
  _wheelLastAng  = angle;
  while (_wheelAccum >= STEP_ANGLE) {
    _wheelAccum -= STEP_ANGLE;
    selectedIdx  = (selectedIdx + 1) % N;
    targetAngle  = idxToAngle(selectedIdx);
    updateInfo();
    Haptic.select();
  }
  while (_wheelAccum <= -STEP_ANGLE) {
    _wheelAccum += STEP_ANGLE;
    selectedIdx  = (selectedIdx - 1 + N) % N;
    targetAngle  = idxToAngle(selectedIdx);
    updateInfo();
    Haptic.select();
  }
}, { passive: false });

canvas.addEventListener('touchend', e => {
  _wheelActive = false;
  if (_tapMoved) return;
  if (!LobbyAuth.isConnected()) return;
  const song = SONGS[selectedIdx];
  if (!song.unlocked || !song.gameUrl) { Haptic.error(); clickFlash = 12; return; }
  Haptic.medium();
  clickFlash = 8;
  setTimeout(() => { window.location.href = song.gameUrl; }, 280);
}, { passive: true });

canvas.addEventListener('mousemove', () => { hovered = true; });
canvas.addEventListener('mouseleave', () => { hovered = false; });

// ─── Color helpers ─────────────────────────────────────────────────

function hexToRgb(hex) {
  return {
    r: parseInt(hex.slice(1, 3), 16),
    g: parseInt(hex.slice(3, 5), 16),
    b: parseInt(hex.slice(5, 7), 16),
  };
}

function _dimColor(hex, alpha) {
  const { r, g, b } = hexToRgb(hex);
  return `rgba(${r},${g},${b},${alpha})`;
}

function _rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return { h: 0, s: 0, l };
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h;
  switch (max) {
    case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
    case g: h = ((b - r) / d + 2) / 6; break;
    default: h = ((r - g) / d + 4) / 6;
  }
  return { h, s, l };
}

function _hslToHex(h, s, l) {
  const hue2rgb = (p, q, t) => {
    if (t < 0) t += 1; if (t > 1) t -= 1;
    if (t < 1/6) return p + (q - p) * 6 * t;
    if (t < 1/2) return q;
    if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
    return p;
  };
  let r, g, b;
  if (s === 0) { r = g = b = l; }
  else {
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1/3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1/3);
  }
  const toHex = v => Math.round(v * 255).toString(16).padStart(2, '0');
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

// Darkens hex to HSL lightness 0.38 if the color is too light to read on light backgrounds
function ensureReadable(hex) {
  const { r, g, b } = hexToRgb(hex);
  const { h, s, l } = _rgbToHsl(r, g, b);
  return l > 0.70 ? _hslToHex(h, s, 0.38) : hex;
}

// ─── Theme: page background shifts to selected song color ──────────

function updateSongTheme(song) {
  const glow = document.getElementById('bg-glow');
  if (!glow || !song.unlocked) return;
  const { r, g, b } = hexToRgb(song.color);
  glow.style.background =
    `radial-gradient(ellipse at 50% 78%, rgba(${r},${g},${b},0.17) 0%, transparent 62%)`;
}

// ─── Info panel ────────────────────────────────────────────────────

function updateInfo() {
  const s = SONGS[selectedIdx];
  if (!s.unlocked) {
    infoTitle.textContent  = '???';
    infoTitle.style.color  = '#1e1b4b';
    infoArtist.textContent = '';
    infoGame.textContent   = 'COMING SOON';
    enterHint.textContent  = '';
    return;
  }
  infoTitle.textContent  = s.title;
  infoTitle.style.color  = ensureReadable(s.color);
  infoArtist.textContent = s.artist;
  infoGame.textContent   = s.gameName;
  enterHint.textContent  = LobbyAuth.isConnected() ? 'PUSH TO ENTER' : 'CONNECT SPOTIFY FIRST';
  updateSongTheme(s);
}

// ─── Draw ──────────────────────────────────────────────────────────

function drawFrame() {
  let diff = targetAngle - currentAngle;
  while (diff >  Math.PI) diff -= Math.PI * 2;
  while (diff < -Math.PI) diff += Math.PI * 2;
  currentAngle += diff * 0.14;

  // Light base + song-colored ambient canvas glow
  ctx.fillStyle = '#f4f1fb';
  ctx.fillRect(0, 0, W, H);

  const song = SONGS[selectedIdx];
  if (song.unlocked) {
    const { r, g, b } = hexToRgb(song.color);
    const songGlow = ctx.createRadialGradient(CX, CY, 0, CX, CY, 300);
    songGlow.addColorStop(0, `rgba(${r},${g},${b},0.09)`);
    songGlow.addColorStop(1, 'transparent');
    ctx.fillStyle = songGlow;
    ctx.fillRect(0, 0, W, H);
  }

  drawWheelFace();
  drawSongs();
  drawClickWheelLabels();
  drawDisk();
  drawActiveIndicator();

  if (clickFlash > 0) {
    ctx.globalAlpha = (clickFlash / 12) * 0.35;
    ctx.fillStyle   = '#ffffff';
    ctx.fillRect(0, 0, W, H);
    ctx.globalAlpha = 1;
    clickFlash--;
  }

  requestAnimationFrame(drawFrame);
}

function drawWheelFace() {
  // Drop shadow beneath the entire wheel
  ctx.save();
  ctx.shadowBlur    = 50;
  ctx.shadowColor   = 'rgba(120, 90, 200, 0.15)';
  ctx.shadowOffsetY = 10;

  const faceGrad = ctx.createRadialGradient(CX - 45, CY - 45, 15, CX, CY, R_RIM);
  faceGrad.addColorStop(0,    '#ffffff');
  faceGrad.addColorStop(0.55, '#faf7ff');
  faceGrad.addColorStop(1,    '#f0ecf8');
  ctx.beginPath();
  ctx.arc(CX, CY, R_RIM, 0, Math.PI * 2);
  ctx.fillStyle = faceGrad;
  ctx.fill();
  ctx.restore();

  // Pearl rim — silver gradient with diagonal sheen
  const rimGrad = ctx.createLinearGradient(CX - R_RIM, CY - R_RIM, CX + R_RIM, CY + R_RIM);
  rimGrad.addColorStop(0,    '#e0daf0');
  rimGrad.addColorStop(0.25, '#eee8f8');
  rimGrad.addColorStop(0.5,  '#d6d0e8');
  rimGrad.addColorStop(0.75, '#eae4f4');
  rimGrad.addColorStop(1,    '#d2cce0');
  ctx.beginPath();
  ctx.arc(CX, CY, R_RIM, 0, Math.PI * 2);
  ctx.strokeStyle = rimGrad;
  ctx.lineWidth   = 14;
  ctx.stroke();

  // Subtle separator between scroll ring and inner area
  ctx.beginPath();
  ctx.arc(CX, CY, R_RING + R_DOT + 10, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(200, 190, 230, 0.2)';
  ctx.lineWidth   = 1;
  ctx.stroke();
}

function drawSongs() {
  for (let i = 0; i < N; i++) {
    const song     = SONGS[i];
    const angle    = currentAngle + (i / N) * Math.PI * 2 - Math.PI / 2;
    const x        = CX + Math.cos(angle) * R_RING;
    const y        = CY + Math.sin(angle) * R_RING;
    const isSelected = (i === selectedIdx);

    // Halo glow for selected gem
    if (isSelected && song.unlocked) {
      const { r, g, b } = hexToRgb(song.color);
      const grd = ctx.createRadialGradient(x, y, 0, x, y, R_DOT * 4.5);
      grd.addColorStop(0,   `rgba(${r},${g},${b},0.55)`);
      grd.addColorStop(0.4, `rgba(${r},${g},${b},0.2)`);
      grd.addColorStop(1,   'transparent');
      ctx.beginPath();
      ctx.arc(x, y, R_DOT * 4.5, 0, Math.PI * 2);
      ctx.fillStyle = grd;
      ctx.fill();
    }

    const dotR = isSelected ? R_DOT + 5 : R_DOT;

    if (song.unlocked) {
      // Gem-style: bright highlight at top-left, deep color at bottom-right
      const { r, g, b } = hexToRgb(song.color);
      const dotGrad = ctx.createRadialGradient(x - 3, y - 4, 1, x, y, dotR);
      dotGrad.addColorStop(0,    'rgba(255,255,255,0.95)');
      dotGrad.addColorStop(0.25, song.color);
      dotGrad.addColorStop(1,    `rgba(${Math.max(0, r - 50)},${Math.max(0, g - 50)},${Math.max(0, b - 50)},1)`);
      ctx.beginPath();
      ctx.arc(x, y, dotR, 0, Math.PI * 2);
      ctx.fillStyle = dotGrad;
      ctx.fill();

      // Selection ring
      if (isSelected) {
        ctx.beginPath();
        ctx.arc(x, y, dotR + 4, 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(${r},${g},${b},0.35)`;
        ctx.lineWidth   = 2.5;
        ctx.stroke();
      }
    } else {
      ctx.beginPath();
      ctx.arc(x, y, dotR, 0, Math.PI * 2);
      ctx.fillStyle = '#dcd8ec';
      ctx.fill();
    }

  }
}

function drawClickWheelLabels() {
  // Classic iPod click wheel labels at compass points
  const LABEL_R = 150;
  const labels = [
    { text: 'MENU', angle: -Math.PI / 2 },
    { text: '▶▶',   angle: 0 },
    { text: '▶ II', angle: Math.PI / 2 },
    { text: '◀◀',   angle: Math.PI },
  ];

  ctx.save();
  ctx.textAlign    = 'center';
  ctx.textBaseline = 'middle';
  ctx.font         = '600 9px Quicksand, sans-serif';
  ctx.fillStyle    = 'rgba(160, 148, 200, 0.55)';

  labels.forEach(({ text, angle }) => {
    const x = CX + Math.cos(angle) * LABEL_R;
    const y = CY + Math.sin(angle) * LABEL_R;
    ctx.fillText(text, x, y);
  });
  ctx.restore();
}

function drawDisk() {
  // ── Background: white pearl button ────────────────────────────────
  ctx.save();
  ctx.shadowBlur    = 20;
  ctx.shadowColor   = 'rgba(130, 100, 210, 0.14)';
  ctx.shadowOffsetY = 4;
  const diskGrad = ctx.createRadialGradient(CX - 22, CY - 22, 8, CX, CY, R_DISK);
  diskGrad.addColorStop(0,    '#ffffff');
  diskGrad.addColorStop(0.5,  '#faf7ff');
  diskGrad.addColorStop(0.85, '#f2eef8');
  diskGrad.addColorStop(1,    '#e8e2f4');
  ctx.beginPath();
  ctx.arc(CX, CY, R_DISK, 0, Math.PI * 2);
  ctx.fillStyle = diskGrad;
  ctx.fill();
  ctx.restore();

  ctx.beginPath();
  ctx.arc(CX, CY, R_DISK, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(210, 200, 235, 0.55)';
  ctx.lineWidth   = 1.5;
  ctx.stroke();

  // ── Clip to disk for list rendering ──────────────────────────────
  ctx.save();
  ctx.beginPath();
  ctx.arc(CX, CY, R_DISK - 3, 0, Math.PI * 2);
  ctx.clip();

  const ROW_H = 22;
  const trunc = (s, n) => s.length > n ? s.slice(0, n - 1) + '…' : s;

  if (!LobbyAuth.isConnected()) {
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';
    ctx.font         = '700 12px Quicksand, sans-serif';
    ctx.fillStyle    = '#a855f7';
    ctx.fillText('CONNECT SPOTIFY', CX, CY - 9);
    ctx.font         = '500 10px Quicksand, sans-serif';
    ctx.fillStyle    = '#c4b5d8';
    ctx.fillText('to play', CX, CY + 9);
    ctx.restore();
    return;
  }

  // ── iPod selection highlight: glowing purple ─────────────────────
  const song = SONGS[selectedIdx];
  {
    // Outer glow (wider, very soft)
    const glow = ctx.createLinearGradient(CX - R_DISK, 0, CX + R_DISK, 0);
    glow.addColorStop(0,    'rgba(168, 85, 247, 0)');
    glow.addColorStop(0.1,  'rgba(168, 85, 247, 0.12)');
    glow.addColorStop(0.9,  'rgba(168, 85, 247, 0.12)');
    glow.addColorStop(1,    'rgba(168, 85, 247, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(CX - R_DISK, CY - ROW_H, R_DISK * 2, ROW_H * 2);

    // Solid highlight band
    ctx.fillStyle = 'rgba(168, 85, 247, 0.22)';
    ctx.fillRect(CX - R_DISK + 10, CY - ROW_H / 2, (R_DISK - 10) * 2, ROW_H);

    // Hairline borders
    ctx.strokeStyle = 'rgba(192, 132, 252, 0.55)';
    ctx.lineWidth   = 1;
    ctx.beginPath();
    ctx.moveTo(CX - R_DISK + 10, CY - ROW_H / 2);
    ctx.lineTo(CX + R_DISK - 10, CY - ROW_H / 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(CX - R_DISK + 10, CY + ROW_H / 2);
    ctx.lineTo(CX + R_DISK - 10, CY + ROW_H / 2);
    ctx.stroke();
  }

  // ── Vertical song list — offsets -3 … +3 ─────────────────────────
  for (let offset = -3; offset <= 3; offset++) {
    const i  = ((selectedIdx + offset) % N + N) % N;
    const s  = SONGS[i];
    const y  = CY + offset * ROW_H;
    const d  = Math.abs(offset);

    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';

    if (offset === 0) {
      // Selected row: full title, left-aligned with ▶
      const title = s.unlocked ? s.title.toUpperCase() : '???';
      ctx.font      = '700 12px Quicksand, sans-serif';
      ctx.fillStyle = s.unlocked ? '#1e1450' : '#c8c0d8';
      ctx.textAlign = 'left';
      ctx.fillText('▶  ' + title, CX - 72, y);
    } else {
      // Non-selected: dark text, fade by distance — no truncation for ±1
      const alpha = d === 1 ? 0.85 : d === 2 ? 0.62 : 0.40;
      const fs    = d === 1 ? 11 : d === 2 ? 10 : 9;
      const weight = d === 1 ? '600' : '500';
      const title = s.unlocked
        ? (d <= 1 ? s.title.toUpperCase() : trunc(s.title.toUpperCase(), 18))
        : '???';
      ctx.font      = `${weight} ${fs}px Quicksand, sans-serif`;
      ctx.fillStyle = `rgba(30, 20, 70, ${alpha})`;
      ctx.fillText(title, CX, y);
    }
  }

  // ── Edge fade so list fades into disk ────────────────────────────
  const FADE = 30;
  const topFade = ctx.createLinearGradient(0, CY - R_DISK + 3, 0, CY - R_DISK + 3 + FADE);
  topFade.addColorStop(0, '#f8f5ff');
  topFade.addColorStop(1, 'rgba(248,245,255,0)');
  ctx.fillStyle = topFade;
  ctx.fillRect(CX - R_DISK, CY - R_DISK + 3, R_DISK * 2, FADE);

  const botFade = ctx.createLinearGradient(0, CY + R_DISK - 3 - FADE, 0, CY + R_DISK - 3);
  botFade.addColorStop(0, 'rgba(248,245,255,0)');
  botFade.addColorStop(1, '#f8f5ff');
  ctx.fillStyle = botFade;
  ctx.fillRect(CX - R_DISK, CY + R_DISK - 3 - FADE, R_DISK * 2, FADE);

  ctx.restore();
}

function drawActiveIndicator() {
  // Soft glowing dot at 12 o'clock — shows which slot is active
  const song        = SONGS[selectedIdx];
  const accentColor = song.unlocked ? song.color : '#a855f7';
  const solidColor  = ensureReadable(accentColor);
  const { r: gr, g: gg, b: gb } = hexToRgb(accentColor); // original for glow
  const { r, g, b }              = hexToRgb(solidColor);  // darkened for solid elements

  const ix = CX;
  const iy = CY - R_RING;

  const grd = ctx.createRadialGradient(ix, iy, 0, ix, iy, 20);
  grd.addColorStop(0,    `rgba(${gr},${gg},${gb},0.9)`);
  grd.addColorStop(0.45, `rgba(${gr},${gg},${gb},0.4)`);
  grd.addColorStop(1,    'transparent');
  ctx.beginPath();
  ctx.arc(ix, iy, 20, 0, Math.PI * 2);
  ctx.fillStyle = grd;
  ctx.fill();

  ctx.beginPath();
  ctx.arc(ix, iy, 5, 0, Math.PI * 2);
  ctx.fillStyle = solidColor;
  ctx.fill();

  // Short color arc on the outer rim at top
  ctx.beginPath();
  ctx.arc(CX, CY, R_RIM - 7, -Math.PI / 2 - 0.22, -Math.PI / 2 + 0.22);
  ctx.strokeStyle = `rgba(${r},${g},${b},0.65)`;
  ctx.lineWidth   = 8;
  ctx.lineCap     = 'round';
  ctx.stroke();
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
  window._saveSpotifySkip();
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

requestAnimationFrame(drawFrame);

// ─── Tilt navigation ───────────────────────────────────────────────

let _tiltCooldown = false;
Motion.onTilt((gamma) => {
  if (_tiltCooldown) return;
  const THRESHOLD = 22;
  if (gamma > THRESHOLD) {
    selectedIdx = (selectedIdx + 1) % N;
    targetAngle = idxToAngle(selectedIdx);
    Haptic.select();
    updateInfo();
    _tiltCooldown = true;
    setTimeout(() => { _tiltCooldown = false; }, 480);
  } else if (gamma < -THRESHOLD) {
    selectedIdx = (selectedIdx - 1 + N) % N;
    targetAngle = idxToAngle(selectedIdx);
    Haptic.select();
    updateInfo();
    _tiltCooldown = true;
    setTimeout(() => { _tiltCooldown = false; }, 480);
  }
});

const _motionBtn = document.getElementById('motion-btn');
if (Motion.isMobile()) {
  if (Motion.needsPermission()) {
    _motionBtn.style.display = '';
    _motionBtn.addEventListener('click', async () => {
      if (await Motion.start()) _motionBtn.remove();
    });
  } else {
    Motion.start();
  }
}
