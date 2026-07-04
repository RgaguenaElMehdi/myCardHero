#!/usr/bin/env python3
"""Generate all game art via the Gemini image API (gemini-2.5-flash-image).

Reads GEMINI_API_KEY from .env at the project root. Idempotent: existing files
are skipped, so it can be re-run until every asset exists. Exit code 0 only
when the full manifest is satisfied.

Usage: python tools/generate_assets.py [--only cards|portraits|backgrounds|ui]
"""

import base64
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "asset_manifest.json"
CARDS_JSON = ROOT / "resources" / "data" / "cards.json"
MODEL = "gemini-2.5-flash-image"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
MAX_RETRIES = 5


def read_api_key() -> str:
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("GEMINI_API_KEY="):
                return line.split("=", 1)[1].strip()
    print("ERROR: GEMINI_API_KEY introuvable dans .env", file=sys.stderr)
    sys.exit(2)


def generate(api_key: str, prompt: str, aspect: str) -> bytes:
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {"aspectRatio": aspect},
        },
    }).encode()
    req = urllib.request.Request(
        f"{URL}?key={api_key}", data=body,
        headers={"Content-Type": "application/json"})
    last_err = None
    for attempt in range(MAX_RETRIES):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.load(resp)
            for part in data["candidates"][0]["content"].get("parts", []):
                blob = part.get("inlineData")
                if blob and blob.get("mimeType", "").startswith("image/"):
                    raw = base64.b64decode(blob["data"])
                    if raw[:4] == b"\x89PNG" or raw[:2] == b"\xff\xd8":
                        return raw
            last_err = f"réponse sans image: {str(data)[:200]}"
        except urllib.error.HTTPError as e:
            last_err = f"HTTP {e.code}: {e.read()[:200]!r}"
            if e.code in (429, 500, 502, 503):
                time.sleep(8 * (attempt + 1))
                continue
        except Exception as e:  # noqa: BLE001 - retry on any transient failure
            last_err = str(e)
        time.sleep(4 * (attempt + 1))
    raise RuntimeError(last_err)


def build_tasks(manifest: dict, only: str | None) -> list[tuple[Path, str, str]]:
    cards_data = json.loads(CARDS_JSON.read_text(encoding="utf-8"))
    guild_of = {c["id"]: c["guild"] for c in cards_data["cards"]}
    tasks = []
    if only in (None, "cards"):
        for cid, subject in manifest["cards"].items():
            hint = manifest["guild_hint"].get(guild_of.get(cid, ""), "")
            prompt = f"{manifest['style_card']} Subject: {subject}. Color mood: {hint}."
            tasks.append((ROOT / "assets/sprites/cards" / f"{cid}.png", prompt, "1:1"))
    if only in (None, "portraits"):
        for pid, subject in manifest["portraits"].items():
            prompt = f"{manifest['style_portrait']} Subject: {subject}."
            tasks.append((ROOT / "assets/portraits" / f"{pid}.png", prompt, "1:1"))
    if only in (None, "backgrounds"):
        for bid, subject in manifest["backgrounds"].items():
            prompt = f"{manifest['style_background']} Scene: {subject}."
            tasks.append((ROOT / "assets/backgrounds" / f"{bid}.png", prompt, "16:9"))
    if only in (None, "ui"):
        for uid, subject in manifest["ui"].items():
            prompt = f"{manifest['style_ui']} Icon: {subject}."
            tasks.append((ROOT / "assets/sprites/ui" / f"{uid}.png", prompt, "1:1"))
    return tasks


def main() -> int:
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
    api_key = read_api_key()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    tasks = build_tasks(manifest, only)
    todo = [t for t in tasks if not t[0].exists()]
    print(f"{len(tasks)} assets au manifeste, {len(todo)} à générer.")
    failures = []
    for i, (path, prompt, aspect) in enumerate(todo, 1):
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            raw = generate(api_key, prompt, aspect)
            path.write_bytes(raw)
            print(f"[{i}/{len(todo)}] OK  {path.relative_to(ROOT)} ({len(raw) // 1024} ko)")
        except Exception as e:  # noqa: BLE001
            failures.append((path, str(e)))
            print(f"[{i}/{len(todo)}] FAIL {path.relative_to(ROOT)} — {e}", file=sys.stderr)
        time.sleep(1.0)  # stay well under rate limits
    missing = [t[0] for t in tasks if not t[0].exists()]
    if missing:
        print(f"\n{len(missing)} asset(s) manquant(s) :", file=sys.stderr)
        for p in missing:
            print(f"  - {p.relative_to(ROOT)}", file=sys.stderr)
        return 1
    print("\nTous les assets sont présents.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
