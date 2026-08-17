/// The tag a release of [version] of [package] carries.
///
/// No `v` prefix: publish.yml routes on the package half, and each pub.dev package is configured
/// with a matching `<package>-{{version}}` pattern.
String releaseTag({required String package, required String version}) => '$package-$version';

/// [tag] split back into package and version, or null when it is not a tag.
///
/// On the first hyphen, since pub names cannot contain one. That keeps `minted-3.0.0-beta.1` whole.
({String package, String version})? splitReleaseTag(String tag) {
  final hyphen = tag.indexOf('-');
  if (hyphen <= 0 || hyphen == tag.length - 1) return null;

  // Offset from indexOf on an ASCII hyphen, so never inside a surrogate pair.
  // ignore: avoid-substring
  return (package: tag.substring(0, hyphen), version: tag.substring(hyphen + 1));
}
