#!/usr/bin/env python3
"""Screenshot a Steam UI page through CEF DevTools (start Steam with -cef-enable-debugging).

Useful for debugging a black Steam window: it shows what Chromium rendered internally.
usage: cefshot.py <out.png> [title substring] [port]
"""
import base64, json, os, socket, struct, sys, urllib.request

out = sys.argv[1]
want = sys.argv[2].lower() if len(sys.argv) > 2 else ""
port = int(sys.argv[3]) if len(sys.argv) > 3 else 8080

targets = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=5))
for t in targets:
    print("target:", t.get("type"), "|", t.get("title"), "|", t.get("url", "")[:70])
pages = [t for t in targets if t.get("type") == "page" and want in t.get("title", "").lower()]
if not pages:
    sys.exit("no matching page")
ws_url = pages[0]["webSocketDebuggerUrl"]
path = "/" + ws_url.split("/", 3)[3]

s = socket.create_connection(("127.0.0.1", port), timeout=20)
key = base64.b64encode(os.urandom(16)).decode()
s.sendall((f"GET {path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
           f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
buf = b""
while b"\r\n\r\n" not in buf:
    buf += s.recv(4096)
buf = buf.split(b"\r\n\r\n", 1)[1]


def send(obj):
    data = json.dumps(obj).encode()
    mask = os.urandom(4)
    n = len(data)
    head = b"\x81" + (bytes([0x80 | n]) if n < 126 else b"\xfe" + struct.pack(">H", n))
    s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))


def need(n):
    global buf
    while len(buf) < n:
        chunk = s.recv(65536)
        if not chunk:
            sys.exit("connection closed")
        buf += chunk
    r, buf = buf[:n], buf[n:]
    return r


def recv():
    msg = b""
    while True:
        b0, b1 = need(2)
        n = b1 & 0x7F
        if n == 126:
            n = struct.unpack(">H", need(2))[0]
        elif n == 127:
            n = struct.unpack(">Q", need(8))[0]
        payload = need(n)
        if b0 & 0x0F in (0, 1, 2):
            msg += payload
            if b0 & 0x80:
                return json.loads(msg)


def call(i, method, params=None):
    send({"id": i, "method": method, "params": params or {}})
    while True:
        m = recv()
        if m.get("id") == i:
            return m


r = call(1, "Runtime.evaluate", {"expression": "document.title + ' | ' + document.body.innerText.slice(0,200)"})
print("dom:", r.get("result", {}).get("result", {}).get("value"))
r = call(2, "Page.captureScreenshot", {"format": "png"})
if "result" not in r:
    sys.exit(f"captureScreenshot: {r}")
open(out, "wb").write(base64.b64decode(r["result"]["data"]))
print("saved", out)
