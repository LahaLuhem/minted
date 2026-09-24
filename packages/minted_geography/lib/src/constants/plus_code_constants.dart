part of '../plus_code.dart';

/// The [PlusCode] floor. There is no ceiling, since nothing caps how many digits a valid code takes.
abstract final class PlusCodeConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The first cell in sort order: every full code sorts at or after this. A 2-digit code, so the
  /// 20° square at the far south-west.
  static const first = PlusCode._('22000000+');
}
