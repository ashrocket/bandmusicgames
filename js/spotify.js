// Spotify PKCE auth — lobby only. Tokens stored as shared cookies
// so all *.bandmusicgames.party subdomains can read them.

const LobbyAuth = {
  async login() {
    const verifier  = _pkceVerifier();
    const challenge = await _pkceChallenge(verifier);
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

  hasToken()    { return !!_readToken('sp_token'); },
  getToken()    { return _readToken('sp_token'); },
  isConnected() { return this.hasToken() || _readToken('sp_skip') === '1'; },
};

// ─── Storage helpers (cookies on prod, sessionStorage on localhost) ─

function _readToken(name) {
  if (location.hostname === 'localhost') return sessionStorage.getItem(name);
  const m = document.cookie.match(new RegExp('(?:^|;\\s*)' + name + '=([^;]+)'));
  return m ? decodeURIComponent(m[1]) : null;
}

function _writeToken(name, value, maxAge) {
  if (location.hostname === 'localhost') {
    sessionStorage.setItem(name, value);
    return;
  }
  document.cookie = [
    `${name}=${encodeURIComponent(value)}`,
    `max-age=${maxAge}`,
    `domain=.bandmusicgames.party`,
    `path=/`,
    `secure`,
    `samesite=lax`,
  ].join('; ');
}

// Called from callback/index.html after token exchange
window._saveSpotifyTokens = function (d) {
  _writeToken('sp_token',   d.access_token,  d.expires_in);
  if (d.refresh_token) _writeToken('sp_refresh', d.refresh_token, 60 * 60 * 24 * 30);
};

// Called when user clicks "play without music"
window._saveSpotifySkip = function () {
  _writeToken('sp_skip', '1', 60 * 60 * 24);
};

// ─── PKCE helpers ──────────────────────────────────────────────────

function _pkceVerifier() {
  const arr = new Uint8Array(32);
  crypto.getRandomValues(arr);
  return btoa(String.fromCharCode(...arr))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

async function _pkceChallenge(v) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(v));
  return btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}
