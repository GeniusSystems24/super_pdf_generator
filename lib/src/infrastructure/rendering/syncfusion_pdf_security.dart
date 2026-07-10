// INFRASTRUCTURE · rendering · Syncfusion security service.
//
// Encrypts / decrypts PDFs and applies permission restrictions with
// `syncfusion_flutter_pdf`. Lives in the outer ring behind the
// [PdfSecurityService] port; the pure layers never see the engine.

import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../application/contracts.dart';
import '../../domain/failures.dart';
import '../../domain/generation.dart';
import '../../domain/security.dart';

/// Applies / removes document encryption using the Syncfusion engine.
class SyncfusionPdfSecurityService implements PdfSecurityService {
  const SyncfusionPdfSecurityService();

  @override
  Future<PdfSecurityResult> protect(PdfSecurityRequest request) async {
    final started = DateTime.now();
    sf.PdfDocument? doc;
    try {
      doc = sf.PdfDocument(inputBytes: request.input.bytes);
      final options = request.options;
      final security = doc.security;
      security.algorithm = _algorithm(options.algorithm);
      if (options.hasUserPassword) {
        security.userPassword = options.userPassword!;
      }
      if (options.hasOwnerPassword) {
        security.ownerPassword = options.ownerPassword!;
      }
      security.permissions.clear();
      security.permissions.addAll(
        options.permissions.map(_permission).toList(),
      );
      final bytes = await _save(doc);
      final pages = doc.pages.count;
      return PdfSecurityResult(
        encrypted: true,
        algorithm: options.algorithm,
        document: PdfGenerationResult(
          bytes: bytes,
          fileName: request.fileName,
          pageCount: pages,
          elapsed: DateTime.now().difference(started),
        ),
      );
    } catch (e, s) {
      throw SecurityFailure(
        code: 'SF_PROTECT_FAILED',
        message: 'The document could not be encrypted.',
        cause: e,
        context: {'stack': s.toString()},
        recovery: 'Verify the input PDF is valid and not already protected.',
      );
    } finally {
      doc?.dispose();
    }
  }

  @override
  Future<PdfSecurityResult> unlock(PdfUnlockRequest request) async {
    final started = DateTime.now();
    sf.PdfDocument? doc;
    try {
      doc = sf.PdfDocument(
        inputBytes: request.input.bytes,
        password: request.password,
      );
      // Clearing both passwords removes protection on save.
      doc.security.userPassword = '';
      doc.security.ownerPassword = '';
      final bytes = await _save(doc);
      final pages = doc.pages.count;
      return PdfSecurityResult(
        encrypted: false,
        algorithm: PdfEncryptionAlgorithm.aesx256,
        document: PdfGenerationResult(
          bytes: bytes,
          fileName: request.fileName,
          pageCount: pages,
          elapsed: DateTime.now().difference(started),
        ),
      );
    } catch (e, s) {
      throw SecurityFailure(
        code: 'SF_UNLOCK_FAILED',
        message: 'The document could not be unlocked.',
        cause: e,
        context: {'stack': s.toString()},
        recovery: 'Check that the supplied password is correct.',
      );
    } finally {
      doc?.dispose();
    }
  }

  sf.PdfEncryptionAlgorithm _algorithm(PdfEncryptionAlgorithm a) => switch (a) {
        PdfEncryptionAlgorithm.rc4x40 => sf.PdfEncryptionAlgorithm.rc4x40Bit,
        PdfEncryptionAlgorithm.rc4x128 => sf.PdfEncryptionAlgorithm.rc4x128Bit,
        PdfEncryptionAlgorithm.aesx128 => sf.PdfEncryptionAlgorithm.aesx128Bit,
        PdfEncryptionAlgorithm.aesx256 => sf.PdfEncryptionAlgorithm.aesx256Bit,
      };

  sf.PdfPermissionsFlags _permission(PdfDocumentPermission p) => switch (p) {
        PdfDocumentPermission.print => sf.PdfPermissionsFlags.print,
        PdfDocumentPermission.highResolutionPrint =>
          sf.PdfPermissionsFlags.fullQualityPrint,
        PdfDocumentPermission.copyContent =>
          sf.PdfPermissionsFlags.copyContent,
        PdfDocumentPermission.editContent =>
          sf.PdfPermissionsFlags.editContent,
        PdfDocumentPermission.editAnnotations =>
          sf.PdfPermissionsFlags.editAnnotations,
        PdfDocumentPermission.fillFields => sf.PdfPermissionsFlags.fillFields,
        PdfDocumentPermission.assembleDocument =>
          sf.PdfPermissionsFlags.assembleDocument,
        PdfDocumentPermission.accessibilityCopy =>
          sf.PdfPermissionsFlags.accessibilityCopyContent,
      };

  Future<Uint8List> _save(sf.PdfDocument doc) async {
    final bytes = await doc.save();
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }
}
