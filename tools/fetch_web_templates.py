"""Fetch Godot's web export templates without downloading the whole pack.

    python3 tools/fetch_web_templates.py                 # list what is there
    python3 tools/fetch_web_templates.py <template-dir>  # extract into it

Godot refuses to export for web unless it finds templates for the EXACT engine
version. 4.7 templates do not satisfy a 4.7.2 editor, and the error names the
path it wanted. The official pack is a 1.28 GB .tpz covering every platform.

It is also a ZIP, so its central directory can be read over HTTP range
requests and only the web members pulled: 88 MB instead of 1.28 GB. Change URL
when the engine version moves.

On Linux the templates live in ~/.local/share/godot/export_templates/<version>/.
Check that version.txt in there matches the engine, or the export succeeds and
the build fails at runtime instead.
"""
import io, sys, zipfile, urllib.request

URL = ("https://github.com/godotengine/godot/releases/download/"
       "4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz")

class HttpFile(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        self.pos = 0
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req) as r:
            self.size = int(r.headers["Content-Length"])
            self.url = r.geturl()
        self.fetched = 0
    def seekable(self): return True
    def readable(self): return True
    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1
                                            else self.size + off)
        return self.pos
    def tell(self): return self.pos
    def read(self, n=-1):
        if n < 0:
            n = self.size - self.pos
        if n == 0:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        self.fetched += len(data)
        self.pos += len(data)
        return data

hf = HttpFile(URL)
zf = zipfile.ZipFile(hf)
want = [i for i in zf.infolist() if "/web" in i.filename or
        i.filename.endswith("version.txt")]
print(f"  archive {hf.size/1e9:.2f} GB, {len(zf.infolist())} members")
print()
for i in want:
    print(f"  {i.filename:52s} {i.compress_size/1e6:8.1f} MB")
print()
print(f"  central directory cost {hf.fetched/1e6:.2f} MB to read")

if len(sys.argv) > 1:
    out = sys.argv[1]
    total = 0
    for i in want:
        data = zf.read(i)
        name = i.filename.split("/")[-1]
        with open(f"{out}/{name}", "wb") as f:
            f.write(data)
        total += len(data)
        print(f"  wrote {name} ({len(data)/1e6:.1f} MB)")
    print(f"  {total/1e6:.1f} MB extracted, {hf.fetched/1e6:.1f} MB transferred")
