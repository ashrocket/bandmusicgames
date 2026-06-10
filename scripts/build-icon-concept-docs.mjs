import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const outDir = "docs/app-icon-concepts";
mkdirSync(outDir, { recursive: true });

const today = "June 3, 2026";

const songColors = {
  grass: "#39ff14",
  francis: "#7b68ee",
  lizzy: "#ff1493",
  amber: "#ffc45f",
  cyan: "#1bd7ff",
  cream: "#fff4c7",
  ink: "#130b1a",
};

const stringConcepts = [
  {
    name: "Woven Orbit",
    thesis: "Closest to the current mark, but cleaner at small sizes: the record reads as one continuous cord wound around the platter.",
    details: "Keep the cream string thick and warm, reduce small dots, and let the tonearm sit as a single confident diagonal.",
    bestFor: "Conservative update; safest replacement for the current app icon.",
  },
  {
    name: "Kite Tail Needle",
    thesis: "The tonearm becomes an illustrator's kite-string tail with two soft bows before it lands in the groove.",
    details: "Adds the requested kite-string character without making the record itself too busy.",
    bestFor: "More hand-made personality while preserving the record-player premise.",
  },
  {
    name: "Single Spiral Drop",
    thesis: "One unbroken string spirals from the outer groove into the center, with a loose drop loop above the platter.",
    details: "The strongest 'made from string' read; one gesture explains the whole object.",
    bestFor: "A bolder, more memorable app-store thumbnail.",
  },
  {
    name: "Confetti Platter",
    thesis: "The turntable stays string-built, while tiny song-color beads make it feel like a game-night party object.",
    details: "Use only a few beads so it does not become decorative noise at 60px.",
    bestFor: "Making the app feel less like a music utility and more like a game launcher.",
  },
  {
    name: "Needle Lasso",
    thesis: "The string tonearm loops around itself like a lasso, then points into the record groove.",
    details: "The lasso gives the arm an animator-drawn motion path without changing the icon silhouette.",
    bestFor: "A playful variation that still reads clearly as a turntable.",
  },
  {
    name: "Game Token Deck",
    thesis: "The platter is still a cord record, but four simple game tokens sit around it like arcade buttons.",
    details: "The tokens are secondary and should use the app song colors, not extra detail.",
    bestFor: "Bridging the current icon to the games premise.",
  },
  {
    name: "Sleeve Corner",
    thesis: "A diagonal record sleeve frames the cord platter, echoing the current orange/plum corner geometry.",
    details: "The sleeve gives the icon a stronger square composition for iOS masks.",
    bestFor: "A premium, album-art-like direction.",
  },
  {
    name: "Thread Reel Platter",
    thesis: "The record player reads like an animation desk spool: the platter is a reel of cream thread feeding the needle.",
    details: "More literal about materials, slightly less literal about vinyl.",
    bestFor: "Leaning into 'illustrators' string' as the brand's craft language.",
  },
  {
    name: "Soundwave Grooves",
    thesis: "The circular grooves become vibrating, imperfect soundwave cords while the arm anchors the record-player read.",
    details: "The variation should animate beautifully later, but still works as a static app icon.",
    bestFor: "A music-forward take with a hand-drawn motion feel.",
  },
  {
    name: "Knotted Center",
    thesis: "A small center knot becomes the spindle, making the whole icon feel tied together from one piece of string.",
    details: "The knot must be simplified to two loops and a dot so it remains legible.",
    bestFor: "Most distinctive craft metaphor among the turntable set.",
  },
];

const alternateConcepts = [
  {
    name: "Cassette Controller",
    thesis: "A cassette shell doubles as a game controller, with tape reels as thumbsticks and song colors as buttons.",
    details: "Strongest direct blend of music plus play; instantly reads as retro without using the record player.",
    bestFor: "A broad, approachable icon for the app premise.",
  },
  {
    name: "Arcade Stage",
    thesis: "An arcade cabinet becomes a tiny stage, with equalizer bars and spotlight beams inside the screen.",
    details: "Communicates band songs becoming playable mini-games.",
    bestFor: "Most explicit 'songs to play games to' idea.",
  },
  {
    name: "Drum Pad Grid",
    thesis: "A compact drum-pad controller turns into a four-button game board using the app song colors.",
    details: "Simple geometry, strong small-size read, and very easy to implement natively.",
    bestFor: "Modern, music-tech, highly scalable icon direction.",
  },
  {
    name: "Guitar Pick Maze",
    thesis: "A guitar pick contains a tiny maze path and a glowing play target.",
    details: "It avoids generic music-note branding while staying close to band culture.",
    bestFor: "A cleaner, less arcade-specific brand mark.",
  },
  {
    name: "Song Dice",
    thesis: "Two rounded dice use music/game symbols as pips, suggesting random party challenges from songs.",
    details: "Clear party-game energy, but risks feeling tabletop if not paired with song colors.",
    bestFor: "Emphasizing group play and replayability.",
  },
  {
    name: "Playlist Trophy",
    thesis: "A trophy cup is built from stacked playlist bars, making winning feel tied to music selection.",
    details: "Good for the competitive game layer; less obvious as music at very small sizes.",
    bestFor: "A game-achievement direction.",
  },
  {
    name: "Jukebox Token",
    thesis: "A token/coin bears a simplified jukebox arch and colored track lanes.",
    details: "Premium, simple, and app-icon-friendly while remaining music-first.",
    bestFor: "A more mature icon that still has party-game warmth.",
  },
  {
    name: "Pinball Note",
    thesis: "A music note becomes a pinball lane with bumpers and a bright ball.",
    details: "High-energy and game-specific without relying on controllers.",
    bestFor: "A kinetic icon that can become animation in the app.",
  },
  {
    name: "Band Board",
    thesis: "A square board-game tile contains four instrument/player lanes converging on a center play button.",
    details: "Represents multiple bands/songs/games in one modular mark.",
    bestFor: "A system icon that can scale as the catalog grows.",
  },
  {
    name: "Headphone Crown",
    thesis: "Headphones form a crown over three game gems, making the player the party DJ.",
    details: "More abstract and brandable, but less literal about gameplay.",
    bestFor: "A consumer-app direction with stronger personality.",
  },
];

