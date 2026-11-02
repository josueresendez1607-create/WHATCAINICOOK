import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MiAplicacion());
}

// ============================================================
//  SERVICIO DE USUARIOS: guarda en usuarios.json + encriptación
// ============================================================
class ServicioUsuarios {
  static const String _claveWeb = 'usuarios_json';

  // ---------- Archivo JSON ----------
  // En Android / Windows: archivo usuarios.json real.
  // En Web (navegador no permite archivos): se guarda el mismo JSON
  // en el almacenamiento local del navegador.
  static Future<File> _archivo() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}usuarios.json');
  }

  static Future<List<Map<String, dynamic>>> _leerUsuarios() async {
    try {
      String contenido;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        contenido = prefs.getString(_claveWeb) ?? '';
      } else {
        final archivo = await _archivo();
        if (!await archivo.exists()) return [];
        contenido = await archivo.readAsString();
      }
      if (contenido.trim().isEmpty) return [];
      final datos = jsonDecode(contenido) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(datos['usuarios'] as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _guardarUsuarios(
      List<Map<String, dynamic>> usuarios) async {
    final contenido =
    const JsonEncoder.withIndent('  ').convert({'usuarios': usuarios});
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveWeb, contenido);
    } else {
      final archivo = await _archivo();
      await archivo.writeAsString(contenido);
    }
  }

  // ---------- Encriptación (SHA-256 + salt) ----------
  static String _generarSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hash(String password, String salt) {
    List<int> resultado = utf8.encode('$salt$password');
    // 1000 iteraciones para hacerlo más difícil de adivinar
    for (var i = 0; i < 1000; i++) {
      resultado = sha256.convert(resultado).bytes;
    }
    return base64UrlEncode(resultado);
  }

  // ---------- Registro ----------
  /// Devuelve null si todo salió bien, o el mensaje de error.
  static Future<String?> registrar(
      String nombre, String usuario, String password) async {
    final usuarios = await _leerUsuarios();
    final existe = usuarios.any(
            (u) => (u['usuario'] as String).toLowerCase() == usuario.toLowerCase());
    if (existe) return 'Ese usuario ya está registrado';

    final salt = _generarSalt();
    usuarios.add({
      'nombre': nombre,
      'usuario': usuario,
      'salt': salt,
      'password': _hash(password, salt), // nunca se guarda en texto plano
    });
    await _guardarUsuarios(usuarios);
    return null;
  }

  // ---------- Inicio de sesión ----------
  /// Devuelve el nombre del usuario si es correcto, o null si falla.
  static Future<String?> iniciarSesion(String usuario, String password) async {
    final usuarios = await _leerUsuarios();
    for (final u in usuarios) {
      if ((u['usuario'] as String).toLowerCase() == usuario.toLowerCase()) {
        final hashIngresado = _hash(password, u['salt'] as String);
        if (hashIngresado == u['password']) {
          return u['nombre'] as String;
        }
      }
    }
    return null;
  }
}

// ===== CLASE 1: Solo pone el MaterialApp =====
class MiAplicacion extends StatelessWidget {
  const MiAplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PantallaLogin(),
    );
  }
}

