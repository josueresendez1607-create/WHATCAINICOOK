import 'package:flutter/material.dart';

/// Snackbar uniforme para acciones reversibles (quitar, ocultar, eliminar).
///
/// Cuando la acción ocurre después de una espera, se puede entregar el
/// [ScaffoldMessengerState] capturado antes del `await` para no reutilizar un
/// [BuildContext] fuera de su marco seguro.
void showUndoSnackBar(
  BuildContext? context, {
  ScaffoldMessengerState? messenger,
  required String message,
  required String actionLabel,
  required Future<void> Function() onUndo,
}) {
  final target = messenger ?? ScaffoldMessenger.of(context!);
  target.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: actionLabel, onPressed: () => onUndo()),
    ),
  );
}
