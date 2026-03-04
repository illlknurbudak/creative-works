// ============================================================
// Generative Grid — Sonik Kaleydoskop
// ChucK ile ambient ses üretimi
// Grid'in görsel mantığını birebir sese dönüştürür
// Çalıştır: chuck grid-sonic.ck
// ============================================================

// ---------- Sabitler ----------
17 => int NUM_COLORS;       // palette renk sayısı
6  => int MAX_POLY;         // eşzamanlı nota (polifoni)
12 => int QW;               // quarter-grid genişlik (grid'den)
20 => int QH;               // quarter-grid yükseklik

QW * QH => int TOTAL_CELLS;

// ---------- A Pentatonik Skala — 17 nota, 3 oktav ----------
// Koyu maviler (0-5)  → 110-196 Hz  (düşük)
// Orta maviler (6-11) → 220-392 Hz  (orta)
// Açık maviler (12-16)→ 440-1046 Hz (yüksek)
[110.0, 130.81, 146.83, 164.81, 196.00,
 220.0, 261.63, 293.66, 329.63, 392.00,
 440.0, 523.25, 587.33, 659.26, 783.99,
 880.0, 1046.50] @=> float NOTE_FREQS[];

// ---------- Zaman parametreleri (grid animasyonuyla uyumlu) ----------
2000::ms => dur transitionMs;   // dissolve süresi
600::ms  => dur holdMs;         // hold süresi

// ---------- RNG ----------
Std.rand2(0, 2147483647) => int rngState;

fun float rand01() {
    (rngState * 1664525 + 1013904223) % 2147483647 => rngState;
    if (rngState < 0) rngState + 2147483647 => rngState;
    return rngState $ float / 2147483647.0;
}

fun int randInt(int lo, int hi) {
    return lo + Math.floor(rand01() * (hi - lo + 1)) $ int;
}

// ---------- Grid State (quarter-grid simülasyonu) ----------
int grid[TOTAL_CELLS];

fun void fillGrid() {
    for (0 => int i; i < TOTAL_CELLS; i++) {
        NUM_COLORS => grid[i]; // PAPER (beyaz = sessiz)
    }
}

fun int randomColor() {
    if (rand01() < 0.28) return NUM_COLORS; // PAPER
    return randInt(0, NUM_COLORS - 1);
}

fun void stampRect(int minW, int maxW, int minH, int maxH) {
    Math.min(maxW, QW) $ int => int mxW;
    Math.min(maxH, QH) $ int => int mxH;
    minW + Math.floor(rand01() * (mxW - minW + 1)) $ int => int rw;
    minH + Math.floor(rand01() * (mxH - minH + 1)) $ int => int rh;
    if (rw > QW) QW => rw;
    if (rh > QH) QH => rh;

    Math.floor(rand01() * Math.max(1, QW - rw + 1)) $ int => int rx;
    Math.floor(rand01() * Math.max(1, QH - rh + 1)) $ int => int ry;
    randomColor() => int col;

    for (ry => int y; y < ry + rh; y++) {
        for (rx => int x; x < rx + rw; x++) {
            if (rand01() < 0.90) {
                col => grid[y * QW + x];
            }
        }
    }
}

fun void initState() {
    fillGrid();
    for (0 => int i; i < 20; i++) stampRect(2, 6, 2, 7);
    for (0 => int i; i < 9; i++)  stampRect(4, 10, 7, 15);
    for (0 => int i; i < 3; i++)  stampRect(6, 12, 10, 18);
}

