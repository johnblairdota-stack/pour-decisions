"""Reference photos for the mega showcase, per game tower and theme, from Wikimedia Commons (stdlib only).

    python tools/sites/fetch_showcase_photos.py <PourDecisions-sites> [ids]

Run on a machine that can reach commons.wikimedia.org (John's PC; the cloud proxy refuses it). Writes
<out>/showcase_refs/<tower>/<theme>/<file> (1280 px wide) and <out>/showcase_refs/credits.csv. Photos stay
OUT of git. Themes:
    area   the streets and ground level round the site (geosearch 350 m + street names)
    build  the tower itself and its construction
    river  the tower and its bank from the river (the fly-over)
    top    the view from the top / the skyline it looks at (the tower card backdrop)
"""
import csv
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "site-reference-fetch/1.0 (python urllib)"
CAP = {"area": 70, "build": 40, "river": 40, "top": 40}
TOWERS = {
    "riverlight": {"lat": -27.4423, "lon": 153.0747,
                   "area": ["Hamilton Reach Brisbane", "Northshore Hamilton", "MacArthur Avenue Hamilton Queensland"],
                   "build": ["Riverlight Hamilton Brisbane", "Hamilton Reach apartments"],
                   "river": ["Hamilton Reach Brisbane River", "Northshore Hamilton ferry terminal", "Hamilton Brisbane from the river"],
                   "top": ["Gateway Bridge from Hamilton", "Brisbane River Hamilton aerial", "Portside Wharf aerial"]},
    "alcyone": {"lat": -27.43975, "lon": 153.06965,
                "area": ["Portside Wharf Hamilton", "Remora Road Hamilton"],
                "build": ["Alcyone Hotel Residences", "Portside Hamilton apartments"],
                "river": ["Portside Wharf Brisbane River", "Brisbane cruise terminal Hamilton"],
                "top": ["Hamilton Brisbane aerial", "Bretts Wharf Hamilton"]},
    "spire": {"lat": -27.4634, "lon": 153.0310,
              "area": ["Petrie Bight Brisbane", "Queen Street Brisbane Petrie Bight", "Ann Street Brisbane Cathedral Square", "Orient Hotel Brisbane"],
              "build": ["Spire Residences Brisbane", "550 Queen Street Brisbane"],
              "river": ["Customs House Brisbane from river", "Petrie Bight from Brisbane River", "Admiralty Towers Brisbane"],
              "top": ["Story Bridge from Brisbane CBD", "Story Bridge aerial", "Kangaroo Point from Brisbane CBD"]},
    "hsw": {"lat": -27.46279, "lon": 153.03712,
            "area": ["Howard Smith Wharves", "Felons Brewing", "Boundary Street Brisbane cliffs Howard Smith"],
            "build": ["Howard Smith Wharves construction", "Fantauzzo hotel Brisbane"],
            "river": ["Howard Smith Wharves from river", "Story Bridge from Brisbane River", "Howard Smith Wharves ferry"],
            "top": ["Story Bridge from New Farm cliffs", "Wilson Outlook Reserve", "Brisbane from Story Bridge"]},
    "william1": {"lat": -27.4738, "lon": 153.0262,
                 "area": ["William Street Brisbane", "Alice Street Brisbane", "Margaret Street Brisbane", "Riverside Expressway Brisbane"],
                 "build": ["1 William Street Brisbane", "1 William Street Brisbane construction"],
                 "river": ["1 William Street from South Bank", "Brisbane CBD from South Bank", "Brisbane CBD from Goodwill Bridge"],
                 "top": ["South Bank Brisbane aerial", "Brisbane City Botanic Gardens aerial", "Brisbane River from 1 William Street"]},
    "skytower": {"lat": -27.47185, "lon": 153.02874,
                 "area": ["Margaret Street Brisbane", "Mary Street Brisbane", "Albert Street Brisbane", "Felix Street Brisbane"],
                 "build": ["Brisbane Skytower", "Brisbane Skytower construction", "222 Margaret Street Brisbane"],
                 "river": ["Brisbane CBD from Kangaroo Point", "Brisbane skyline from Kangaroo Point cliffs", "Brisbane CBD from Captain Cook Bridge"],
                 "top": ["Brisbane aerial CBD", "View from Brisbane Skytower", "Brisbane from above Botanic Gardens"]},
    "queenswharf": {"lat": -27.47356, "lon": 153.02544,
                    "area": ["Queen's Wharf Brisbane", "George Street Brisbane Treasury", "William Street Brisbane Queens Wharf", "Queens Wharf Road Brisbane"],
                    "build": ["Queen's Wharf Brisbane construction", "Star Brisbane", "Queen's Wharf Tower"],
                    "river": ["Neville Bonner Bridge", "Queen's Wharf from South Bank", "Star Brisbane from river"],
                    "top": ["Sky Deck Brisbane", "View from Sky Deck Queen's Wharf", "South Bank from Queen's Wharf"]},
}


