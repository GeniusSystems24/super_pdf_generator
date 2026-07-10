// DOMAIN · document security. Pure Dart. No Flutter, no dart:io, no pdf engine.
//
// Value objects describing how a PDF is encrypted and which permissions are
// granted. The concrete encryption is performed by an infrastructure adapter
// behind the [PdfSecurityService] port; this layer only describes intent.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'generation.dart';
import 'processing.dart';

/// Encryption algorithm applied to a protected document.
enum PdfEncryptionAlgorithm {
  /// Legacy RC4 40-bit — weak; provided only for compatibility.
  rc4x40,

  /// RC4 128-bit.
  rc4x128,

  /// AES 128-bit.
  aesx128,

  /// AES 256-bit — the recommended default.
  aesx256,
}

/// A single access permission granted to the *user* (as opposed to the owner).
///
/// Absence of a flag denies that action when a user password is set.
enum PdfDocumentPermission {
  print,
  highResolutionPrint,
  copyContent,
  editContent,
  editAnnotations,
  fillFields,
  assembleDocument,
  accessibilityCopy,
}

/// Declarative encryption + permission settings for a document.
///
/// ```dart
/// const options = PdfSecurityOptions(
///   ownerPassword: 'owner-secret',
///   userPassword: 'open-sesame',
///   algorithm: PdfEncryptionAlgorithm.aesx256,
///   permissions: {PdfDocumentPermission.print, PdfDocumentPermission.copyContent},
/// );
/// ```
@immutable
class PdfSecurityOptions {
  const PdfSecurityOptions({
    this.ownerPassword,
    this.userPassword,
    this.algorithm = PdfEncryptionAlgorithm.aesx256,
    this.permissions = const <PdfDocumentPermission>{
      PdfDocumentPermission.print,
      PdfDocumentPermission.copyContent,
    },
  });

  /// Full-control password. Required to change security or permissions.
  final String? ownerPassword;

  /// Password required to open the document. When null the file opens freely
  /// but is still permission-restricted for the granted actions.
  final String? userPassword;

  final PdfEncryptionAlgorithm algorithm;

  /// Actions granted to a user opening with the [userPassword].
  final Set<PdfDocumentPermission> permissions;

  bool get hasOwnerPassword =>
      ownerPassword != null && ownerPassword!.isNotEmpty;
  bool get hasUserPassword => userPassword != null && userPassword!.isNotEmpty;

  PdfSecurityOptions copyWith({
    String? ownerPassword,
    String? userPassword,
    PdfEncryptionAlgorithm? algorithm,
    Set<PdfDocumentPermission>? permissions,
  }) =>
      PdfSecurityOptions(
        ownerPassword: ownerPassword ?? this.ownerPassword,
        userPassword: userPassword ?? this.userPassword,
        algorithm: algorithm ?? this.algorithm,
        permissions: permissions ?? this.permissions,
      );

  /// Redacted JSON — passwords are never serialized, only their presence, so
  /// logs and isolate messages can never leak a secret.
  Map<String, Object?> toJson() => <String, Object?>{
        'algorithm': algorithm.name,
        'hasOwnerPassword': hasOwnerPassword,
        'hasUserPassword': hasUserPassword,
        'permissions': permissions.map((p) => p.name).toList(),
      };
}

/// A request to protect an existing PDF with [options].
@immutable
class PdfSecurityRequest {
  const PdfSecurityRequest({
    required this.input,
    required this.options,
    this.fileName = 'protected.pdf',
  });

  final PdfInputFile input;
  final PdfSecurityOptions options;
  final String fileName;
}

/// A request to remove protection from an encrypted PDF, given its password.
@immutable
class PdfUnlockRequest {
  const PdfUnlockRequest({
    required this.input,
    required this.password,
    this.fileName = 'unlocked.pdf',
  });

  final PdfInputFile input;
  final String password;
  final String fileName;
}

/// The outcome of a security operation: the produced bytes plus a summary of
/// what was applied.
@immutable
class PdfSecurityResult {
  const PdfSecurityResult({
    required this.document,
    required this.encrypted,
    required this.algorithm,
  });

  final PdfGenerationResult document;
  final bool encrypted;
  final PdfEncryptionAlgorithm algorithm;

  Uint8List get bytes => document.bytes;
}
