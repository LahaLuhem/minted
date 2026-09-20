part of '../ip_address.dart';

/// The individual [IpAddress] values the RFCs name. A range is a block, so it lives in [CidrConstants].
abstract final class IpAddressConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  //=================================== UNSPECIFIED & LOOPBACK ===================================//

  /// "This host on this network", and what a socket binds to for every interface. RFC 1122 §3.2.1.3.
  static const unspecifiedV4 = IpAddress._('0.0.0.0');

  /// The v4 loopback, one address out of the whole `127.0.0.0/8` that carries it. RFC 1122 §3.2.1.3.
  static const loopbackV4 = IpAddress._('127.0.0.1');

  /// The v6 spelling of [unspecifiedV4]. RFC 4291 §2.5.2.
  static const unspecifiedV6 = IpAddress._('::');

  /// The v6 loopback, a single address where v4 reserves a whole block. RFC 4291 §2.5.3.
  static const loopbackV6 = IpAddress._('::1');

  //========================================= BROADCAST ==========================================//

  /// Every host on this link, which routers never forward. RFC 919, RFC 922.
  static const limitedBroadcast = IpAddress._('255.255.255.255');
}
