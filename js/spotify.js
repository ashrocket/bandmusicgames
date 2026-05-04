// Spotify PKCE auth — lobby only (no playback SDK)

const LobbyAuth = {
  async login() {
    const verifier  = _lobbyPkceVerifier();
    const challenge = await _lobbyPkceChallenge(verifier);
    sessionStorage.setItem('lobby_verifier', verifier);

    const p = new URLSearchParams({
      client_id:             LOBBY_CONFIG.spotifyClientId,
      response_type:         'code',
      redirect_uri:          LOBBY_CONFIG.spotifyRedirectUri,
      scope:                 'streaming user-read-email user-read-private',
      code_challenge_method: 'S256',
      code_challenge:        challenge,
    });
    window.location.href = `https://accounts.spotify.com/authorize?${p}`;
  },

  async handleCallback(code) {
    const verifier = sessionStorage.getItem('lobby_verifier');
    const res = await fetch('https://accounts.spotify.com/api/token', {
      method:  'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body:    new URLSearchParams({
        client_id:     LOBBY_CONFIG.spotifyClientId,
        grant_type:    'authorization_code',
        code,
        redirect_uri:  LOBBY_CONFIG.spotifyRedirectUri,
        code_verifier: verifier,
      }),
    });
    if (!res.ok) return false;
    const d = await res.json();
    _lobbySaveTokens(d);
    return true;
  },

  hasToken() {
    return !!(sessionStorage.getItem('lobby_token') &&
              Date.now() < +sessionStorage.getItem('lobby_expires'));
  },

  getToken() { return sessionStorage.getItem('lobby_token'); },

  async refresh() {
    const rt = sessionStorage.getItem('lobby_refresh');
    if (!rt) return null;
    const res = await fetch('https://accounts.spotify.com/api/token', {
      method:  'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body:    new URLSearchParams({
        grant_type:    'refresh_token',
        refresh_token: rt,
        client_id:     LOBBY_CONFIG.spotifyClientId,
      }),
    });
    if (!res.ok) return null;
    const d = await res.json();
    _lobbySaveTokens(d);
    return d.access_token;
  },

  isConnected() { return this.hasToken() || sessionStorage.getItem('lobby_skip') === '1'; },
};

function _lobbySaveTokens(d) {
  sessionStorage.setItem('lobby_token',   d.access_token);
  sessionStorage.setItem('lobby_expires', Date.now() + d.expires_in * 1000);
  if (d.refresh_token) sessionStorage.setItem('lobby_refresh', d.refresh_token);
}

function _lobbyPkceVerifier() {
  const arr = new Uint8Array(32);
  crypto.getRandomValues(arr);
  return btoa(String.fromCharCode(...arr))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

async function _lobbyPkceChallenge(v) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(v));
  return btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}
