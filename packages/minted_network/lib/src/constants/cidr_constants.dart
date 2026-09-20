part of '../ip_address.dart';

/// The [Cidr] blocks the RFCs reserve. A single address is no block, so it lives in [IpAddressConstants].
abstract final class CidrConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  //======================================== PRIVATE USE =========================================//

  /// `10.0.0.0/8`, the largest RFC 1918 block.
  static const private10 = Cidr._(_private10Network, 8);

  /// `172.16.0.0/12`, the middle RFC 1918 block.
  static const private172 = Cidr._(_private172Network, 12);

  /// `192.168.0.0/16`, the RFC 1918 block home routers hand out of.
  static const private192 = Cidr._(_private192Network, 16);

  /// `fc00::/7`, unique local addresses, which is v6's answer to RFC 1918. RFC 4193.
  static const uniqueLocalV6 = Cidr._(_uniqueLocalV6Network, 7);

  //==================================== SHARED ADDRESS SPACE ====================================//

  /// `100.64.0.0/10`, for carrier-grade NAT. RFC 6598 keeps this separate from RFC 1918 because it
  /// sits on the provider's side, so a subscriber can still use `10.0.0.0/8` behind it.
  static const sharedAddress = Cidr._(_sharedAddressNetwork, 10);

  //========================================= LINK-LOCAL =========================================//

  /// `169.254.0.0/16`, self-assigned when DHCP does not answer. RFC 3927.
  static const linkLocalV4 = Cidr._(_linkLocalV4Network, 16);

  /// `fe80::/10`, which every v6 interface has one of whether or not it is configured. RFC 4291.
  static const linkLocalV6 = Cidr._(_linkLocalV6Network, 10);

  //========================================= MULTICAST ==========================================//

  /// `224.0.0.0/4`, the old class D. RFC 5771.
  static const multicastV4 = Cidr._(_multicastV4Network, 4);

  /// `ff00::/8`. v6 has no broadcast, so this covers what broadcast used to do. RFC 4291.
  static const multicastV6 = Cidr._(_multicastV6Network, 8);

  //======================================= DOCUMENTATION ========================================//

  /// `192.0.2.0/24`, which RFC 5737 calls TEST-NET-1.
  static const docV4_1 = Cidr._(_docV4_1Network, 24);

  /// `198.51.100.0/24`, TEST-NET-2.
  static const docV4_2 = Cidr._(_docV4_2Network, 24);

  /// `203.0.113.0/24`, TEST-NET-3.
  static const docV4_3 = Cidr._(_docV4_3Network, 24);

  /// `2001:db8::/32`, the v6 documentation block. RFC 3849.
  static const docV6 = Cidr._(_docV6Network, 32);

  //======================================== IPV4-MAPPED =========================================//

  /// `::ffff:0.0.0.0/96`, where a v4 address sits when a dual-stack socket reports it as v6.
  /// RFC 4291 §2.5.5.2.
  static const v4MappedV6 = Cidr._(_v4MappedV6Network, 96);
}

//====================================== NETWORK ADDRESSES =======================================//
// A const Cidr needs a const IpAddress, and only this library can mint one. Private rather than
// members of IpAddressConstants, because nobody wants `10.0.0.0` on its own.

const _private10Network = IpAddress._('10.0.0.0');
const _private172Network = IpAddress._('172.16.0.0');
const _private192Network = IpAddress._('192.168.0.0');
const _uniqueLocalV6Network = IpAddress._('fc00::');
const _sharedAddressNetwork = IpAddress._('100.64.0.0');
const _linkLocalV4Network = IpAddress._('169.254.0.0');
const _linkLocalV6Network = IpAddress._('fe80::');
const _multicastV4Network = IpAddress._('224.0.0.0');
const _multicastV6Network = IpAddress._('ff00::');
const _docV4_1Network = IpAddress._('192.0.2.0');
const _docV4_2Network = IpAddress._('198.51.100.0');
const _docV4_3Network = IpAddress._('203.0.113.0');
const _docV6Network = IpAddress._('2001:db8::');
const _v4MappedV6Network = IpAddress._('::ffff:0.0.0.0');
