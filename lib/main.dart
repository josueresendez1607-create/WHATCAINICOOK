import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void main() {
  runApp(const MiAplicacion());
}

// ===== CLASE 1: Solo pone el MaterialApp =====
class MiAplicacion extends StatelessWidget {
  const MiAplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PantallaPrincipal(),
    );
  }
}

// ===== CLASE 2: La pantalla principal =====
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi primera aplicación'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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