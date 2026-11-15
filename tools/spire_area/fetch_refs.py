"""Collect Spire-area reference photos (streets, cathedral, neighbours) for John's private showcase.
Never committed. Copied from tools/hsw/fetch_refs.py with Spire-area categories and sources.

Run with Blender's Python (no system Python on the PC), Pillow in PourDecisions-sites/pylib:
  & "C:/Program Files/Blender Foundation/Blender 4.5/4.5/python/bin/python.exe" -I -u tools/spire_area/fetch_refs.py <sites_dir> [stage...]
Stages: collect (candidates.jsonl), download (images + manifest.csv), sheets (contact sheets). Default: all.
Downloads are resumable: a file that exists is skipped.
"""
import csv, hashlib, html, io, json, os, re, sys, threading, time, urllib.parse
from concurrent.futures import ThreadPoolExecutor

SITES = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\John\Documents\PourDecisions-sites"
sys.path.insert(0, os.path.join(SITES, "pylib"))
import requests
from PIL import Image, ImageDraw, ImageFont, ImageOps

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(SITES, "refs", "spire_area")
CAND = os.path.join(OUT, "candidates.jsonl")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/130.0.0.0 Safari/537.36")
CATS = ["cathedral_exterior", "cathedral_car_park", "cathedral_grounds", "ann_st", "queen_st", "adelaide_st",
        "wickham_tce_boundary_st", "petrie_bight", "church_house_webber_deanery", "orient_hotel",
        "willahra_admiralty_mantra", "other_towers_near_spire", "street_furniture_signals", "road_markings",
        "greenery_street_trees", "aerial_overview", "story_bridge_approach"]
CAP_PER_CAT = 70

SKIP_HOSTS = ("facebook", "fbcdn", "tiktok", "instagram", "cdninstagram", "shutterstock", "alamy",
              "gettyimages", "istockphoto", "dreamstime", "depositphotos", "123rf", "ftcdn",
              "stock.adobe", "bigstock", "pond5", "agefotostock", "superstock", "pinimg", "pinterest",
              "canstockphoto", "masterfile", "stocksy", "eyeem", "vecteezy", "freepik", "lookaside")
EXCLUDE = re.compile(r"interior|inside|bedroom|suite|room\b|lobby|menu|dish|plate|food|burger|pizza|"
                     r"cocktail|wine|beer glass|wedding|bride|portrait|selfie|crowd|concert|fireworks|"
                     r"riverfire|logo|map\b|floor ?plan|render(ing)?\b|cgi|artist.?s impression|"
                     r"table|dining|breakfast|staff|chef|bartender|\.svg|\.gif|icon|nave|altar|organ\b|"
                     r"stained|window glass|choir|pulpit|font\b|vault|pew|candle|bishop|service|mass\b|"
                     r"procession|parade|protest|rally|march\b|timetable|\btram\b|\b18[4-9]\d\b|\b19[0-6]\d\b|"
                     r"\b19[0-6]0s\b|historic photo|state library", re.I)

# keyword -> category, most specific first
RULES = [
    ("cathedral_car_park", r"car ?park|parking|carpark"),
    ("church_house_webber_deanery", r"church house|webber|deanery|old bishopsbourne|diocesan|st martin"),
    ("cathedral_grounds", r"cathedral.*(garden|ground|lawn|courtyard|cloister|close|precinct)|"
                          r"(garden|ground|lawn|courtyard|cloister).*cathedral"),
    ("cathedral_exterior", r"st\.? john.?s cathedral|cathedral of st\.? john|anglican cathedral"),
    ("orient_hotel", r"orient hotel|the orient\b"),
    ("willahra_admiralty_mantra", r"willahra|admiralty|mantra|one wharf"),
    ("petrie_bight", r"petrie.?bight|customs house|wharf st|macrossan|eagle st pier"),
    ("story_bridge_approach", r"story.?bridge|bradfield|boundary.?st.*valley|ivory.?st"),
    ("road_markings", r"zebra|crossing|road marking|line marking|bike lane|cycle lane|bus lane|arrow|stop line"),
    ("street_furniture_signals", r"traffic.?light|signal|street.?light|lamp|bus stop|bus shelter|sign\b|"
                                 r"bollard|bench|\bbin\b|bike rack|post box|letterbox|street sign"),
    ("greenery_street_trees", r"\btree|\bfig\b|poinciana|jacaranda|palm|brush box|tuckeroo|hedge|verge|"
                              r"garden|park\b|anzac square|wickham park"),
    ("wickham_tce_boundary_st", r"wickham|boundary st|spring hill|leichhardt|windmill|observatory"),
    ("adelaide_st", r"adelaide st"),
    ("queen_st", r"queen st"),
    ("ann_st", r"ann st"),
    ("other_towers_near_spire", r"tower|apartment|residen|skyscraper|highrise|high-rise|building|office"),
    ("aerial_overview", r"aerial|drone|overview|panorama|skyline|bird|from above"),
]


