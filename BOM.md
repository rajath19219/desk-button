# Parts list

Prices are rough (late 2026, INR) and move around. Robu.in, Amazon.in and the Indian keyboard shops deliver in a few days. AliExpress is roughly half the price but takes 2–4 weeks. Search terms are given instead of exact links because listings change often.

| # | Part | Qty | ≈ India (Robu / Amazon.in / Meckeys) | ≈ AliExpress | Search for |
|---|------|-----|-----|-----|-----|
| 1 | **ESP32-C3 SuperMini** board (USB-C) | 1 | ₹250–350 | ₹150–200 | `ESP32-C3 SuperMini` |
| 2 | **3.12" OLED, 256×64, SSD1322, SPI** module, white (or yellow) | 1 | ₹1,600–2,600 | ₹900–1,300 | `3.12 inch OLED 256x64 SSD1322` |
| 3 | **Kailh Choc v1 clicky switch**: *Jade* (crisp, firm) or *White* (lighter) | 1 (comes in packs of 10) | ₹400–700 / 10 at Meckeys or StacksKB | ₹250–400 / 10 | `Kailh Choc Jade` |
| 4 | Silicone hook-up wire, 26–28 AWG, a few colours | ~1 m | ₹100 | ₹80 | `28 AWG silicone wire` |
| 5 | Heat-shrink tube, small assortment | 1 | ₹80 | ₹60 | `heat shrink assortment` |
| 6 | M3 × 8 countersunk (flat-head) **self-tapping** screws (back cover) | 4 | ₹60 (pack) | ₹40 | `M3 countersunk self tapping` |
| 7 | M3 × 10 pan-head self-tapping screws (bar hinge) | 2 | (same pack family) | | `M3 pan head self tapping` |
| 8 | M2 × 8 pan-head self-tapping screws (screen clamps) | 4 | ₹60 (pack) | ₹40 | `M2 self tapping screw` |
| 9 | Rubber bumper feet, Ø10 mm × 3 mm, self-adhesive | 4 | ₹60–100 | ₹50 | `rubber bumper feet 10mm` |
| 10 | USB-C **data** cable (not a charge-only one) | 1 | you probably have one | | |
| 11 | Filament: ~110 g **white/light grey** PLA or PETG (body, back) + ~30 g **black** (screen panel, bar) | | friend's spools | | |

**Total ≈ ₹2,600–3,800** from Indian shops (≈ ₹1,500–2,000 from AliExpress), plus filament. The OLED is most of it.

**OLED buying tips:**
- Pick a listing that says **SPI** (most are "4-wire SPI by default").
- White text on black looks the cleanest; yellow is a nice retro alternative.
- When it arrives, measure the glass and the board. The model assumes a glass of 88 × 27.8 mm and a board of 100.5 × 33.5 mm.

Tools: soldering iron, solder, small side cutters, and a hot-glue gun (optional, for strain relief).

## Why the ESP32-C3 SuperMini

- **Plugs straight into USB-C** and shows up as a normal COM port on Windows 10/11, with no driver and no separate USB-serial chip.
- **Tiny** (22.5 × 18 mm), and one of the cheapest boards in India.
- **Wi-Fi and Bluetooth are built in**, so a cordless version later needs new firmware, not a new board.

An **RP2040-Zero** would work just as well over USB only, but it has no wireless. An **ESP32-S3** is more board than this needs.

## Why this screen and switch

- **3.12" 256×64 OLED:** it's the wide, letterbox-shaped screen in your sketch. Unlit pixels are truly black, so behind the black front panel the whole panel looks like one screen. It's monochrome, so recording is shown with a REC dot and a running clock rather than a colour. The firmware nudges the picture by a pixel each minute and dims when idle, so it won't burn in.
- **Kailh Choc switch under a hinged bar:** you can press the bar anywhere and it clicks like a good keyboard. The hinge keeps a long bar from rocking, which a bar sitting on one switch would do.

## Optional extras (for the stretch ideas)

| Part | ≈ Price | For |
|------|---------|-----|
| LiPo 3.7 V 500–1000 mAh + TP4056 USB-C charger board | ₹250–400 | cordless Bluetooth version |
| Coin vibration motor + small NPN transistor + diode | ₹60 | haptic "thunk" on press |
