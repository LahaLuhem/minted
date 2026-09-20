import 'package:meta/meta.dart';

import 'minted_failure.dart';
import 'minted_format_error.dart';

/// The result of parsing text: either the value, or the [MintedFailure] saying why not.
///
/// Lossless, unlike a nullable return, and reachable without `try`/`catch`. Sealed, so a `switch` over
/// [ParseSuccess] and [ParseFailure] is exhaustive and the compiler catches a missed arm.
@immutable
sealed class const ParseOutcome<F extends MintedFailure, T>() {
  /// Subclasses only: the type is sealed.
  this;

  /// Whether this holds a parsed value.
  bool get isSuccess => this is ParseSuccess<F, T>;

  /// Whether this holds a failure.
  bool get isFailure => this is ParseFailure<F, T>;

  /// The failure, or `null` when this succeeded. The dual of [getOrNull], and the shortest route from
  /// a parse to a form-field error.
  F? get reasonOrNull => switch (this) {
    ParseSuccess() => null,
    ParseFailure(:final reason) => reason,
  };

  /// Collapses both cases to a [C] with [onFailure] or [onSuccess]. The way out of this type, to a widget,
  /// a log line, or another library's `Either`.
  C fold<C>(C Function(F reason) onFailure, C Function(T value) onSuccess) => switch (this) {
    ParseSuccess(:final value) => onSuccess(value),
    ParseFailure(:final reason) => onFailure(reason),
  };

  /// The parsed value, or `null` when this failed. What `tryParse` is built from.
  T? getOrNull() => switch (this) {
    ParseSuccess(:final value) => value,
    ParseFailure() => null,
  };

  /// The parsed value, or [orElse]'s result when this failed.
  T getOrElse(T Function() orElse) => switch (this) {
    ParseSuccess(:final value) => value,
    ParseFailure() => orElse(),
  };

  /// The parsed value, throwing [MintedFormatError] when this failed. The only thing here that throws.
  ///
  /// Beats `getOrNull()!`, which drops the typed reason this outcome is holding and leaves a bare null-check
  /// error in its place.
  T getOrThrow() => switch (this) {
    ParseSuccess(:final value) => value,
    ParseFailure(:final reason) => throw MintedFormatError.from(reason),
  };

  /// This outcome with a successful value passed through [transform]. A failure carries across untouched.
  ParseOutcome<F, U> map<U>(U Function(T value) transform) => switch (this) {
    ParseSuccess(:final value) => ParseSuccess(transform(value)),
    ParseFailure(:final reason) => ParseFailure(reason),
  };

  /// As [map], for a [transform] that's fallible itself. Chains parses without nesting, and the first
  /// failure short-circuits the rest.
  ParseOutcome<F, U> flatMap<U>(ParseOutcome<F, U> Function(T value) transform) => switch (this) {
    ParseSuccess(:final value) => transform(value),
    ParseFailure(:final reason) => ParseFailure(reason),
  };
}

/// A parse that produced [value].
final class const ParseSuccess<F extends MintedFailure, T>(
  /// The parsed value.
  final T value,
) extends ParseOutcome<F, T> {
  /// Wraps an already-parsed [value]. Public because there's no invariant to protect: you can only pass
  /// a [T], which only parsing produces.
  this;

  @override
  bool operator ==(Object other) => other is ParseSuccess<F, T> && other.value == value;

  @override
  int get hashCode => Object.hash(ParseSuccess, value);

  @override
  String toString() => 'ParseSuccess($value)';
}

/// A parse that failed, for the [reason] given.
final class const ParseFailure<F extends MintedFailure, T>(
  /// Why the parse failed, in the offending type's own vocabulary.
  final F reason,
) extends ParseOutcome<F, T> {
  /// Wraps the [reason] a parse failed. Public so tests and callers can build the arm they expect.
  this;

  @override
  bool operator ==(Object other) => other is ParseFailure<F, T> && other.reason == reason;

  @override
  int get hashCode => Object.hash(ParseFailure, reason);

  @override
  String toString() => 'ParseFailure($reason)';
}
