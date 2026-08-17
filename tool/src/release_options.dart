import 'package:args/args.dart';

import 'release_abort.dart';
import 'versioning/bump_type.dart';

/// What the caller asked for, before anything is read from disk.
class ReleaseOptions {
  const new({
    this.bump,
    this.package,
    this.tagMessage,
    this.skipConfirmation = false,
    this.dryRun = false,
    this.helpRequested = false,
  });

  /// Which part of the version to move, or null to ask.
  final BumpType? bump;

  /// Which member to release, or null to ask.
  final String? package;

  /// Message for an annotated tag. Without one the tag is lightweight.
  final String? tagMessage;

  final bool skipConfirmation;
  final bool dryRun;
  final bool helpRequested;

  /// Parses [arguments], or aborts with a usage error.
  factory parse(List<String> arguments) {
    final ArgResults parsed;
    try {
      parsed = _parser.parse(arguments);
    } on FormatException catch (error) {
      // args' message is the whole value here; a parser trace would bury it.
      // ignore: avoid-throw-in-catch-block
      throw ReleaseAbort('${error.message} (use --help)', code: usageErrorCode);
    }

    if (parsed.flag('help')) return const ReleaseOptions(helpRequested: true);

    return ReleaseOptions(
      bump: _bumpFrom(parsed.rest),
      package: _nonEmpty(parsed, 'package'),
      tagMessage: _nonEmpty(parsed, 'tag-message'),
      skipConfirmation: parsed.flag('yes'),
      dryRun: parsed.flag('dry-run'),
    );
  }

  /// The usage text, kept here so `--help` and the error paths cannot drift apart.
  static String get usage =>
      '''
release.dart — bump version, finalise CHANGELOG, commit, tag, push to origin.

Usage:
  dart run tool/release.dart [BUMP] [OPTIONS]

Arguments:
  BUMP            one of: ${BumpType.names}  (prompted if omitted on a TTY)

Options:
${_parser.usage}

Non-interactive example:
  dart run tool/release.dart patch --package minted --yes''';

  static final _parser = ArgParser(usageLineLength: 100)
    ..addOption(
      'package',
      abbr: 'p',
      valueHelp: 'NAME',
      help:
          'Which workspace member to release. Must be one with a populated `## Unreleased` '
          'block. Prompted if omitted on a TTY and more than one qualifies; required otherwise.',
    )
    ..addOption(
      'tag-message',
      abbr: 'm',
      valueHelp: 'MSG',
      help:
          'Attach MSG as the tag message, creating an annotated, signed-if-configured tag. '
          'Without this flag the tag is lightweight.',
    )
    ..addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Skip the confirmation prompt. Required off a TTY.',
    )
    ..addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Run the full preflight and print the plan, with no side effects.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this message.');

  /// The bump named among [rest], or null when none was given.
  static BumpType? _bumpFrom(List<String> rest) {
    if (rest.isEmpty) return null;
    if (rest.length > 1) {
      throw ReleaseAbort(
        'unexpected extra arguments: ${rest.skip(1).join(' ')}',
        code: usageErrorCode,
      );
    }

    final bump = BumpType.tryParse(rest.single);
    if (bump == null) {
      throw ReleaseAbort(
        'unknown argument: ${rest.single} (expected one of ${BumpType.names}, or --help)',
        code: usageErrorCode,
      );
    }

    return bump;
  }

  /// The value of [option], rejecting the empty string the way a missing argument is rejected.
  static String? _nonEmpty(ArgResults parsed, String option) {
    final value = parsed.option(option);
    if (value == null) return null;
    if (value.isEmpty) {
      throw ReleaseAbort('--$option requires a non-empty value', code: usageErrorCode);
    }

    return value;
  }
}
