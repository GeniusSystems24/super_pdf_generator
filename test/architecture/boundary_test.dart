// TEST · architectural boundaries.
//
// Executable enforcement of the dependency rules from the design proposal:
// the Domain and Application layers must stay framework-free. This test reads
// the source and fails the build if a forbidden import appears — the same
// guarantee the Web proposal's dependency-cruiser rules provide.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('architectural boundaries', () {
    final forbidden = <RegExp>[
      RegExp("import\\s+['\"]package:flutter/"),
      RegExp("import\\s+['\"]dart:ui"),
      RegExp("import\\s+['\"]dart:io"),
      RegExp("import\\s+['\"]package:pdf/"),
      RegExp("import\\s+['\"]package:printing/"),
    ];

    List<File> dartFilesUnder(String path) {
      final dir = Directory(path);
      if (!dir.existsSync()) return const <File>[];
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }

    test('domain never imports Flutter, dart:ui, dart:io, pdf or printing', () {
      final offenders = <String>[];
      for (final file in dartFilesUnder('lib/src/domain')) {
        final src = file.readAsStringSync();
        for (final re in forbidden) {
          if (re.hasMatch(src)) offenders.add('${file.path} :: ${re.pattern}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Domain must be pure Dart:\n${offenders.join('\n')}',);
    });

    test('application never imports Flutter, dart:ui, dart:io, pdf or printing', () {
      final offenders = <String>[];
      for (final file in dartFilesUnder('lib/src/application')) {
        final src = file.readAsStringSync();
        for (final re in forbidden) {
          if (re.hasMatch(src)) offenders.add('${file.path} :: ${re.pattern}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Application must be framework-independent:\n${offenders.join('\n')}',);
    });

    test('infrastructure is the only layer allowed to import the pdf engine', () {
      // Sanity check the inverse: at least one infrastructure file imports pdf,
      // proving the engine lives where it should (outer ring), not inward.
      final importsPdf = dartFilesUnder('lib/src/infrastructure')
          .any((f) => f.readAsStringSync().contains("package:pdf/"));
      expect(importsPdf, isTrue,
          reason: 'The pdf engine should be adapted in infrastructure.',);
    });
  });
}
