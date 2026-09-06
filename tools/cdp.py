"""A minimal Chrome DevTools Protocol client: boot the web build in a real
browser, wait for the engine to start, press keys, screenshot.

Hand-written because no websocket library was installed, and one page of
RFC 6455 is cheaper than a dependency. Used by web_smoke.py.

The reason it exists: the web build cannot be checked by reasoning about it.
Godot exports cleanly and then the page is blank, or the canvas letterboxes
wrongly, or a glyph the desktop renders from a system font arrives as an empty
box because a browser has no system font to fall back on. All three happened
here. This drives an actual browser and looks at the result.
"""
import base64, json, os, socket, struct, sys, time, urllib.request

class WS:
    def __init__(self, url):
        _, rest = url.split("://", 1)
        hostport, path = rest.split("/", 1)
        host, port = hostport.split(":")
        self.s = socket.create_connection((host, int(port)))
        self.s.settimeout(90)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((
            f"GET /{path} HTTP/1.1\r\nHost: {hostport}\r\n"
            f"Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        ).encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            buf += self.s.recv(4096)
        assert b"101" in buf.split(b"\r\n")[0], buf[:200]
        self.buf = buf.split(b"\r\n\r\n", 1)[1]
        self.next_id = 0

    def _recv(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(65536)
            if not chunk:
                raise EOFError
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def send(self, method, **params):
        self.next_id += 1
        payload = json.dumps({"id": self.next_id, "method": method,
                              "params": params}).encode()
        mask = os.urandom(4)
        n = len(payload)
        head = b"\x81"
        if n < 126:
            head += bytes([0x80 | n])
        elif n < 65536:
            head += b"\xfe" + struct.pack(">H", n)
        else:
            head += b"\xff" + struct.pack(">Q", n)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.s.sendall(head + mask + masked)
        return self.next_id

    def _frame(self):
        b0, b1 = self._recv(2)
        n = b1 & 0x7F
        if n == 126:
            n = struct.unpack(">H", self._recv(2))[0]
        elif n == 127:
            n = struct.unpack(">Q", self._recv(8))[0]
        return b0 & 0x80, b0 & 0x0F, self._recv(n)

    def message(self):
        fin, op, data = self._frame()
        while not fin:
            fin, _, more = self._frame()
            data += more
        if op == 0x8:
            raise EOFError("closed")
        return json.loads(data)

    def call(self, method, **params):
        want = self.send(method, **params)
        while True:
            m = self.message()
            # A beforeunload handler blocks navigation on a modal dialog. Accept
            # it, the way a player clicking "leave" would -- and record that it
            # fired, because the dialog appearing IS the guard working.
            if m.get("method") == "Page.javascriptDialogOpening":
                self.dialogs = getattr(self, "dialogs", 0) + 1
                self.send("Page.handleJavaScriptDialog", accept=True)
                continue
            if m.get("id") == want:
                if "error" in m:
                    raise RuntimeError(m["error"])
                return m.get("result", {})

def attach(port):
    for _ in range(40):
        try:
            pages = json.load(urllib.request.urlopen(
                f"http://127.0.0.1:{port}/json/list"))
            for p in pages:
                if p.get("type") == "page" and p.get("webSocketDebuggerUrl"):
                    return WS(p["webSocketDebuggerUrl"])
        except Exception:
            pass
        time.sleep(0.5)
    raise SystemExit("could not attach to the browser")

def key(ws, code, keycode, text=None):
    for kind in ("keyDown", "keyUp"):
        p = {"type": kind, "code": code, "key": text or code,
             "windowsVirtualKeyCode": keycode, "nativeVirtualKeyCode": keycode}
        if text and kind == "keyDown":
            p["text"] = text
        ws.call("Input.dispatchKeyEvent", **p)
        time.sleep(0.04)

def shot(ws, path):
    r = ws.call("Page.captureScreenshot", format="png")
    open(path, "wb").write(base64.b64decode(r["data"]))
    return path
