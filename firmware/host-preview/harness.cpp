// Runs the firmware's real drawScreen() on a PC and prints each screen as text pixels.
// Built and run by render.py — you don't call this directly.
#include "Arduino.h"
#include "SPI.h"
#include "Wire.h"
#include <U8g2lib.h>

uint32_t g_millis = 0;
HostSerial Serial;
SPIClass SPI;
TwoWire Wire;

// Same U8g2 setup the real displays use, but the bytes go nowhere; we read the frame buffer instead.
class HostOled : public U8G2 {
 public:
  HostOled(const u8g2_cb_t *r, bool wide) {
    if (wide) u8g2_Setup_ssd1322_nhd_256x64_f(&u8g2, r, u8x8_byte_empty, u8x8_dummy_cb);
    else      u8g2_Setup_ssd1306_i2c_128x64_noname_f(&u8g2, r, u8x8_byte_empty, u8x8_dummy_cb);
  }
  u8g2_t *raw() { return &u8g2; }
};
struct HostWide  : HostOled { HostWide(const u8g2_cb_t *r, int, int, int) : HostOled(r, true) {} };
struct HostSmall : HostOled { HostSmall(const u8g2_cb_t *r, int, int, int) : HostOled(r, false) {} };
#define U8G2_SSD1322_NHD_256X64_F_4W_HW_SPI HostWide
#define U8G2_SSD1306_128X64_NONAME_F_HW_I2C HostSmall
#define U8G2_SH1106_128X64_NONAME_F_HW_I2C  HostSmall

#include "../src/main.cpp"

static void dump(const char *name) {
  u8g2_t *g = oled.raw();
  int w = u8g2_GetDisplayWidth(g), h = u8g2_GetDisplayHeight(g), tw = u8g2_GetBufferTileWidth(g);
  uint8_t *buf = u8g2_GetBufferPtr(g);
  printf("SCREEN %s %d %d\n", name, w, h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) putchar((buf[(y / 8) * tw * 8 + x] >> (y % 8)) & 1 ? '1' : '0');
    putchar('\n');
  }
}

static void scene(const char *name, bool heard, bool rec, uint32_t elapsed, uint32_t today,
                  const char *app, uint32_t ageMs = 0, bool flash = false) {
  g_millis = 7 * 60000;            // a minute where the anti-burn-in shift is zero
  everHeard = heard;
  running = rec;
  elapsedAt = elapsed;
  todayAt = today;
  statusMs = g_millis - ageMs;
  changedMs = g_millis;
  flashUntil = flash ? g_millis + 100 : 0;
  strncpy(appName, app, sizeof(appName) - 1);
  drawScreen();
  dump(name);
}

int main() {
  oled.begin();
  oled.setFontMode(1);
  scene("recording", true, true, 24 * 60 + 7, 3 * 3600 + 12 * 60, "Premiere Pro");
  scene("recording_long", true, true, 3600 + 2 * 60 + 45, 4 * 3600 + 51 * 60, "Visual Studio Code");
  scene("ready", true, false, 0, 3 * 3600 + 12 * 60, "");
  scene("pressed", true, true, 5, 3 * 3600 + 12 * 60, "Chrome", 0, true);
  scene("offline", true, false, 0, 0, "", 10000);
  scene("waiting", false, false, 0, 0, "", 10000);
  return 0;
}
