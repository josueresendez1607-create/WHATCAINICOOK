import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

// ===== Colores de la app =====
const Color naranja = Color(0xFFFF6B00);
const Color crema = Color(0xFFFFF6EC);
const Color cafe = Color(0xFF3E2723);

void main() {
  runApp(const MiAplicacion());
}

// ============================================================
// SERVICIO DE USUARIOS
// ============================================================

class ServicioUsuarios {
static const String _base = 'http://192.168.1.103:5000';

  static Future<String?> registrar(
      String nombre, String usuario, String password) async {
    try {
      final respuesta = await http.post(
        Uri.parse('$_base/registrar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'usuario': usuario,
          'password': password,
        }),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 201) {
        return null;
      }

      return datos['mensaje'] ?? 'No se pudo crear la cuenta';
    } catch (e) {
      return 'No se pudo conectar con el servidor';
    }
  }

  static Future<String?> iniciarSesion(
      String usuario, String password) async {
    try {
      final respuesta = await http.post(
        Uri.parse('$_base/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario': usuario,
          'password': password,
        }),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 200) {
        return datos['nombre'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

// ============================================================
// MATERIAL APP
// ============================================================

class MiAplicacion extends StatelessWidget {
  const MiAplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: naranja,
          primary: naranja,
        ),
        scaffoldBackgroundColor: crema,
        appBarTheme: const AppBarTheme(
          backgroundColor: naranja,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: naranja,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: naranja,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: naranja,
              width: 2,
            ),
          ),
        ),
      ),
      home: const PantallaLogin(),
    );
  }
}

// ============================================================
// INICIO DE SESIÓN Y REGISTRO
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

  bool modoRegistro = false;
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

  void _cambiarModo() {
    setState(() {
      modoRegistro = !modoRegistro;
      passwordController.clear();
      confirmarController.clear();
      ocultarPassword = true;
    });
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Future<void> _iniciarSesion() async {
    final usuario = usuarioController.text.trim();
    final password = passwordController.text;

    if (usuario.isEmpty || password.isEmpty) {
      _mensaje('Completa usuario y contraseña');
      return;
    }

    setState(() => cargando = true);

    final nombre = await ServicioUsuarios.iniciarSesion(
      usuario,
      password,
    );

    if (!mounted) return;

    setState(() => cargando = false);

    if (nombre == null) {
      _mensaje('Usuario o contraseña incorrectos, o servidor desconectado');
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

    final error = await ServicioUsuarios.registrar(
      nombre,
      usuario,
      password,
    );

    if (!mounted) return;

    setState(() => cargando = false);

    if (error != null) {
      _mensaje(error);
      return;
    }

    _mensaje('Cuenta creada. Ya puedes iniciar sesión');

    nombreController.clear();
    _cambiarModo();
  }

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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
              isDense: true,
              suffixIcon: mostrarOjo
                  ? IconButton(
                icon: Icon(
                  ocultarPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    ocultarPassword = !ocultarPassword;
                  });
                },
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
        title: Text(
          modoRegistro ? 'Registrarse' : 'Iniciar sesión',
        ),
        backgroundColor: naranja,
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
                  ayuda: modoRegistro
                      ? 'Mínimo 6 caracteres'
                      : 'Tu contraseña',
                  alEnviar: (_) {
                    if (!modoRegistro) {
                      _iniciarSesion();
                    }
                  },
                ),
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      modoRegistro
                          ? 'Crear cuenta'
                          : 'Iniciar sesión',
                    ),
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

// ============================================================
// PANTALLA PRINCIPAL
// ============================================================

class PantallaPrincipal extends StatefulWidget {
  final String nombre;

