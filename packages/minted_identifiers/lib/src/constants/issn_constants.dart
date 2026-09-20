part of '../issn.dart';

/// The [Issn] placeholder habit. No standard names it.
abstract final class IssnConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The all-zero ISSN that stands in for a record with none. No standard names it.
  static const unavailable = Issn._('0000-0000');
}
