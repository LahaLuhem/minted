part of '../isin.dart';

/// The [Isin] values documentation uses, 1 national and 1 international.
abstract final class IsinConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// A US example.
  static const example = Isin._('US0000000002');

  /// An international one, under the Euroclear and Clearstream prefix rather than a country.
  static const exampleInternational = Isin._('XS0000000009');
}
