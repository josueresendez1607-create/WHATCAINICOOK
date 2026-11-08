import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
//  PANTALLA DE INICIO DE SESIÓN + REGISTRO (todo en la misma)
// ============================================================
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmarController = TextEditingController();

  bool modoRegistro = false; // false = iniciar sesión, true = registrarse
  bool ocultarPassword = true; // la contraseña se ve como puntos
  bool cargando = false;

  @override
  void dispose() {
    nombreController.dispose();
    usuarioController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  void _cambiarModo() {
    setState(() {
      modoRegistro = !modoRegistro;
      passwordController.clear();
      confirmarController.clear();
      ocultarPassword = true;
    });
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
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
    // La contraseña se guarda encriptada (hash + salt) en usuarios.json
    final error = await ServicioUsuarios.registrar(nombre, usuario, password);
    if (!mounted) return;
    setState(() => cargando = false);

    if (error != null) {
      _mensaje(error);
      return;
    }

    _mensaje('Cuenta creada. Ya puedes iniciar sesión');
    nombreController.clear();
    // Regresa al modo iniciar sesión conservando el usuario escrito
    _cambiarModo();
  }

  // Campo con la etiqueta a la IZQUIERDA (fuera de la caja de texto)
  Widget _campo({
    required String etiqueta,
    required TextEditingController controller,
    bool esPassword = false,
    bool mostrarOjo = false,
    void Function(String)? alEnviar,
    String? ayuda,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            etiqueta,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: esPassword ? ocultarPassword : false,
            onSubmitted: alEnviar,
            decoration: InputDecoration(
              hintText: ayuda,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: mostrarOjo
                  ? IconButton(
                icon: Icon(ocultarPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () =>
                    setState(() => ocultarPassword = !ocultarPassword),
              )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(modoRegistro ? 'Registrarse' : 'Iniciar sesión'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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

                // Nombre: solo aparece al registrarse
                if (modoRegistro) ...[
                  _campo(
                    etiqueta: 'Nombre:',
                    controller: nombreController,
                    ayuda: 'Tu nombre completo',
                  ),
                  const SizedBox(height: 15),
                ],

                _campo(
                  etiqueta: 'Usuario:',
                  controller: usuarioController,
                  ayuda: 'Escribe tu usuario',
                ),
                const SizedBox(height: 15),

                _campo(
                  etiqueta: 'Contraseña:',
                  controller: passwordController,
                  esPassword: true,
                  mostrarOjo: true,
                  ayuda: modoRegistro ? 'Mínimo 6 caracteres' : 'Tu contraseña',
                  alEnviar: (_) {
                    if (!modoRegistro) _iniciarSesion();
                  },
                ),

                // Confirmar contraseña: solo aparece al registrarse
                if (modoRegistro) ...[
                  const SizedBox(height: 15),
                  _campo(
                    etiqueta: 'Confirmar contraseña:',
                    controller: confirmarController,
                    esPassword: true,
                    ayuda: 'Repite tu contraseña',
                    alEnviar: (_) => _registrar(),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cargando
                        ? null
                        : (modoRegistro ? _registrar : _iniciarSesion),
                    child: cargando
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(modoRegistro ? 'Crear cuenta' : 'Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: cargando ? null : _cambiarModo,
                  child: Text(
                    modoRegistro
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿No tienes cuenta? Regístrate',
                  ),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.home), text: 'Inicio'),
              Tab(icon: Icon(Icons.cloud), text: 'API JSON'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(
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
            const PestanaApi(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  PESTAÑA 2: CONEXIÓN A UN JSON PÚBLICO (API REST)
//  API: JSONPlaceholder  ->  https://jsonplaceholder.typicode.com/posts
//  Métodos: GET, POST, PUT, PATCH y DELETE
// ============================================================
class PestanaApi extends StatefulWidget {
  const PestanaApi({super.key});

  @override
  State<PestanaApi> createState() => _PestanaApiState();
}

class _PestanaApiState extends State<PestanaApi>
    with AutomaticKeepAliveClientMixin {
  static const String _base = 'https://jsonplaceholder.typicode.com/posts';
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  // Mantiene los datos al cambiar de pestaña
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> posts = [];
  bool cargando = false;
  String registro = 'Cargando datos...';

  @override
  void initState() {
    super.initState();
    _get();
  }

  // JSONPlaceholder solo simula los cambios: lo que se crea (id 101 en
  // adelante) no existe realmente en el servidor, así que se edita local.
  bool _esLocal(Map<String, dynamic> post) => (post['id'] as int) > 100;

  void _anotar(String metodo, String url, int? estado, String detalle) {
    if (!mounted) return;
    setState(() {
      registro = '$metodo  $url\nEstado: ${estado ?? 'sin respuesta'}\n$detalle';
    });
  }

  String _bonito(Object? datos) =>
      const JsonEncoder.withIndent('  ').convert(datos);

  // ---------------- GET: mostrar información ----------------
  Future<void> _get() async {
    setState(() => cargando = true);
    final url = '$_base?_limit=15';
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) {
        final lista = List<Map<String, dynamic>>.from(jsonDecode(r.body));
        if (!mounted) return;
        setState(() => posts = lista);
        _anotar('GET', url, r.statusCode,
            'Se recibieron ${lista.length} publicaciones');
      } else {
        _anotar('GET', url, r.statusCode, 'No se pudo obtener la información');
      }
    } catch (e) {
      _anotar('GET', url, null, 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  // ---------------- POST: crear ----------------
  Future<void> _post() async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _DialogoPost(titulo: 'Nuevo post (POST)'),
    );
    if (datos == null) return;

    final cuerpo = {'title': datos['title'], 'body': datos['body'], 'userId': 1};
    try {
      final r = await http.post(Uri.parse(_base),
          headers: _headers, body: jsonEncode(cuerpo));
      final respuesta = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 201 && mounted) {
        setState(() => posts.insert(0, {...cuerpo, 'id': respuesta['id']}));
      }
      _anotar('POST', _base, r.statusCode, _bonito(respuesta));
    } catch (e) {
      _anotar('POST', _base, null, 'Error de conexión: $e');
    }
  }

  // ---------------- PUT: reemplazar todo el post ----------------
  Future<void> _put(Map<String, dynamic> post) async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DialogoPost(
        titulo: 'Editar todo (PUT)',
        tituloInicial: post['title'] as String,
        cuerpoInicial: post['body'] as String,
      ),
    );
    if (datos == null) return;

    final cuerpo = {
      'id': post['id'],
      'title': datos['title'],
      'body': datos['body'],
      'userId': post['userId'],
    };

    if (_esLocal(post)) {
      setState(() => _reemplazar(post['id'], cuerpo));
      _anotar('PUT', '$_base/${post['id']}', null,
          'Post creado en esta sesión: se edita solo en la app.\n'
              '(JSONPlaceholder no guarda lo que se crea)');
      return;
    }

    final url = '$_base/${post['id']}';
    try {
      final r = await http.put(Uri.parse(url),
          headers: _headers, body: jsonEncode(cuerpo));
      if (r.statusCode == 200 && mounted) {
        setState(() => _reemplazar(post['id'], cuerpo));
      }
      _anotar('PUT', url, r.statusCode, _bonito(jsonDecode(r.body)));
    } catch (e) {
      _anotar('PUT', url, null, 'Error de conexión: $e');
    }
  }

  // ---------------- PATCH: cambiar solo el título ----------------
  Future<void> _patch(Map<String, dynamic> post) async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DialogoPost(
        titulo: 'Cambiar título (PATCH)',
        tituloInicial: post['title'] as String,
        soloTitulo: true,
      ),
    );
    if (datos == null) return;

    final cuerpo = {'title': datos['title']};

    if (_esLocal(post)) {
      setState(() => _reemplazar(post['id'], {...post, ...cuerpo}));
      _anotar('PATCH', '$_base/${post['id']}', null,
          'Post creado en esta sesión: se edita solo en la app.\n'
              '(JSONPlaceholder no guarda lo que se crea)');
      return;
    }

    final url = '$_base/${post['id']}';
    try {
      final r = await http.patch(Uri.parse(url),
          headers: _headers, body: jsonEncode(cuerpo));
      if (r.statusCode == 200 && mounted) {
        setState(() => _reemplazar(post['id'], {...post, ...cuerpo}));
      }
      _anotar('PATCH', url, r.statusCode, _bonito(jsonDecode(r.body)));
    } catch (e) {
      _anotar('PATCH', url, null, 'Error de conexión: $e');
    }
  }

  // ---------------- DELETE: eliminar ----------------
  Future<void> _delete(Map<String, dynamic> post) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar (DELETE)'),
        content: Text('¿Eliminar el post ${post['id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    if (_esLocal(post)) {
      setState(() => posts.removeWhere((p) => p['id'] == post['id']));
      _anotar('DELETE', '$_base/${post['id']}', null,
          'Post creado en esta sesión: se elimina solo de la app.');
      return;
    }

    final url = '$_base/${post['id']}';
    try {
      final r = await http.delete(Uri.parse(url));
      if (r.statusCode == 200 && mounted) {
        setState(() => posts.removeWhere((p) => p['id'] == post['id']));
      }
      _anotar('DELETE', url, r.statusCode, 'Post ${post['id']} eliminado');
    } catch (e) {
      _anotar('DELETE', url, null, 'Error de conexión: $e');
    }
  }

  void _reemplazar(dynamic id, Map<String, dynamic> nuevo) {
    final i = posts.indexWhere((p) => p['id'] == id);
    if (i != -1) posts[i] = Map<String, dynamic>.from(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // necesario para AutomaticKeepAliveClientMixin
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: cargando ? null : _get,
                icon: const Icon(Icons.download),
                label: const Text('GET (actualizar)'),
              ),
              ElevatedButton.icon(
                onPressed: _post,
                icon: const Icon(Icons.add),
                label: const Text('POST (nuevo)'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Panel con la última petición y su respuesta
          Container(
            width: double.infinity,
            height: 110,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF263238),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                registro,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: cargando && posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                ? const Center(child: Text('Sin datos. Presiona GET.'))
                : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final post = posts[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            child: Text('${post['id']}'),
                          ),
                          title: Text(
                            '${post['title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${post['body']}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () => _put(post),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('PUT'),
                            ),
                            TextButton.icon(
                              onPressed: () => _patch(post),
                              icon: const Icon(
                                  Icons.drive_file_rename_outline,
                                  size: 18),
                              label: const Text('PATCH'),
                            ),
                            TextButton.icon(
                              onPressed: () => _delete(post),
                              icon: const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              label: const Text(
                                'DELETE',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Ventana para escribir título y contenido (POST, PUT y PATCH)
class _DialogoPost extends StatefulWidget {
  final String titulo;
  final String tituloInicial;
  final String cuerpoInicial;
  final bool soloTitulo;

  const _DialogoPost({
    required this.titulo,
    this.tituloInicial = '',
    this.cuerpoInicial = '',
    this.soloTitulo = false,
  });

  @override
  State<_DialogoPost> createState() => _DialogoPostState();
}

class _DialogoPostState extends State<_DialogoPost> {
  late final TextEditingController tituloController;
  late final TextEditingController cuerpoController;

  @override
  void initState() {
    super.initState();
    tituloController = TextEditingController(text: widget.tituloInicial);
    cuerpoController = TextEditingController(text: widget.cuerpoInicial);
  }

  @override
  void dispose() {
    tituloController.dispose();
    cuerpoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            if (!widget.soloTitulo) ...[
              const SizedBox(height: 12),
              TextField(
                controller: cuerpoController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (tituloController.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': tituloController.text.trim(),
              'body': cuerpoController.text.trim(),
            });
          },
          child: const Text('Enviar'),
        ),
      ],
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