def classify(text, default):
    for cat, pat in RULES:
        if re.search(pat, text, re.I):
            return cat
    return default


# ---------------------------------------------------------------- polite http
_host_lock = {}
_host_last = {}
_glock = threading.Lock()
S = requests.Session()
S.headers.update({"User-Agent": UA, "Accept-Language": "en-AU,en;q=0.9"})


def get(url, timeout=40, **kw):
    host = urllib.parse.urlparse(url).netloc
    gap = 2.6 if "commons.wikimedia" in host else 1.6 if "wikimedia" in host or "wikipedia" in host else 1.05
    with _glock:
        lk = _host_lock.setdefault(host, threading.Lock())
    with lk:
        wait = _host_last.get(host, 0) + gap - time.time()
        if wait > 0:
            time.sleep(wait)
        if "wikimedia" in host or "wikipedia" in host:   # Wikimedia asks bots for a plain tool name, throttles browser UAs
            kw = dict(kw, headers=dict(kw.get("headers") or {}, **{"User-Agent": "PourDecisionsRefFetcher/1.0 (personal reference set; python-requests)"}))
        for attempt in range(8):
            try:
                r = S.get(url, timeout=timeout, **kw)
            except requests.RequestException as e:
                r = None
                err = e
            _host_last[host] = time.time()
            if r is not None and r.status_code == 429:
                print("  429", host, flush=True)
                time.sleep(min(60, 10 * (attempt + 1)))
                continue
            if r is None:
                if attempt == 7:
                    raise err
                time.sleep(3)
                continue
            return r
        return r


def skip_host(url):
    h = urllib.parse.urlparse(url).netloc.lower()
    return any(s in h for s in SKIP_HOSTS)


# ---------------------------------------------------------------- collectors
def from_tsv():
    """Google image results gathered in John's Chrome by the cloud thread (optional file).
    Columns: query, cat, url (cat is one of CATS when known)."""
    out = []
    path = os.path.join(REPO, "reference", "sites", "spire_area", "google_image_urls.tsv")
    if not os.path.exists(path):
        print("  no google_image_urls.tsv yet", flush=True)
        return out
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            q = row.get("query", "")
            url = row.get("url", "")
            if not url.startswith("http"):
                continue
            default = row.get("cat") if row.get("cat") in CATS else classify(q, "aerial_overview")
            cat = classify(url.rsplit("/", 1)[-1].replace("-", " ").replace("_", " "), default) \
                if default == "aerial_overview" else default
            out.append(dict(src="gg", category=cat, image_url=url, source_page=row.get("page") or ("google images: " + q),
                            credit="", licence="", date="", gps="", desc=f"Google result for '{q}'"))
    return out


COMMONS_API = "https://commons.wikimedia.org/w/api.php"


def commons_members(cat, depth, seen):
    files = []
    if cat in seen:
        return files
    seen.add(cat)
    cont = {}
    while True:
        p = dict(action="query", list="categorymembers", cmtitle="Category:" + cat, cmtype="file|subcat",
                 cmlimit="500", format="json", **cont)
        j = get(COMMONS_API, params=p).json()
        for m in j.get("query", {}).get("categorymembers", []):
            if m["ns"] == 6:
                files.append((m["title"], cat))
            elif m["ns"] == 14 and depth > 0:
                sub = m["title"].split(":", 1)[1]
                if not EXCLUDE.search(sub) and not re.search(r"at night|Construction of the Story|Hotel$|19[0-9]0s", sub):
                    files += commons_members(sub, depth - 1, seen)
        if "continue" in j:
            cont = {"cmcontinue": j["continue"]["cmcontinue"]}
        else:
            break
    return files