def get(url, binary=False):
    for k in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=60) as r:
                b = r.read()
            return b if binary else json.loads(b.decode("utf-8"))
        except Exception as err:
            if k == 3:
                raise
            time.sleep(2 + 3 * k)


def api(params):
    return get(API + "?" + urllib.parse.urlencode(dict(params, format="json")))


def strip(s):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", s or "")).strip()


def main():
    out = os.path.join(os.path.abspath(sys.argv[1]), "showcase_refs")
    ids = sys.argv[2:] or list(TOWERS)
    rows, seen = [], set()
    for tid in ids:
        T = TOWERS[tid]
        for theme in ("build", "river", "top", "area"):
            titles = []
            for words in T[theme]:
                try:
                    r = api({"action": "query", "list": "search", "srnamespace": 6, "srlimit": 50, "srsearch": words + " filetype:bitmap"})
                    titles += [(g["title"], words) for g in r.get("query", {}).get("search", [])]
                except Exception as err:
                    print("  search failed", words, err)
                time.sleep(0.5)
            if theme == "area":
                try:
                    r = api({"action": "query", "list": "geosearch", "gsnamespace": 6, "gslimit": 300, "gsradius": 350,
                             "gscoord": "%f|%f" % (T["lat"], T["lon"])})
                    titles += [(g["title"], "within 350 m (%d m)" % g.get("dist", 0)) for g in r.get("query", {}).get("geosearch", [])]
                except Exception as err:
                    print("  geosearch failed", tid, err)
            why, order = {}, []
            for t, w in titles:
                if (tid, t) not in seen and t not in why:
                    why[t] = w
                    order.append(t)
            n = 0
            for i in range(0, len(order), 40):
                if n >= CAP[theme]:
                    break
                try:
                    r = api({"action": "query", "titles": "|".join(order[i:i + 40]), "prop": "imageinfo",
                             "iiprop": "url|extmetadata|size|mime", "iiurlwidth": 1280})
                except Exception as err:
                    print("  info failed", err)
                    continue
                pages = {p["title"]: p["imageinfo"][0] for p in r.get("query", {}).get("pages", {}).values() if p.get("imageinfo")}
                for t in order[i:i + 40]:
                    ii = pages.get(t)
                    if n >= CAP[theme] or not ii or not str(ii.get("mime", "")).startswith("image/") or ii.get("width", 0) < 800:
                        continue
                    meta = ii.get("extmetadata", {})
                    lic = meta.get("LicenseShortName", {}).get("value", "")
                    if not any(k in lic for k in ("CC", "Public domain", "PD", "Attribution")):
                        continue
                    safe = "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in t.split(":", 1)[1])[:110]
                    if not safe.lower().endswith((".jpg", ".jpeg", ".png")):
                        continue
                    p = os.path.join(out, tid, theme, safe)
                    if not (os.path.exists(p) and os.path.getsize(p) > 2000):
                        try:
                            body = get(ii.get("thumburl") or ii["url"], binary=True)
                            os.makedirs(os.path.dirname(p), exist_ok=True)
                            with open(p, "wb") as f:
                                f.write(body)
                        except Exception as err:
                            print("   photo failed", safe, err)
                            continue
                        time.sleep(0.4)
                    seen.add((tid, t))
                    n += 1
                    rows.append({"tower": tid, "theme": theme, "file": "%s/%s/%s" % (tid, theme, safe), "found_by": why[t], "title": t,
                                 "description": strip(meta.get("ImageDescription", {}).get("value", ""))[:300],
                                 "date": strip(meta.get("DateTimeOriginal", {}).get("value", ""))[:40],
                                 "author": strip(meta.get("Artist", {}).get("value", ""))[:120], "licence": lic,
                                 "lat": meta.get("GPSLatitude", {}).get("value", ""), "lon": meta.get("GPSLongitude", {}).get("value", ""),
                                 "source": ii.get("descriptionurl", "")})
                time.sleep(0.5)
            print("%s %s: %d photos" % (tid, theme, n), flush=True)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "credits.csv"), "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else ["file"])
        wr.writeheader()
        wr.writerows(rows)
    print("total", len(rows), "photos in", out)


if __name__ == "__main__":
    main()
