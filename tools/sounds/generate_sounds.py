"""Makes the sounds in sound_list.json with ElevenLabs' sound effects API.

    set ELEVENLABS_API_KEY=...   (Windows: a user environment variable)
    python tools/sounds/generate_sounds.py [out_dir] [--only name,name] [--again]

Each sound lands in <out_dir>/<folder>/<name>.mp3 (default out_dir:
sound_staging, next to the project, so nothing reaches the game until it's
been listened to and copied into res://sounds/). Sounds already made are
skipped unless --again. Godot plays .mp3 as it is.

The key is read from the environment only; it's never written anywhere.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://api.elevenlabs.io/v1/sound-generation"
HERE = os.path.dirname(os.path.abspath(__file__))


def make(key, s):
    body = {"text": s["text"], "duration_seconds": s["seconds"], "prompt_influence": 0.5}
    if s.get("loop"):
        body["loop"] = True
    for attempt in range(3):
        req = urllib.request.Request(API, data=json.dumps(body).encode(), method="POST",
                                     headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:300]
            # (an older model may not take "loop": try once without it)
            if e.code in (400, 422) and "loop" in body:
                del body["loop"]
                continue
            if e.code == 429:
                time.sleep(10 * (attempt + 1))
                continue
            raise RuntimeError("HTTP %d: %s" % (e.code, msg))
    raise RuntimeError("gave up after retries")


def main():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        sys.exit("Set ELEVENLABS_API_KEY first (a Windows user environment variable), then open a new terminal.")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = args[0] if args else os.path.join(HERE, "..", "..", "..", "sound_staging")
    only = None
    again = "--again" in sys.argv
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = set(a[7:].split(","))
    with open(os.path.join(HERE, "sound_list.json"), encoding="utf-8") as f:
        sounds = json.load(f)["sounds"]
    made, skipped, failed = 0, 0, []
    for s in sounds:
        if only and s["name"] not in only:
            continue
        path = os.path.join(out, s["folder"], s["name"] + ".mp3")
        if os.path.exists(path) and not again:
            skipped += 1
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        try:
            data = make(key, s)
        except Exception as e:  # noqa: BLE001 (report and carry on with the rest)
            failed.append((s["name"], str(e)))
            print("FAILED %s/%s: %s" % (s["folder"], s["name"], e))
            continue
        with open(path, "wb") as f:
            f.write(data)
        made += 1
        print("made %s/%s (%d KB)" % (s["folder"], s["name"], len(data) // 1024))
        time.sleep(0.5)
    print("\n%d made, %d already there, %d failed -> %s" % (made, skipped, len(failed), os.path.abspath(out)))
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