def strip_html(s):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s or ""))).strip()


def from_commons():
    seen = set()
    titles = []
    for cat, depth in [("St_John's_Cathedral,_Brisbane", 2), ("St_John's_Cathedral_(Brisbane)", 2),
                       ("Old_Bishopsbourne", 0), ("Church_House,_Brisbane", 0), ("Webber_House,_Brisbane", 0),
                       ("Deanery,_Brisbane", 0), ("Ann_Street,_Brisbane", 1), ("Queen_Street,_Brisbane", 1),
                       ("Adelaide_Street,_Brisbane", 1), ("Wickham_Terrace,_Brisbane", 0),
                       ("Boundary_Street,_Spring_Hill", 0), ("Petrie_Bight", 1), ("Customs_House,_Brisbane", 1),
                       ("Fortitude_Valley,_Queensland", 0), ("Spring_Hill,_Queensland", 0),
                       ("Anzac_Square,_Brisbane", 0), ("Traffic_signals_in_Brisbane", 0),
                       ("Street_signs_in_Brisbane", 0), ("Streets_in_Brisbane", 0), ("Brisbane_CBD", 0),
                       ("Orient_Hotel,_Brisbane", 0), ("Wickham_Park,_Brisbane", 0), ("Story_Bridge", 0),
                       ("Traffic_lights_in_Brisbane", 0), ("Roads_in_Brisbane", 1),
                       ("Aerial_photographs_of_Brisbane", 0)]:
        got = commons_members(cat, depth, seen)
        print(f"  commons {cat}: {len(got)} files", flush=True)
        titles += got
    uniq = {}
    for t, c in titles:
        uniq.setdefault(t, c)
    extra = [t for t in from_commons_search() if PLACE.search(t)]
    for t in extra:
        uniq.setdefault(t, "search")
    print(f"  commons search adds: {len(uniq) - len(set(t for t, _ in titles))}", flush=True)
    out = []
    items = list(uniq.items())
    for i in range(0, len(items), 50):
        batch = items[i:i + 50]
        p = dict(action="query", titles="|".join(t for t, _ in batch), prop="imageinfo",
                 iiprop="url|size|extmetadata|mime", iiurlwidth="1600", format="json")
        j = get(COMMONS_API, params=p).json()
        for pg in j.get("query", {}).get("pages", {}).values():
            ii = (pg.get("imageinfo") or [None])[0]
            if not ii or ii.get("mime") not in ("image/jpeg", "image/png", "image/tiff", "image/webp"):
                continue
            if ii.get("width", 0) < 900:
                continue
            em = ii.get("extmetadata", {})
            val = lambda k: strip_html(em.get(k, {}).get("value", ""))
            title = pg["title"]
            desc = val("ImageDescription")[:200]
            text = title + " " + desc
            if EXCLUDE.search(title):
                continue
            ccat = uniq.get(title, "")
            default = next((c for k, c in CCAT_DEFAULT if k in ccat), "other_towers_near_spire")
            # category of the Commons folder wins for the cathedral; keyword rules otherwise
            cat = classify(text, default)
            if "Cathedral" in ccat and cat not in ("cathedral_car_park", "cathedral_grounds",
                                                   "church_house_webber_deanery"):
                cat = "cathedral_exterior"
            date = val("DateTimeOriginal") or val("DateTime")
            if re.match(r"(18|19[0-7])", date):   # old photos: wrong era for the model
                continue
            gps = ""
            if val("GPSLatitude"):
                gps = f"{val('GPSLatitude')},{val('GPSLongitude')}"
            out.append(dict(src="cm", category=cat, image_url=ii.get("thumburl") or ii["url"],
                            source_page=ii.get("descriptionurl", ""), credit=val("Artist")[:120],
                            licence=val("LicenseShortName"), date=date[:19], gps=gps,
                            desc=(title.split(":", 1)[1].rsplit(".", 1)[0].replace("_", " ") + ". " + desc)[:240]))
    print(f"  commons usable: {len(out)}", flush=True)
    return out


