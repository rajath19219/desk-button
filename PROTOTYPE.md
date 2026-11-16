# Bare-bones prototype

Prove the idea works before buying the expensive screen or printing anything. The firmware and PC bridge are the same as in the real build; only the hardware is cut down.

| Stage | What you need | Cost | Soldering | What it proves |
|-------|---------------|------|-----------|----------------|
| **1. Board only** | ESP32-C3 SuperMini + a USB-C data cable | ₹399 | none | press → Timer starts/stops; the board's LED shows recording |
| **2. Board + small screen** | + 0.96" I2C OLED, a push button, breadboard, jumper wires | + ₹733 | none (with the pre-soldered board) | the screen shows running time, app, today's total |

The **real 3.12" screen and the press-bar case** come after stage 2 works.

## Shopping list (Amazon.in, checked 16 Nov 2026)

| For | Part | Price | Link |
|-----|------|-------|------|
| Stage 1 | ESP32-C3 SuperMini, **header pins already soldered** (OceanLabz) | ₹399 | [amazon.in/dp/B0D2DM322M](https://www.amazon.in/dp/B0D2DM322M) |
| Stage 2 | 0.96" OLED, I2C, 4-pin, SSD1306, white (Tishvi) | ₹325 | [amazon.in/dp/B0GZ4HKDNN](https://www.amazon.in/dp/B0GZ4HKDNN) |
| Stage 2 | 400-point breadboard + 60 jumper wires (Electronic Spices) | ₹259 | [amazon.in/dp/B0CP25NH8Z](https://www.amazon.in/dp/B0CP25NH8Z) |
| Stage 2 | 12 mm tactile push buttons with caps, 15 pcs | ₹149 | [amazon.in/dp/B08JZHFQ4T](https://www.amazon.in/dp/B08JZHFQ4T) |

That's ₹399 for stage 1 and about ₹1,130 for everything. You also need a USB-C **data** cable.

Robu.in has the SuperMini for ₹289–299, but it was out of stock when checked.

---

## Stage 1: just the board

The SuperMini has its own **BOOT** button and a small **blue LED**, so it's already a one-button device.

### Buy
- **ESP32-C3 SuperMini**, about ₹250–350 on Robu.in or Amazon.in.
- A **USB-C data cable**. Some cables only charge; if Windows doesn't make a sound when you plug the board in, try another cable.

### Flash it (once)
1. Install the **PlatformIO IDE** extension in VS Code.
2. **File → Open Folder** → `desk-button\firmware`.
3. Plug in the board, then click the **→ Upload** arrow in the blue bar at the bottom. The default build is `bare`.
4. If the upload fails, hold **BOOT**, tap **RST**, let go of BOOT, and click Upload again.

### Run the PC side in a window you can watch
In PowerShell, inside `Z:\Time tracker - Claude\desk-button`:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe bridge.py --console
```

The first two lines are a one-time setup. Make sure the Timer app is running (tray icon).

### Test checklist

| Do this | You should see |
|---------|----------------|
| Plug in the board, with the bridge not running yet | blue LED blinks briefly every 2 s, meaning "no PC" |
| Start `bridge.py --console` | `connected to desk button on COMx`; LED goes **off** (ready) or **solid** (already recording) |
| **Tap BOOT** | console shows `button says: TOGGLE`, the Timer starts, LED turns **solid** |
| Tap BOOT again | Timer stops, LED **off** |
| **Hold BOOT** for 1 s | console shows `button says: SHOW`, and the Timer window opens |
| Start/stop from the Timer's tray icon instead | LED follows within about a second |
| Unplug and replug the board | console reconnects by itself within a few seconds |

If all of that works, **the idea works**. Everything after this is just a nicer button and a screen.

---

## Stage 2: add a small screen and a real button

### Buy (Robu.in / Amazon.in)
| Part | ≈ Price |
|------|---------|
| 0.96" OLED 128×64, **I2C** (4 pins: GND VCC SCL SDA), SSD1306 | ₹150–250 |
| A push button: a 12 mm tactile button, any arcade button, or the Kailh Choc switch from the final parts list | ₹10–60 |
| Half-size breadboard + male-to-male jumper wires | ₹150 |

The board in the shopping list comes with its header pins already soldered, so it pushes straight into the breadboard with **no soldering at all**. Other SuperMinis often come with loose pins, which take about 10 minutes to solder.

### Wire it (6 wires, no soldering on the breadboard)

```
SuperMini        0.96" OLED
3V3     ───────  VCC
GND     ───────  GND
GPIO 4  ───────  SCL
GPIO 6  ───────  SDA

SuperMini        Button
GPIO 5  ───────  one leg
GND     ───────  the other leg   (for a 4-leg tactile button, use two diagonal legs)
```

### Flash the `proto` build
In VS Code: **PlatformIO sidebar (ant icon) → Project Tasks → proto → Upload**.

- If the picture looks shifted or has garbage down one side, you have a 1.3" SH1106 screen. Upload **proto13** instead.
- If the screen stays blank, swap the SCL and SDA wires.

### What you should see
- No PC: *Waiting for PC*.
- Ready: `READY`, today's total in big digits, and *press to start*.
- Recording: a blinking `REC` dot, a big running clock, the current app, and *today Xh YYm* in the corner.
- Press the button: a frame flashes around the screen and the Timer toggles. The BOOT button still works too.

---

## When it works

1. Run `setup.ps1` once, so the bridge starts hidden every time you log in.
2. Order the real parts in [BOM.md](BOM.md), and have your friend print the case (see [README.md](README.md)).
3. Upload the **final** build to the same board.

## Not working?

| Problem | Fix |
|---------|-----|
| `bridge.py --console` never says "connected" | Check the board shows up: `.venv\Scripts\python.exe bridge.py --ports` should list a port with `0x303a`. If not, try another cable. |
| "Another bridge is already running" | One started earlier. End `pythonw.exe` in Task Manager, or just use that one; its log is `bridge.log`. |
| Press does nothing, but the console shows `TOGGLE` | The Timer app isn't running. The bridge will start it, which takes about 2 s the first time. |
| Upload fails every time | Hold BOOT, tap RST, release BOOT, then upload. |
