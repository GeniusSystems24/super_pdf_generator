// APPLICATION · templates · registry. Pure Dart.
//
// A simple, injectable registry that maps template ids to templates. The
// composition root (or an app) registers the built-in business templates; call
// sites resolve by id. Mirrors the reference's template registry.

import 'engine/template.dart';

/// Registry of available templates, keyed by [PdfTemplate.id].
class PdfTemplateRegistry {
  PdfTemplateRegistry();

  final Map<String, PdfTemplate<Object?>> _byId = <String, PdfTemplate<Object?>>{};

  /// Register [template]. Throws [StateError] on a duplicate id unless
  /// [replace] is true.
  void register<T>(PdfTemplate<T> template, {bool replace = false}) {
    if (!replace && _byId.containsKey(template.id)) {
      throw StateError('A template with id "${template.id}" is already registered.');
    }
    _byId[template.id] = template as PdfTemplate<Object?>;
  }

  /// Resolve a template by id, or null if not registered.
  PdfTemplate<Object?>? resolve(String id) => _byId[id];

  /// Resolve or throw [ArgumentError].
  PdfTemplate<Object?> require(String id) {
    final t = _byId[id];
    if (t == null) {
      throw ArgumentError.value(id, 'id', 'No template registered with this id');
    }
    return t;
  }

  bool contains(String id) => _byId.containsKey(id);

  /// All registered templates, in registration order.
  List<PdfTemplate<Object?>> get all => List.unmodifiable(_byId.values);

  /// All registered ids.
  List<String> get ids => List.unmodifiable(_byId.keys);

  int get length => _byId.length;
}