BING_Q = {
    "overview_aerial": ["howard smith wharves aerial", "howard smith wharves drone story bridge",
                        "story bridge aerial brisbane"],
    "from_kangaroo_point": ["story bridge from kangaroo point", "howard smith wharves from kangaroo point cliffs"],
    "from_river": ["howard smith wharves from the river", "story bridge from citycat brisbane river"],
    "bridge_truss": ["story bridge truss close up", "story bridge steel cantilever detail"],
    "bridge_piers": ["story bridge northern pier howard smith wharves", "story bridge pier pylon concrete"],
    "bridge_underside": ["story bridge underside", "under the story bridge brisbane"],
    "bridge_deck_and_approach": ["story bridge footpath deck", "story bridge approach span new farm"],
    "cliffs": ["new farm cliffs story bridge", "howard smith wharves cliff face"],
    "lift_tower_stairs": ["howard smith wharves lift tower corten", "howard smith wharves stairs cliff"],
    "hotel": ["crystalbrook vincent brisbane exterior", "the fantauzzo hotel exterior howard smith wharves"],
    "sheds_felons_stanley": ["felons brewing howard smith wharves exterior", "stanley restaurant howard smith wharves building",
                             "howard smith wharves heritage shed"],
    "mr_percivals": ["mr percivals overwater bar", "mr percivals howard smith wharves"],
    "boardwalk_riverwalk": ["howard smith wharves riverwalk", "story bridge from new farm riverwalk"],
    "pontoons_ferry": ["howard smith wharves ferry terminal", "howard smith wharves pontoon"],
    "lawn_greenery": ["howard smith wharves main lawn", "howard smith wharves gardens"],
    "bowen_tce_wilson_outlook": ["wilson outlook reserve story bridge", "bowen terrace new farm howard smith wharves view"],
    "construction_2017_18": ["howard smith wharves construction 2017", "howard smith wharves construction 2018 hutchinson"],
}


def from_bing():
    out = []
    for cat, qs in BING_Q.items():
        for q in qs:
            url = "https://www.bing.com/images/async?" + urllib.parse.urlencode(
                dict(q=q, first=0, count=35, adlt="strict", qft="+filterui:imagesize-large"))
            try:
                t = get(url).text
            except Exception as e:
                print("  bing fail", q, e)
                continue
            n = 0
            for m in re.finditer(r'\bm="([^"]+)"', t):
                try:
                    d = json.loads(html.unescape(m.group(1)))
                except Exception:
                    continue
                if "murl" not in d:
                    continue
                title = d.get("t", "")
                if EXCLUDE.search(title + " " + d["murl"]):
                    continue
                n += 1
                out.append(dict(src="bg", category=cat, image_url=d["murl"], source_page=d.get("purl", ""),
                                credit="", licence="", date="", gps="",
                                desc=f"{strip_html(title)[:150]} (Bing '{q}')"))
            print(f"  bing '{q}': {n}", flush=True)
    return out


CCAT_DEFAULT = [  # Commons folder name piece -> default category
    ("Cathedral", "cathedral_exterior"), ("Bishopsbourne", "church_house_webber_deanery"),
    ("Church_House", "church_house_webber_deanery"), ("Webber", "church_house_webber_deanery"),
    ("Deanery", "church_house_webber_deanery"), ("Ann_Street", "ann_st"), ("Queen_Street", "queen_st"),
    ("Adelaide", "adelaide_st"), ("Wickham_T", "wickham_tce_boundary_st"), ("Boundary", "wickham_tce_boundary_st"),
    ("Spring_Hill", "wickham_tce_boundary_st"), ("Petrie", "petrie_bight"), ("Customs", "petrie_bight"),
    ("Fortitude", "story_bridge_approach"), ("Story_Bridge", "story_bridge_approach"),
    ("Anzac", "greenery_street_trees"), ("Wickham_Park", "greenery_street_trees"),
    ("Traffic", "street_furniture_signals"), ("signs", "street_furniture_signals"),
    ("Traffic_lights", "street_furniture_signals"), ("Roads_in", "road_markings"), ("Aerial", "aerial_overview"),
    ("Orient", "orient_hotel"), ("search", "other_towers_near_spire")]

