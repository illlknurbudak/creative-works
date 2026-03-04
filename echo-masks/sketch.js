// ECHO MASKS - Brush Accumulation
// Basitleştirilmiş, çalışır versiyon

let seed = 42424;
let particles = [];
let pgHalf;
let currentPreset = 'INK';

const CONFIG = {
  bgColor: '#f8f6f3',
  shadowAlpha: 30,
  stampJitter: 2,
  colorShiftChance: 0.08
};

const PALETTES = [
  ['#ed3b2b', '#efb72b', '#1357c4', '#366b34', '#3a2349'],
  ['#f98939', '#d36e20', '#641d1e', '#344a2e', '#171d6a'],
  ['#ed3b2b', '#100c7b', '#efb72b', '#92cc5f', '#f98939']
];

const PRESETS = {
  INK: { count: 600, speed: 0.5, turb: 0.005, stamps: 6, minW: 0.5, maxW: 1.8, pal: 0 },
  DENSE: { count: 1200, speed: 0.7, turb: 0.008, stamps: 10, minW: 0.8, maxW: 2.5, pal: 1 },
  WILD: { count: 1800, speed: 1.0, turb: 0.012, stamps: 14, minW: 0.6, maxW: 3.0, pal: 2 }
};

let params, activePalette;

function setup() {
  let c = createCanvas(540, 675);
  c.parent('canvas-container');

  pgHalf = createGraphics(270, 675);
  pgHalf.background(CONFIG.bgColor);
  background(CONFIG.bgColor);

  loadPreset('INK');

  console.log('N=yeni seed | 1/2/3=preset | C=temizle | S=kaydet');
}

function loadPreset(name) {
  currentPreset = name;
  params = PRESETS[name];
  activePalette = PALETTES[params.pal];

  randomSeed(seed);
  noiseSeed(seed);

  particles = [];
  for (let i = 0; i < params.count; i++) {
    particles.push(createParticle());
  }

  pgHalf.background(CONFIG.bgColor);
  console.log(name + ' | seed:' + seed);
}

function createParticle() {
  let hw = 270, hh = 675;
  let cx = hw * 0.5, cy = hh * 0.4;

  let p = {
    x: 0, y: 0, prevX: 0, prevY: 0,
    life: random(150, 400),
    col: color(random(activePalette))
  };

  // Spawn pozisyonu
  let form = floor(random(4));
  if (form === 0) {
    let a = random(TWO_PI);
    let r = pow(random(), 0.5) * hw * 0.4;
    p.x = cx + cos(a) * r;
    p.y = cy + sin(a) * r * 1.2;
  } else if (form === 1) {
    p.x = random(hw * 0.2, hw * 0.8);
    p.y = random(hh * 0.25, hh * 0.5);
  } else if (form === 2) {
    p.x = cx + random(-hw * 0.1, hw * 0.1);
    p.y = random(hh * 0.15, hh * 0.8);
  } else {
    p.x = random(hw * 0.1, hw * 0.9);
    p.y = random(hh * 0.1, hh * 0.9);
  }

  p.x = constrain(p.x, 5, hw - 5);
  p.y = constrain(p.y, 5, hh - 5);
  p.prevX = p.x;
  p.prevY = p.y;

  return p;
}

function draw() {
  // Parçacıkları güncelle ve çiz
  for (let p of particles) {
    p.prevX = p.x;
    p.prevY = p.y;

    // Flow field
    let n = noise(p.x * params.turb, p.y * params.turb, frameCount * 0.002);
    let angle = n * TWO_PI * 2 + 1.5;

    p.x += cos(angle) * params.speed;
    p.y += sin(angle) * params.speed;
    p.life--;

    // Renk kayması
    if (random() < CONFIG.colorShiftChance) {
      p.col = color(random(activePalette));
    }

    // Sınır veya ölüm - yeniden spawn
    if (p.life <= 0 || p.x < 0 || p.x > 270 || p.y < 0 || p.y > 675) {
      let np = createParticle();
      p.x = np.x; p.y = np.y;
      p.prevX = np.prevX; p.prevY = np.prevY;
      p.life = np.life; p.col = np.col;
    }

    // Çiz
    drawBrush(p);
  }

  // Mirror ile ana canvas'a
  background(CONFIG.bgColor);
  image(pgHalf, 0, 0);
  push();
  translate(width, 0);
  scale(-1, 1);
  image(pgHalf, 0, 0);
  pop();

  // Info
  fill(0, 80);
  noStroke();
  textSize(9);
  text(currentPreset + ' | seed:' + seed + ' | f:' + frameCount, 8, height - 6);
}

function drawBrush(p) {
  let dx = p.x - p.prevX;
  let dy = p.y - p.prevY;
  let d = sqrt(dx*dx + dy*dy);
  if (d < 0.3) return;

  for (let i = 0; i < params.stamps; i++) {
    let t = i / params.stamps;
    let px = lerp(p.prevX, p.x, t) + random(-CONFIG.stampJitter, CONFIG.stampJitter);
    let py = lerp(p.prevY, p.y, t) + random(-CONFIG.stampJitter, CONFIG.stampJitter);
    let sw = random(params.minW, params.maxW);

    // Gölge
    pgHalf.noStroke();
    pgHalf.fill(30, CONFIG.shadowAlpha);
    pgHalf.ellipse(px + 1.5, py + 1.5, sw * 2, sw * 2);

    // Ana brush
    pgHalf.fill(p.col);
    pgHalf.ellipse(px, py, sw * 1.5, sw * 1.2);
  }
}

function keyPressed() {
  if (key === 'n' || key === 'N') {
    seed = floor(random(999999));
    loadPreset(currentPreset);
  }
  if (key === '1') loadPreset('INK');
  if (key === '2') loadPreset('DENSE');
  if (key === '3') loadPreset('WILD');
  if (key === 'c' || key === 'C') {
    pgHalf.background(CONFIG.bgColor);
  }
  if (key === 's' || key === 'S') {
    saveCanvas('EchoMasks_' + currentPreset + '_' + seed, 'png');
  }
}