  const PantallaPrincipal({
    super.key,
    required this.nombre,
  });

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal>
    with SingleTickerProviderStateMixin {
  late AnimationController controlador;

  final TextEditingController textoController = TextEditingController();

  bool notificacionesActivadas = true;
  int indiceMenu = 0;

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
      MaterialPageRoute(
        builder: (context) => const PantallaLogin(),
      ),
    );
  }

  Widget _paginaInicio() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bienvenido, ${widget.nombre}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cafe,
              ),
            ),
            const SizedBox(height: 20),

            // NUEVO OBJETO GIRATORIO
            const ContadorCilindro(),

            const SizedBox(height: 25),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
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
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: controlador,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
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
              ],
            ),
            const SizedBox(height: 25),
            TextField(
              controller: textoController,
              decoration: const InputDecoration(
                labelText: 'Escribe tu nombre',
                hintText: 'Ejemplo: Josue',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Notificaciones: '),
                  CupertinoSwitch(
                    value: notificacionesActivadas,
                    activeTrackColor: naranja,
                    onChanged: (bool valor) {
                      setState(() {
                        notificacionesActivadas = valor;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            CupertinoButton(
              color: naranja,
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
    );
  }

  Widget _paginaPerfil() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: Image.asset(
                'assets/logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Sesión iniciada'),
            const SizedBox(height: 24),
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock, color: naranja),
                title: Text('Contraseña protegida'),
                subtitle: Text(
                  'Se guarda con PBKDF2 y salt en usuarios.json',
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paginaAcerca() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 70,
              color: naranja,
            ),
            SizedBox(height: 16),
            Text(
              'WHATCAINICOOK',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Aplicación hecha con Flutter y Dart.\n'
                  'Incluye inicio de sesión, registro y contraseñas protegidas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
              child: Image.asset(
                'assets/logo.png',
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Mi primera aplicación'),
          ],
        ),
        backgroundColor: naranja,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: IndexedStack(
        index: indiceMenu,
        children: [
          _paginaInicio(),
          const PantallaRegistros(),
          _paginaPerfil(),
          _paginaAcerca(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indiceMenu,
        onTap: (i) {
          setState(() {
            indiceMenu = i;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: naranja,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud),
            label: 'Registros',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'Acerca de',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NUEVO OBJETO GIRATORIO CON CONTADOR
// ============================================================

class ContadorCilindro extends StatefulWidget {
  const ContadorCilindro({super.key});

  @override
  State<ContadorCilindro> createState() => _ContadorCilindroState();
}

class _ContadorCilindroState extends State<ContadorCilindro>
    with SingleTickerProviderStateMixin {
  late AnimationController animacion;
  Timer? temporizador;
  StreamSubscription<AccelerometerEvent>? suscripcionSensor;

  int contador = 0;
  Offset desplazamiento = Offset.zero;

  @override
  void initState() {
    super.initState();

    animacion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    temporizador = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (mounted) {
          setState(() {
            contador++;
          });
        }
      },
    );

    suscripcionSensor = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((evento) {
      if (!mounted) return;

      final nuevoX = (-evento.x * 12).clamp(-55.0, 55.0).toDouble();
      final nuevoY = (evento.y * 12).clamp(-55.0, 55.0).toDouble();

      setState(() {
        desplazamiento = Offset(
          desplazamiento.dx * 0.7 + nuevoX * 0.3,
          desplazamiento.dy * 0.7 + nuevoY * 0.3,
        );
      });
    });
  }

  @override
  void dispose() {
    suscripcionSensor?.cancel();
    temporizador?.cancel();
    animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Cilindro arcoíris giratorio',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cafe,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: 220,
          height: 230,
          child: AnimatedBuilder(
            animation: animacion,
            builder: (context, child) {
              final angulo = animacion.value * 2 * math.pi;

              return Transform.translate(
                offset: desplazamiento,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.003)
                    ..rotateZ(-0.85)
                    ..rotateX(0.9)
                    ..rotateY(angulo),
                  child: child,
                ),
              );
            },
            child: CustomPaint(
              size: const Size(130, 170),
              painter: CilindroArcoirisPainter(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Contador: $contador',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
        Text(
          'Tiempo transcurrido: $contador segundos',
          style: const TextStyle(
            fontSize: 14,
            color: cafe,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Inclina tu teléfono para mover el cilindro',
          style: TextStyle(color: cafe),
        ),
      ],
    );
  }
}

class CilindroArcoirisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(35, 25, 60, 120),
      const Radius.circular(8),
    );

    final pintura = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
        ],
      ).createShader(
        Rect.fromLTWH(35, 25, 60, 120),
      );

    final borde = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final tapa = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.pink,
          Colors.purple,
          Colors.blue,
        ],
      ).createShader(
        const Rect.fromLTWH(35, 15, 60, 25),
      );

    final brillo = Paint()
      ..color = Colors.white54
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(38, 145, 54, 12),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.deepPurple,
    );

    canvas.drawRRect(cuerpo, pintura);
    canvas.drawRRect(cuerpo, borde);

    canvas.drawOval(
      const Rect.fromLTWH(35, 15, 60, 22),
      tapa,
    );

    canvas.drawOval(
      const Rect.fromLTWH(35, 15, 60, 22),
      borde,
    );

    canvas.drawLine(
      const Offset(48, 40),
      const Offset(48, 125),
      brillo,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ============================================================
// REGISTROS: JSONPLACEHOLDER
// ============================================================

class PantallaRegistros extends StatefulWidget {
  const PantallaRegistros({super.key});

  @override
  State<PantallaRegistros> createState() => _PantallaRegistrosState();
}

class _PantallaRegistrosState extends State<PantallaRegistros> {
  static const String _base =
      'https://jsonplaceholder.typicode.com/posts';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  List<Map<String, dynamic>> registros = [];

  bool cargando = false;

  String respuesta = 'Cargando datos...';

  int _siguienteLocal = 101;

  @override
  void initState() {
    super.initState();
    _get();
  }

  bool _esLocal(Map<String, dynamic> r) {
    return (r['id'] as int) > 100;
  }

  void _anotar(
      String metodo,
      String url,
      int? estado,
      String detalle,
      ) {
    if (!mounted) return;

    setState(() {
      respuesta =
      '$metodo  $url\nEstado: ${estado ?? 'sin respuesta'}\n$detalle';
    });
  }

  String _bonito(Object? datos) {
    return const JsonEncoder.withIndent('  ').convert(datos);
  }

  void _reemplazar(dynamic id, Map<String, dynamic> nuevo) {
    final i = registros.indexWhere((r) => r['id'] == id);

    if (i != -1) {
      registros[i] = Map<String, dynamic>.from(nuevo);
    }
  }

  Future<void> _get() async {
    setState(() => cargando = true);

    final url = '$_base?_limit=15';

    try {
      final r = await http.get(Uri.parse(url));

      if (r.statusCode == 200) {
        final lista = (jsonDecode(r.body) as List)
            .map<Map<String, dynamic>>((e) => {
          'id': e['id'],
          'user': 'usuario${e['userId']}',
          'text': e['title'],
        })
            .toList();

        if (!mounted) return;

        setState(() {
          registros = lista;
        });

        _anotar(
          'GET',
          url,
          r.statusCode,
          'Se recibieron ${lista.length} registros',
        );
      } else {
        _anotar(
          'GET',
          url,
          r.statusCode,
          'No se pudo obtener la información',
        );
      }
    } catch (e) {
      _anotar(
        'GET',
        url,
        null,
        'Error de conexión: $e',
      );
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  Future<void> _post() async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) {
        return const _DialogoRegistro(
          titulo: 'Nuevo registro (POST)',
        );
      },
    );

    if (datos == null) return;

    final cuerpo = {
      'user': datos['user'],
      'text': datos['text'],
    };

    try {
      final r = await http.post(
        Uri.parse(_base),
        headers: _headers,
        body: jsonEncode(cuerpo),
      );

      if (r.statusCode == 201 && mounted) {
        setState(() {
          registros.insert(0, {
            'id': _siguienteLocal++,
            ...cuerpo,
          });
        });
      }

      _anotar(
        'POST',
        _base,
        r.statusCode,
        _bonito(jsonDecode(r.body)),
      );
    } catch (e) {
      _anotar('POST', _base, null, 'Error de conexión: $e');
    }
  }

  Future<void> _put(Map<String, dynamic> registro) async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) {
        return _DialogoRegistro(
          titulo: 'Editar registro (PUT)',
          usuarioInicial: '${registro['user']}',
          contenidoInicial: '${registro['text']}',
        );
      },
    );

    if (datos == null) return;

    final nuevo = {
      'id': registro['id'],
      'user': datos['user'],
      'text': datos['text'],
    };

    final url = '$_base/${registro['id']}';

    if (_esLocal(registro)) {
      setState(() {
        _reemplazar(registro['id'], nuevo);
      });

      _anotar(
        'PUT',
        url,
        null,
        'Registro creado en la app: se edita solo aquí.\n'
            '(JSONPlaceholder no guarda lo que se crea)',
      );

      return;
    }

    try {
      final r = await http.put(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(nuevo),
      );

      if (r.statusCode == 200 && mounted) {
        setState(() {
          _reemplazar(registro['id'], nuevo);
        });
      }

      _anotar(
        'PUT',
        url,
        r.statusCode,
        _bonito(jsonDecode(r.body)),
      );
    } catch (e) {
      _anotar('PUT', url, null, 'Error de conexión: $e');
    }
  }

  Future<void> _patch(Map<String, dynamic> registro) async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) {
        return _DialogoRegistro(
          titulo: 'Cambiar contenido (PATCH)',
          contenidoInicial: '${registro['text']}',
          soloContenido: true,
        );
      },
    );

    if (datos == null) return;

    final cambio = {
      'text': datos['text'],
    };

    final nuevo = {
      ...registro,
      ...cambio,
    };

    final url = '$_base/${registro['id']}';

    if (_esLocal(registro)) {
      setState(() {
        _reemplazar(registro['id'], nuevo);
      });

      _anotar(
        'PATCH',
        url,
        null,
        'Registro creado en la app: se edita solo aquí.\n'
            '(JSONPlaceholder no guarda lo que se crea)',
      );

      return;
    }

    try {
      final r = await http.patch(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(cambio),
      );

      if (r.statusCode == 200 && mounted) {
        setState(() {
          _reemplazar(registro['id'], nuevo);
        });
      }

      _anotar(
        'PATCH',
        url,
        r.statusCode,
        _bonito(jsonDecode(r.body)),
      );
    } catch (e) {
      _anotar('PATCH', url, null, 'Error de conexión: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> registro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Eliminar (DELETE)'),
          content: Text(
            '¿Eliminar el registro ${registro['id']}?',
          ),
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
        );
      },
    );

    if (confirmar != true) return;

    final url = '$_base/${registro['id']}';

    if (_esLocal(registro)) {
      setState(() {
        registros.removeWhere(
              (r) => r['id'] == registro['id'],
        );
      });

      _anotar(
        'DELETE',
        url,
        null,
        'Registro creado en la app: se elimina solo de aquí.',
      );

      return;
    }

    try {
      final r = await http.delete(Uri.parse(url));

      if (r.statusCode == 200 && mounted) {
        setState(() {
          registros.removeWhere(
                (x) => x['id'] == registro['id'],
          );
        });
      }

      _anotar(
        'DELETE',
        url,
        r.statusCode,
        'Registro ${registro['id']} eliminado',
      );
    } catch (e) {
      _anotar('DELETE', url, null, 'Error de conexión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                label: const Text('POST (agregar)'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 100,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF263238),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                respuesta,
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
            child: cargando && registros.isEmpty
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : registros.isEmpty
                ? const Center(
              child: Text('Sin datos. Presiona GET.'),
            )
                : ListView.builder(
              itemCount: registros.length,
              itemBuilder: (context, i) {
                final registro = registros[i];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: naranja,
                            foregroundColor: Colors.white,
                            child: Text('${registro['id']}'),
                          ),
                          title: Text(
                            'Usuario: ${registro['user']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Contenido: ${registro['text']}',
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () => _put(registro),
                              icon: const Icon(
                                Icons.edit,
                                size: 18,
                              ),
                              label: const Text('Editar (PUT)'),
                            ),
                            TextButton.icon(
                              onPressed: () => _patch(registro),
                              icon: const Icon(
                                Icons.drive_file_rename_outline,
                                size: 18,
                              ),
                              label: const Text(
                                'Contenido (PATCH)',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _delete(registro),
                              icon: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Eliminar (DELETE)',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
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

// ============================================================
// DIÁLOGO PARA REGISTROS
// ============================================================

class _DialogoRegistro extends StatefulWidget {
  final String titulo;
  final String usuarioInicial;
  final String contenidoInicial;
  final bool soloContenido;

  const _DialogoRegistro({
    required this.titulo,
    this.usuarioInicial = '',
    this.contenidoInicial = '',
    this.soloContenido = false,
  });

  @override
  State<_DialogoRegistro> createState() => _DialogoRegistroState();
}

class _DialogoRegistroState extends State<_DialogoRegistro> {
  late final TextEditingController usuarioController;
  late final TextEditingController contenidoController;

  @override
  void initState() {
    super.initState();

    usuarioController = TextEditingController(
      text: widget.usuarioInicial,
    );

    contenidoController = TextEditingController(
      text: widget.contenidoInicial,
    );
  }

  @override
  void dispose() {
    usuarioController.dispose();
    contenidoController.dispose();
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
            if (!widget.soloContenido) ...[
              TextField(
                controller: usuarioController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  hintText: 'Ejemplo: jon',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: contenidoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Contenido',
                hintText: 'Ejemplo: hello xd',
              ),
            ),
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
            if (contenidoController.text.trim().isEmpty) {
              return;
            }

            if (!widget.soloContenido &&
                usuarioController.text.trim().isEmpty) {
              return;
            }

            Navigator.pop(context, {
              'user': usuarioController.text.trim(),
              'text': contenidoController.text.trim(),
            });
          },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

// ============================================================
// SEGUNDA PÁGINA
// ============================================================

class SegundaPagina extends StatelessWidget {
  const SegundaPagina({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Segunda página'),
        backgroundColor: naranja,
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