PAGES = [
    "https://stjohnscathedral.com.au/", "https://stjohnscathedral.com.au/visit/",
    "https://stjohnscathedral.com.au/about/", "https://stjohnscathedral.com.au/history/",
    "https://www.theorienthotel.com.au/", "https://www.mantra.com.au/queensland/brisbane-region/brisbane/accommodation/hotels/mantra-on-queen/",
    "https://www.spireresidences.com.au/", "https://www.anglicanchurchsq.org.au/",
    "https://en.wikipedia.org/wiki/St_John%27s_Cathedral_(Brisbane)",
    "https://en.wikipedia.org/wiki/Ann_Street,_Brisbane", "https://en.wikipedia.org/wiki/Queen_Street,_Brisbane",
    "https://en.wikipedia.org/wiki/Petrie_Bight", "https://en.wikipedia.org/wiki/Customs_House,_Brisbane",
    "https://en.wikipedia.org/wiki/Old_Bishopsbourne", "https://en.wikipedia.org/wiki/Webber_House",
    "https://en.wikipedia.org/wiki/Church_House,_Brisbane", "https://en.wikipedia.org/wiki/The_Deanery,_Brisbane",
    "https://www.brisbane.qld.gov.au/traffic-and-transport/roads-infrastructure-and-bikeways/street-lighting",
]


