import 'dart:io';

import 'package:terminice/terminice.dart';

import '../versioning/bump_type.dart';
import 'release_ui.dart';

/// Prompts and prints through terminice, so the picker filters and the slow gates spin.
///
/// Only the interaction changes: every decision still reaches the flow through [ReleaseUi].
class TerminiceReleaseUi implements ReleaseUi {
  new({Terminice? client}) : _client = client ?? terminice;

  final Terminice _client;

  @override
  void log(String message) => _client.detail(message);

  @override
  void step(String message) => _client.info(message);

  @override
  void error(String message) => _client.error(message);

  /// Straight to stdout, unthemed: the message helpers trim each line and join them, which would
  /// destroy the indentation and column alignment the plan and the usage text rely on.
  @override
  void block(String text) => stdout.writeln(text);

  @override
  Future<T> task<T>(String label, Future<T> Function() work) =>
      _client.task(label, run: work, success: label);

  /// Read from the terminal terminice is using, not `dart:io`, so a test can fake it.
  @override
  bool get isInteractive => TerminalContext.input.hasTerminal;

  @override
  String? choosePackage(List<String> names) => _pickOne(names, 'Release which package?');

  @override
  BumpType? chooseBump() {
    final names = BumpType.values.map((bump) => bump.name).toList(growable: false);
    final chosen = _pickOne(names, 'Which part of the version moves?');

    return chosen == null ? null : .tryParse(chosen);
  }

  @override
  bool confirmRelease() {
    if (!isInteractive) return false;

    return _client.confirm(prompt: 'Release', message: 'Proceed with the plan above?');
  }

  /// One of [options], or null when the prompt was cancelled or nobody was there to answer.
  ///
  /// `searchSelector` is a multi-select that returns a list, so a cancel reads as empty.
  String? _pickOne(List<String> options, String prompt) {
    if (!isInteractive) return null;

    return _client.searchSelector(options: options, prompt: prompt, showSearch: true).firstOrNull;
  }
}