fun void evolve() {
    // piksel mutasyonları
    5 + Math.floor(rand01() * 10) $ int => int mutations;
    for (0 => int i; i < mutations; i++) {
        randInt(0, QW - 1) => int x;
        randInt(0, QH - 1) => int y;
        randomColor() => grid[y * QW + x];
    }

    // küçük blok
    1 + Math.floor(rand01() * 2) $ int => int stamps;
    for (0 => int i; i < stamps; i++) stampRect(2, 5, 2, 5);

    // orta boy plaka (%30)
    if (rand01() < 0.30) stampRect(3, 7, 4, 9);

    // büyük plaka (%12)
    if (rand01() < 0.12) stampRect(5, 10, 6, 13);

    // erosion (nefes)
    Math.floor(TOTAL_CELLS * 0.025) $ int => int breaths;
    for (0 => int i; i < breaths; i++) {
        randInt(0, TOTAL_CELLS - 1) => int k;
        if (rand01() < 0.45) NUM_COLORS => grid[k];
    }

    // satır kaydırma (%25)
    if (rand01() < 0.25) {
        randInt(0, QH - 1) => int row;
        row * QW => int base;
        if (rand01() < 0.5) {
            // sağa kaydır
            grid[base + QW - 1] => int last;
            for (QW - 1 => int x; x > 0; x--) {
                grid[base + x - 1] => grid[base + x];
            }
            last => grid[base];
        } else {
            // sola kaydır
            grid[base] => int first;
            for (0 => int x; x < QW - 1; x++) {
                grid[base + x + 1] => grid[base + x];
            }
            first => grid[base + QW - 1];
        }
    }
}

// ---------- Grid Analizi: Baskın Renkleri Bul ----------
int   topIdx[MAX_POLY];
float topGain[MAX_POLY];
int   topCount;
float whiteRatio;

fun void analyzeGrid() {
    int counts[NUM_COLORS + 1];

    for (0 => int i; i < TOTAL_CELLS; i++) {
        counts[grid[i]] + 1 => counts[grid[i]];
    }

    counts[NUM_COLORS] $ float / TOTAL_CELLS => whiteRatio;

    // Basit selection sort ile en baskın MAX_POLY renk
    int used[NUM_COLORS];
    0 => topCount;

    for (0 => int pick; pick < MAX_POLY; pick++) {
        -1 => int bestIdx;
        0  => int bestVal;
        for (0 => int c; c < NUM_COLORS; c++) {
            if (!used[c] && counts[c] > bestVal) {
                counts[c] => bestVal;
                c => bestIdx;
            }
        }
        if (bestIdx < 0 || bestVal == 0) break;
        1 => used[bestIdx];
        bestIdx => topIdx[topCount];
        topCount + 1 => topCount;
    }

    // Gain normalize
    if (topCount > 0) {
        counts[topIdx[0]] $ float => float maxC;
        for (0 => int i; i < topCount; i++) {
            (counts[topIdx[i]] $ float / maxC) * (1.0 - whiteRatio * 0.7) => topGain[i];
        }
    }
}

// ---------- Ses Mimarisi ----------

// Osilatörler + gain'ler + reverb
SinOsc   oscSin[MAX_POLY];
TriOsc   oscTri[MAX_POLY];
Gain     oscGain[MAX_POLY];
Gain     dryBus => NRev reverb => Gain master => dac;

// Reverb ayarları — uzayımsı, ambient
0.12 => reverb.mix;
0.18 => master.gain;

// Her osilatörü bağla (başta sessiz)
for (0 => int i; i < MAX_POLY; i++) {
    oscSin[i] => oscGain[i] => dryBus;
    oscTri[i] => oscGain[i];
    0.0 => oscGain[i].gain;
    0.0 => oscSin[i].gain;
    0.0 => oscTri[i].gain;
    220.0 => oscSin[i].freq;
    220.0 => oscTri[i].freq;
}

// ---------- Ses Güncelleme (Yumuşak Crossfade) ----------
fun void updateSound() {
    analyzeGrid();

    1.0 - whiteRatio * 0.8 => float breathFactor;

    for (0 => int i; i < MAX_POLY; i++) {
        if (i < topCount) {
            NOTE_FREQS[topIdx[i]] => float freq;
            topGain[i] * breathFactor * 0.35 => float vol;
            if (vol < 0.001) 0.001 => vol;

            freq => oscSin[i].freq;
            freq => oscTri[i].freq;

            // Düşük frekanslar sine, yüksek triangle
            if (freq < 300.0) {
                1.0 => oscSin[i].gain;
                0.0 => oscTri[i].gain;
            } else {
                0.0 => oscSin[i].gain;
                1.0 => oscTri[i].gain;
            }

            vol => oscGain[i].gain;
        } else {
            // Kullanılmayan slot → sessiz
            0.0 => oscGain[i].gain;
        }
    }
}

