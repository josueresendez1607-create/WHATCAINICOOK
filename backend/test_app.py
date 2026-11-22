"""Pruebas del backend con Gemini simulado.

No se usa ni se imprime la clave real: se sustituye por un valor de prueba
y se parchean todas las llamadas HTTP salientes.
"""

import io
import json
import os
import sys
import unittest
from unittest.mock import patch

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import app as backend_app  # noqa: E402


class FakeResponse:
    def __init__(self, payload, status_code=200, text=""):
        self._payload = payload
        self.status_code = status_code
        self.text = text

    def json(self):
        return self._payload


def gemini_text_response(text):
    return FakeResponse(
        {
            "modelVersion": "gemini-3.8-flash",
            "candidates": [
                {"content": {"parts": [{"text": text}]}}
            ],
        }
    )


class BackendTestCase(unittest.TestCase):
    def setUp(self):
        backend_app.app.config.update(TESTING=True)
        self.client = backend_app.app.test_client()

    def test_health_reports_endpoints_and_catalog(self):
        response = self.client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertEqual(body["status"], "ok")
        self.assertEqual(body["model"], "gemini-3.8-flash")
        self.assertGreater(body["recipesAvailable"], 0)
        self.assertEqual(body["recipesEndpoint"], "/api/recipes")
        self.assertEqual(body["generateEndpoint"], "/api/recipes/generate")

    def test_list_recipes_filters_and_limits(self):
        response = self.client.get("/api/recipes?category=desayuno&limit=2")
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertLessEqual(len(body["recipes"]), 2)
        self.assertTrue(
            all("desayuno" in recipe["tags"] for recipe in body["recipes"])
        )
        self.assertEqual(body["total"], len(backend_app.RECIPES))

    def test_get_recipe_detail_and_missing_id(self):
        recipe_id = backend_app.RECIPES[0]["id"]
        response = self.client.get(f"/api/recipes/{recipe_id}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["id"], recipe_id)

        response = self.client.get("/api/recipes/no-existe")
        self.assertEqual(response.status_code, 404)

    def test_generate_without_gemini_uses_local_ranking(self):
        with patch.object(backend_app, "API_KEY", ""):
            response = self.client.post(
                "/api/recipes/generate",
                json={"ingredients": ["tomate", "frijol"], "count": 3},
            )
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertEqual(body["mode"], "local")
        self.assertTrue(body["verifiedOnly"])
        self.assertLessEqual(len(body["recipes"]), 3)
        valid_ids = {recipe["id"] for recipe in backend_app.RECIPES}
        self.assertTrue(set(body["selected"]).issubset(valid_ids))
        self.assertTrue(all(recipe["id"] in valid_ids for recipe in body["recipes"]))

    def test_generate_accepts_only_catalog_ids_from_gemini(self):
        first_id = backend_app.RECIPES[0]["id"]
        second_id = backend_app.RECIPES[1]["id"]
        fake_text = json.dumps(
            {
                "selected": [first_id, "receta-inventada", second_id],
                "reasons": {first_id: "Buena coincidencia"},
            }
        )
        with patch.object(backend_app, "API_KEY", "test-key"), patch.object(
            backend_app.requests, "post", return_value=gemini_text_response(fake_text)
        ):
            response = self.client.post(
                "/api/recipes/generate",
                json={"ingredients": ["tomate"], "count": 2},
            )

        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertEqual(body["mode"], "gemini")
        self.assertEqual(body["selected"], [first_id, second_id])
        self.assertEqual(body["reasons"][first_id], "Buena coincidencia")
        self.assertTrue(all(recipe["id"] in body["selected"] for recipe in body["recipes"]))

    def test_generate_rejects_invalid_payload_and_filters(self):
        response = self.client.post(
            "/api/recipes/generate", json={"ingredients": "tomate"}
        )
        self.assertEqual(response.status_code, 400)

        response = self.client.post(
            "/api/recipes/generate",
            json={
                "ingredients": ["tomate"],
                "filters": ["categoria-que-no-existe"],
            },
        )
        self.assertEqual(response.status_code, 422)

    def test_vision_requires_image_and_supported_mime(self):
        with patch.object(backend_app, "API_KEY", "test-key"):
            response = self.client.post("/api/vision/ingredients")
        self.assertEqual(response.status_code, 400)

        data = {"image": (io.BytesIO(b"fake-image"), "test.txt", "text/plain")}
        with patch.object(backend_app, "API_KEY", "test-key"):
            response = self.client.post(
                "/api/vision/ingredients", data=data, content_type="multipart/form-data"
            )
        self.assertEqual(response.status_code, 400)

    def test_vision_returns_normalized_ingredients(self):
        fake_text = json.dumps(
            {
                "ingredients": [
                    {"name": "Tomate", "confidence": 0.91},
                    {"name": "", "confidence": 0.4},
                ]
            }
        )
        data = {
            "image": (io.BytesIO(b"\xff\xd8\xfffakejpeg"), "test.jpg", "image/jpeg")
        }
        with patch.object(backend_app, "API_KEY", "test-key"), patch.object(
            backend_app.requests, "post", return_value=gemini_text_response(fake_text)
        ):
            response = self.client.post(
                "/api/vision/ingredients", data=data, content_type="multipart/form-data"
            )

        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertEqual(body["ingredients"], [{"name": "Tomate", "confidence": 0.91}])
        self.assertIn("revisa", body["warning"].lower())

    def test_vision_without_key_returns_503(self):
        data = {
            "image": (io.BytesIO(b"\xff\xd8\xfffakejpeg"), "test.jpg", "image/jpeg")
        }
        with patch.object(backend_app, "API_KEY", ""):
            response = self.client.post(
                "/api/vision/ingredients", data=data, content_type="multipart/form-data"
            )
        self.assertEqual(response.status_code, 503)


if __name__ == "__main__":
    unittest.main()
