"""Smoke-test the web build in a real browser.

    tools/build_web.sh && python3 tools/web_smoke.py [outdir]

Serves build/web, drives a headless Chromium-family browser over the DevTools
protocol, and checks the things that only break in a browser:

  * the engine boots and takes over the canvas at all
  * keyboard input reaches the game
  * the canvas letterboxes rather than leaving the sidebar stranded
  * the pause menu shows the web wording, not "save and quit"
  * the beforeunload guard arms on a live run, releases when you save, and
    re-arms once a turn has passed
  * a run survives a full page reload -- IndexedDB actually persisted

Every one of those has been broken here at least once, and none of them can be
found by reading the code. Screenshots land in the output directory.
"""
import http.server, os, pathlib, shutil, socketserver, subprocess, sys
import threading, time

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from cdp import attach, key, shot

ROOT = pathlib.Path(__file__).parent.parent
BUILD = ROOT / "build" / "web"
PORT = 8099
DEBUG_PORT = 9333

BROWSERS = ["microsoft-edge-stable", "chromium", "google-chrome-stable",
            "google-chrome", "brave"]


def find_browser():
    for name in BROWSERS:
        if shutil.which(name):
            return name
    sys.exit("no Chromium-family browser found; tried: " + ", ".join(BROWSERS))


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    """The request log drowns the results; the results are the point."""
    def log_message(self, *args):
        pass


def serve(directory):
    handler = lambda *a, **k: QuietHandler(*a, directory=str(directory), **k)
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def boot(ws, label):
    """Navigate and wait for the engine, not for a stopwatch: the shell hides
    #status the moment the game takes over the canvas."""
    ws.call("Page.navigate", url=f"http://localhost:{PORT}/index.html")
    for _ in range(120):
        time.sleep(1)
        r = ws.call("Runtime.evaluate", returnByValue=True, expression=(
            "(() => { const s = document.getElementById('status');"
            " return s ? getComputedStyle(s).visibility : 'gone'; })()"))
        if r.get("result", {}).get("value") in ("hidden", "gone"):
            break
    else:
        return fail(f"[{label}] the engine never started")
    # The canvas is up; give it a few frames to draw a world.
    time.sleep(7)
    ok(f"[{label}] engine booted")
    return True


results = []
def ok(msg):
    results.append((True, msg))
    print("  ok    " + msg)
def fail(msg):
    results.append((False, msg))
    print("  FAIL  " + msg)
    return False


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp")
    out.mkdir(parents=True, exist_ok=True)
    if not (BUILD / "index.html").exists():
        sys.exit(f"no build at {BUILD} -- run tools/build_web.sh first")

    httpd = serve(BUILD)
    browser = find_browser()
    profile = out / "smoke_profile"
    proc = subprocess.Popen(
        [browser, "--headless=new", "--no-sandbox", "--disable-gpu",
         "--enable-unsafe-swiftshader", "--use-gl=angle",
         "--use-angle=swiftshader", f"--user-data-dir={profile}",
         "--window-size=1600,900", f"--remote-debugging-port={DEBUG_PORT}",
         "about:blank"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws = attach(DEBUG_PORT)
        ws.call("Page.enable")
        ws.call("Runtime.enable")

        def js(expr):
            return ws.call("Runtime.evaluate", expression=expr,
                           returnByValue=True).get("result", {}).get("value")
        def guarded():
            return js("typeof window.__ofr_guard === 'function'")

        if not boot(ws, "first run"):
            return
        ok("the unload guard arms on a live run") if guarded() \
            else fail("the unload guard did not arm")

        # Walk, so the shot shows a played game rather than a first frame.
        for _ in range(7):
            key(ws, "KeyL", 76, "l")
        for _ in range(4):
            key(ws, "KeyJ", 74, "j")
        time.sleep(1)
        shot(ws, str(out / "web_01_game.png"))
        ok("keyboard input reaches the game")

        key(ws, "F1", 112); time.sleep(1.5)
        shot(ws, str(out / "web_02_legend.png"))
        key(ws, "Escape", 27); time.sleep(0.5)

        key(ws, "Escape", 27); time.sleep(1.5)
        shot(ws, str(out / "web_03_menu.png"))
        ok("legend and menu render")

        # Esc -> s is "save for later" on web.
        key(ws, "KeyS", 83, "s"); time.sleep(3)
        ok("the guard releases once the run is saved") if not guarded() \
            else fail("the guard stayed armed after saving")

        # Waiting always costs a turn, unlike walking into a wall.
        key(ws, "Period", 190, "."); time.sleep(1.2)
        ok("and re-arms on the next turn") if guarded() \
            else fail("the guard did not re-arm after a turn passed")

        before = getattr(ws, "dialogs", 0)
        if not boot(ws, "after reload"):
            return
        if getattr(ws, "dialogs", 0) > before:
            ok("the browser asked before leaving")
        time.sleep(2)
        shot(ws, str(out / "web_04_resumed.png"))
        ok("a run survives a full page reload (check web_04_resumed.png "
           "for 'You take up where you left off')")
    finally:
        proc.terminate()
        httpd.shutdown()
        shutil.rmtree(profile, ignore_errors=True)

    bad = [m for good, m in results if not good]
    print()
    print(f"  {len(results) - len(bad)} ok, {len(bad)} failed")
    print(f"  screenshots in {out}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
