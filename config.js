const LOBBY_CONFIG = {
  spotifyClientId:   'aa16f7f72c04485fb93d86d2f7ee33d1',
  spotifyRedirectUri: window.location.hostname === 'localhost'
    ? 'https://localhost:8081/callback'
    : 'https://bandmusicgames.party/callback',

  // Apple Music — generate at: developer.apple.com → Certificates, Identifiers & Profiles
  // JWT signed with your .p8 private key, valid up to 6 months. Renew before expiry.
  appleMusicDeveloperToken: 'REPLACE_WITH_DEVELOPER_TOKEN',
};

const SONGS = [
  {
    id:       'goon',
    title:    'FOR CUTTING GRASS',
    artist:   'GOON',
    gameName: 'GRASS CUTTER 2003',
    gameUrl:  'https://forcuttinggrass.goon.bandmusicgames.party',
    trackUri: 'spotify:track:6EJAb3oTjDFwrt1dpIJPbr',
    appleMusicId: null,
    color:    '#39ff14',
    unlocked: true,
  },
  {
    id:       'francis',
    title:    'FRANCIS',
    artist:   'DARGER',
    gameName: 'FRANCIS',
    gameUrl:  'https://francis.darger.bandmusicgames.party',
    trackUri: 'spotify:track:64h0585a6LWXOdsCD2pOiW',
    appleMusicId: null,
    color:    '#7b68ee',
    unlocked: true,
  },
  {
    id:       'narasroom',
    title:    'LIZZY MCGUIRE',
    artist:   "NARA'S ROOM",
    gameName: 'HALF COURT HERO',
    gameUrl:  'https://lizzymcguire.narasroom.bandmusicgames.party',
    trackUri: 'spotify:track:7kNqAfUxLmrETcwvBTQCkg',
    appleMusicId: null,
    color:    '#FF1493',
    unlocked: true,
  },
];