const cassetteControllerConcepts = [
  {
    name: "Classic Joycassette",
    thesis: "A clean cassette shell turns directly into a gamepad: reels as sticks, small song-color buttons on the right.",
    details: "This is the safest refinement of the original combo idea, with fewer parts and stronger icon readability.",
    bestFor: "Primary candidate if we want the cassette/controller direction to feel broad and friendly.",
  },
  {
    name: "Boombox Pad",
    thesis: "The cassette sits inside a tiny boombox face, while the speaker circles become controller pads.",
    details: "Adds band-room energy without requiring a literal instrument or record player.",
    bestFor: "A warmer, more music-first version of the concept.",
  },
  {
    name: "Twin Reel Sticks",
    thesis: "The two tape reels become oversized thumbsticks, with a minimal cassette window connecting them.",
    details: "Leans harder into controller ergonomics while keeping the tape read intact.",
    bestFor: "A modern game-controller read at small sizes.",
  },
  {
    name: "Pocket Player",
    thesis: "A portable cassette player becomes the controller, with a d-pad and buttons built into the lower face.",
    details: "The strongest nostalgic object direction; it feels like a playable music device.",
    bestFor: "A retro consumer-app icon with personality.",
  },
  {
    name: "Tape Trail D-Pad",
    thesis: "The magnetic tape exits the cassette and curls into a d-pad shape.",
    details: "More illustrative and ownable, but the tape line must stay thick for app-icon scale.",
    bestFor: "A memorable craft-driven variation.",
  },
  {
    name: "Arcade Cassette",
    thesis: "A cassette becomes a mini arcade control deck with joystick, buttons, and a tape window.",
    details: "The most literal party-game take while still keeping the music source visible.",
    bestFor: "Making the app premise obvious in one glance.",
  },
  {
    name: "Minimal Tapepad",
    thesis: "A reduced rounded-square cassette uses only two reel dots, a slot, and four colored button cuts.",
    details: "Removes most retro detail so the icon can feel more current and premium.",
    bestFor: "A polished iOS-home-screen direction.",
  },
  {
    name: "Co-op Deck",
    thesis: "Two small cassette controllers overlap like player-one/player-two tiles.",
    details: "Sells the party and multiplayer side more than any single-device mark.",
    bestFor: "A social game-night positioning.",
  },
  {
    name: "D-Pad Tape Label",
    thesis: "The cassette label itself becomes a large plus-shaped d-pad, framed by two small tape reels.",
    details: "Very simple silhouette: music object first, game control second.",
    bestFor: "Smallest icon sizes and notification surfaces.",
  },
  {
    name: "Neon Mixpad",
    thesis: "A diagonal cassette-controller hybrid uses neon track lanes and arcade buttons inside one compact slab.",
    details: "Closest to the existing neon party palette and the earlier arcade drafts.",
    bestFor: "The highest-energy, most branded variant.",
  },
];

