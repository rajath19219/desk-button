"""Render the firmware's real screens on the PC, as pictures.

Compiles src/main.cpp's drawScreen() together with the real U8g2 library for the PC (with Zig's
C++ compiler), runs it for a few situations (recording, ready, offline, ...), and saves:
    preview/screens/<display>_<situation>.png   the bare screen, enlarged
    preview/look_<situation>.png                the screen on the finished desk button (front view)
    preview/look_prototype.png                  the 0.96" prototype screen

Needs: the U8g2 library downloaded by PlatformIO (build the firmware once), and
    pip install pillow ziglang
Run:   python firmware/host-preview/render.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
FW = HERE.parent
OUT = FW.parent / "preview"
BUILD = HERE / "build"


def find_u8g2() -> Path:
    for p in sorted((FW / ".pio" / "libdeps").glob("*/U8g2")):
        if (p / "src" / "clib" / "u8g2.h").exists():
            return p / "src"
    sys.exit("U8g2 not found: build the firmware once with PlatformIO first (it downloads the library).")


def zig(*args: str) -> None:
    subprocess.run([sys.executable, "-m", "ziglang", *args], check=True)


def build(src: Path, kind: int) -> Path:
    BUILD.mkdir(exist_ok=True)
    flags = ["-O1", f"-I{src}", f"-I{src / 'clib'}"]
    objs = []
    for c in sorted((src / "clib").glob("*.c")):
        o = BUILD / (c.stem + ".o")
        if not o.exists() or o.stat().st_mtime < c.stat().st_mtime:
            zig("cc", "-c", *flags, str(c), "-o", str(o))
        objs.append(str(o))
    exe = BUILD / f"preview_{kind}.exe"
    zig("c++", "-std=c++17", *flags, f"-I{HERE}", f"-DDISPLAY_KIND={kind}", "-Wno-everything",
        str(HERE / "harness.cpp"), *objs, "-o", str(exe))
    return exe


def run(exe: Path) -> dict[str, list[str]]:
    screens, cur = {}, None
    for line in subprocess.run([str(exe)], capture_output=True, text=True, check=True).stdout.splitlines():
        if line.startswith("SCREEN "):
            cur = line.split()[1]
            screens[cur] = []
        elif cur:
            screens[cur].append(line)
    return screens


# ------------------------------------------------------------------ drawing helpers
PIXEL = (238, 238, 230)


def oled_layer(rows: list[str], px: int, color=PIXEL) -> Image.Image:
    """Lit pixels as small squares with a soft glow, on a transparent background."""
    w, h = len(rows[0]), len(rows)
    sharp = Image.new("RGBA", (w * px, h * px), (0, 0, 0, 0))
    d = ImageDraw.Draw(sharp)
    gap = 1 if px >= 3 else 0
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "1":
                d.rectangle([x * px, y * px, x * px + px - 1 - gap, y * px + px - 1 - gap], fill=color + (255,))
    glow = sharp.filter(ImageFilter.GaussianBlur(px * 1.2))
    glow.putalpha(glow.getchannel("A").point(lambda a: int(a * 0.45)))
    out = Image.new("RGBA", sharp.size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(sharp)
    return out


def bare_screen(rows: list[str], px: int) -> Image.Image:
    layer = oled_layer(rows, px)
    img = Image.new("RGBA", (layer.width + 2 * px * 4, layer.height + 2 * px * 4), (8, 8, 9, 255))
    img.alpha_composite(layer, (px * 4, px * 4))
    return img.convert("RGB")


def vgrad(size, top, bottom) -> Image.Image:
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return g.resize((w, h))


def rounded(size, r, fill_img: Image.Image) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], r, fill=255)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(fill_img, (0, 0), mask)
    return out


def device(rows: list[str]) -> Image.Image:
    """Front view of the finished desk button at 10 px/mm, with the real screen in the panel."""
    S = 10
    W, H = 132 * S, 56 * S
    m = 90
    img = Image.new("RGBA", (W + 2 * m, H + 2 * m + 40), (243, 243, 240, 255))
    bx, by = m, m + 30
    # shadow on the desk
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([bx - 20, by + H - 10, bx + W + 20, by + H + 40], fill=(0, 0, 0, 90))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(18)))
    # press bar (3 mm proud), body, feet
    bar = rounded((104 * S, 60), 22, vgrad((104 * S, 60), (52, 52, 56), (20, 20, 22)))
    img.alpha_composite(bar, (bx + (W - 104 * S) // 2, by - 30))
    img.alpha_composite(rounded((W, H), 3 * S, vgrad((W, H), (240, 240, 236), (214, 214, 209))), (bx, by))
    d = ImageDraw.Draw(img)
    for fx in (16, 132 - 16 - 10):
        d.rounded_rectangle([bx + fx * S, by + H, bx + (fx + 10) * S, by + H + 2 * S], 6, fill=(70, 70, 70))
    # black screen panel 121 x 45
    pw, ph = 121 * S, 45 * S
    px0, py0 = bx + (W - pw) // 2, by + (H - ph) // 2
    img.alpha_composite(rounded((pw, ph), 5 * S, vgrad((pw, ph), (24, 24, 27), (12, 12, 13))), (px0, py0))
    # OLED pixels: 256 x 64 over the 76.8 x 19.2 mm active area -> 3 px each
    layer = oled_layer(rows, 3)
    img.alpha_composite(layer, (bx + (W - layer.width) // 2, by + (H - layer.height) // 2))
    # faint reflection across the panel
    refl = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    ImageDraw.Draw(refl).polygon([(0, 0), (pw * 0.42, 0), (pw * 0.22, ph), (0, ph)], fill=(255, 255, 255, 10))
    img.alpha_composite(refl, (px0, py0))
    return img.convert("RGB")


def proto_module(rows: list[str]) -> Image.Image:
    """A 0.96" OLED module (blue board, black glass) showing the real prototype screen."""
    px = 3
    layer = oled_layer(rows, px)
    gw, gh = layer.width + 40, layer.height + 70
    bw, bh = gw + 60, gh + 110
    img = Image.new("RGBA", (bw + 120, bh + 120), (243, 243, 240, 255))
    ox, oy = 60, 60
    img.alpha_composite(rounded((bw, bh), 14, vgrad((bw, bh), (32, 92, 168), (20, 66, 128))), (ox, oy))
    d = ImageDraw.Draw(img)
    for hx, hy in ((ox + 18, oy + 18), (ox + bw - 18, oy + 18), (ox + 18, oy + bh - 18), (ox + bw - 18, oy + bh - 18)):
        d.ellipse([hx - 9, hy - 9, hx + 9, hy + 9], fill=(243, 243, 240))
    for i, name in enumerate(("GND", "VCC", "SCL", "SDA")):
        cx = ox + bw // 2 + (i - 1.5) * 34
        d.ellipse([cx - 9, oy + 22, cx + 9, oy + 40], fill=(210, 180, 90))
        d.text((cx - 10, oy + 46), name, fill=(230, 235, 245))
    gx, gy = ox + (bw - gw) // 2, oy + 80
    d.rectangle([gx, gy, gx + gw, gy + gh], fill=(10, 10, 11))
    img.alpha_composite(layer, (gx + 20, gy + 26))
    return img.convert("RGB")


def main() -> None:
    src = find_u8g2()
    (OUT / "screens").mkdir(parents=True, exist_ok=True)
    wide = run(build(src, 2))
    small = run(build(src, 1))
    for name, rows in wide.items():
        bare_screen(rows, 4).save(OUT / "screens" / f"final_{name}.png")
    for name, rows in small.items():
        bare_screen(rows, 5).save(OUT / "screens" / f"proto_{name}.png")
    for name in ("recording", "ready", "offline"):
        device(wide[name]).save(OUT / f"look_{name}.png")
    proto_module(small["recording"]).save(OUT / "look_prototype.png")
    print("saved to", OUT)


if __name__ == "__main__":
    main()
