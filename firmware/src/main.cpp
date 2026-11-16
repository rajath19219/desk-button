// Desk Button for Simple Timer
// ESP32-C3 SuperMini + 1.28" round GC9A01 display + WS2812 16-LED ring + 30 mm arcade button.
//
// Talks to bridge.py on the PC over USB serial (115200, one text line per message):
//   device -> PC   "HELLO desk-button 1"   reply to "?" (lets the bridge find the right COM port)
//                  "TOGGLE"                short press: start/stop the timer
//                  "SHOW"                  long press (0.7 s): open the Timer window
//   PC -> device   "S <running 0|1> <elapsed_s> <today_s> <app name>"   about once a second
//                  "?"                     who are you?

#include <Arduino.h>
#include <Arduino_GFX_Library.h>
#include <Adafruit_NeoPixel.h>

// ------------------------------------------------------------------ pins (see wiring.svg)
constexpr int PIN_TFT_SCK  = 4;
constexpr int PIN_TFT_MOSI = 6;   // labelled SDA on most displays
constexpr int PIN_TFT_CS   = 7;
constexpr int PIN_TFT_DC   = 10;
constexpr int PIN_TFT_RST  = 3;
constexpr int PIN_TFT_BL   = 1;   // backlight; leave unconnected if your module has no BL pin
constexpr int PIN_BUTTON   = 5;   // arcade button between this pin and GND
constexpr int PIN_LEDS     = 0;   // WS2812 ring DIN (through a 330 Ω resistor)
constexpr int NUM_LEDS     = 16;

// ------------------------------------------------------------------ tuning
constexpr uint32_t DEBOUNCE_MS   = 25;
constexpr uint32_t LONG_PRESS_MS = 700;
constexpr uint32_t OFFLINE_MS    = 4000;  // no status from the PC for this long -> "PC offline"
constexpr uint8_t  LED_MAX       = 70;    // brightness cap (0-255); also keeps current low

// ------------------------------------------------------------------ hardware objects
Arduino_DataBus *bus   = new Arduino_HWSPI(PIN_TFT_DC, PIN_TFT_CS, PIN_TFT_SCK, PIN_TFT_MOSI, GFX_NOT_DEFINED);
Arduino_GFX     *panel = new Arduino_GC9A01(bus, PIN_TFT_RST, 0 /*rotation*/, true /*IPS*/);
Arduino_Canvas  *gfx   = new Arduino_Canvas(240, 240, panel);   // draw off-screen, then flush: no flicker
Adafruit_NeoPixel ring(NUM_LEDS, PIN_LEDS, NEO_GRB + NEO_KHZ800);

// ------------------------------------------------------------------ colours (RGB565)
constexpr uint16_t rgb(uint8_t r, uint8_t g, uint8_t b) {
  return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
}
const uint16_t C_BG      = rgb(0, 0, 0);
const uint16_t C_REC     = rgb(255, 72, 72);
const uint16_t C_IDLE    = rgb(80, 220, 140);
const uint16_t C_OFF     = rgb(255, 176, 64);
const uint16_t C_TEXT    = rgb(235, 235, 240);
const uint16_t C_MUTED   = rgb(120, 124, 135);
const uint16_t C_GHOST   = rgb(24, 26, 30);    // unlit 7-segment bars
const uint16_t C_TICK    = rgb(40, 42, 48);

// ------------------------------------------------------------------ state from the PC
bool     running    = false;
uint32_t elapsedAt  = 0;     // elapsed seconds when the last status arrived
uint32_t todayAt    = 0;     // today's total seconds when the last status arrived
uint32_t statusMs   = 0;     // millis() when the last status arrived
bool     everHeard  = false;
char     appName[40] = "";
uint32_t flashUntil = 0;     // white flash on the ring after a press

// ------------------------------------------------------------------ serial protocol
void handleLine(char *line) {
  if (strcmp(line, "?") == 0) {
    Serial.println("HELLO desk-button 1");
    return;
  }
  if (line[0] == 'S' && line[1] == ' ') {
    int run = 0;
    unsigned long el = 0, td = 0;
    int used = 0;
    if (sscanf(line + 2, "%d %lu %lu %n", &run, &el, &td, &used) >= 3) {
      running   = run == 1;
      elapsedAt = el;
      todayAt   = td;
      statusMs  = millis();
      everHeard = true;
      strncpy(appName, used > 0 ? line + 2 + used : "", sizeof(appName) - 1);
      appName[sizeof(appName) - 1] = 0;
    }
  }
}

