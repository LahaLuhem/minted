import '../../../tool/src/io/release_ui.dart';
import '../../../tool/src/versioning/bump_type.dart';

/// A [ReleaseUi] that answers prompts from fields and keeps everything it printed.
class FakeReleaseUi implements ReleaseUi {
  new({this.isInteractive = false, this.packageChoice, this.bumpChoice, this.confirmation = true});

  /// Everything printed, in order, prefixes and all.
  final List<String> printed = [];

  @override
  final bool isInteractive;

  /// What [choosePackage] answers. Null stands for "no choice was made".
  final String? packageChoice;

  /// What [chooseBump] answers. Null stands for "no choice was made".
  final BumpType? bumpChoice;

  /// What [confirmRelease] answers.
  final bool confirmation;

  /// Whether anything printed contains [fragment].
  bool said(String fragment) => printed.any((line) => line.contains(fragment));

  @override
  void log(String message) => printed.add(message);

  @override
  void step(String message) => printed.add(message);

  @override
  void error(String message) => printed.add(message);

  @override
  void block(String text) => printed.add(text);

  @override
  String? choosePackage(List<String> names) => packageChoice;

  @override
  BumpType? chooseBump() => bumpChoice;

  @override
  bool confirmRelease() => confirmation;
}
