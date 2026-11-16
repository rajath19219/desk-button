"""Desk Button bridge: connects the USB desk button to the Simple Timer app.

- Finds the button's COM port by itself (ESP32-C3 USB id 303A, confirmed with a "?" -> "HELLO" handshake).
- Button "TOGGLE" -> sets the Timer's Local\\SimpleTimerToggle event (or launches timer.py --toggle if
  the Timer isn't running). Button "SHOW" (long press) -> opens the Timer window.
- About once a second sends the timer state to the button's display:  S <running> <elapsed_s> <today_s> <app>
  The state is read from the Timer's SQLite database, read-only. The Timer itself is never modified.

Usage:
    pythonw bridge.py           run in the background (what the Startup shortcut does)
    python  bridge.py --status  print what would be sent to the button, then exit (no button needed)
    python  bridge.py --ports   list serial ports
"""
from __future__ import annotations

import ctypes
import ctypes.wintypes as wt
import logging
import os
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timedelta
from logging.handlers import RotatingFileHandler
from pathlib import Path

HERE = Path(__file__).resolve().parent
TIMER_DIR = HERE.parent / "simple-timer"
TIMER_PY = TIMER_DIR / "timer.py"
TIMER_PYTHONW = TIMER_DIR / ".venv" / "Scripts" / "pythonw.exe"

EVENT_TOGGLE = "Local\\SimpleTimerToggle"
EVENT_SHOW = "Local\\SimpleTimerShow"
TIMER_MUTEX = "Local\\SimpleTimerSingleInstance"
BRIDGE_MUTEX = "Local\\DeskButtonBridge"
ESPRESSIF_VID = 0x303A
BAUD = 115200
FMT = "%Y-%m-%d %H:%M:%S"

log = logging.getLogger("bridge")
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
kernel32.OpenEventW.restype = wt.HANDLE
kernel32.OpenMutexW.restype = wt.HANDLE
kernel32.CreateMutexW.restype = wt.HANDLE


# ------------------------------------------------------------------ talking to the Timer app

def _open_event(name: str):
    return kernel32.OpenEventW(0x0002, False, name)  # EVENT_MODIFY_STATE


def timer_running() -> bool:
    h = kernel32.OpenMutexW(0x00100000, False, TIMER_MUTEX)  # SYNCHRONIZE
    if h:
        kernel32.CloseHandle(h)
        return True
    return False


def _signal(name: str, fallback_args: list[str]) -> None:
    h = _open_event(name)
    if h:
        kernel32.SetEvent(h)
        kernel32.CloseHandle(h)
        log.info("signalled %s", name)
        return
    # Timer isn't running: start it (with --toggle it starts recording right away)
    exe = TIMER_PYTHONW if TIMER_PYTHONW.exists() else Path(sys.executable).with_name("pythonw.exe")
    log.info("Timer not running; launching %s %s", TIMER_PY.name, " ".join(fallback_args))
    subprocess.Popen([str(exe), str(TIMER_PY), *fallback_args], cwd=str(TIMER_DIR),
                     creationflags=0x00000008 | 0x00000200)  # DETACHED_PROCESS | NEW_PROCESS_GROUP


def toggle() -> None:
    _signal(EVENT_TOGGLE, ["--toggle"])


def show() -> None:
    _signal(EVENT_SHOW, [])


# ------------------------------------------------------------------ reading the Timer's database

def find_db() -> Path | None:
    """The Timer runs on Microsoft Store Python, which redirects %APPDATA% writes into its package
    folder. Look in both places and use whichever database was written most recently."""
    candidates = []
    if os.environ.get("APPDATA"):
        candidates.append(Path(os.environ["APPDATA"]) / "SimpleTimer" / "timer.db")
    pkgs = Path(os.environ.get("LOCALAPPDATA", "")) / "Packages"
    if pkgs.is_dir():
        candidates += pkgs.glob("PythonSoftwareFoundation.Python.*/LocalCache/Roaming/SimpleTimer/timer.db")

    def mtime(p: Path) -> float:
        return max((q.stat().st_mtime for q in (p, p.with_name(p.name + "-wal")) if q.exists()), default=0)

    existing = [p for p in candidates if p.exists()]
    return max(existing, key=mtime) if existing else None


def _parse(s: str) -> datetime:
    return datetime.strptime(s, FMT)


