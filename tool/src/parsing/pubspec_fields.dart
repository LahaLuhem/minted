import 'dart:convert';

import 'package:collection/collection.dart';

/// What a version must look like, for the pubspec read and for the cider cross-check.
final semverPattern = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$');

final _publishToNone = RegExp('^publish_to: *none', multiLine: true);
final _whitespace = RegExp(r'\s+');
final _integer = RegExp('[0-9]+');

/// The value of the first line in [pubspec] whose first token is `<field>:`.
///
/// Not a YAML parse: these files have to stay byte-identical, and a reserialise round trip is the
/// one thing that could reformat them.
String? _firstFieldValue(String pubspec, String field) {
  final declaration = const LineSplitter()
      .convert(pubspec)
      .map((line) => line.trim().split(_whitespace))
      .firstWhereOrNull((tokens) => tokens.length > 1 && tokens.first == '$field:');

  return declaration?[1];
}

/// The first integer anywhere in [text], or null when it holds none.
int? _firstInteger(String text) => int.tryParse(_integer.stringMatch(text) ?? '');

/// The `name:` [pubspec] declares. The tag is built from this, not the directory: the two match by
/// convention only.
String? pubspecName(String pubspec) => _firstFieldValue(pubspec, 'name');

/// The `version:` [pubspec] declares, or null when it declares none.
String? pubspecVersion(String pubspec) => _firstFieldValue(pubspec, 'version');

/// The major of the `version:` [pubspec] declares, or null when it declares none.
int? pubspecMajor(String pubspec) => _firstInteger(pubspecVersion(pubspec) ?? '');

bool publishesToNone(String pubspec) => _publishToNone.hasMatch(pubspec);

/// The dependency line [pubspec] declares for [dependency], matched at the one nesting level where
/// `dependencies:` entries sit.
String? dependencyLine(String pubspec, String dependency) {
  final declaration = RegExp('^  ${RegExp.escape(dependency)}:');

  return const LineSplitter().convert(pubspec).firstWhereOrNull(declaration.hasMatch);
}

/// Just the constraint from a [dependencyLine], with the dependency name stripped off.
String constraintOf(String dependencyLine) {
  final separator = dependencyLine.indexOf(': ');

  // Offset from indexOf on an ASCII separator, so never inside a surrogate pair.
  // ignore: avoid-substring
  return separator < 0 ? dependencyLine : dependencyLine.substring(separator + 2);
}

/// A sibling constraint whose lower bound is older than the major this tree builds against.
typedef StaleConstraint = ({String member, String declared, int treeMajor});

/// Sibling constraints in [selectedPubspec] that name an older major than [memberPubspecs] build.
///
/// pub.dev cannot unpublish, so a constraint that is wrong at upload is wrong permanently. It has
/// happened: siblings carried `minted: '>=2.0.0 <4.0.0'` through the v3 split.
///
/// An unmodifiable `Set`, since one finding per sibling is unique and nothing consults the order.
Set<StaleConstraint> staleConstraints({
  required String selectedName,
  required String selectedPubspec,
  required Map<String, String> memberPubspecs,
}) => Set.unmodifiable(
  memberPubspecs.entries
      .where((member) => member.key != selectedName)
      .map((member) => _staleConstraintOn(selectedPubspec, member.key, member.value))
      .nonNulls,
);

/// What [selectedPubspec] declares on [member], when that is behind what [memberPubspec] builds.
///
/// Null covers all three of undeclared, unversioned, and current, none of which is a finding.
StaleConstraint? _staleConstraintOn(String selectedPubspec, String member, String memberPubspec) {
  final declared = dependencyLine(selectedPubspec, member);
  final treeMajor = pubspecMajor(memberPubspec);
  if (declared == null || treeMajor == null) return null;

  // The first version is the lower bound, for `^X.Y.Z` and `>=X.Y.Z <W.0.0` alike.
  final wantedMajor = _firstInteger(declared);

  return wantedMajor != null && wantedMajor < treeMajor
      ? (member: member, declared: declared, treeMajor: treeMajor)
      : null;
}
