part of '../hostname.dart';

/// The [Hostname] values a standard reserves, plus the ones convention settled on.
abstract final class HostnameConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  //===================================== RFC 2606 RESERVED ======================================//
  // Both of its sets, whole: 4 top-level names in §2 and 3 second-level ones in §3.

  /// The loopback name, which resolves without asking a nameserver.
  static const localhost = Hostname._('localhost');

  /// Reserved for testing, so it will never be delegated.
  static const test = Hostname._('test');

  /// Reserved to be obviously wrong, for a name that has to fail.
  static const invalid = Hostname._('invalid');

  /// Reserved for documentation and examples.
  static const example = Hostname._('example');

  /// `example.com`, reserved for documentation.
  static const exampleCom = Hostname._('example.com');

  /// `example.net`, reserved for documentation.
  static const exampleNet = Hostname._('example.net');

  /// `example.org`, reserved for documentation.
  static const exampleOrg = Hostname._('example.org');

  //======================================== SPECIAL-USE =========================================//

  /// Multicast DNS, so a name resolved by shouting on the local link. RFC 6762.
  static const local = Hostname._('local');

  /// Private-use TLD, reserved by ICANN in 2024 rather than by an RFC.
  static const internal = Hostname._('internal');

  //======================================== CONVENTIONAL ========================================//
  // Habits, not standards. Nothing reserves these, so treat a match as a hint, never as proof.

  /// The `/etc/hosts` loopback line most Linux distributions ship.
  static const localhostLocaldomain = Hostname._('localhost.localdomain');

  /// The bare suffix behind [localhostLocaldomain].
  static const localdomain = Hostname._('localdomain');

  /// What home routers hand out as the search domain.
  static const lan = Hostname._('lan');

  /// A home network. ICANN shelved `.home` as a new gTLD over exactly this collision risk.
  static const home = Hostname._('home');

  /// A company network. Shelved alongside [home], and for the same reason.
  static const corp = Hostname._('corp');
}
