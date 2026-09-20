part of '../isni.dart';

/// The [Isni] example ORCID publishes, for a professor who never existed.
abstract final class IsniConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// ORCID's own example record, belonging to a professor Brown University invented in 1929.
  static const example = Isni._('0000000218250097');
}
