# mitmproxy addon — capture traffic HP dengan filter configurable.
# FILTER env: nama domain (mis. "flip.id") = cuma log request ke domain itu secara DETAIL.
#             "all" (default) = log SEMUA request secara detail.
# Output:
#   OUT_DIR/all.txt      -> ringkas SEMUA request (METHOD host/path) — buat lihat endpoint apa aja
#   OUT_DIR/capture.txt  -> DETAIL (header + body request & response) sesuai FILTER
import os
from mitmproxy import http

OUT_DIR = os.environ.get("CAP_OUT", ".")
FILTER = os.environ.get("CAP_FILTER", "all").strip().lower()
ALL = os.path.join(OUT_DIR, "all.txt")
CAP = os.path.join(OUT_DIR, "capture.txt")
MAXBODY = int(os.environ.get("CAP_MAXBODY", "3000"))

def _w(path, s):
    with open(path, "a", encoding="utf-8") as f:
        f.write(s)

def _match(host):
    return FILTER == "all" or FILTER in host.lower()

def request(flow: http.HTTPFlow):
    # ringkas semua (biar keliatan endpoint apa aja yang jalan)
    _w(ALL, flow.request.method + " " + flow.request.host + flow.request.path.split("?")[0] + "\n")
    if _match(flow.request.host):
        L = ["\n===== REQ " + flow.request.method + " " + flow.request.pretty_url]
        for k, v in flow.request.headers.items():
            L.append("H " + k + ": " + v)
        L.append("BODY: " + (flow.request.get_text() or "")[:MAXBODY])
        _w(CAP, "\n".join(L) + "\n")

def response(flow: http.HTTPFlow):
    if _match(flow.request.host):
        body = ""
        try:
            body = flow.response.get_text() or ""
        except Exception:
            body = "<non-text/binary>"
        _w(CAP, "----- RESP " + str(flow.response.status_code) + " " + flow.request.path.split("?")[0] + " -----\n" + body[:MAXBODY] + "\n=====END=====\n")

def load(loader):
    print("[capture] FILTER=%r  OUT_DIR=%r" % (FILTER, OUT_DIR))