void readSerial() {
  static char buf[96];
  static size_t len = 0;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\r') continue;
    if (c == '\n') {
      buf[len] = 0;
      if (len) handleLine(buf);
      len = 0;
    } else if (len < sizeof(buf) - 1) {
      buf[len++] = c;
    }
  }
}

bool online() { return everHeard && millis() - statusMs < OFFLINE_MS; }

uint32_t elapsedNow() {
  return running ? elapsedAt + (millis() - statusMs) / 1000 : elapsedAt;
}

// ------------------------------------------------------------------ button
void pollButton() {
  static bool stable = HIGH, last = HIGH;
  static uint32_t changedAt = 0, pressedAt = 0;
  static bool longSent = false;

  bool raw = digitalRead(PIN_BUTTON);
  uint32_t now = millis();
  if (raw != last) { last = raw; changedAt = now; }
  if (now - changedAt >= DEBOUNCE_MS && raw != stable) {
    stable = raw;
    if (stable == LOW) {                       // pressed
      pressedAt = now;
      longSent = false;
    } else if (!longSent) {                    // released after a short press
      Serial.println("TOGGLE");
      flashUntil = now + 150;
      // Show the change straight away; the PC's next status corrects us if needed.
      if (online()) {
        running = !running;
        elapsedAt = 0;
        statusMs = now;
      }
    }
  }
  if (stable == LOW && !longSent && now - pressedAt >= LONG_PRESS_MS) {
    Serial.println("SHOW");
    longSent = true;
    flashUntil = now + 300;
  }
}

// ------------------------------------------------------------------ LED ring
void updateRing() {
  uint32_t now = millis();
  uint32_t c;
  if (now < flashUntil) {
    c = ring.Color(LED_MAX, LED_MAX, LED_MAX);
  } else if (!online()) {
    // slow amber "breathing": the PC side isn't talking to us
    float k = 0.5f - 0.5f * cosf(now / 1600.0f * 2 * PI);
    c = ring.Color(uint8_t(LED_MAX * 0.5f * k), uint8_t(LED_MAX * 0.25f * k), 0);
  } else if (running) {
    // red, gently breathing between 40% and 100%
    float k = 0.7f - 0.3f * cosf(now / 2400.0f * 2 * PI);
    c = ring.Color(uint8_t(LED_MAX * k), 0, 0);
  } else {
    c = ring.Color(0, LED_MAX / 6, 0);           // dim green: ready
  }
  for (int i = 0; i < NUM_LEDS; i++) ring.setPixelColor(i, c);
  ring.show();
}

// ------------------------------------------------------------------ drawing helpers
// segments: bit0=a(top) 1=b(top right) 2=c(bottom right) 3=d(bottom) 4=e(bottom left) 5=f(top left) 6=g(middle)
const uint8_t DIGITS[10] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};

void drawDigit(int x, int y, int w, int h, int t, int d, uint16_t on) {
  uint8_t m = DIGITS[d];
  int r = t / 2, hx = x + r + 1, hw = w - t - 2, vh = h / 2 - r - 2;
  auto seg = [&](int bit, int sx, int sy, int sw, int sh) {
    gfx->fillRoundRect(sx, sy, sw, sh, r, (m >> bit) & 1 ? on : C_GHOST);
  };
  seg(0, hx, y, hw, t);                          // a
  seg(6, hx, y + h / 2 - r, hw, t);              // g
  seg(3, hx, y + h - t, hw, t);                  // d
  seg(5, x, y + r + 1, t, vh);                   // f
  seg(1, x + w - t, y + r + 1, t, vh);           // b
  seg(4, x, y + h / 2 + 1, t, vh);               // e
  seg(2, x + w - t, y + h / 2 + 1, t, vh);       // c
}

// "mm:ss" under an hour, "h:mm:ss" after that, centred at (cx, cy)
void drawClock(uint32_t secs, int cx, int cy, uint16_t color) {
  uint32_t h = secs / 3600, m = (secs / 60) % 60, s = secs % 60;
  int digits[6], n = 0, colonsAfter[2] = {-1, -1};
  if (h > 0) {
    if (h > 9) digits[n++] = (h / 10) % 10;
    digits[n++] = h % 10; colonsAfter[0] = n - 1;
    digits[n++] = m / 10; digits[n++] = m % 10; colonsAfter[1] = n - 1;
  } else {
    digits[n++] = m / 10; digits[n++] = m % 10; colonsAfter[0] = n - 1;
  }
  digits[n++] = s / 10; digits[n++] = s % 10;

  bool big = h == 0;
  int w = big ? 34 : 24, hgt = big ? 62 : 46, t = big ? 8 : 6, gap = big ? 7 : 5, colon = big ? 14 : 10;
  int colons = (colonsAfter[0] >= 0) + (colonsAfter[1] >= 0);
  int total = n * w + (n - 1) * gap + colons * colon;
  int x = cx - total / 2, y = cy - hgt / 2;
  for (int i = 0; i < n; i++) {
    drawDigit(x, y, w, hgt, t, digits[i], color);
    x += w + gap;
    if (i == colonsAfter[0] || i == colonsAfter[1]) {
      int dx = x - gap / 2 + colon / 2;
      gfx->fillCircle(dx, y + hgt / 3, t / 2, color);
      gfx->fillCircle(dx, y + 2 * hgt / 3, t / 2, color);
      x += colon;
    }
  }
}