function h(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function defs(id, stops = ["#1b1024", "#421e35", "#c26230"]) {
  return `
    <defs>
      <radialGradient id="${id}-glow" cx="48%" cy="38%" r="70%">
        <stop offset="0%" stop-color="${stops[1]}" />
        <stop offset="56%" stop-color="${stops[0]}" />
        <stop offset="100%" stop-color="#050409" />
      </radialGradient>
      <linearGradient id="${id}-angle" x1="12%" y1="10%" x2="88%" y2="90%">
        <stop offset="0%" stop-color="#241833" />
        <stop offset="54%" stop-color="#4b2534" />
        <stop offset="100%" stop-color="${stops[2]}" />
      </linearGradient>
      <filter id="${id}-soft" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="18" stdDeviation="20" flood-color="#000000" flood-opacity="0.42" />
      </filter>
      <filter id="${id}-thread" x="-25%" y="-25%" width="150%" height="150%">
        <feDropShadow dx="0" dy="9" stdDeviation="6" flood-color="#000000" flood-opacity="0.34" />
      </filter>
    </defs>
  `;
}

function stringBg(id) {
  return `
    <rect width="1024" height="1024" fill="url(#${id}-angle)" />
    <path d="M0 768 L0 1024 L252 1024 Z" fill="#050307" opacity="0.9" />
    <path d="M900 0 L1024 0 L1024 126 Z" fill="#07040a" opacity="0.95" />
    <circle cx="512" cy="514" r="364" fill="#120915" opacity="0.78" />
    <circle cx="512" cy="514" r="354" fill="none" stroke="#6e4050" stroke-width="9" opacity="0.45" />
  `;
}

function strokeAttrs(width = 38) {
  return `fill="none" stroke="${songColors.cream}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round" filter="url(#ID-thread)"`;
}

function withId(svg, id) {
  return svg.replaceAll("#ID-", `#${id}-`).replaceAll('url(#ID-', `url(#${id}-`);
}

function turntableBase(id, extra = "") {
  return withId(`
    ${stringBg(id)}
    <g filter="url(#ID-soft)">
      <circle cx="512" cy="514" r="286" fill="#0d0710" opacity="0.74" />
      <circle cx="512" cy="514" r="258" fill="none" stroke="#fff1b8" stroke-width="34" opacity="0.96" />
      <circle cx="512" cy="514" r="205" fill="none" stroke="#fff7d6" stroke-width="26" opacity="0.95" />
      <circle cx="512" cy="514" r="149" fill="none" stroke="#fff1b8" stroke-width="22" opacity="0.95" />
      <circle cx="512" cy="514" r="79" fill="none" stroke="#fff4c7" stroke-width="22" opacity="0.98" />
      <circle cx="512" cy="514" r="27" fill="#ffc45f" />
      ${extra}
    </g>
  `, id);
}

function tonearm(id, path = "M736 736 C704 674 653 613 585 548", pivot = true) {
  return withId(`
    <g>
      <path d="${path}" ${strokeAttrs(42)} />
      <path d="${path}" fill="none" stroke="#fff9e6" stroke-width="20" stroke-linecap="round" stroke-linejoin="round" opacity="0.65" />
      ${pivot ? '<circle cx="748" cy="748" r="58" fill="#251833" stroke="#fff4c7" stroke-width="36" filter="url(#ID-thread)" />' : ""}
    </g>
  `, id);
}

function svgWrap(id, body) {
  return `<svg class="icon-svg" role="img" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">${defs(id)}${body}</svg>`;
}

function stringIcon(index, id) {
  switch (index) {
    case 0:
      return svgWrap(id, turntableBase(id, `
        <path d="M272 282 C362 178 421 244 483 286 C549 332 585 184 692 216" fill="none" stroke="#fff4c7" stroke-width="28" stroke-linecap="round" opacity="0.98" filter="url(#ID-thread)" />
      `) + tonearm(id));
    case 1:
      return svgWrap(id, turntableBase(id, `
        <path d="M268 284 C322 228 382 211 440 254 C489 289 529 292 574 260 C634 217 681 218 738 263" fill="none" stroke="#fff4c7" stroke-width="26" stroke-linecap="round" opacity="0.98" filter="url(#ID-thread)" />
      `) + tonearm(id, "M741 745 C690 658 646 637 608 575 C574 519 624 492 653 538 C680 582 640 609 591 557"));
    case 2:
      return svgWrap(id, `
        ${stringBg(id)}
        <path d="M516 220 C684 220 806 345 806 512 C806 701 660 816 496 802 C332 788 208 667 219 501 C231 338 362 271 499 288 C648 307 720 404 705 529 C690 650 592 713 482 692 C378 672 322 592 343 494 C361 411 434 373 513 386 C588 398 629 453 617 522 C607 581 558 613 504 603 C457 594 431 558 438 516 C445 480 474 462 507 467" ${withId(strokeAttrs(42), id)} />
        <circle cx="512" cy="514" r="28" fill="#ffc45f" />
        <path d="M324 231 C398 164 447 233 501 252 C565 275 596 168 696 195" fill="none" stroke="#fff4c7" stroke-width="25" stroke-linecap="round" opacity="0.98" filter="url(#${id}-thread)" />
        ${tonearm(id, "M742 742 C690 682 650 620 588 548")}
      `);
    case 3:
      return svgWrap(id, turntableBase(id, `
        <circle cx="272" cy="750" r="18" fill="${songColors.amber}" />
        <circle cx="748" cy="292" r="18" fill="${songColors.lizzy}" />
        <circle cx="792" cy="376" r="18" fill="${songColors.grass}" />
        <circle cx="338" cy="256" r="16" fill="${songColors.cyan}" />
        <circle cx="682" cy="792" r="16" fill="${songColors.francis}" />
      `) + tonearm(id, "M745 744 C715 684 670 628 615 570"));
    case 4:
      return svgWrap(id, turntableBase(id, `
        <path d="M267 296 C360 196 425 279 493 291 C559 302 604 207 728 233" fill="none" stroke="#fff4c7" stroke-width="25" stroke-linecap="round" opacity="0.95" filter="url(#ID-thread)" />
      `) + tonearm(id, "M748 746 C674 693 671 624 616 606 C548 583 531 667 594 663 C654 659 670 592 590 544"));
    case 5:
      return svgWrap(id, turntableBase(id, `
        <circle cx="252" cy="520" r="31" fill="${songColors.grass}" opacity="0.9" />
        <rect x="736" y="316" width="54" height="54" rx="16" fill="${songColors.francis}" opacity="0.9" />
        <path d="M747 675 l31 54 l-62 0 z" fill="${songColors.lizzy}" opacity="0.9" />
        <circle cx="348" cy="740" r="28" fill="${songColors.cyan}" opacity="0.9" />
      `) + tonearm(id, "M748 746 C704 674 657 623 601 560"));
    case 6:
      return svgWrap(id, `
        ${stringBg(id)}
        <path d="M124 662 L694 92 L928 326 L357 896 Z" fill="#e17739" opacity="0.88" />
        <path d="M171 694 L698 167 L853 322 L326 849 Z" fill="#251331" opacity="0.72" />
        <g transform="translate(22 -6)">
          <circle cx="512" cy="514" r="258" fill="none" stroke="#fff7d6" stroke-width="36" stroke-linecap="round" filter="url(#${id}-thread)" />
          <circle cx="512" cy="514" r="192" fill="none" stroke="#fff4c7" stroke-width="28" stroke-linecap="round" filter="url(#${id}-thread)" />
          <circle cx="512" cy="514" r="116" fill="none" stroke="#fff7d6" stroke-width="24" stroke-linecap="round" filter="url(#${id}-thread)" />
          <circle cx="512" cy="514" r="28" fill="#ffc45f" />
        </g>
        ${tonearm(id, "M760 720 C694 660 644 612 586 556")}
      `);
    case 7:
      return svgWrap(id, `
        ${stringBg(id)}
        <g filter="url(#${id}-soft)">
          <circle cx="512" cy="514" r="260" fill="#110910" opacity="0.78" />
          <circle cx="512" cy="514" r="236" fill="none" stroke="#fff4c7" stroke-width="48" />
          <circle cx="512" cy="514" r="138" fill="none" stroke="#fff4c7" stroke-width="42" opacity="0.96" />
          <circle cx="512" cy="514" r="52" fill="none" stroke="#fff4c7" stroke-width="34" />
          <path d="M280 516 C224 456 226 376 286 337 C355 291 432 333 425 410 C419 478 345 480 306 438" fill="none" stroke="#fff4c7" stroke-width="24" stroke-linecap="round" />
          <circle cx="512" cy="514" r="27" fill="#ffc45f" />
        </g>
        ${tonearm(id, "M745 744 C696 681 655 630 596 566")}
      `);
    case 8:
      return svgWrap(id, `
        ${stringBg(id)}
        <g filter="url(#${id}-soft)">
          <path d="M257 356 C332 300 410 295 512 310 C626 326 701 383 745 461" fill="none" stroke="#fff4c7" stroke-width="34" stroke-linecap="round" />
          <path d="M234 489 C338 424 462 416 582 449 C676 475 737 529 779 602" fill="none" stroke="#fff7d6" stroke-width="34" stroke-linecap="round" />
          <path d="M260 638 C374 584 496 578 608 619 C671 642 717 681 748 728" fill="none" stroke="#fff4c7" stroke-width="34" stroke-linecap="round" />
          <circle cx="512" cy="514" r="78" fill="none" stroke="#fff4c7" stroke-width="28" />
          <circle cx="512" cy="514" r="27" fill="#ffc45f" />
        </g>
        ${tonearm(id, "M748 746 C705 684 656 629 598 566")}
      `);
    case 9:
      return svgWrap(id, turntableBase(id, `
        <path d="M474 486 C431 441 485 394 531 429 C558 449 552 490 522 501 C486 514 455 482 473 449" fill="none" stroke="#fff7d6" stroke-width="24" stroke-linecap="round" filter="url(#ID-thread)" />
        <path d="M545 523 C589 563 535 614 488 578 C460 557 468 516 498 505 C534 492 564 525 545 557" fill="none" stroke="#fff4c7" stroke-width="24" stroke-linecap="round" filter="url(#ID-thread)" />
      `) + tonearm(id, "M746 744 C699 675 652 624 592 562"));
    default:
      return "";
  }
}

function altBg(id, accent = songColors.lizzy) {
  return `
    ${defs(id, ["#090a13", "#1c1731", accent])}
    <rect width="1024" height="1024" fill="url(#${id}-glow)" />
    <circle cx="212" cy="196" r="130" fill="${songColors.cyan}" opacity="0.12" />
    <circle cx="850" cy="810" r="190" fill="${accent}" opacity="0.16" />
    <path d="M0 786 L0 1024 L256 1024 Z" fill="#020306" opacity="0.68" />
  `;
}

function altIcon(index, id) {
  switch (index) {
    case 0:
      return svgWrap(id, `
        ${altBg(id, songColors.cyan)}
        <rect x="188" y="312" width="648" height="398" rx="82" fill="#f2ede2" filter="url(#${id}-soft)" />
        <rect x="242" y="380" width="540" height="158" rx="40" fill="#21162c" />
        <circle cx="384" cy="618" r="58" fill="#21162c" />
        <circle cx="640" cy="618" r="58" fill="#21162c" />
        <circle cx="384" cy="618" r="26" fill="${songColors.amber}" />
        <circle cx="640" cy="618" r="26" fill="${songColors.francis}" />
        <circle cx="512" cy="458" r="42" fill="none" stroke="${songColors.cream}" stroke-width="20" />
        <rect x="688" y="583" width="38" height="38" rx="12" fill="${songColors.grass}" />
        <rect x="736" y="631" width="38" height="38" rx="12" fill="${songColors.lizzy}" />
      `);
    case 1:
      return svgWrap(id, `
        ${altBg(id, songColors.lizzy)}
        <path d="M270 208 H754 Q812 208 824 266 L884 812 H140 L200 266 Q212 208 270 208 Z" fill="#11101c" stroke="#ffc45f" stroke-width="20" filter="url(#${id}-soft)" />
        <rect x="268" y="298" width="488" height="274" rx="44" fill="#201332" stroke="${songColors.cyan}" stroke-width="14" />
        <path d="M331 518 V412 M412 518 V360 M493 518 V436 M574 518 V386 M655 518 V333" stroke="${songColors.cream}" stroke-width="28" stroke-linecap="round" />
        <circle cx="388" cy="697" r="48" fill="${songColors.grass}" />
        <circle cx="512" cy="697" r="48" fill="${songColors.amber}" />
        <circle cx="636" cy="697" r="48" fill="${songColors.lizzy}" />
      `);
    case 2:
      return svgWrap(id, `
        ${altBg(id, songColors.grass)}
        <rect x="244" y="236" width="536" height="536" rx="126" fill="#f6eedc" filter="url(#${id}-soft)" />
        <rect x="318" y="310" width="160" height="160" rx="38" fill="${songColors.lizzy}" />
        <rect x="546" y="310" width="160" height="160" rx="38" fill="${songColors.cyan}" />
        <rect x="318" y="538" width="160" height="160" rx="38" fill="${songColors.amber}" />
        <rect x="546" y="538" width="160" height="160" rx="38" fill="${songColors.grass}" />
        <path d="M399 390 V342 M626 582 V650 M366 618 H432 M590 390 H662" stroke="#19111f" stroke-width="22" stroke-linecap="round" />
      `);
    case 3:
      return svgWrap(id, `
        ${altBg(id, "#f08338")}
        <path d="M512 146 C705 146 848 302 848 510 C848 727 690 878 512 878 C334 878 176 727 176 510 C176 302 319 146 512 146 Z" fill="#f5ead6" filter="url(#${id}-soft)" />
        <path d="M512 228 C665 228 766 346 766 509 C766 676 653 794 512 794 C371 794 258 676 258 509 C258 346 359 228 512 228 Z" fill="#20132c" />
        <path d="M360 578 C434 540 447 478 405 430 C500 422 578 378 642 316 C668 412 632 509 543 575 C483 619 416 626 360 578 Z" fill="${songColors.cream}" />
        <path d="M398 612 C478 548 548 548 626 613" fill="none" stroke="${songColors.grass}" stroke-width="24" stroke-linecap="round" />
      `);
    case 4:
      return svgWrap(id, `
        ${altBg(id, songColors.amber)}
        <rect x="260" y="228" width="286" height="286" rx="72" fill="#f6eedc" filter="url(#${id}-soft)" />
        <rect x="478" y="448" width="286" height="286" rx="72" fill="#f6eedc" filter="url(#${id}-soft)" />
        <circle cx="356" cy="326" r="24" fill="${songColors.lizzy}" />
        <circle cx="450" cy="420" r="24" fill="${songColors.cyan}" />
        <path d="M380 428 C430 378 433 322 388 286" fill="none" stroke="#22152a" stroke-width="20" stroke-linecap="round" />
        <circle cx="574" cy="548" r="24" fill="${songColors.grass}" />
        <circle cx="622" cy="592" r="24" fill="${songColors.amber}" />
        <circle cx="670" cy="638" r="24" fill="${songColors.francis}" />
      `);
    case 5:
      return svgWrap(id, `
        ${altBg(id, songColors.grass)}
        <path d="M322 258 H702 V420 Q702 566 564 604 V704 H664 V776 H360 V704 H460 V604 Q322 566 322 420 Z" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <path d="M322 338 H238 Q212 338 206 366 C190 462 227 540 326 548" fill="none" stroke="${songColors.cream}" stroke-width="48" stroke-linecap="round" />
        <path d="M702 338 H786 Q812 338 818 366 C834 462 797 540 698 548" fill="none" stroke="${songColors.cream}" stroke-width="48" stroke-linecap="round" />
        <rect x="404" y="342" width="216" height="34" rx="17" fill="${songColors.lizzy}" />
        <rect x="376" y="420" width="272" height="34" rx="17" fill="${songColors.cyan}" />
        <rect x="420" y="498" width="184" height="34" rx="17" fill="${songColors.amber}" />
      `);
    case 6:
      return svgWrap(id, `
        ${altBg(id, songColors.amber)}
        <circle cx="512" cy="512" r="314" fill="#f6ead4" filter="url(#${id}-soft)" />
        <circle cx="512" cy="512" r="242" fill="#21152c" />
        <path d="M392 584 V424 Q392 376 440 376 H584 Q632 376 632 424 V584" fill="none" stroke="${songColors.cream}" stroke-width="36" stroke-linecap="round" />
        <path d="M392 462 H632 M430 540 H594" stroke="${songColors.cyan}" stroke-width="24" stroke-linecap="round" />
        <path d="M452 674 H572" stroke="${songColors.lizzy}" stroke-width="34" stroke-linecap="round" />
      `);
    case 7:
      return svgWrap(id, `
        ${altBg(id, songColors.francis)}
        <path d="M568 220 V642 C568 744 488 810 394 792 C304 775 254 698 288 627 C321 556 410 542 462 594 V282 Z" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <path d="M568 284 C656 310 720 380 744 470" fill="none" stroke="${songColors.cream}" stroke-width="54" stroke-linecap="round" filter="url(#${id}-soft)" />
        <circle cx="396" cy="682" r="56" fill="${songColors.lizzy}" />
        <circle cx="630" cy="512" r="42" fill="${songColors.grass}" />
        <circle cx="704" cy="438" r="32" fill="${songColors.amber}" />
        <path d="M370 682 H422 M396 656 V708" stroke="#1d1326" stroke-width="16" stroke-linecap="round" />
      `);
    case 8:
      return svgWrap(id, `
        ${altBg(id, songColors.cyan)}
        <rect x="224" y="224" width="576" height="576" rx="118" fill="#f5ecd8" filter="url(#${id}-soft)" />
        <path d="M330 362 H694 M330 512 H694 M330 662 H694" stroke="#20142c" stroke-width="34" stroke-linecap="round" />
        <path d="M380 664 C462 564 560 462 648 362" fill="none" stroke="${songColors.lizzy}" stroke-width="28" stroke-linecap="round" />
        <circle cx="380" cy="664" r="36" fill="${songColors.grass}" />
        <circle cx="648" cy="362" r="36" fill="${songColors.amber}" />
        <circle cx="512" cy="512" r="44" fill="${songColors.cyan}" />
      `);
    case 9:
      return svgWrap(id, `
        ${altBg(id, songColors.lizzy)}
        <path d="M298 480 C298 340 394 248 512 248 C630 248 726 340 726 480" fill="none" stroke="${songColors.cream}" stroke-width="56" stroke-linecap="round" filter="url(#${id}-soft)" />
        <rect x="236" y="448" width="112" height="210" rx="48" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <rect x="676" y="448" width="112" height="210" rx="48" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <path d="M512 420 L566 524 L682 540 L598 618 L620 730 L512 674 L404 730 L426 618 L342 540 L458 524 Z" fill="${songColors.amber}" />
        <circle cx="512" cy="574" r="44" fill="${songColors.grass}" />
        <circle cx="436" cy="608" r="34" fill="${songColors.cyan}" />
        <circle cx="588" cy="608" r="34" fill="${songColors.lizzy}" />
      `);
    default:
      return "";
  }
}

function cassetteBg(id, accent = songColors.cyan) {
  return `
    ${altBg(id, accent)}
    <rect x="126" y="126" width="772" height="772" rx="214" fill="#130b1a" opacity="0.56" />
    <path d="M126 740 L126 898 L284 898 Z" fill="#030206" opacity="0.78" />
  `;
}

function cassetteShell({
  x = 190,
  y = 316,
  w = 644,
  h = 390,
  rx = 82,
  fill = "#f6eedc",
  id,
  stroke = "",
}) {
  const strokeAttrs = stroke ? ` stroke="${stroke}" stroke-width="18"` : "";
  return `
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}"${strokeAttrs} filter="url(#${id}-soft)" />
    <rect x="${x + w * 0.12}" y="${y + h * 0.18}" width="${w * 0.76}" height="${h * 0.33}" rx="${Math.min(42, rx * 0.52)}" fill="#21152c" />
  `;
}

function reel(cx, cy, r, color = "#21152c", dot = songColors.amber) {
  return `
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="${color}" />
    <circle cx="${cx}" cy="${cy}" r="${Math.max(12, r * 0.42)}" fill="${dot}" />
  `;
}

function plus(cx, cy, size, color = "#21152c") {
  const arm = size * 0.28;
  const len = size * 0.78;
  return `
    <rect x="${cx - arm / 2}" y="${cy - len / 2}" width="${arm}" height="${len}" rx="${arm / 2}" fill="${color}" />
    <rect x="${cx - len / 2}" y="${cy - arm / 2}" width="${len}" height="${arm}" rx="${arm / 2}" fill="${color}" />
  `;
}

function buttonCluster(x, y, r = 21) {
  return `
    <circle cx="${x}" cy="${y}" r="${r}" fill="${songColors.grass}" />
    <circle cx="${x + r * 2.25}" cy="${y - r * 0.85}" r="${r}" fill="${songColors.cyan}" />
    <circle cx="${x + r * 4.5}" cy="${y}" r="${r}" fill="${songColors.lizzy}" />
    <circle cx="${x + r * 2.25}" cy="${y + r * 0.95}" r="${r}" fill="${songColors.amber}" />
  `;
}

function spinningReel(cx, cy, r, accent, id, dur = "1.35s", reverse = false) {
  const from = reverse ? `360 ${cx} ${cy}` : `0 ${cx} ${cy}`;
  const to = reverse ? `0 ${cx} ${cy}` : `360 ${cx} ${cy}`;
  const hole = Math.max(7, r * 0.14);
  const spoke = Math.max(10, r * 0.2);
  return `
    <g class="reel-spin">
      <animateTransform attributeName="transform" type="rotate" from="${from}" to="${to}" dur="${dur}" repeatCount="indefinite" />
      <circle cx="${cx}" cy="${cy}" r="${r}" fill="#21152c" />
      <circle cx="${cx}" cy="${cy}" r="${Math.max(18, r * 0.44)}" fill="${accent}" />
      <circle cx="${cx - r * 0.42}" cy="${cy - r * 0.12}" r="${hole}" fill="#fff4c7" opacity="0.88" />
      <circle cx="${cx + r * 0.28}" cy="${cy - r * 0.36}" r="${hole}" fill="#fff4c7" opacity="0.88" />
      <circle cx="${cx + r * 0.22}" cy="${cy + r * 0.4}" r="${hole}" fill="#fff4c7" opacity="0.88" />
      <path d="M${cx - spoke} ${cy} H${cx + spoke} M${cx} ${cy - spoke} V${cy + spoke}" stroke="#fff4c7" stroke-width="${Math.max(5, r * 0.1)}" stroke-linecap="round" opacity="0.56" />
    </g>
  `;
}

function cassetteControllerIcon(index, id) {
  switch (index) {
    case 0:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.cyan)}
        ${cassetteShell({ id })}
        ${spinningReel(390, 614, 58, songColors.amber, id, "1.18s")}
        ${spinningReel(642, 614, 58, songColors.francis, id, "1.42s", true)}
        <circle cx="512" cy="446" r="42" fill="none" stroke="${songColors.cream}" stroke-width="20" />
        ${plus(284, 604, 86, "#21152c")}
        ${buttonCluster(704, 590, 18)}
      `);
    case 1:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.amber)}
        <rect x="168" y="260" width="688" height="472" rx="90" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <rect x="246" y="332" width="532" height="176" rx="42" fill="#21152c" />
        <circle cx="306" cy="600" r="78" fill="#21152c" />
        <circle cx="718" cy="600" r="78" fill="#21152c" />
        ${plus(306, 600, 82, songColors.cyan)}
        ${buttonCluster(662, 584, 20)}
        <path d="M400 420 H624" stroke="${songColors.cream}" stroke-width="24" stroke-linecap="round" />
        <circle cx="448" cy="420" r="24" fill="none" stroke="${songColors.amber}" stroke-width="14" />
        <circle cx="576" cy="420" r="24" fill="none" stroke="${songColors.lizzy}" stroke-width="14" />
      `);
    case 2:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.grass)}
        <rect x="230" y="340" width="564" height="310" rx="76" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <rect x="332" y="404" width="360" height="98" rx="32" fill="#21152c" />
        <circle cx="346" cy="624" r="96" fill="#21152c" stroke="${songColors.cream}" stroke-width="18" />
        <circle cx="678" cy="624" r="96" fill="#21152c" stroke="${songColors.cream}" stroke-width="18" />
        <circle cx="346" cy="624" r="34" fill="${songColors.grass}" />
        <circle cx="678" cy="624" r="34" fill="${songColors.lizzy}" />
        <path d="M434 606 H590" stroke="${songColors.cyan}" stroke-width="28" stroke-linecap="round" />
        <path d="M454 444 H570" stroke="${songColors.amber}" stroke-width="20" stroke-linecap="round" />
      `);
    case 3:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.francis)}
        <rect x="236" y="192" width="552" height="652" rx="126" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <rect x="318" y="288" width="388" height="168" rx="42" fill="#21152c" />
        ${reel(420, 372, 34, "#3a2747", songColors.cyan)}
        ${reel(604, 372, 34, "#3a2747", songColors.amber)}
        <rect x="330" y="540" width="152" height="152" rx="42" fill="#21152c" />
        ${plus(406, 616, 96, songColors.cream)}
        ${buttonCluster(560, 596, 22)}
        <path d="M408 766 H616" stroke="#21152c" stroke-width="28" stroke-linecap="round" />
      `);
    case 4:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.lizzy)}
        <rect x="202" y="304" width="620" height="360" rx="78" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <rect x="286" y="374" width="452" height="120" rx="38" fill="#21152c" />
        ${reel(400, 434, 34, "#3a2747", songColors.amber)}
        ${reel(624, 434, 34, "#3a2747", songColors.cyan)}
        <path d="M332 602 C394 540 450 590 410 642 C382 678 320 660 332 602 Z" fill="none" stroke="${songColors.lizzy}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round" />
        <path d="M338 625 H398 M368 594 V656" stroke="#21152c" stroke-width="17" stroke-linecap="round" />
        ${buttonCluster(614, 598, 19)}
        <path d="M654 492 C694 550 668 602 716 644" fill="none" stroke="${songColors.cream}" stroke-width="18" stroke-linecap="round" />
      `);
    case 5:
      return svgWrap(id, `
        ${cassetteBg(id, "#f08338")}
        <path d="M234 270 H790 Q840 270 850 318 L890 738 H134 L174 318 Q184 270 234 270 Z" fill="#17101f" stroke="${songColors.amber}" stroke-width="18" filter="url(#${id}-soft)" />
        <rect x="286" y="344" width="452" height="152" rx="40" fill="${songColors.cream}" />
        ${reel(414, 420, 34, "#21152c", songColors.lizzy)}
        ${reel(610, 420, 34, "#21152c", songColors.cyan)}
        <circle cx="350" cy="628" r="62" fill="${songColors.cream}" />
        <path d="M350 572 V684 M294 628 H406" stroke="#21152c" stroke-width="26" stroke-linecap="round" />
        <circle cx="620" cy="628" r="32" fill="${songColors.grass}" />
        <circle cx="710" cy="628" r="32" fill="${songColors.lizzy}" />
      `);
    case 6:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.grass)}
        <rect x="244" y="244" width="536" height="536" rx="130" fill="${songColors.cream}" filter="url(#${id}-soft)" />
        <rect x="326" y="334" width="372" height="116" rx="36" fill="#21152c" />
        <circle cx="426" cy="392" r="24" fill="${songColors.amber}" />
        <circle cx="598" cy="392" r="24" fill="${songColors.cyan}" />
        ${plus(392, 610, 98, "#21152c")}
        <rect x="548" y="554" width="62" height="62" rx="18" fill="${songColors.lizzy}" />
        <rect x="626" y="554" width="62" height="62" rx="18" fill="${songColors.cyan}" />
        <rect x="548" y="632" width="62" height="62" rx="18" fill="${songColors.amber}" />
        <rect x="626" y="632" width="62" height="62" rx="18" fill="${songColors.grass}" />
      `);
    case 7:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.cyan)}
        <g transform="rotate(-10 512 512)">
          <rect x="198" y="314" width="430" height="304" rx="70" fill="${songColors.cream}" filter="url(#${id}-soft)" />
          <rect x="250" y="370" width="326" height="88" rx="30" fill="#21152c" />
          ${plus(296, 544, 70, "#21152c")}
          ${buttonCluster(438, 530, 15)}
        </g>
        <g transform="rotate(11 512 512)">
          <rect x="406" y="434" width="430" height="304" rx="70" fill="#f0dfc0" filter="url(#${id}-soft)" />
          <rect x="458" y="490" width="326" height="88" rx="30" fill="#21152c" />
          ${plus(504, 664, 70, "#21152c")}
          ${buttonCluster(646, 650, 15)}
        </g>
      `);
    case 8:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.amber)}
        ${cassetteShell({ id, x: 188, y: 292, w: 648, h: 438, rx: 88 })}
        <path d="M360 566 V686 M300 626 H420" stroke="#21152c" stroke-width="34" stroke-linecap="round" />
        ${reel(498, 442, 32, "#3a2747", songColors.cyan)}
        ${reel(626, 442, 32, "#3a2747", songColors.lizzy)}
        <circle cx="620" cy="620" r="28" fill="${songColors.grass}" />
        <circle cx="704" cy="620" r="28" fill="${songColors.lizzy}" />
        <path d="M286 360 H738" stroke="${songColors.amber}" stroke-width="18" stroke-linecap="round" opacity="0.8" />
      `);
    case 9:
      return svgWrap(id, `
        ${cassetteBg(id, songColors.lizzy)}
        <g transform="rotate(-8 512 512)">
          <rect x="190" y="292" width="648" height="404" rx="84" fill="#16101f" stroke="${songColors.cyan}" stroke-width="18" filter="url(#${id}-soft)" />
          <rect x="276" y="360" width="472" height="128" rx="36" fill="${songColors.cream}" />
          <path d="M334 424 H690" stroke="${songColors.lizzy}" stroke-width="20" stroke-linecap="round" />
          <path d="M376 458 H648" stroke="${songColors.cyan}" stroke-width="18" stroke-linecap="round" />
          ${reel(420, 424, 24, "#21152c", songColors.amber)}
          ${reel(604, 424, 24, "#21152c", songColors.grass)}
          ${plus(354, 614, 88, songColors.cream)}
          ${buttonCluster(610, 596, 22)}
        </g>
      `);
    default:
      return "";
  }
}

