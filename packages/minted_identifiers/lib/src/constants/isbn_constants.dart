part of '../isbn.dart';

/// The [Isbn] placeholder habit. No standard names it.
abstract final class IsbnConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The all-zero ISBN that stands in for a record with none. No standard names it.
  static const unavailable = Isbn._('9780000000002');
}
