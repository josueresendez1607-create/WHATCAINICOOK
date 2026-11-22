@echo off
setlocal

set "ADB=C:\Users\josue\AppData\Local\Android\Sdk\platform-tools\adb.exe"
set "APK=%~dp0releases\WHATCANICOOK.apk"

echo.
echo === WHATCANICOOK - Instalacion por cable USB ===
echo 1) Activa "Opciones de desarrollador" y "Depuracion USB" en el telefono.
echo 2) Conecta el cable USB y acepta la autorizacion de depuracion.
echo.

"%ADB%" wait-for-device
if errorlevel 1 goto :error

echo Redirigiendo el backend del PC al telefono por USB (localhost:5000)...
"%ADB%" reverse tcp:5000 tcp:5000
if errorlevel 1 goto :error

echo Instalando %APK% ...
"%ADB%" install -r "%APK%"
if errorlevel 1 goto :error

echo Iniciando WHATCANICOOK...
"%ADB%" shell monkey -p com.whatcanicook.app -c android.intent.category.LAUNCHER 1
if errorlevel 1 goto :error

echo.
echo Listo. La app usa el backend del PC a traves del cable.
echo Para ver logs en vivo:
echo   "%ADB%" logcat ^| findstr flutter
echo.
pause
exit /b 0

:error
echo.
echo Ocurrio un error. Verifica el cable, la depuracion USB y que el backend este corriendo.
echo El backend debe estar activo en http://127.0.0.1:5000 en esta PC.
pause
exit /b 1
