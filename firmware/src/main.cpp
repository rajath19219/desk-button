// Desk Button for Simple Timer (v2: wide OLED + press bar)
// ESP32-C3 SuperMini + 3.12" 256x64 SSD1322 OLED (4-wire SPI) + one keyboard switch under the bar.
//
// Talks to bridge.py on the PC over USB serial (115200, one text line per message):
//   device -> PC   "HELLO desk-button 1"   reply to "?" (lets the bridge find the right COM port)
//                  "TOGGLE"                short press: start/stop the timer
//                  "SHOW"                  long press (0.7 s): open the Timer window
//   PC -> device   "S <running 0|1> <elapsed_s> <today_s> <app name>"   about once a second
//                  "?"                     who are you?

#include <Arduino.h>
#include <SPI.h>
#include <U8g2lib.h>

// ------------------------------------------------------------------ pins (see wiring.svg)
constexpr int PIN_SCK    = 4;   // OLED SCL / CLK / D0
constexpr int PIN_MOSI   = 6;   // OLED SDA / DIN / D1
constexpr int PIN_CS     = 7;
constexpr int PIN_DC     = 10;
constexpr int PIN_RST    = 3;
constexpr int PIN_BUTTON = 5;   // switch between this pin and GND

// ------------------------------------------------------------------ tuning
constexpr uint32_t DEBOUNCE_MS   = 25;
constexpr uint32_t LONG_PRESS_MS = 700;
constexpr uint32_t OFFLINE_MS    = 4000;        // no status from the PC for this long -> "PC offline"
constexpr uint32_t DIM_AFTER_MS  = 10UL * 60 * 1000;   // idle this long -> very dim (protects the OLED)
constexpr uint8_t  BRIGHT_REC    = 200;
constexpr uint8_t  BRIGHT_IDLE   = 60;
constexpr uint8_t  BRIGHT_DIM    = 6;

U8G2_SSD1322_NHD_256X64_F_4W_HW_SPI oled(U8G2_R0, PIN_CS, PIN_DC, PIN_RST);

// ------------------------------------------------------------------ state from the PC
bool     running    = false;
uint32_t elapsedAt  = 0;     // elapsed seconds when the last status arrived
uint32_t todayAt    = 0;     // today's total seconds when the last status arrived
uint32_t statusMs   = 0;     // millis() when the last status arrived
uint32_t changedMs  = 0;     // last time running/idle changed or the bar was pressed
bool     everHeard  = false;
char     appName[40] = "";
uint32_t flashUntil = 0;     // brief frame around the screen after a press

