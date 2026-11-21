"""Backend seguro para WHATCANICOOK.

La clave de Gemini se lee SOLO desde variables de entorno del servidor.
Nunca se envía al APK ni se guarda en el repositorio.

Uso local:
    python -m venv .venv
    .venv\\Scripts\\activate
    pip install -r requirements.txt
    copy ..\\.env.example .env
    # editar .env y pegar la clave real
    python app.py
"""

import base64
import json
import os
import re
from typing import Any, Dict

import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))
load_dotenv(os.path.join(os.path.dirname(BASE_DIR), ".env"))

API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
MODEL = os.getenv("GEMINI_MODEL", "gemini-3.8-flash").strip()
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").strip()
MAX_IMAGE_BYTES = 12 * 1024 * 1024
ALLOWED_MIMES = {"image/jpeg", "image/png", "image/webp"}

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

app = Flask(__name__)
if CORS_ORIGINS == "*":
    CORS(app)
else:
    CORS(app, origins=[origin.strip() for origin in CORS_ORIGINS.split(",")])


def _extract_json(text: str) -> Dict[str, Any]:
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    return json.loads(cleaned)


@app.get("/api/health")
def health():
    return jsonify(
        {
            "status": "ok",
            "aiConfigured": bool(API_KEY),
            "model": MODEL,
        }
    )


@app.post("/api/vision/ingredients")
def analyze_ingredients():
    if not API_KEY:
        return jsonify(
            {
                "error": "El backend no tiene GEMINI_API_KEY configurada. "
                "Copia .env.example a .env y agrega la clave del servidor."
            }
        ), 503

    upload = request.files.get("image")
    if upload is None or not upload.filename:
        return jsonify({"error": "Falta la imagen en el campo 'image'."}), 400

    mime = upload.mimetype or ""
    if mime not in ALLOWED_MIMES:
        return jsonify({"error": "Formato no soportado. Usa JPEG, PNG o WebP."}), 400

    raw = upload.read()
    if not raw:
        return jsonify({"error": "La imagen está vacía."}), 400
    if len(raw) > MAX_IMAGE_BYTES:
        return jsonify({"error": "La imagen supera el límite de 12 MB."}), 413

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
        return jsonify({"error": f"No se pudo contactar a Gemini: {exc}"}), 502

    if response.status_code != 200:
        return jsonify(
            {
                "error": "Gemini rechazó la solicitud.",
                "detail": response.text[:400],
                "status": response.status_code,
            }
        ), 502

    try:
        body = response.json()
        text = body["candidates"][0]["content"]["parts"][0]["text"]
        parsed = _extract_json(text)
        items = parsed.get("ingredients", [])
        clean_items = []
        for item in items:
            name = str(item.get("name", "")).strip()
            if not name:
                continue
            confidence = item.get("confidence", 0.5)
            try:
                confidence = max(0.0, min(1.0, float(confidence)))
            except (TypeError, ValueError):
                confidence = 0.5
            clean_items.append({"name": name, "confidence": confidence})
    except (KeyError, IndexError, ValueError, json.JSONDecodeError) as exc:
        return jsonify({"error": f"No se pudo interpretar la respuesta de IA: {exc}"}), 500

    return jsonify(
        {
            "model": body.get("modelVersion", MODEL),
            "ingredients": clean_items,
            "warning": "La IA puede equivocarse. Revisa y corrige la lista antes de continuar.",
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")), debug=True)
