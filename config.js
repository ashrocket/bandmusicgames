const LOBBY_CONFIG = {
  spotifyClientId:   'aa16f7f72c04485fb93d86d2f7ee33d1',
  spotifyRedirectUri: ['localhost', '127.0.0.1', '::1'].includes(window.location.hostname)
    ? 'http://127.0.0.1:8081/callback'
    : 'https://bandmusicgames.party/callback',
};

const SONGS = [
  {
    id:       'goon',
    title:    'FOR CUTTING GRASS',
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
    trackUri: 'spotify:track:33lVSu93J91BDmhfRT7iTA',
    color:    '#ff8c00',
    unlocked: true,
  },
  {
    id:       'narasroom',
    title:    'LIZZY MCGUIRE',
    artist:   "NARA'S ROOM",
    gameName: 'HALF COURT HERO',
    gameUrl:  'https://lizzymcguire.narasroom.bandmusicgames.party',
    trackUri: 'spotify:track:7kNqAfUxLmrETcwvBTQCkg',
    color:    '#FF1493',
    unlocked: true,
  },
];