// ------------------------------------------------------------------ serial protocol
void handleLine(char *line) {
  if (strcmp(line, "?") == 0) {
    Serial.println("HELLO desk-button 1");
    return;
  }
  if (line[0] == 'S' && line[1] == ' ') {
    int run = 0, used = 0;
    unsigned long el = 0, td = 0;
    if (sscanf(line + 2, "%d %lu %lu %n", &run, &el, &td, &used) >= 3) {
      if ((run == 1) != running) changedMs = millis();
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
uint32_t sinceStatus() { return (millis() - statusMs) / 1000; }
uint32_t elapsedNow() { return running ? elapsedAt + sinceStatus() : elapsedAt; }
uint32_t todayNow() { return running ? todayAt + sinceStatus() : todayAt; }

// ------------------------------------------------------------------ button
void pollButton() {
  static bool stable = HIGH, last = HIGH, longSent = false;
  static uint32_t changedAt = 0, pressedAt = 0;

  bool raw = digitalRead(PIN_BUTTON);
  uint32_t now = millis();
  if (raw != last) { last = raw; changedAt = now; }
  if (now - changedAt >= DEBOUNCE_MS && raw != stable) {
    stable = raw;
    if (stable == LOW) {                        // pressed
      pressedAt = now;
      longSent = false;
    } else if (!longSent) {                     // released after a short press
      Serial.println("TOGGLE");
      flashUntil = now + 150;
      changedMs = now;
      if (online()) {                           // show it straight away; the PC corrects us if needed
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
    changedMs = now;
  }
}

// ------------------------------------------------------------------ drawing
void fmtClock(uint32_t s, char *out, size_t n) {          // 24:07  or  1:02:45
  uint32_t h = s / 3600, m = (s / 60) % 60, sec = s % 60;
  if (h) snprintf(out, n, "%lu:%02lu:%02lu", (unsigned long)h, (unsigned long)m, (unsigned long)sec);
  else   snprintf(out, n, "%02lu:%02lu", (unsigned long)m, (unsigned long)sec);
}

void fmtDuration(uint32_t s, char *out, size_t n) {       // 3h 12m  or  12m
  uint32_t m = (s + 30) / 60, h = m / 60;
  if (h) snprintf(out, n, "%luh %02lum", (unsigned long)h, (unsigned long)(m % 60));
  else   snprintf(out, n, "%lum", (unsigned long)m);
}

void drawFitted(const char *s, int x, int y, int maxW) { // clip long app names with ".."
  char buf[40];
  strncpy(buf, s, sizeof(buf) - 1);
  buf[sizeof(buf) - 1] = 0;
  while (strlen(buf) > 2 && oled.getStrWidth(buf) > maxW) {
    size_t n = strlen(buf);
    buf[n - 3] = '.'; buf[n - 2] = '.'; buf[n - 1] = 0;
  }
  oled.drawStr(x, y, buf);
}

void drawScreen() {
  uint32_t now = millis();
  bool on = online();
  // move everything by a pixel or two each minute so nothing burns into the OLED
  int ox = int((now / 60000) % 5) - 2, oy = int((now / 60000 / 5) % 3) - 1;
  uint8_t bright = !on ? BRIGHT_IDLE : running ? BRIGHT_REC
                 : (now - changedMs > DIM_AFTER_MS ? BRIGHT_DIM : BRIGHT_IDLE);
  oled.setContrast(bright);
  oled.clearBuffer();

  char big[16], small[24];
  if (!on) {
    oled.setFont(u8g2_font_helvB14_tr);
    const char *t = everHeard ? "PC offline" : "Waiting for PC";
    oled.drawStr(128 - oled.getStrWidth(t) / 2 + ox, 32 + oy, t);
    oled.setFont(u8g2_font_helvR08_tr);
    const char *h = "start bridge.py on the PC";
    oled.drawStr(128 - oled.getStrWidth(h) / 2 + ox, 50 + oy, h);
  } else if (running) {
    // left: big running time
    fmtClock(elapsedNow(), big, sizeof(big));
    oled.setFont(u8g2_font_logisoso42_tn);
    if (oled.getStrWidth(big) > 168) oled.setFont(u8g2_font_logisoso32_tn);
    oled.drawStr(6 + ox, 53 + oy, big);
    // right: REC, app, today
    int rx = 182 + ox;
    if ((now / 1000) % 2 == 0) oled.drawDisc(rx + 4, 13 + oy, 4);
    else                       oled.drawCircle(rx + 4, 13 + oy, 4);
    oled.setFont(u8g2_font_helvB10_tr);
    oled.drawStr(rx + 13, 18 + oy, "REC");
    oled.setFont(u8g2_font_helvR08_tr);
    drawFitted(appName[0] ? appName : "-", rx, 37 + oy, 256 - rx - 2);
    fmtDuration(todayNow(), small, sizeof(small));
    char line[32];
    snprintf(line, sizeof(line), "today %s", small);
    oled.drawStr(rx, 53 + oy, line);
    oled.drawVLine(174 + ox, 8 + oy, 48);
  } else {
    // ready: today's total big, hint on the right
    oled.setFont(u8g2_font_helvR08_tr);
    oled.drawStr(8 + ox, 14 + oy, "TODAY");
    fmtDuration(todayNow(), big, sizeof(big));
    oled.setFont(u8g2_font_logisoso32_tf);
    oled.drawStr(6 + ox, 53 + oy, big);
    int rx = 182 + ox;
    oled.drawCircle(rx + 4, 13 + oy, 4);
    oled.setFont(u8g2_font_helvB10_tr);
    oled.drawStr(rx + 13, 18 + oy, "READY");
    oled.setFont(u8g2_font_helvR08_tr);
    oled.drawStr(rx, 37 + oy, "press the bar");
    oled.drawStr(rx, 50 + oy, "to start");
    oled.drawVLine(174 + ox, 8 + oy, 48);
  }
  if (now < flashUntil) oled.drawFrame(0, 0, 256, 64);   // "press seen"
  oled.sendBuffer();
}

// ------------------------------------------------------------------ main
void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  SPI.begin(PIN_SCK, -1, PIN_MOSI, -1);   // our pins; U8g2 then reuses this SPI bus
  oled.setBusClock(10000000);
  oled.begin();
  oled.setFontMode(1);
  changedMs = millis();
  Serial.println("HELLO desk-button 1");
}

void loop() {
  static uint32_t lastDraw = 0;
  readSerial();
  pollButton();
  uint32_t now = millis();
  if (now - lastDraw >= 100) { lastDraw = now; drawScreen(); }
  delay(2);
}
