"""Backend seguro para WHATCANICOOK.

La clave de Gemini se lee SOLO desde variables de entorno del servidor.
Nunca se envía al APK ni se guarda en el repositorio.

Endpoints:
    GET  /api/health
    POST /api/vision/ingredients
    GET  /api/recipes
    GET  /api/recipes/<id>
    POST /api/recipes/generate

La generación asistida por IA NUNCA inventa recetas: Gemini únicamente ordena
y selecciona IDs del catálogo oficial verificado. El backend valida cada ID y
devuelve la receta completa desde el catálogo local.
"""

import base64
import json
import os
import re
import unicodedata
from typing import Any, Dict, List, Tuple

import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(BASE_DIR)
load_dotenv(os.path.join(BASE_DIR, ".env"))
load_dotenv(os.path.join(PROJECT_DIR, ".env"))

API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
MODEL_FROM_ENV = os.getenv("GEMINI_MODEL", "").strip()
MODEL = MODEL_FROM_ENV or "gemini-3.8-flash"
MODEL_SOURCE = "env" if MODEL_FROM_ENV else "default"
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").strip()
MAX_IMAGE_BYTES = 12 * 1024 * 1024
ALLOWED_MIMES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}
RECIPES_PATH = os.path.join(PROJECT_DIR, "assets", "data", "recipes.json")

GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"{MODEL}:generateContent"
)

SYSTEM_INSTRUCTION = (
    "Eres un asistente de cocina. Analiza la imagen y devuelve SOLO un objeto JSON válido. "
    "El objeto debe tener la forma: "
    '{"ingredients":[{"name":"texto en español","confidence":0.0}]}. '
    "Incluye únicamente alimentos claramente visibles. No inventes cantidades exactas, "
    "fechas de caducidad, marcas ni valores nutricionales. No incluyas texto explicativo, "
    "bloques de código ni Markdown. confidence debe ser un número entre 0 y 1."
)

RANKING_SYSTEM_INSTRUCTION = (
    "Eres un seleccionador de recetas. Trabajas SOLO con un catálogo cerrado de recetas "
    "verificadas. NUNCA inventes recetas, nombres, tiempos ni ingredientes. "
    "Devuelve SOLO un objeto JSON válido con la forma: "
    '{"selected":["id1","id2"],"reasons":{"id1":"razón breve en español"}}. '
    "selected debe contener únicamente IDs que aparezcan en la lista proporcionada, "
    "sin duplicados, ordenados de mejor a peor. No incluyas Markdown ni texto explicativo."
)

app = Flask(__name__)
if CORS_ORIGINS == "*":
    CORS(app)
else:
    CORS(app, origins=[origin.strip() for origin in CORS_ORIGINS.split(",")])


