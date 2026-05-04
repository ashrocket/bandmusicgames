const LOBBY_CONFIG = {
  spotifyClientId:   'aa16f7f72c04485fb93d86d2f7ee33d1',
  spotifyRedirectUri: window.location.hostname === 'localhost'
    ? 'https://localhost:8081/callback'
    : 'https://bandmusicgames.party/callback',
};

const SONGS = [
  {
    id:       'goon',
    title:    'THE GOON SONG',
    artist:   'GOON',
    gameName: 'GRASS CUTTER 2003',
    gameUrl:  'https://forcuttinggrass.goon.bandmusicgames.party',
    trackUri: 'spotify:track:6EJAb3oTjDFwrt1dpIJPbr',
    color:    '#39ff14',
    unlocked: true,
  },
  {
    id:       'fratty',
    title:    'FRATTY PIPELINE',
    artist:   'GROUCHO BARKS',
    gameName: 'FRATTY PIPELINE',
    gameUrl:  'https://frattypipeline.grouchobarks.bandmusicgames.party',
    trackUri: null,
    color:    '#ff8c00',
    unlocked: true,
  },
  { id: 'c1', title: '???', artist: '???', gameName: 'COMING SOON', gameUrl: null, color: '#444', unlocked: false },
  { id: 'c2', title: '???', artist: '???', gameName: 'COMING SOON', gameUrl: null, color: '#444', unlocked: false },
  { id: 'c3', title: '???', artist: '???', gameName: 'COMING SOON', gameUrl: null, color: '#444', unlocked: false },
];