def from_pages():
    out = []
    for pu in PAGES:
        try:
            r = get(pu)
            if r.status_code != 200:
                print("  page", r.status_code, pu)
                continue
        except Exception as e:
            print("  page fail", pu, e)
            continue
        t = r.text
        urls = re.findall(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', t)
        for m in re.finditer(r'<img[^>]+>', t):
            tag = m.group(0)
            src = re.search(r'\b(?:data-src|src)=["\']([^"\']+)', tag)
            srcset = re.search(r'\bsrcset=["\']([^"\']+)', tag)
            if srcset:
                best = sorted(((int(w or 0), u) for u, w in re.findall(r'(\S+)\s+(\d+)w', srcset.group(1))))
                if best:
                    urls.append(best[-1][1])
                    continue
            if src:
                urls.append(src.group(1))
        alts = {}
        n = 0
        for u in dict.fromkeys(urls):
            u = urllib.parse.urljoin(pu, html.unescape(u))
            if not u.startswith("http") or EXCLUDE.search(u) or re.search(r"\.(svg|gif)(\?|$)", u, re.I):
                continue
            if re.search(r"(-|_)(\d{2,3})x(\d{2,3})\.", u):  # wp thumbnails
                continue
            name = u.rsplit("/", 1)[-1]
            host = urllib.parse.urlparse(pu).netloc
            low = pu.lower()
            default = ("cathedral_exterior" if ("cathedral" in low or "anglican" in low) else
                       "orient_hotel" if "orient" in low else "willahra_admiralty_mantra" if "mantra" in low else
                       "church_house_webber_deanery" if re.search(r"bishopsbourne|webber|church_house|deanery", low) else
                       "petrie_bight" if re.search(r"petrie|customs", low) else "ann_st" if "ann_street" in low else
                       "queen_st" if "queen_street" in low else "street_furniture_signals" if "lighting" in low
                       else "other_towers_near_spire")
            if "wikipedia" in host and not re.search(r"upload\.wikimedia", u):
                continue
            out.append(dict(src="pg", category=classify(name, default), image_url=u, source_page=pu,
                            credit=host, licence="", date="", gps="", desc=f"image on {pu}: {name[:80]}"))
            n += 1
        print(f"  page {pu}: {n}", flush=True)
    return out


PLACE = re.compile(r"st\.? john.?s cathedral|cathedral|ann st|queen st|adelaide st|wickham|boundary st|"
                   r"spring hill|fortitude valley|petrie.?bight|customs house|story.?bridge|orient hotel|"
                   r"willahra|admiralty|mantra|spire|anzac square|wharf st|eagle st|creek st|brisbane cbd|"
                   r"brisbane city|bishopsbourne|webber house|deanery|church house", re.I)

OV_Q = {  # query -> default category (keyword rules still win)
    "st johns cathedral brisbane": "cathedral_exterior", "st john's cathedral brisbane": "cathedral_exterior",
    "cathedral brisbane ann street": "cathedral_exterior", "brisbane anglican cathedral": "cathedral_exterior",
    "st johns cathedral garden brisbane": "cathedral_grounds", "cathedral car park brisbane": "cathedral_car_park",
    "old bishopsbourne brisbane": "church_house_webber_deanery", "deanery brisbane ann street": "church_house_webber_deanery",
    "ann street brisbane": "ann_st", "ann st brisbane": "ann_st", "queen street brisbane": "queen_st",
    "adelaide street brisbane": "adelaide_st", "wickham terrace brisbane": "wickham_tce_boundary_st",
    "spring hill brisbane street": "wickham_tce_boundary_st", "petrie bight brisbane": "petrie_bight",
    "customs house brisbane": "petrie_bight", "eagle street brisbane": "petrie_bight",
    "orient hotel brisbane": "orient_hotel", "fortitude valley street": "story_bridge_approach",
    "story bridge fortitude valley": "story_bridge_approach", "brisbane traffic lights": "street_furniture_signals",
    "brisbane street sign": "street_furniture_signals", "brisbane bus stop": "street_furniture_signals",
    "brisbane pedestrian crossing": "road_markings", "brisbane bike lane": "road_markings",
    "brisbane street trees": "greenery_street_trees", "brisbane fig tree city": "greenery_street_trees",
    "anzac square brisbane": "greenery_street_trees", "brisbane cbd aerial": "aerial_overview",
    "brisbane skyline spring hill": "aerial_overview", "brisbane city apartment tower": "other_towers_near_spire",
}


def from_openverse():
    out = []
    for q, default in OV_Q.items():
        n = 0
        for page in (1, 2, 3):
            url = "https://api.openverse.org/v1/images/?" + urllib.parse.urlencode(
                dict(q=q, page_size=20, page=page, extension="jpg"))
            try:
                j = get(url).json()
            except Exception as e:
                print("  openverse fail", q, e)
                break
            for r in j.get("results", []):
                title = r.get("title", "") or ""
                tags = " ".join(t.get("name", "") for t in (r.get("tags") or []))
                if (r.get("width") or 0) < 900 or EXCLUDE.search(title) or not PLACE.search(title + " " + tags):
                    continue
                n += 1
                out.append(dict(src="fl", category=classify(title, default), image_url=r["url"],
                                source_page=r.get("foreign_landing_url", ""), credit=r.get("creator", "") or "",
                                licence=f"CC {r.get('license', '')} {r.get('license_version', '')}".upper(),
                                date="", gps="", desc=f"{title[:150]} ({r.get('source', '')} via Openverse)"))
            if page >= (j.get("page_count") or 1):
                break
        print(f"  openverse '{q}': {n}", flush=True)
    return out


def from_commons_search():
    """Full-text search of Commons files (finds photos not filed in the categories)."""
    out_titles = []
    for q in ["St John's Cathedral Brisbane", "Ann Street Brisbane", "Queen Street Brisbane", "Petrie Bight",
              "Fortitude Valley street", "Spring Hill Brisbane", "Wickham Terrace", "Customs House Brisbane",
              "Brisbane traffic lights", "Adelaide Street Brisbane", "Old Bishopsbourne", "Webber House Brisbane",
              "Orient Hotel Brisbane", "Eagle Street Brisbane", "Anzac Square Brisbane", "Brisbane CBD aerial"]:
        p = dict(action="query", list="search", srsearch=q + " filetype:bitmap", srnamespace="6", srlimit="100", format="json")
        j = get(COMMONS_API, params=p).json()
        out_titles += [s["title"] for s in j.get("query", {}).get("search", [])]
    return out_titles


def collect():
    os.makedirs(OUT, exist_ok=True)
    allc = []
    # Bing (from_bing) was tried on 15 Nov 2026: its async endpoint ignored the query and returned
    # unrelated images, so it is not used.
    for fn in (from_tsv, from_commons, from_pages, from_openverse):
        print(fn.__name__, flush=True)
        try:
            allc += fn()
        except Exception as e:
            print("  FAILED", fn.__name__, e, flush=True)
    seen, res = set(), []
    for c in allc:
        if c["image_url"] in seen or skip_host(c["image_url"]) or skip_host(c["source_page"]):
            continue
        seen.add(c["image_url"])
        res.append(c)
    with open(CAND, "w", encoding="utf-8") as f:
        for c in res:
            f.write(json.dumps(c) + "\n")
    print("candidates:", len(res))


# ---------------------------------------------------------------- download
def dhash(im, n=8):
    g = im.convert("L").resize((n + 1, n), Image.LANCZOS)
    px = list(g.getdata())
    bits = 0
    for y in range(n):
        for x in range(n):
            bits = (bits << 1) | (px[y * (n + 1) + x] > px[y * (n + 1) + x + 1])
    return bits


def fname(c):
    return f"{c['src']}_{hashlib.sha1(c['image_url'].encode()).hexdigest()[:8]}.jpg"


def download():
    cands = [json.loads(l) for l in open(CAND, encoding="utf-8")]
    # order: commons/openverse first (known licence), then pages, tsv, bing
    rank = {"cm": 0, "fl": 1, "pg": 2, "gg": 3, "bg": 4}
    cands.sort(key=lambda c: rank[c["src"]])
    state_path = os.path.join(OUT, "download_state.json")
    state = json.load(open(state_path)) if os.path.exists(state_path) else {}
    lock = threading.Lock()
    hashes = []  # (hash, file)
    count = {c: 0 for c in CATS}
    for f, s in state.items():
        if s.get("ok"):
            hashes.append((s["hash"], f))
            count[s["category"]] += 1

    def work(c):
        f = fname(c)
        if f in state:
            return
        with lock:
            if count[c["category"]] >= CAP_PER_CAT:
                return
        if c["src"] == "cm" and "/1600px-" in c["image_url"]:   # standard thumb bucket: cached, not rate limited
            c = dict(c, image_url=c["image_url"].replace("/1600px-", "/1920px-"))
        try:
            r = get(c["image_url"], timeout=60, headers={"Referer": c["source_page"]} if c["source_page"].startswith("http") else {})
            if r.status_code != 200 or not r.headers.get("content-type", "image").startswith("image"):
                with lock:
                    state[f] = {"ok": False, "why": f"http {r.status_code} {r.headers.get('content-type','')[:20]}"}
                return
            im = Image.open(io.BytesIO(r.content))
            im = ImageOps.exif_transpose(im).convert("RGB")
        except Exception as e:
            with lock:
                state[f] = {"ok": False, "why": str(e)[:80]}
            return
        if im.width < 900:
            with lock:
                state[f] = {"ok": False, "why": f"small {im.width}"}
            return
        h = dhash(im)
        with lock:
            for oh, of in hashes:
                if bin(oh ^ h).count("1") <= 6:
                    state[f] = {"ok": False, "why": "dupe of " + of}
                    return
            if count[c["category"]] >= CAP_PER_CAT:
                return
            hashes.append((h, f))
            count[c["category"]] += 1
        s = 1600 / max(im.size)
        if s < 1:
            im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        d = os.path.join(OUT, c["category"])
        os.makedirs(d, exist_ok=True)
        im.save(os.path.join(d, f), quality=85, optimize=True)
        with lock:
            state[f] = dict(c, ok=True, hash=h, size=f"{im.width}x{im.height}")
            n = sum(1 for v in state.values() if v.get("ok"))
            if n % 20 == 0:
                print(f"  saved {n}", flush=True)
                json.dump(state, open(state_path, "w"))

    by_host = {}
    for c in cands:
        by_host.setdefault(urllib.parse.urlparse(c["image_url"]).netloc, []).append(c)
    # interleave hosts so one slow host doesn't block; per-host politeness is in get()
    order = []
    lists = list(by_host.values())
    while any(lists):
        for l in lists:
            if l:
                order.append(l.pop(0))
    with ThreadPoolExecutor(10) as ex:
        list(ex.map(work, order))
    json.dump(state, open(state_path, "w"))
    write_manifest(state)


def write_manifest(state=None):
    state_path = os.path.join(OUT, "download_state.json")
    state = state or json.load(open(state_path))
    rows = []
    for f, s in state.items():
        if not s.get("ok") or not os.path.exists(os.path.join(OUT, s["category"], f)):
            continue
        rows.append([f"{s['category']}/{f}", s["category"], s["source_page"], s["image_url"], s["credit"],
                     s["licence"], s["date"], s["gps"], s["desc"]])
    mine = os.path.join(SITES, "my_photos", "spire")
    for f in sorted(os.listdir(mine)) if os.path.isdir(mine) else []:
        if f.lower().endswith((".jpg", ".jpeg", ".png")) and "floor plan" not in f.lower():
            t = f.lower()
            cat = ("aerial_overview" if re.search(r"fly|satal|top deck|looking down", t) else
                   "orient_hotel" if "orient" in t else "queen_st" if "queen" in t else
                   "ann_st" if "ann st" in t or "street view" in t else
                   "other_towers_near_spire")
            rows.append([f"../../my_photos/spire/{f}", cat, "John's own collection", "", "John (collected)",
                         "", "", "", "John's Spire photo (kept in my_photos/spire)"])
    rows.sort(key=lambda r: (CATS.index(r[1]), r[0]))
    with open(os.path.join(OUT, "manifest.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["file", "category", "source_page", "image_url", "credit", "licence_if_known", "date",
                    "gps_if_known", "description"])
        w.writerows(rows)
    cnt = {}
    for r in rows:
        cnt[r[1]] = cnt.get(r[1], 0) + 1
    print("manifest rows:", len(rows))
    for c in CATS:
        print(f"  {c}: {cnt.get(c, 0)}")


# ---------------------------------------------------------------- contact sheets
def sheets():
    d = os.path.join(OUT, "sheets")
    os.makedirs(d, exist_ok=True)
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
    for c in CATS:
        cd = os.path.join(OUT, c)
        files = sorted(os.listdir(cd)) if os.path.isdir(cd) else []
        files = [f for f in files if f.endswith(".jpg")]
        if not files:
            continue
        cols, tw, th = 6, 300, 210
        rows = (len(files) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * tw, rows * (th + 18)), (30, 30, 30))
        dr = ImageDraw.Draw(sheet)
        for i, f in enumerate(files):
            im = Image.open(os.path.join(cd, f))
            im.thumbnail((tw - 6, th - 6))
            x, y = (i % cols) * tw, (i // cols) * (th + 18)
            sheet.paste(im, (x + (tw - im.width) // 2, y + (th - im.height) // 2))
            dr.text((x + 4, y + th), f, fill=(230, 230, 230), font=font)
        sheet.save(os.path.join(d, c + ".jpg"), quality=80)
    print("sheets done")


if __name__ == "__main__":
    stages = sys.argv[2:] or ["collect", "download", "sheets"]
    if any(s.startswith("drop=") for s in stages):  # drop files by prefix, e.g. drop=bg_  (removes them and their state entries)
        pre = next(s[5:] for s in stages if s.startswith("drop="))
        sp = os.path.join(OUT, "download_state.json")
        st = json.load(open(sp)) if os.path.exists(sp) else {}
        st = {k: v for k, v in st.items() if not k.startswith(pre)}
        json.dump(st, open(sp, "w"))
        n = 0
        for c in CATS:
            cd = os.path.join(OUT, c)
            for f in (os.listdir(cd) if os.path.isdir(cd) else []):
                if f.startswith(pre):
                    os.remove(os.path.join(cd, f))
                    n += 1
        print("dropped", n)
    if "collect" in stages:
        collect()
    if "download" in stages:
        download()
    if "manifest" in stages:
        write_manifest()
    if "sheets" in stages:
        sheets()
