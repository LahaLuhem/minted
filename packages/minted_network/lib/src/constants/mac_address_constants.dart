part of '../mac_address.dart';

/// The [MacAddress] values IEEE and IANA single out.
abstract final class MacAddressConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  //========================================= SENTINELS ==========================================//

  /// Names no interface. IEEE Std 802.3 calls it the null address.
  static const allZeros = MacAddress._('00:00:00:00:00:00');

  /// Every station on the link, which [MacAddress.isBroadcast] tests for.
  static const broadcast = MacAddress._('ff:ff:ff:ff:ff:ff');

  //====================================== IANA OUI BLOCKS =======================================//
  // 00-00-5E and its 01-00-5E multicast twin, which RFC 9542 §2.1 splits into blocks of 256. Each
  // name is a block's first address, so it is a landmark rather than a membership test.

  /// Reserved, handed out only on IESG ratification.
  static const ianaReserved = MacAddress._('00:00:5e:00:00:00');

  /// The virtual router address, last octet the VRID. RFC 5798 §7.3, IPv4 flavour.
  static const vrrp = MacAddress._('00:00:5e:00:01:00');

  /// Unicast documentation.
  static const ianaDocumentation = MacAddress._('00:00:5e:00:53:00');

  /// Multicast documentation.
  static const ianaDocMulticast = MacAddress._('01:00:5e:90:10:00');

  //=================================== BRIDGE GROUP ADDRESSES ===================================//
  // IEEE Std 802.1D does not relay a frame addressed in this range, so a bridge consumes it.

  /// The bridge group address, and the nearest customer bridge.
  static const stpBridgeGroup = MacAddress._('01:80:c2:00:00:00');

  /// IEEE MAC-specific control protocols.
  static const macControlGroup = MacAddress._('01:80:c2:00:00:01');

  /// The IEEE 802.3 slow protocols address.
  static const slowProtocols = MacAddress._('01:80:c2:00:00:02');

  /// The nearest non-TPMR bridge, which is also the 802.1X PAE address.
  static const nearestNonTpmr = MacAddress._('01:80:c2:00:00:03');

  /// The provider bridge group.
  static const providerBridge = MacAddress._('01:80:c2:00:00:08');

  /// The provider bridge MVRP address.
  static const providerMvrp = MacAddress._('01:80:c2:00:00:0d');

  /// The nearest bridge, and the individual LAN scope group address.
  static const nearestBridge = MacAddress._('01:80:c2:00:00:0e');
}
