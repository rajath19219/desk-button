// Minimal stand-in for Arduino.h so the firmware's drawing code can be compiled and run on a PC.
#pragma once
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <cstdio>
#include <cmath>

#define HIGH 1
#ifndef U8X8_PIN_NONE
#define U8X8_PIN_NONE 255
#endif
#define LOW 0
#define INPUT 0
#define OUTPUT 1
#define INPUT_PULLUP 2
#ifndef PI
#define PI 3.14159265358979f
#endif

extern uint32_t g_millis;
inline uint32_t millis() { return g_millis; }
inline void delay(uint32_t) {}
inline void pinMode(int, int) {}
inline void digitalWrite(int, int) {}
inline int digitalRead(int) { return HIGH; }

class Print {
 public:
  virtual ~Print() {}
  virtual size_t write(uint8_t) = 0;
  virtual size_t write(const uint8_t *buf, size_t n) { size_t k = 0; while (n--) k += write(*buf++); return k; }
  size_t write(const char *s) { return s ? write((const uint8_t *)s, strlen(s)) : 0; }
  size_t print(const char *s) { return write(s); }
  size_t print(int v) { char b[16]; snprintf(b, sizeof b, "%d", v); return write(b); }
};

struct HostSerial {
  void begin(long) {}
  void println(const char *) {}
  int available() { return 0; }
  int read() { return -1; }
};
extern HostSerial Serial;
