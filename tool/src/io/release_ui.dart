import '../versioning/bump_type.dart';

/// Everything the release flow needs from a person or says to one.
///
/// One seam, so the flow knows nothing about terminice and a test can answer every prompt.
abstract interface class ReleaseUi {
  /// A progress line.
  void log(String message);

  /// A section boundary, for the gates that take a while.
  void step(String message);

  /// A failure line, on stderr.
  void error(String message);

  /// Printed unprefixed: the plan, the usage text.
  void block(String text);

  /// Runs [work] under a progress indication labelled [label], so a slow gate can show one.
  Future<T> task<T>(String label, Future<T> Function() work);

  /// Whether there is someone there to answer a prompt.
  bool get isInteractive;

  /// Null from either chooser means the choice was not made.
  String? choosePackage(List<String> names);

  BumpType? chooseBump();

  bool confirmRelease();
}