function card(concept, index, svg) {
  const n = String(index + 1).padStart(2, "0");
  return `
    <article class="card">
      <div class="icon-frame">${svg}</div>
      <div class="card-copy">
        <p class="number">${n}</p>
        <h2>${h(concept.name)}</h2>
        <p class="thesis">${h(concept.thesis)}</p>
        <p><strong>Build note:</strong> ${h(concept.details)}</p>
        <p><strong>Best for:</strong> ${h(concept.bestFor)}</p>
      </div>
    </article>
  `;
}

function makeDoc({
  title,
  subtitle,
  intro,
  recommendation,
  concepts,
  iconFactory,
  slug,
}) {
  const cards = concepts
    .map((concept, index) => card(concept, index, iconFactory(index, `${slug}-${index + 1}`)))
    .join("\n");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${h(title)}</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #08070d;
      --panel: #16111e;
      --panel-2: #21172b;
      --text: #fff7e4;
      --muted: #c9b9af;
      --line: rgba(255, 244, 199, 0.18);
      --cream: ${songColors.cream};
      --amber: ${songColors.amber};
      --pink: ${songColors.lizzy};
      --green: ${songColors.grass};
      --cyan: ${songColors.cyan};
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background:
        radial-gradient(circle at 18% 8%, rgba(27, 215, 255, 0.18), transparent 30rem),
        radial-gradient(circle at 86% 10%, rgba(255, 20, 147, 0.16), transparent 28rem),
        linear-gradient(135deg, #08070d 0%, #17101f 56%, #2b1724 100%);
      color: var(--text);
      font: 16px/1.55 -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
      padding: 28px;
    }
    .page {
      max-width: 1180px;
      margin: 0 auto;
    }
    header {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 18px;
      padding: 28px 0 24px;
      border-bottom: 1px solid var(--line);
    }
    .eyebrow {
      margin: 0;
      color: var(--amber);
      font-size: 13px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      font-weight: 800;
    }
    h1 {
      margin: 0;
      max-width: 920px;
      font-size: clamp(34px, 6vw, 68px);
      line-height: 0.96;
      letter-spacing: 0;
    }
    .subtitle {
      max-width: 840px;
      color: var(--muted);
      margin: 0;
      font-size: clamp(17px, 2.2vw, 23px);
    }
    .brief {
      display: grid;
      grid-template-columns: 1.35fr 1fr;
      gap: 18px;
      margin: 24px 0 28px;
    }
    .note {
      background: rgba(255, 244, 199, 0.08);
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 18px;
    }
    .note h2 {
      margin: 0 0 8px;
      font-size: 17px;
      color: var(--cream);
    }
    .note p {
      margin: 0;
      color: var(--muted);
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 22px;
      margin: 28px 0 42px;
    }
    .card {
      background: linear-gradient(180deg, rgba(255,255,255,0.055), rgba(255,255,255,0.025));
      border: 1px solid var(--line);
      border-radius: 20px;
      overflow: hidden;
      display: grid;
      grid-template-columns: 210px minmax(0, 1fr);
      min-height: 238px;
    }
    .icon-frame {
      padding: 18px;
      background:
        linear-gradient(135deg, rgba(255,255,255,0.08), rgba(255,255,255,0.02)),
        rgba(0,0,0,0.18);
      display: flex;
      align-items: center;
      justify-content: center;
      border-right: 1px solid var(--line);
    }
    .icon-svg {
      width: 100%;
      aspect-ratio: 1;
      display: block;
      border-radius: 22.37%;
      box-shadow: 0 20px 45px rgba(0,0,0,0.38);
      overflow: hidden;
    }
    .card-copy {
      padding: 18px 18px 20px;
    }
    .number {
      margin: 0 0 7px;
      color: var(--amber);
      font-weight: 900;
      font-size: 12px;
      letter-spacing: 0.1em;
    }
    .card h2 {
      margin: 0 0 8px;
      color: var(--text);
      font-size: 24px;
      line-height: 1.08;
    }
    .card p {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 14px;
    }
    .card .thesis {
      color: var(--text);
      font-size: 15px;
    }
    strong {
      color: var(--cream);
    }
    footer {
      color: var(--muted);
      border-top: 1px solid var(--line);
      padding: 18px 0 8px;
      font-size: 13px;
    }
    @media (max-width: 900px) {
      body { padding: 18px; }
      .brief { grid-template-columns: 1fr; }
      .grid { grid-template-columns: 1fr; }
    }
    @media (max-width: 560px) {
      .card {
        grid-template-columns: 1fr;
      }
      .icon-frame {
        border-right: 0;
        border-bottom: 1px solid var(--line);
      }
      .icon-svg {
        max-width: 240px;
      }
    }
  </style>
</head>
<body>
  <main class="page">
    <header>
      <p class="eyebrow">Band Music Games Party · App Icon Exploration · ${today}</p>
      <h1>${h(title)}</h1>
      <p class="subtitle">${h(subtitle)}</p>
    </header>
    <section class="brief" aria-label="Creative brief">
      <div class="note">
        <h2>Creative Direction</h2>
        <p>${h(intro)}</p>
      </div>
      <div class="note">
        <h2>Prototype First</h2>
        <p>${h(recommendation)}</p>
      </div>
    </section>
    <section class="grid" aria-label="Icon concepts">
      ${cards}
    </section>
    <footer>
      Generated as a self-contained Pidgin-ready design document. Preview icons use the iOS mask in the document; final exported PNGs should remain square so iOS applies its own mask.
    </footer>
  </main>
</body>
</html>`;
}

function makeIconExport(iconSvg, title) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>${h(title)}</title>
  <style>
    html, body {
      width: 1024px;
      height: 1024px;
      margin: 0;
      overflow: hidden;
      background: #08070d;
    }
    svg {
      width: 1024px;
      height: 1024px;
      display: block;
    }
  </style>
</head>
<body>
${iconSvg}
</body>
</html>`;
}