void centredText(const char *s, int cy, uint8_t size, uint16_t color) {
  int len = strlen(s);
  gfx->setTextSize(size);
  gfx->setTextColor(color);
  gfx->setCursor(120 - len * 3 * size, cy - 4 * size);   // built-in font is 6x8 px
  gfx->print(s);
}

void fmtDuration(uint32_t secs, char *out, size_t n) {
  uint32_t m = (secs + 30) / 60, h = m / 60;
  if (h) snprintf(out, n, "%luh %02lum", (unsigned long)h, (unsigned long)(m % 60));
  else   snprintf(out, n, "%lum", (unsigned long)m);
}

// ------------------------------------------------------------------ screen
void drawScreen() {
  uint32_t secs = elapsedNow();
  bool on = online();
  uint16_t accent = !on ? C_OFF : running ? C_REC : C_IDLE;

  gfx->fillScreen(C_BG);

  // 60 dots around the edge: the seconds hand while recording
  int lit = running && on ? (secs % 60) + 1 : 0;
  for (int i = 0; i < 60; i++) {
    float a = (i / 60.0f) * 2 * PI - PI / 2;
    int x = 120 + cosf(a) * 112, y = 120 + sinf(a) * 112;
    bool five = i % 5 == 0;
    gfx->fillCircle(x, y, five ? 3 : 2, i < lit ? accent : C_TICK);
  }

  if (!on) {
    centredText(everHeard ? "PC OFFLINE" : "WAITING", 92, 2, C_OFF);
    centredText("start bridge.py", 130, 1, C_MUTED);
    centredText("on the PC", 144, 1, C_MUTED);
  } else {
    const char *label = running ? "REC" : "READY";
    int x0 = 120 - (strlen(label) * 12 + 16) / 2;   // dot + gap + text, centred
    gfx->fillCircle(x0 + 5, 52, 5, accent);
    gfx->setTextSize(2);
    gfx->setTextColor(accent);
    gfx->setCursor(x0 + 16, 45);
    gfx->print(label);

    drawClock(secs, 120, 112, running ? C_TEXT : C_MUTED);

    // current app (or a hint when idle), clipped to fit the circle
    char line[16];
    if (running && appName[0]) {
      strncpy(line, appName, sizeof(line) - 1);
      line[sizeof(line) - 1] = 0;
      if (strlen(appName) > 13) { line[12] = '.'; line[13] = '.'; line[14] = 0; }
      centredText(line, 166, 2, C_TEXT);
    } else if (!running) {
      centredText("tap to start", 166, 2, C_MUTED);
    }

    char today[24], dur[16];
    fmtDuration(todayAt + (running ? (millis() - statusMs) / 1000 : 0), dur, sizeof(dur));
    snprintf(today, sizeof(today), "today %s", dur);
    centredText(today, 194, 1, C_MUTED);
  }
  gfx->flush();
}

// ------------------------------------------------------------------ main
void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_TFT_BL, OUTPUT);
  digitalWrite(PIN_TFT_BL, HIGH);

  ring.begin();
  ring.clear();
  ring.show();

  if (!gfx->begin()) {
    // display missing or wired wrong: blink the ring blue so it's obvious
    for (;;) {
      for (int i = 0; i < NUM_LEDS; i++) ring.setPixelColor(i, ring.Color(0, 0, (millis() / 300) % 2 ? 40 : 0));
      ring.show();
      delay(50);
    }
  }
  gfx->fillScreen(C_BG);
  gfx->flush();
  Serial.println("HELLO desk-button 1");
}

void loop() {
  static uint32_t lastDraw = 0, lastLeds = 0;
  readSerial();
  pollButton();
  uint32_t now = millis();
  if (now - lastLeds >= 20) { lastLeds = now; updateRing(); }
  if (now - lastDraw >= 200) { lastDraw = now; drawScreen(); }
  delay(2);
}
