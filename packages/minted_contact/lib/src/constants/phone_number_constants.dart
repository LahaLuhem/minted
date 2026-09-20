part of '../phone_number.dart';

/// The [PhoneNumber] values RFC 3966 and RFC 6116 use as their own examples.
abstract final class PhoneNumberConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// `+1 201 555 0123`, RFC 3966 §6's example, inside the `555-0100`-`0199` block NANPA reserves.
  static const exampleUs = PhoneNumber._('+12015550123');

  /// `+44 20 7946 0148`, RFC 6116 §3.2's example, inside Ofcom's `020 7946` range for drama.
  static const exampleGb = PhoneNumber._('+442079460148');
}