// ---------- Yumuşak Geçiş (Crossfade Ramping) ----------
float currentGains[MAX_POLY];
float targetGains[MAX_POLY];
float currentFreqs[MAX_POLY];
float targetFreqs[MAX_POLY];

for (0 => int i; i < MAX_POLY; i++) {
    0.0 => currentGains[i];
    0.0 => targetGains[i];
    220.0 => currentFreqs[i];
    220.0 => targetFreqs[i];
}

fun void prepareTargets() {
    analyzeGrid();
    1.0 - whiteRatio * 0.8 => float breathFactor;

    for (0 => int i; i < MAX_POLY; i++) {
        if (i < topCount) {
            NOTE_FREQS[topIdx[i]] => targetFreqs[i];
            topGain[i] * breathFactor * 0.35 => targetGains[i];
            if (targetGains[i] < 0.001) 0.001 => targetGains[i];
        } else {
            currentFreqs[i] => targetFreqs[i];
            0.0 => targetGains[i];
        }
    }
}

fun void crossfade(dur rampTime) {
    // Adım sayısı: 20ms aralıklarla
    20::ms => dur stepDur;
    (rampTime / stepDur) $ int => int steps;
    if (steps < 1) 1 => steps;

    for (1 => int s; s <= steps; s++) {
        s $ float / steps => float t;
        // Smooth easing: cubic
        t * t * (3.0 - 2.0 * t) => float ease;

        for (0 => int i; i < MAX_POLY; i++) {
            // Gain interpolasyon
            currentGains[i] + (targetGains[i] - currentGains[i]) * ease => float g;
            g => oscGain[i].gain;

            // Frekans interpolasyon (glissando)
            Math.exp(
                Math.log(Math.max(1.0, currentFreqs[i])) +
                (Math.log(Math.max(1.0, targetFreqs[i])) - Math.log(Math.max(1.0, currentFreqs[i]))) * ease
            ) => float f;
            f => oscSin[i].freq;
            f => oscTri[i].freq;

            // Dalga tipi seç
            if (f < 300.0) {
                1.0 => oscSin[i].gain;
                0.0 => oscTri[i].gain;
            } else {
                0.0 => oscSin[i].gain;
                1.0 => oscTri[i].gain;
            }
        }

        stepDur => now;
    }

    // Final değerleri kaydet
    for (0 => int i; i < MAX_POLY; i++) {
        targetGains[i] => currentGains[i];
        targetFreqs[i] => currentFreqs[i];
    }
}

// ---------- Hız Rastgeleleştirme ----------
fun void randomizeSpeed() {
    (1600 + Math.floor(rand01() * 1400)) $ int => int tMs;
    (400  + Math.floor(rand01() * 500))  $ int => int hMs;
    tMs::ms => transitionMs;
    hMs::ms => holdMs;
}

// ---------- Ana Döngü ----------
<<< "=== Generative Grid Sonik Kaleydoskop ===" >>>;
<<< "Sonsuz ambient ses üretimi başlıyor..." >>>;
<<< "Ctrl+C ile durdur." >>>;

initState();

// İlk ses durumu
prepareTargets();
crossfade(800::ms);

while (true) {
    // Evolve — grid durumu değişir
    evolve();
    randomizeSpeed();

    // Yeni hedef notaları hesapla
    prepareTargets();

    // Yumuşak geçiş (transition süresiyle senkron)
    crossfade(transitionMs);

    // Hold — grid sabit, ses de sabit
    holdMs => now;
}
