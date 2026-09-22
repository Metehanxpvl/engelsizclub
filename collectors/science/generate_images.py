#!/usr/bin/env python3
"""Imagen 3 kapak görselleri — filtrelenen / kuyruktaki bilimsel makaleler.

Node toplayıcı `output/papers.json` yazar. Bu betik:
  1) o kuyruğu (ve isteğe bağlı Supabase pending_review satırlarını) okur
  2) GEMINI_API_KEY + imagen-3.0-generate-002 ile görsel üretir
  3) PNG'leri output/{tarih}_{slug}.png olarak kaydeder

google-genai SDK tercih edilir; yoksa / hata olursa REST (requests) kullanılır.
API anahtarı yazdırılmaz. Çocuk/hasta yüzü üretilmez (personGeneration=dont_allow).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
from datetime import date
from pathlib import Path
from typing import Any

IMAGEN_MODEL = "imagen-3.0-generate-002"
DEFAULT_LIMIT = 20
REST_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"{IMAGEN_MODEL}:predict"
)

HERE = Path(__file__).resolve().parent
DEFAULT_OUTPUT = HERE / "output"
DEFAULT_PAPERS = DEFAULT_OUTPUT / "papers.json"


def env(name: str) -> str:
    return os.environ.get(name, "").strip()


def slugify(title: str, fallback: str = "makale") -> str:
    raw = unicodedata.normalize("NFKD", str(title or ""))
    ascii_ = "".join(ch for ch in raw if not unicodedata.combining(ch))
    ascii_ = (
        ascii_.replace("ı", "i")
        .replace("İ", "I")
        .replace("ş", "s")
        .replace("Ş", "S")
        .replace("ğ", "g")
        .replace("Ğ", "G")
        .replace("ü", "u")
        .replace("Ü", "U")
        .replace("ö", "o")
        .replace("Ö", "O")
        .replace("ç", "c")
        .replace("Ç", "C")
    )
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", ascii_.lower()).strip("-")
    slug = slug[:60].strip("-")
    return slug or fallback


def paper_date(paper: dict[str, Any]) -> str:
    raw = str(paper.get("publication_date") or "").strip()
    m = re.match(r"^(\d{4}-\d{2}-\d{2})", raw)
    if m:
        return m.group(1)
    return date.today().isoformat()


def paper_stem(paper: dict[str, Any]) -> str:
    ident = str(paper.get("pmid") or paper.get("nct_id") or paper.get("id") or "")
    ident = re.sub(r"[^a-zA-Z0-9]+", "", ident)[:16]
    title = paper.get("title") or paper.get("original_title") or "makale"
    parts = [paper_date(paper), slugify(str(title))]
    if ident:
        parts.append(ident.lower())
    return "_".join(parts)


def imagen_prompt(paper: dict[str, Any]) -> str:
    title = str(paper.get("title") or paper.get("original_title") or "").strip()
    summary = str(paper.get("summary") or "").strip()[:280]
    return (
        "Abstract scientific editorial illustration, not a photograph. "
        "Hopeful, calm medical-research cover art in teal and soft green. "
        "No text, no logos, no watermarks, no faces, no children, no patients, "
        "no body parts, no needles, no realistic clinical procedures. "
        "Flat modern illustration, high quality, 16:9. "
        f"Topic: {title}. {summary}"
    )


def load_json_list(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    if isinstance(data, dict) and isinstance(data.get("papers"), list):
        return [x for x in data["papers"] if isinstance(x, dict)]
    return []


def fetch_supabase_queue(limit: int, ids: list[str]) -> list[dict[str, Any]]:
    url = env("SUPABASE_URL").rstrip("/")
    key = env("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        return []
    try:
        import requests
    except ImportError:
        print("requests yok; Supabase kuyruğu atlandı.", file=sys.stderr)
        return []
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Accept": "application/json",
    }
    select = (
        "id,title,original_title,summary,publication_date,pmid,nct_id,"
        "treatment_potential"
    )
    if ids:
        in_list = ",".join(ids)
        endpoint = (
            f"{url}/rest/v1/scientific_researches"
            f"?id=in.({in_list})&select={select}"
        )
    else:
        endpoint = (
            f"{url}/rest/v1/scientific_researches"
            f"?status=eq.pending_review&select={select}"
            f"&order=created_at.desc&limit={max(1, limit)}"
        )
    try:
        res = requests.get(endpoint, headers=headers, timeout=30)
        if res.status_code >= 400:
            print(f"Supabase kuyruk HTTP {res.status_code}", file=sys.stderr)
            return []
        data = res.json()
        return data if isinstance(data, list) else []
    except requests.RequestException as exc:
        print(f"Supabase kuyruk okunamadı: {type(exc).__name__}", file=sys.stderr)
        return []


def merge_papers(*groups: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    for group in groups:
        for paper in group:
            key = (
                str(paper.get("id") or "")
                or str(paper.get("pmid") or "")
                or str(paper.get("nct_id") or "")
                or paper_stem(paper)
            )
            if key in seen:
                continue
            seen.add(key)
            out.append(paper)
    return out


def generate_via_sdk(api_key: str, prompt: str) -> bytes | None:
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        return None
    try:
        client = genai.Client(api_key=api_key)
        cfg = types.GenerateImagesConfig(
            number_of_images=1,
            aspect_ratio="16:9",
            person_generation="DONT_ALLOW",
        )
        result = client.models.generate_images(
            model=IMAGEN_MODEL,
            prompt=prompt,
            config=cfg,
        )
        images = getattr(result, "generated_images", None) or []
        if not images:
            return None
        image = getattr(images[0], "image", None)
        if image is None:
            return None
        raw = getattr(image, "image_bytes", None)
        if raw:
            return bytes(raw)
        blob = getattr(image, "data", None) or getattr(image, "_bytes", None)
        if blob:
            return bytes(blob)
    except Exception as exc:  # noqa: BLE001 — quota / model availability
        print(f"google-genai Imagen hata: {type(exc).__name__}", file=sys.stderr)
    return None


def generate_via_rest(api_key: str, prompt: str) -> bytes | None:
    try:
        import requests
    except ImportError:
        print("requests yok; REST Imagen atlandı.", file=sys.stderr)
        return None
    try:
        res = requests.post(
            REST_URL,
            params={"key": api_key},
            json={
                "instances": [{"prompt": prompt}],
                "parameters": {
                    "sampleCount": 1,
                    "aspectRatio": "16:9",
                    "personGeneration": "dont_allow",
                },
            },
            timeout=90,
        )
        if res.status_code >= 400:
            print(f"Imagen REST HTTP {res.status_code}", file=sys.stderr)
            return None
        payload = res.json()
        preds = payload.get("predictions") or []
        if not preds:
            return None
        b64 = preds[0].get("bytesBase64Encoded") or preds[0].get("bytes")
        if not b64:
            return None
        import base64

        return base64.b64decode(b64)
    except Exception as exc:  # noqa: BLE001
        print(f"Imagen REST hata: {type(exc).__name__}", file=sys.stderr)
        return None


def generate_image_bytes(api_key: str, prompt: str) -> bytes | None:
    png = generate_via_sdk(api_key, prompt)
    if png:
        return png
    return generate_via_rest(api_key, prompt)


def save_png(output_dir: Path, paper: dict[str, Any], png: bytes) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / f"{paper_stem(paper)}.png"
    dest.write_bytes(png)
    return dest


def parse_ids(raw: str) -> list[str]:
    return [p.strip() for p in str(raw or "").split(",") if p.strip()]


def run(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Imagen 3 scientific paper covers")
    parser.add_argument("--papers", type=Path, default=DEFAULT_PAPERS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=int(env("SCIENCE_IMAGE_LIMIT") or DEFAULT_LIMIT))
    parser.add_argument("--from-supabase", action="store_true")
    parser.add_argument("--ids", default=env("SCIENCE_PAPER_IDS"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    papers = load_json_list(args.papers)
    ids = parse_ids(args.ids)
    if args.from_supabase or ids:
        papers = merge_papers(papers, fetch_supabase_queue(args.limit, ids))
    papers = papers[: max(0, args.limit)]

    api_key = env("GEMINI_API_KEY") or env("AI_API_KEY")
    if not papers:
        print("görsel kuyruğu boş (papers.json / pending_review).")
        _write_manifest(args.output, [])
        return 0
    if args.dry_run:
        for paper in papers:
            print(f"dry-run {paper_stem(paper)}.png")
        _write_manifest(args.output, [])
        return 0
    if not api_key:
        print("GEMINI_API_KEY yok; görsel üretilmedi.", file=sys.stderr)
        _write_manifest(args.output, [])
        return 0

    saved: list[dict[str, Any]] = []
    for i, paper in enumerate(papers):
        prompt = imagen_prompt(paper)
        png = generate_image_bytes(api_key, prompt)
        if not png:
            print(f"görsel yok: {paper.get('title') or paper.get('pmid')}")
            continue
        dest = save_png(args.output, paper, png)
        print(f"kaydedildi {dest.name} ({len(png)} bytes)")
        saved.append(
            {
                "file": dest.name,
                "title": paper.get("title"),
                "id": paper.get("id"),
                "pmid": paper.get("pmid"),
                "publication_date": paper_date(paper),
            }
        )
        if i + 1 < len(papers):
            time.sleep(2)

    _write_manifest(args.output, saved)
    print(f"imagen done count={len(saved)} model={IMAGEN_MODEL}")
    return 0


def _write_manifest(output_dir: Path, rows: list[dict[str, Any]]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / "manifest.json"
    dest.write_text(
        json.dumps({"model": IMAGEN_MODEL, "images": rows}, ensure_ascii=False, indent=2)
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    raise SystemExit(run())
