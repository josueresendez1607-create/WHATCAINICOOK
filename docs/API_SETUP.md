# Configuración de la API de IA

El escaneo de ingredientes usa Gemini desde un **backend propio**. La clave nunca viaja dentro de la app ni se sube al repositorio.

## 1. Obtener la clave

1. Entra en [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Inicia sesión con tu cuenta de Google.
3. Crea una API key y cópiala.
4. Guárdala solo en tu máquina. **No la pegues en GitHub, Flutter, correos ni capturas.**

> El modelo por defecto es `gemini-3.8-flash`. Si Google cambia los nombres de modelo, ajusta `GEMINI_MODEL` en `.env` según la documentación oficial.

## 2. Archivo `.env`

Desde la raíz del proyecto:

```powershell
copy .env.example .env
```

Edita `.env`:

```dotenv
WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000
GEMINI_API_KEY=TU_CLAVE_REAL_AQUI
GEMINI_MODEL=gemini-3.8-flash
CORS_ORIGINS=*
```

- `WHATCANICOOK_API_BASE_URL`: lo usa **Flutter** al compilar/ejecutar.
- `GEMINI_API_KEY`: lo usa **solo el backend**.
- `.env` está ignorado por Git; no se sube.

## 3. Ejecutar el backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

El servidor escucha en `http://0.0.0.0:5000`.

Comprobación rápida:

```powershell
curl http://127.0.0.1:5000/api/health
```

Respuesta esperada cuando la clave está configurada:

```json
{"aiConfigured":true,"model":"gemini-3.8-flash","status":"ok"}
```

## 4. Ejecutar Flutter contra el backend

### Emulador Android

El emulador ve tu PC como `10.0.2.2`:

```powershell
flutter run --dart-define=WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000
```

### Dispositivo físico en la misma Wi-Fi

Obtén la IP de tu PC (`ipconfig`) y usa HTTP solo en desarrollo local:

```powershell
flutter run --dart-define=WHATCANICOOK_API_BASE_URL=http://192.168.1.10:5000
```

Android requiere tráfico claro permitido para HTTP; el manifest debug de este proyecto ya lo habilita. Para una build release en dispositivo físico, usa HTTPS o configura `networkSecurityConfig` de forma controlada.

### Producción

Publica el backend detrás de HTTPS y compila con:

```powershell
flutter build apk --release --dart-define=WHATCANICOOK_API_BASE_URL=https://tu-dominio-seguro.example
```

## 5. Endpoints

| Método | Ruta | Descripción |
| --- | --- | --- |
| `GET` | `/api/health` | Estado del backend e indicador `aiConfigured` |
| `POST` | `/api/vision/ingredients` | Recibe `multipart/form-data` con el campo `image` (JPEG/PNG/WebP, máx. 12 MB) y devuelve `{ingredients:[{name, confidence}], warning}` |

El prompt del backend pide **únicamente JSON** con nombres de alimentos visibles. No se solicitan cantidades exactas, marcas, caducidades ni nutrición a la IA.

## 6. CORS

En desarrollo, `CORS_ORIGINS=*` es suficiente. En producción, reemplázalo por orígenes explícitos:

```dotenv
CORS_ORIGINS=https://tu-dominio-seguro.example
```

## 7. Problemas comunes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| La app dice “IA no configurada” | Falta `GEMINI_API_KEY` o el backend no está corriendo | Revisa `.env`, reinicia Flask y verifica `/api/health` |
| `Connection refused` en emulador | URL incorrecta | Usa `http://10.0.2.2:5000` |
| `Connection refused` en dispositivo | PC y teléfono en redes distintas o firewall | Misma Wi-Fi; abre el puerto 5000 en el firewall |
| Gemini responde 400/403 | Clave inválida, modelo inexistente o cuota agotada | Revisa la clave, `GEMINI_MODEL` y la consola de Google AI Studio |
| La IA se equivoca al detectar | Oclusión, luz o empaque poco claro | La app permite corregir la lista antes de continuar; usa esa corrección |
