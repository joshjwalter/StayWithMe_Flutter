import time
import urllib.request
import sys

ok = False
for _ in range(30):
    try:
        r = urllib.request.urlopen('http://127.0.0.1:54010/health', timeout=1)
        ok = (getattr(r, 'status', None) == 200)
        r.close()
        if ok:
            break
    except Exception:
        time.sleep(1)

if not ok:
    sys.exit('server did not become healthy in time')
