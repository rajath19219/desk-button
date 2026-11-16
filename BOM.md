# Parts list

Prices are rough (late 2026, INR) and move around. Robu.in and Amazon.in deliver in a few days; AliExpress is roughly half the price but takes 2–4 weeks. Search terms are given instead of exact links because listings change often.

| # | Part | Qty | ≈ Robu / Amazon.in | ≈ AliExpress | Search for |
|---|------|-----|-----|-----|-----|
| 1 | **ESP32-C3 SuperMini** board (USB-C) | 1 | ₹250–350 | ₹150–200 | `ESP32-C3 SuperMini` |
| 2 | **1.28" round TFT, GC9A01, 240×240, SPI** (module with pins, not the bare screen) | 1 | ₹550–700 | ₹280–380 | `1.28 inch round TFT GC9A01` |
| 3 | **WS2812B 16-LED RGB ring, 44 mm** (outer ≈ 44.5 mm, inner ≈ 31.75 mm) | 1 | ₹150–220 | ₹70–120 | `WS2812 16 bit RGB LED ring` |
| 4 | **30 mm arcade push button, screw-nut type, with microswitch** (red or white) | 1 (+1 spare) | ₹60–150 | ₹40–80 | `30mm arcade button` |
| 5 | Resistor 330 Ω, ¼ W | 1 | ₹5 | — | any |
| 6 | Silicone hook-up wire, 26–28 AWG, a few colours | ~1 m | ₹100 | ₹80 | `28 AWG silicone wire` |
| 7 | Heat-shrink tube, small assortment | 1 | ₹80 | ₹60 | `heat shrink assortment` |
| 8 | M3 × 8 countersunk (flat-head) **self-tapping** screws | 4 | ₹60 (pack) | ₹40 | `M3 countersunk self tapping` |
| 9 | M2 × 8 pan-head self-tapping screws | 4 | ₹60 (pack) | ₹40 | `M2 self tapping screw` |
| 10 | Rubber bumper feet, Ø10 mm × 3 mm, self-adhesive | 4 | ₹60–100 | ₹50 | `rubber bumper feet 10mm` |
| 11 | USB-C **data** cable (not a charge-only one) | 1 | you probably have one | | |
| 12 | Filament: ~90 g dark PLA/PETG (body) + ~10 g **white or natural** PETG/PLA (light ring) | | friend's spool | | |

**Total ≈ ₹1,400–1,900** from Indian shops (≈ ₹800–1,100 from AliExpress), plus filament.

Buy the arcade button as the **screw-nut** kind: the light ring and LED ring add up to ~7.5 mm of "panel", which is too thick for snap-in buttons. For a nicer click, a Sanwa OBSF-30 (~₹300–400) also fits, but it's a snap-in, so it needs the halo made thinner (`halo_t`) — skip unless you care.

Tools: soldering iron, solder, small side cutters, a hot-glue gun (optional, for strain relief).

## Why the ESP32-C3 SuperMini

- **Plugs straight into USB-C** and shows up as a normal COM port on Windows 10/11 — no driver, no separate USB-serial chip.
- **Tiny** (22.5 × 18 mm), so the case stays small, and it's one of the cheapest boards you can buy in India.
- **Wi-Fi + Bluetooth built in**, so a cordless battery version later needs new firmware, not a new board.
- Enough pins for the display (6), LED ring (1) and button (1), with spares.

Alternatives, briefly: an **RP2040-Zero** works just as well for USB-only, but has no wireless; an **ESP32-S3** is more board than this needs and costs more.

## Optional extras (for the stretch ideas)

| Part | ≈ Price | For |
|------|---------|-----|
| LiPo 3.7 V 500–1000 mAh + TP4056 USB-C charger board | ₹250–400 | cordless Bluetooth version |
| Coin vibration motor + 2N7000 / small NPN + diode | ₹60 | haptic "thunk" on press |
