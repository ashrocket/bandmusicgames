// Apple Music MusicKit JS — lobby auth only.
// Developer token lives in LOBBY_CONFIG.appleMusicDeveloperToken (config.js).
// User token is stored as am_token cookie on .bandmusicgames.party so all
// subdomains can read it for playback.

const AppleMusicAuth = {
  _configured: false,

  async configure() {
    if (this._configured) return;
    const devToken = LOBBY_CONFIG.appleMusicDeveloperToken;
    if (!devToken || devToken === 'REPLACE_WITH_DEVELOPER_TOKEN') return;
    await MusicKit.configure({
      developerToken: devToken,
      app: { name: 'Band Music Games', build: '1.0' },
    });
    this._configured = true;
  },

  async authorize() {
    await this.configure();
    if (!this._configured) return false;
    try {
      const userToken = await MusicKit.getInstance().authorize();
      if (userToken) {
        _writeAmToken('am_token', userToken, 60 * 60 * 24 * 180); // 180 days
        return true;
      }
    } catch (e) {
      console.warn('[Apple Music] auth failed:', e);
    }
    return false;
  },

  hasToken()    { return !!_readAmToken('am_token'); },
  getToken()    { return _readAmToken('am_token'); },
  isConnected() { return this.hasToken(); },
};

// ─── Storage helpers ──────────────────────────────────────────────

function _readAmToken(name) {
  if (location.hostname === 'localhost') return sessionStorage.getItem(name);
  const m = document.cookie.match(new RegExp('(?:^|;\\s*)' + name + '=([^;]+)'));
  return m ? decodeURIComponent(m[1]) : null;
}

function _writeAmToken(name, value, maxAge) {
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
