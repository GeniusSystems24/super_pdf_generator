// DOMAIN · failures & result type. Pure Dart. No Flutter, no dart:io, no pdf.
//
// Every SDK operation resolves to a [Result] — an [Ok] value or an [Err]
// carrying a typed [PdfFailure]. Expected conditions are values, never thrown
// exceptions. This mirrors the Web proposal's "typed failure, never silent".

import 'package:meta/meta.dart';

/// A typed result: either an [Ok] value or an [Err] failure.
@immutable
sealed class Result<T> {
  const Result();

  /// Wrap a success value.
  const factory Result.ok(T value) = Ok<T>;

  /// Wrap a failure.
  const factory Result.err(PdfFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value when [Ok], otherwise `null`.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// The failure when [Err], otherwise `null`.
  PdfFailure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  /// Fold both branches into a single [R].
  R fold<R>(R Function(T value) onOk, R Function(PdfFailure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  /// Map the success value, preserving a failure.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final PdfFailure failure;
}

/// The failure taxonomy. One category per axis of the SDK — every failure is a
/// member of this sealed hierarchy so `switch` over it is exhaustive.
enum PdfFailureCategory {
  validation,
  font,
  image,
  rendering,
  file,
  printing,
  sharing,
  processing,
  unsupportedFeature,
  permission,
  cancelled,
  timeout,
  unknown,
}

/// Base type for every failure. Carries a developer-readable [code], a
/// user-readable [message], the original [cause], whether it is [retryable],
/// a suggested [recovery] action and structured [context] for logging.
@immutable
sealed class PdfFailure {
  const PdfFailure({
    required this.code,
    required this.message,
    this.cause,
    this.retryable = false,
    this.recovery,
    this.context = const <String, Object?>{},
  });

  final String code;
  final String message;
  final Object? cause;
  final bool retryable;
  final String? recovery;
  final Map<String, Object?> context;

  PdfFailureCategory get category;

  Map<String, Object?> toJson() => <String, Object?>{
        'category': category.name,
        'code': code,
        'message': message,
        'retryable': retryable,
        'recovery': recovery,
        'cause': cause?.toString(),
        'context': context,
      };

  @override
  String toString() => '$runtimeType($code): $message';
}

class ValidationFailure extends PdfFailure {
  const ValidationFailure({
    required super.code,
    required super.message,
    super.cause,
    super.recovery,
    super.context,
  }) : super(retryable: false);
  @override
  PdfFailureCategory get category => PdfFailureCategory.validation;
}

class FontFailure extends PdfFailure {
  const FontFailure({
    required super.code,
    required super.message,
    super.cause,
    super.retryable = true,
    super.recovery,
    super.context,
  });
  @override
  PdfFailureCategory get category => PdfFailureCategory.font;
}

class ImageFailure extends PdfFailure {
  const ImageFailure({
    required super.code,
    required super.message,
    super.cause,
    super.retryable = true,
    super.recovery,
    super.context,
  });
  @override
  PdfFailureCategory get category => PdfFailureCategory.image;
}

class RenderingFailure extends PdfFailure {
  const RenderingFailure({
    required super.code,
    required super.message,
    super.cause,
    super.retryable = true,
    super.recovery,
    super.context,
  });
  @override
  PdfFailureCategory get category => PdfFailureCategory.rendering;
}

class FileFailure extends PdfFailure {
  const FileFailure({
    required super.code,
    required super.message,
    super.cause,
    super.retryable = true,
    super.recovery,
    super.context,
  });
  @override
  PdfFailureCategory get category => PdfFailureCategory.file;
}

class PrintingFailure extends PdfFailure {
  const PrintingFailure({
    required super.code,
    required super.message,
    super.cause,
    super.retryable = true,
    super.recovery,
    super.context,
  });
  @override
  PdfFailureCategory get category => PdfFailureCategory.printing;
}

class SharingFailure extends PdfFailure {
  const SharingFailure({
    required super.code,
    required super.message,
    super.cause,
    super.retryable = true,
    super.recovery,
    super.context,
  });
  @override
  PdfFailureCategory get category => PdfFailureCategory.sharing;
}

class ProcessingFailure extends PdfFailure {
  const ProcessingFailure({
    required super.code,
    required super.message,
    super.cause,
    super.retryable = true,
    super.recovery,
    super.context,
  });
  @override
  PdfFailureCategory get category => PdfFailureCategory.processing;
}

class UnsupportedFeatureFailure extends PdfFailure {
  const UnsupportedFeatureFailure({
    required super.code,
    required super.message,
    super.cause,
    super.recovery,
    super.context,
  }) : super(retryable: false);
  @override
  PdfFailureCategory get category => PdfFailureCategory.unsupportedFeature;
}

class PermissionFailure extends PdfFailure {
  const PermissionFailure({
    required super.code,
    required super.message,
    super.cause,
    super.recovery,
    super.context,
  }) : super(retryable: false);
  @override
  PdfFailureCategory get category => PdfFailureCategory.permission;
}

class CancelledFailure extends PdfFailure {
  const CancelledFailure({
    super.code = 'CANCELLED',
    super.message = 'The operation was cancelled.',
    super.context,
  }) : super(retryable: false);
  @override
  PdfFailureCategory get category => PdfFailureCategory.cancelled;
}

class TimeoutFailure extends PdfFailure {
  const TimeoutFailure({
    required super.code,
    required super.message,
    super.cause,
    super.recovery,
    super.context,
  }) : super(retryable: true);
  @override
  PdfFailureCategory get category => PdfFailureCategory.timeout;
}

class UnknownFailure extends PdfFailure {
  const UnknownFailure({
    super.code = 'UNKNOWN',
    required super.message,
    super.cause,
    super.context,
  }) : super(retryable: false);
  @override
  PdfFailureCategory get category => PdfFailureCategory.unknown;

  /// Wrap an arbitrary caught error as an [UnknownFailure].
  factory UnknownFailure.from(Object error, [StackTrace? stack]) =>
      UnknownFailure(
        message: error.toString(),
        cause: error,
        context: stack == null
            ? const <String, Object?>{}
            : <String, Object?>{'stack': stack.toString()},
      );
}