def read_status() -> tuple[bool, int, int, str]:
    """(running, elapsed seconds, today's total seconds, current app)"""
    path = find_db()
    if not path:
        return False, 0, 0, ""
    now = datetime.now()
    alive = timer_running()
    db = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True, timeout=2)
    try:
        cur = db.execute("SELECT id, start FROM sessions WHERE end IS NULL ORDER BY id DESC LIMIT 1").fetchone()
        running = bool(cur) and alive   # an unfinished row with no Timer process is a crash leftover
        elapsed = int((now - _parse(cur[1])).total_seconds()) if running else 0

        app = ""
        if running:
            row = db.execute("SELECT app FROM segments WHERE session_id=? ORDER BY end DESC, id DESC LIMIT 1",
                             (cur[0],)).fetchone()
            app = row[0] if row else ""

        day0 = datetime(now.year, now.month, now.day)
        day1 = day0 + timedelta(days=1)
        today = 0.0
        for start, end, last_seen in db.execute(
                "SELECT start, end, last_seen FROM sessions WHERE start < ? AND (end IS NULL OR end > ?)",
                (day1.strftime(FMT), day0.strftime(FMT))):
            a = _parse(start)
            b = _parse(end) if end else (now if alive else _parse(last_seen or start))
            today += max(0.0, (min(b, day1) - max(a, day0)).total_seconds())
        return running, max(0, elapsed), int(today), app
    finally:
        db.close()


def status_line() -> str:
    running, elapsed, today, app = read_status()
    # the display's built-in font is plain ASCII
    app = app.encode("ascii", "replace").decode().replace("\n", " ").strip()[:30]
    return f"S {int(running)} {elapsed} {today} {app}"


# ------------------------------------------------------------------ serial connection

def open_button():
    import serial
    from serial.tools import list_ports

    for p in list_ports.comports():
        if p.vid != ESPRESSIF_VID:   # only ESP32 USB ports; never poke other serial devices
            continue
        try:
            ser = serial.Serial()
            ser.port, ser.baudrate, ser.timeout = p.device, BAUD, 0.1
            ser.dtr, ser.rts = True, False   # don't pulse the ESP32's reset line
            ser.open()
        except (serial.SerialException, OSError):
            continue
        try:
            ser.reset_input_buffer()
            deadline = time.monotonic() + 2.5
            while time.monotonic() < deadline:
                ser.write(b"?\n")
                line = ser.readline().decode(errors="ignore").strip()
                if line.startswith("HELLO desk-button"):
                    log.info("connected to desk button on %s", p.device)
                    return ser
            ser.close()
        except (serial.SerialException, OSError):
            ser.close()
    return None


def run() -> None:
    import serial

    ser, last_scan = None, 0.0
    while True:
        if ser is None:
            if time.monotonic() - last_scan < 3:
                time.sleep(0.5)
                continue
            last_scan = time.monotonic()
            ser = open_button()
            if ser is None:
                continue
            next_status = 0.0
        try:
            if time.monotonic() >= next_status:
                ser.write((status_line() + "\n").encode())
                next_status = time.monotonic() + 1.0
            line = ser.readline().decode(errors="ignore").strip()
            if line:
                log.info("button says: %s", line)
            if line == "TOGGLE":
                toggle()
                next_status = time.monotonic() + 0.4   # let the Timer write, then refresh the display
            elif line == "SHOW":
                show()
        except (serial.SerialException, OSError) as e:
            log.info("button disconnected (%s)", e)
            try:
                ser.close()
            except Exception:
                pass
            ser = None
        except Exception:
            log.exception("unexpected error")
            time.sleep(1)


def main() -> None:
    args = sys.argv[1:]
    if "--status" in args:
        print("database:", find_db())
        print("timer running:", timer_running())
        print(status_line())
        return
    if "--ports" in args:
        from serial.tools import list_ports
        for p in list_ports.comports():
            print(p.device, hex(p.vid) if p.vid else "-", p.description)
        return

    console = "--console" in args   # for testing: show everything in this window
    kernel32.CreateMutexW(None, False, BRIDGE_MUTEX)
    if ctypes.get_last_error() == 183:   # already running
        if console:
            print("Another bridge is already running (check Task Manager for pythonw.exe). Close it first.")
        return
    handlers = [RotatingFileHandler(HERE / "bridge.log", maxBytes=200_000, backupCount=1, encoding="utf-8")]
    if console:
        handlers.append(logging.StreamHandler(sys.stdout))
        print("Bridge running. Plug in the button and press it. Ctrl+C to stop.")
    logging.basicConfig(handlers=handlers, level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
    log.info("bridge started; database %s", find_db())
    run()


if __name__ == "__main__":
    main()
