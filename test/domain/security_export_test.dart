// TEST · domain — security & export value types (public API compat + behaviour).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

void main() {
  final input = PdfInputFile(name: 'in.pdf', bytes: Uint8List.fromList(const [1, 2, 3]));

  group('security', () {
    test('options default to AES-256 with print + copy permissions', () {
      const options = PdfSecurityOptions();
      expect(options.algorithm, PdfEncryptionAlgorithm.aesx256);
      expect(options.permissions, contains(PdfDocumentPermission.print));
    });

    test('toJson redacts passwords', () {
      const options = PdfSecurityOptions(
        ownerPassword: 'owner',
        userPassword: 'open',
        permissions: {PdfDocumentPermission.print},
      );
      final json = options.toJson();
      expect(json['hasOwnerPassword'], isTrue);
      expect(json['hasUserPassword'], isTrue);
      expect(json.toString(), isNot(contains('owner')));
      expect(json.toString(), isNot(contains('open')));
    });

    test('requests are constructible', () {
      final protect = PdfSecurityRequest(input: input, options: const PdfSecurityOptions());
      final unlock = PdfUnlockRequest(input: input, password: 'pw');
      expect(protect.fileName, 'protected.pdf');
      expect(unlock.password, 'pw');
    });
  });

  group('export', () {
    test('every request exposes its format', () {
      expect(PdfHtmlExportRequest(input: input).format, PdfExportFormat.html);
      expect(PdfImageExportRequest(input: input).format, PdfExportFormat.image);
      expect(PdfTextExportRequest(input: input).format, PdfExportFormat.plainText);
      expect(PdfAExportRequest(input: input).format, PdfExportFormat.pdfA);
    });

    test('result exposes its primary artifact', () {
      final result = PdfExportResult(
        format: PdfExportFormat.plainText,
        artifacts: [
          PdfExportArtifact(
            name: 'a.txt',
            bytes: Uint8List.fromList(const [65]),
            mimeType: 'text/plain',
          ),
        ],
      );
      expect(result.count, 1);
      expect(result.primary.name, 'a.txt');
    });
  });

  group('sharing', () {
    test('targets carry bilingual labels', () {
      expect(PdfShareTarget.bluetooth.label, 'Bluetooth');
      expect(PdfShareTarget.email.labelAr, 'البريد الإلكتروني');
    });
  });
}