const docs = [
  {
    filename: "band-music-games-string-turntable-icon-iterations.html",
    html: makeDoc({
      title: "10 String Turntable Icon Iterations",
      subtitle: "Variations that preserve the current record-player-made-from-animator-kite-string idea while tightening the app-icon silhouette.",
      intro: "These options keep the cream cord, dark plum/orange warmth, hand-drawn line energy, record platter, and tonearm. The iteration space is composition, string gesture, party-game accents, and small-size clarity.",
      recommendation: "Prototype Single Spiral Drop, Needle Lasso, and Woven Orbit first. They give the biggest range: boldest craft metaphor, most playful motion, and safest current-icon refinement.",
      concepts: stringConcepts,
      iconFactory: stringIcon,
      slug: "string",
    }),
  },
  {
    filename: "band-music-games-alternate-icon-directions.html",
    html: makeDoc({
      title: "10 Alternate App Icon Directions",
      subtitle: "Non-record-player ideas built around the premise: band songs become games you play with other people.",
      intro: "These directions drop the turntable constraint and explore more direct hybrids of music, games, party play, and the current song-color palette. They are intentionally broader so the next brand decision is not trapped inside vinyl metaphors.",
      recommendation: "Prototype Cassette Controller, Arcade Stage, and Drum Pad Grid first. They are the clearest at icon size and give three distinct brand positions: retro-playful, premise-literal, and modern music-tech.",
      concepts: alternateConcepts,
      iconFactory: altIcon,
      slug: "alt",
    }),
  },
  {
    filename: "band-music-games-cassette-controller-icon-variations.html",
    html: makeDoc({
      title: "10 Cassette Controller Icon Variations",
      subtitle: "Focused iterations on the cassette-plus-game-controller direction: music source, game input, and party-song palette in one icon.",
      intro: "These options stay inside the cassette/controller hybrid and test which visual hierarchy should lead: cassette shell, handheld player, thumbsticks, d-pad, arcade deck, co-op play, or neon mixpad.",
      recommendation: "Prototype Classic Joycassette first for the iOS app icon, then compare Pocket Player and Minimal Tapepad if the first pass feels too retro or too detailed on-device.",
      concepts: cassetteControllerConcepts,
      iconFactory: cassetteControllerIcon,
      slug: "cassette",
    }),
  },
  {
    filename: "cassette-controller-app-icon-export.html",
    html: makeIconExport(
      cassetteControllerIcon(0, "cassette-controller-app-icon"),
      "Band Music Games Cassette Controller App Icon Export"
    ),
  },
];

for (const doc of docs) {
  const target = join(outDir, doc.filename);
  writeFileSync(target, doc.html, "utf8");
  console.log(target);
}