// ============================================================
//  PANTALLA DE INICIO DE SESIÓN
// ============================================================
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool ocultarPassword = true;
  bool cargando = false;

  @override
  void dispose() {
    usuarioController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final usuario = usuarioController.text.trim();
    final password = passwordController.text;

    if (usuario.isEmpty || password.isEmpty) {
      _mensaje('Completa usuario y contraseña');
      return;
    }

    setState(() => cargando = true);
    final nombre = await ServicioUsuarios.iniciarSesion(usuario, password);
    if (!mounted) return;
    setState(() => cargando = false);

    if (nombre == null) {
      _mensaje('Usuario o contraseña incorrectos');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaPrincipal(nombre: nombre),
      ),
    );
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: ocultarPassword,
                  onSubmitted: (_) => _iniciarSesion(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(ocultarPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => ocultarPassword = !ocultarPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cargando ? null : _iniciarSesion,
                    child: cargando
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaRegistro(),
                      ),
                    );
                  },
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  PANTALLA DE REGISTRO
// ============================================================
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmarController = TextEditingController();
  bool ocultarPassword = true;
  bool cargando = false;

  @override
  void dispose() {
    nombreController.dispose();
    usuarioController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final nombre = nombreController.text.trim();
    final usuario = usuarioController.text.trim();
    final password = passwordController.text;
    final confirmar = confirmarController.text;

    if (nombre.isEmpty || usuario.isEmpty || password.isEmpty) {
      _mensaje('Completa todos los campos');
      return;
    }
    if (password.length < 6) {
      _mensaje('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (password != confirmar) {
      _mensaje('Las contraseñas no coinciden');
      return;
    }

    setState(() => cargando = true);
    final error = await ServicioUsuarios.registrar(nombre, usuario, password);
    if (!mounted) return;
    setState(() => cargando = false);

    if (error != null) {
      _mensaje(error);
      return;
    }

    _mensaje('Cuenta creada. Ya puedes iniciar sesión');
    Navigator.pop(context);
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrarse'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: ocultarPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña (mínimo 6 caracteres)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(ocultarPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => ocultarPassword = !ocultarPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: confirmarController,
                  obscureText: ocultarPassword,
                  onSubmitted: (_) => _registrar(),
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cargando ? null : _registrar,
                    child: cargando
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Crear cuenta'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== CLASE 2: La pantalla principal =====
class PantallaPrincipal extends StatefulWidget {
  final String nombre;

  const PantallaPrincipal({super.key, required this.nombre});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal>
    with SingleTickerProviderStateMixin {
  late AnimationController controlador;
  final TextEditingController textoController = TextEditingController();

  bool notificacionesActivadas = true;

  @override
  void initState() {
    super.initState();
    controlador = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    controlador.dispose();
    textoController.dispose();
    super.dispose();
  }

  void _cerrarSesion() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PantallaLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Text('Mi primera aplicación'),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenido, ${widget.nombre}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // ============ STACK ============
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/imagen.jpg',
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '¡Hola Mundo!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              RotationTransition(
                turns: controlador,
                child: const Text(
                  '¡Hola Mundo!',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              TextField(
                controller: textoController,
                decoration: const InputDecoration(
                  labelText: 'Escribe tu nombre',
                  hintText: 'Ejemplo: Josue',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),

              const SizedBox(height: 15),

              // ============ BOTÓN SALUDAR + ALERTA ============
              ElevatedButton(
                onPressed: () {
                  String nombre = textoController.text;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        nombre.isEmpty
                            ? 'No escribiste ningún nombre'
                            : 'Hola, $nombre',
                      ),
                    ),
                  );

                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext ctx) {
                      return CupertinoAlertDialog(
                        title: const Text('Aviso importante'),
                        content: const Text('ALERTAAAAAAA'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Saludar'),
              ),

              const SizedBox(height: 20),

              // ============ CUPERTINO: SWITCH ============
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Notificaciones: '),
                  CupertinoSwitch(
                    value: notificacionesActivadas,
                    onChanged: (bool valor) {
                      setState(() {
                        notificacionesActivadas = valor;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ============ CUPERTINO: BOTÓN + ALERTA ============
              CupertinoButton(
                color: CupertinoColors.activeBlue,
                onPressed: () {
                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext ctx) {
                      return CupertinoAlertDialog(
                        title: const Text('Aviso importante'),
                        content: const Text('ALERTAAAAAAA'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text(
                  'Botón Cupertino',
                  style: TextStyle(color: Colors.white),
                ),
              ),

              const SizedBox(height: 15),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SegundaPagina(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('FUGA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SegundaPagina extends StatelessWidget {
  const SegundaPagina({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Segunda página'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Text(
            'XDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
      ),
    );
  }
}