
import json
import os
import secrets
import hashlib
import hmac

from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

ARCHIVO = os.path.join(
    os.path.dirname(__file__),
    "usuarios.json"
)

ITERACIONES = 310000


def cargar_usuarios():
    if not os.path.exists(ARCHIVO):
        return []

    try:
        with open(ARCHIVO, "r", encoding="utf-8") as archivo:
            datos = json.load(archivo)

            if isinstance(datos, list):
                return datos

            return []

    except (json.JSONDecodeError, OSError):
        return []


def guardar_usuarios(usuarios):
    temporal = ARCHIVO + ".tmp"

    with open(temporal, "w", encoding="utf-8") as archivo:
        json.dump(
            usuarios,
            archivo,
            indent=4,
            ensure_ascii=False
        )

    os.replace(temporal, ARCHIVO)


def generar_password(password):
    salt = secrets.token_hex(16)

    password_hash = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        bytes.fromhex(salt),
        ITERACIONES
    ).hex()

    return salt, password_hash


def verificar_password(password, salt, password_hash):
    nuevo_hash = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        bytes.fromhex(salt),
        ITERACIONES
    ).hex()

    return hmac.compare_digest(nuevo_hash, password_hash)


@app.route("/", methods=["GET"])
def inicio():
    return jsonify({
        "mensaje": "Servidor WHATCAINICOOK funcionando"
    }), 200


@app.route("/registrar", methods=["POST"])
def registrar():
    datos = request.get_json(silent=True)

    if not isinstance(datos, dict):
        return jsonify({
            "mensaje": "Datos JSON inválidos"
        }), 400

    nombre = str(datos.get("nombre", "")).strip()
    usuario = str(datos.get("usuario", "")).strip()
    password = datos.get("password", "")

    if not isinstance(password, str):
        return jsonify({
            "mensaje": "Contraseña inválida"
        }), 400

    if not nombre or not usuario or not password:
        return jsonify({
            "mensaje": "Completa todos los campos"
        }), 400

    if len(password) < 6:
        return jsonify({
            "mensaje": "La contraseña debe tener al menos 6 caracteres"
        }), 400

    usuarios = cargar_usuarios()

    for u in usuarios:
        if u.get("usuario", "").lower() == usuario.lower():
            return jsonify({
                "mensaje": "Ese usuario ya existe"
            }), 409

    salt, password_hash = generar_password(password)

    nuevo_usuario = {
        "nombre": nombre,
        "usuario": usuario,
        "salt": salt,
        "password_hash": password_hash
    }

    usuarios.append(nuevo_usuario)

    try:
        guardar_usuarios(usuarios)
    except OSError:
        return jsonify({
            "mensaje": "No se pudo guardar el usuario"
        }), 500

    return jsonify({
        "mensaje": "Cuenta creada correctamente"
    }), 201


@app.route("/login", methods=["POST"])
def login():
    datos = request.get_json(silent=True)

    if not isinstance(datos, dict):
        return jsonify({
            "mensaje": "Datos JSON inválidos"
        }), 400

    usuario = str(datos.get("usuario", "")).strip()
    password = datos.get("password", "")

    if not usuario or not isinstance(password, str) or not password:
        return jsonify({
            "mensaje": "Completa usuario y contraseña"
        }), 400

    usuarios = cargar_usuarios()

    for u in usuarios:
        if u.get("usuario", "").lower() == usuario.lower():

            salt = u.get("salt")
            password_hash = u.get("password_hash")

            if not salt or not password_hash:
                break

            if verificar_password(password, salt, password_hash):
                return jsonify({
                    "mensaje": "Inicio de sesión correcto",
                    "nombre": u.get("nombre", usuario)
                }), 200

            break

    return jsonify({
        "mensaje": "Usuario o contraseña incorrectos"
    }), 401


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)
