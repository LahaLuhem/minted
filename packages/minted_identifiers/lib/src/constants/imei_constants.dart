part of '../imei.dart';

/// The [Imei] values GSMA keeps off the market, so neither names a handset.
abstract final class ImeiConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// All zeros, what an emulator or a modem with no IMEI reports.
  static const unavailable = Imei._('000000000000000');

  /// A test IMEI in the shape §9.1 gives: `00`, then `44` for TÜV SÜD, a maker code and a serial.
  static const test = Imei._('004400000000008');
}