def _load_recipes() -> List[Dict[str, Any]]:
    try:
        with open(RECIPES_PATH, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return []
    recipes = data.get("recipes", [])
    return [item for item in recipes if isinstance(item, dict)]


RECIPES = _load_recipes()
RECIPE_BY_ID = {str(item.get("id", "")): item for item in RECIPES}


def _error(message: str, status: int = 400, **extra: Any):
    payload: Dict[str, Any] = {"error": message}
    payload.update(extra)
    return jsonify(payload), status


def _extract_json(text: str) -> Dict[str, Any]:
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    parsed = json.loads(cleaned)
    if not isinstance(parsed, dict):
        raise ValueError("La respuesta de IA no es un objeto JSON.")
    return parsed


def _normalize(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(char for char in text if not unicodedata.combining(char))
    text = text.lower().replace("_", " ")
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def _tokens(value: Any) -> set:
    return {token for token in _normalize(value).split() if len(token) > 2}


def _total_minutes(recipe: Dict[str, Any]) -> int:
    prep = recipe.get("prepMinutes") or 0
    cook = recipe.get("cookMinutes") or 0
    return int(prep) + int(cook) if isinstance(prep, int) and isinstance(cook, int) else 9999


def _matches_filter(recipe: Dict[str, Any], filters: List[str]) -> bool:
    if not filters:
        return True
    tags = {str(tag) for tag in recipe.get("tags", [])}
    wanted = {_normalize(item).replace(" ", "_") for item in filters}
    if tags & wanted:
        return True
    if "rapida" in wanted and _total_minutes(recipe) <= 20:
        return True
    return False


def _ingredient_tokens(raw_ingredients: Any) -> Tuple[set, List[str]]:
    """Convierte la entrada Flutter en tokens y nombres limpios."""
    tokens: set = set()
    names: List[str] = []

    if not isinstance(raw_ingredients, list):
        return tokens, names

    for item in raw_ingredients:
        if isinstance(item, str):
            name = item.strip()
            key = ""
        elif isinstance(item, dict):
            name = str(item.get("name", "")).strip()
            key = str(item.get("key", "")).strip()
        else:
            continue

        if not name and not key:
            continue
        if len(name) > 80 or len(key) > 80:
            continue
        if name:
            names.append(name)
        if key:
            tokens.add(_normalize(key))
            tokens.update(_tokens(key))
        if name:
            tokens.add(_normalize(name))
            tokens.update(_tokens(name))

    # Deduplica nombres conservando el orden.
    unique_names: List[str] = []
    seen = set()
    for name in names:
        marker = _normalize(name)
        if marker and marker not in seen:
            seen.add(marker)
            unique_names.append(name)
    return tokens, unique_names


def _score_recipe(recipe: Dict[str, Any], available_tokens: set) -> Tuple[int, int, int]:
    keys = {
        str(item.get("key", ""))
        for item in recipe.get("ingredients", [])
        if isinstance(item, dict) and item.get("key")
    }
    matched = 0
    for key in keys:
        normalized = _normalize(key)
        if normalized in available_tokens or (_tokens(key) & available_tokens):
            matched += 1
    missing = len(keys) - matched
    return matched, missing, _total_minutes(recipe)


def _rank_local(candidates: List[Dict[str, Any]], available_tokens: set) -> List[str]:
    scored = []
    for recipe in candidates:
        matched, missing, minutes = _score_recipe(recipe, available_tokens)
        scored.append((-matched, missing, minutes, str(recipe.get("id", ""))))
    scored.sort()
    return [item[3] for item in scored if item[3]]


def _recipe_summaries(recipes: List[Dict[str, Any]], limit: int) -> List[Dict[str, Any]]:
    summaries = []
    for recipe in recipes[:limit]:
        summaries.append(
            {
                "id": recipe.get("id", ""),
                "title": recipe.get("title", ""),
                "description": recipe.get("description", ""),
                "tags": recipe.get("tags", []),
                "minutes": _total_minutes(recipe),
                "ingredients": [
                    str(item.get("key", ""))
                    for item in recipe.get("ingredients", [])
                    if isinstance(item, dict) and item.get("key")
                ],
            }
        )
    return summaries


def _gemini_select(
    candidates: List[Dict[str, Any]], names: List[str], count: int
) -> Tuple[List[str], Dict[str, str], str]:
    """Pide a Gemini que seleccione IDs del catálogo. Nunca inventa recetas."""
    if not API_KEY:
        return [], {}, "Gemini no está configurado en el servidor."

    payload = {
        "systemInstruction": {"parts": [{"text": RANKING_SYSTEM_INSTRUCTION}]},
        "contents": [
            {
                "parts": [
                    {
                        "text": (
                            "Ingredientes disponibles: "
                            + (", ".join(names) if names else "ninguno")
                            + ". Selecciona hasta "
                            + str(count)
                            + " recetas del siguiente catálogo cerrado, ordenadas por "
                            "adecuación a esos ingredientes: "
                            + json.dumps(
                                _recipe_summaries(candidates, len(candidates)),
                                ensure_ascii=False,
                            )
                        )
                    }
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json",
            "maxOutputTokens": 1024,
        },
    }

    try:
        response = requests.post(
            GEMINI_URL,
            headers={
                "x-goog-api-key": API_KEY,
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=15,
        )
    except requests.RequestException as exc:
        return [], {}, f"No se pudo contactar a Gemini: {type(exc).__name__}"

    if response.status_code != 200:
        return [], {}, f"Gemini devolvió HTTP {response.status_code}."

    try:
        body = response.json()
        text = body["candidates"][0]["content"]["parts"][0]["text"]
        parsed = _extract_json(text)
    except (KeyError, IndexError, TypeError, ValueError, json.JSONDecodeError) as exc:
        return [], {}, f"No se pudo interpretar la selección de Gemini: {exc}"

    raw_selected = parsed.get("selected") or parsed.get("recipeIds") or []
    if not isinstance(raw_selected, list):
        return [], {}, "Gemini no devolvió una lista de IDs."

    valid_ids = {str(recipe.get("id", "")) for recipe in candidates}
    selected: List[str] = []
    for value in raw_selected:
        recipe_id = str(value).strip()
        if recipe_id in valid_ids and recipe_id not in selected:
            selected.append(recipe_id)
        if len(selected) >= count:
            break

    raw_reasons = parsed.get("reasons") or {}
    reasons: Dict[str, str] = {}
    if isinstance(raw_reasons, dict):
        for recipe_id, reason in raw_reasons.items():
            key = str(recipe_id).strip()
            if key in selected:
                reasons[key] = str(reason).strip()[:180]

    model = str(body.get("modelVersion") or MODEL)
    if not selected:
        return [], reasons, "Gemini no devolvió IDs válidos del catálogo."
    return selected, reasons, model


@app.get("/api/health")
def health():
    return jsonify(
        {
            "status": "ok",
            "integration": "ready" if API_KEY else "api_key_missing",
            "aiConfigured": bool(API_KEY),
            "model": MODEL,
            "modelSource": MODEL_SOURCE,
            "recipesAvailable": len(RECIPES),
            "visionEndpoint": "/api/vision/ingredients",
            "recipesEndpoint": "/api/recipes",
            "generateEndpoint": "/api/recipes/generate",
            "geminiApi": GEMINI_URL,
        }
    )


@app.post("/api/vision/ingredients")
def analyze_ingredients():
    if not API_KEY:
        return _error(
            "El backend no tiene GEMINI_API_KEY configurada. "
            "Copia .env.example a .env y agrega la clave del servidor.",
            503,
        )

    upload = request.files.get("image")
    if upload is None or not upload.filename:
        return _error("Falta la imagen en el campo 'image'.")

    declared_mime = (upload.mimetype or "").lower().split(";")[0].strip()
    head = upload.stream.read(12)
    upload.stream.seek(0)

    detected_mime = ""
    if head.startswith(b"\xff\xd8\xff"):
        detected_mime = "image/jpeg"
    elif head.startswith(b"\x89PNG\r\n\x1a\n"):
        detected_mime = "image/png"
    elif head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        detected_mime = "image/webp"
    elif len(head) >= 12 and head[4:8] == b"ftyp" and head[8:12] in {
        b"heic",
        b"heix",
        b"hevc",
        b"hevx",
        b"mif1",
        b"msf1",
    }:
        detected_mime = "image/heic"

    mime = detected_mime or declared_mime
    if mime == "image/jpg":
        mime = "image/jpeg"
    if mime not in ALLOWED_MIMES:
        return _error("Formato no soportado. Usa JPEG, PNG o WebP.")

    raw = upload.read()
    if not raw:
        return _error("La imagen está vacía.")
    if len(raw) > MAX_IMAGE_BYTES:
        return _error("La imagen supera el límite de 12 MB.", 413)

    payload = {
        "systemInstruction": {"parts": [{"text": SYSTEM_INSTRUCTION}]},
        "contents": [
            {
                "parts": [
                    {"text": "Identifica los ingredientes visibles en esta imagen."},
                    {
                        "inline_data": {
                            "mime_type": mime,
                            "data": base64.b64encode(raw).decode("ascii"),
                        }
                    },
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json",
        },
    }

    try:
        response = requests.post(
            GEMINI_URL,
            headers={
                "x-goog-api-key": API_KEY,
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=45,
        )
    except requests.RequestException as exc:
        return _error(f"No se pudo contactar a Gemini: {type(exc).__name__}", 502)

    if response.status_code != 200:
        return _error(
            "Gemini rechazó la solicitud.",
            502,
            upstream_status=response.status_code,
            detail=str(response.text)[:300],
        )

    try:
        body = response.json()
        text = body["candidates"][0]["content"]["parts"][0]["text"]
        parsed = _extract_json(text)
        items = parsed.get("ingredients", [])
        if not isinstance(items, list):
            raise ValueError("Formato de ingredientes inválido.")
        clean_items = []
        for item in items:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name", "")).strip()
            if not name:
                continue
            confidence = item.get("confidence", 0.5)
            try:
                confidence = max(0.0, min(1.0, float(confidence)))
            except (TypeError, ValueError):
                confidence = 0.5
            clean_items.append({"name": name[:80], "confidence": confidence})
    except (KeyError, IndexError, ValueError, TypeError, json.JSONDecodeError) as exc:
        return _error(f"No se pudo interpretar la respuesta de IA: {exc}", 500)

    return jsonify(
        {
            "model": body.get("modelVersion", MODEL),
            "ingredients": clean_items,
            "warning": "La IA puede equivocarse. Revisa y corrige la lista antes de continuar.",
        }
    )


@app.get("/api/recipes")
def list_recipes():
    query = _normalize(request.args.get("q", ""))
    category = _normalize(request.args.get("category", "")).replace(" ", "_")
    try:
        limit = int(request.args.get("limit", str(len(RECIPES))))
    except (TypeError, ValueError):
        return _error("El parámetro 'limit' debe ser un número entero.")
    limit = max(1, min(limit, 100))

    filtered = []
    for recipe in RECIPES:
        if category and category not in {str(tag) for tag in recipe.get("tags", [])}:
            continue
        if query:
            haystack = " ".join(
                [
                    str(recipe.get("title", "")),
                    str(recipe.get("description", "")),
                    " ".join(str(tag) for tag in recipe.get("tags", [])),
                    " ".join(
                        str(item.get("key", ""))
                        for item in recipe.get("ingredients", [])
                        if isinstance(item, dict)
                    ),
                ]
            )
            if query not in _normalize(haystack):
                continue
        filtered.append(recipe)

    return jsonify(
        {
            "count": len(filtered[:limit]),
            "total": len(RECIPES),
            "recipes": filtered[:limit],
        }
    )


@app.get("/api/recipes/<recipe_id>")
def get_recipe(recipe_id: str):
    recipe = RECIPE_BY_ID.get(recipe_id)
    if recipe is None:
        return _error("No existe una receta verificada con ese ID.", 404)
    return jsonify(recipe)


@app.post("/api/recipes/generate")
def generate_recipes():
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return _error("Se espera un objeto JSON.")

    raw_ingredients = body.get("ingredients", [])
    if not isinstance(raw_ingredients, list):
        return _error("'ingredients' debe ser una lista.")
    if len(raw_ingredients) > 50:
        return _error("Máximo 50 ingredientes por solicitud.", 413)

    try:
        count = int(body.get("count", 5))
    except (TypeError, ValueError):
        return _error("'count' debe ser un número entero.")
    count = max(1, min(count, len(RECIPES) or 1))

    raw_filters = body.get("filters", [])
    if not isinstance(raw_filters, list):
        return _error("'filters' debe ser una lista.")
    filters = [str(item).strip() for item in raw_filters if str(item).strip()][:20]
    if len(filters) > 20:
        return _error("Máximo 20 filtros por solicitud.", 413)

    candidates = [recipe for recipe in RECIPES if _matches_filter(recipe, filters)]
    if not candidates:
        return _error(
            "No hay recetas verificadas para esa combinación de filtros.",
            422,
            totalCandidates=0,
        )

    tokens, names = _ingredient_tokens(raw_ingredients)
    local_order = _rank_local(candidates, tokens)

    # Limitar candidatos enviados a Gemini para reducir latencia.
    gemini_pool_ids = set(local_order[:30])
    gemini_candidates = [r for r in candidates if r.get("id") in gemini_pool_ids]
    if not gemini_candidates:
        gemini_candidates = candidates[:30]

    selected, reasons, gemini_note = _gemini_select(gemini_candidates, names, count)
    mode = "gemini" if selected else "local"
    filled_locally: List[str] = []
    for recipe_id in local_order:
        if len(selected) >= count:
            break
        if recipe_id not in selected:
            selected.append(recipe_id)
            filled_locally.append(recipe_id)

    chosen = [RECIPE_BY_ID[recipe_id] for recipe_id in selected if recipe_id in RECIPE_BY_ID]
    warning = (
        "Gemini seleccionó parte del catálogo; el resto se completó con ranking local."
        if filled_locally
        else "Selección local sobre el catálogo verificado."
        if mode == "local"
        else None
    )
    if gemini_note and mode == "local":
        warning = f"{gemini_note} {warning}"

    return jsonify(
        {
            "mode": mode,
            "model": gemini_note if mode == "gemini" else None,
            "selected": selected,
            "recipes": chosen,
            "reasons": reasons,
            "filledLocally": filled_locally,
            "totalCandidates": len(candidates),
            "verifiedOnly": True,
            "warning": warning,
        }
    )


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.getenv("PORT", "5000")),
        debug=os.getenv("FLASK_DEBUG", "0") == "1",
    )
