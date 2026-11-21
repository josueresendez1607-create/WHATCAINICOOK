import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Acceso cómodo al valor de un [AsyncValue] sin depender de API internas.
extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrNull => switch (this) {
    AsyncData<T>(:final T value) => value,
    _ => null,
  };
}
