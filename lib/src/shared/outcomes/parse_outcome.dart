import 'package:meta/meta.dart';

import 'minted_failure.dart';
import 'minted_format_exception.dart';

/// The result of parsing text: either the value, or the [MintedFailure] saying why not.
///
/// Lossless, unlike a nullable return, and reachable without `try`/`catch`. Sealed, so a `switch`
/// over [ParseSuccess] and [ParseFailure] is exhaustive and the compiler catches a missed arm.
@immutable
sealed class ParseOutcome<F extends MintedFailure, T> {
  const new();

  /// Whether this holds a parsed value.
  bool get isSuccess => this is ParseSuccess<F, T>;

  /// Whether this holds a failure.
  bool get isFailure => this is ParseFailure<F, T>;

  /// The failure, or `null` when this succeeded. The dual of [getOrNull], and the shortest route
  /// from parsing to a form-field error message.
  F? get reasonOrNull => switch (this) {
    ParseSuccess() => null,
    ParseFailure(:final reason) => reason,
  };

  /// Collapses both cases to a [C], applying [onFailure] or [onSuccess]. The exit from this type:
  /// use it to reach a widget, a log line, or another library's `Either`.
  C fold<C>(C Function(F reason) onFailure, C Function(T value) onSuccess) => switch (this) {
    ParseSuccess(:final value) => onSuccess(value),
    ParseFailure(:final reason) => onFailure(reason),
  };

  /// The parsed value, or `null` when this failed. What `tryParse` is built from.
  T? getOrNull() => switch (this) {
    ParseSuccess(:final value) => value,
    ParseFailure() => null,
  };

  /// The parsed value, or the result of [orElse] when this failed.
  T getOrElse(T Function() orElse) => switch (this) {
    ParseSuccess(:final value) => value,
    ParseFailure() => orElse(),
  };

  /// The parsed value, throwing [MintedFormatException] when this failed.
  ///
  /// The door for a claim made in source: the caller asserts the input is valid, so a failure is a
  /// bug in their code rather than a branch to write. Prefer it to `getOrNull()!`, which discards
  /// the typed reason this outcome is holding and leaves a bare null-check error in its place.
  T getOrThrow() => switch (this) {
    ParseSuccess(:final value) => value,
    ParseFailure(:final reason) => throw MintedFormatException.from(reason),
  };

  /// This outcome with a successful value passed through [transform]; a failure is carried across
  /// untouched.
  ParseOutcome<F, U> map<U>(U Function(T value) transform) => switch (this) {
    ParseSuccess(:final value) => ParseSuccess(transform(value)),
    ParseFailure(:final reason) => ParseFailure(reason),
  };

  /// As [map], for a [transform] that is itself fallible. Chains parses without nesting: the first
  /// failure short-circuits the rest.
  ParseOutcome<F, U> flatMap<U>(ParseOutcome<F, U> Function(T value) transform) => switch (this) {
    ParseSuccess(:final value) => transform(value),
    ParseFailure(:final reason) => ParseFailure(reason),
  };
}

/// A parse that produced [value].
final class ParseSuccess<F extends MintedFailure, T> extends ParseOutcome<F, T> {
  /// The parsed value.
  final T value;

  /// Wraps an already-parsed [value]. Public because there is no invariant to protect: you can
  /// only pass a [T], which only parsing can produce in the first place.
  const new(this.value);

  @override
  bool operator ==(Object other) => other is ParseSuccess<F, T> && other.value == value;

  @override
  int get hashCode => Object.hash(ParseSuccess, value);

  @override
  String toString() => 'ParseSuccess($value)';
}

/// A parse that failed, for the [reason] given.
final class ParseFailure<F extends MintedFailure, T> extends ParseOutcome<F, T> {
  /// Why the parse failed, in the offending type's own vocabulary.
  final F reason;

  /// Wraps the [reason] a parse failed. Public so tests and callers can build the arm they expect.
  const new(this.reason);

  @override
  bool operator ==(Object other) => other is ParseFailure<F, T> && other.reason == reason;

  @override
  int get hashCode => Object.hash(ParseFailure, reason);

  @override
  String toString() => 'ParseFailure($reason)';
}
