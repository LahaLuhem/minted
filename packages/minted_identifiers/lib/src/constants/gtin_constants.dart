part of '../gtin.dart';

/// The [Gtin] GS1 keeps company-internal, so it names no product.
abstract final class GtinConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// A restricted circulation number. GS1 keeps `20`-`29` company-internal, so it names no product.
  static const restrictedCirculation = Gtin._('02000000000008');
}
