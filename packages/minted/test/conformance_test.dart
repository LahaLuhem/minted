// Test file
// ignore_for_file: prefer-match-file-name

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Enforces structurally what the value-type contract cannot state in the type system, over every
/// public type under `lib/src/` outside `shared/` and the per-category `failures/` directories.
///
/// 1. **Nothing throws but an [Error].** A fallible door reports its failure in its return type, so
///    a `throw` here would be a door lying about what it can do. An `Error` is allowed through
///    because it says a caller asserted something false, which is a bug rather than input to handle.
/// 2. **An extension type names its representation `value`**, so the canonical form is `.value`.
/// 3. **A classification declares no parse door.** An `enum` in this space is derived from something
///    already parsed, and a `parse` on one would read as a value type while escaping every check.
///
/// It deliberately requires no door to *exist*. Prescribing a spine (`parse` and `tryParse` on
/// everything) needed one carve-out per category, and each was a shape forced on a domain that did
/// not want it. Forbidding dishonesty needs none.
void main() {
  const notTypes = {'shared', 'failures'};

  final typeFiles = Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (entity) =>
            entity.path.endsWith('.dart') && !entity.uri.pathSegments.any(notTypes.contains),
      )
      .toList();

  test('there are value-type sources to check', () {
    check(typeFiles).isNotEmpty();
  });

  for (final file in typeFiles) {
    final collector = _TypeCollector();
    parseString(content: file.readAsStringSync()).unit.accept(collector);

    group(file.uri.pathSegments.last, () {
      for (final type in collector.types) {
        test('${type.name} throws nothing that is not an Error', () {
          check(
            type.nonErrorThrows,
            because:
                '${type.name} throws something that is not an Error. A fallible door reports its '
                'failure instead: return a ParseOutcome, or a nullable for a plain range check. '
                'ParseOutcome.getOrThrow is where a caller opts into a throw.',
          ).isEmpty();
        });

        if (type.isEnum) {
          test('${type.name} is a classification, so it declares no parse door', () {
            check(
              type.staticMethods.intersection(_parseDoors),
              because:
                  '${type.name} is an enum, so it is derived from something that already parsed. '
                  'Build it with tryFrom; a parse door would read as a value type while escaping '
                  'every check here.',
            ).isEmpty();
          });
        }

        if (type.isExtensionType) {
          test('${type.name} names its representation `value`', () {
            check(
              type.representationIsValue,
              because:
                  '${type.name} is an extension type; its representation must be named `value` so '
                  'the canonical form is `.value` everywhere.',
            ).isTrue();
          });
        }
      }
    });
  }
}

/// The doors a classification may not declare.
const _parseDoors = {'parse', 'tryParse'};

/// A thrown name ending in `Error` is a bug signal rather than input handling, so it is allowed.
final _errorThrow = RegExp(r'\b\w*Error\b');

/// A type discovered in a source file, and what the three rules need to know about it.
class _ValueType {
  new(
    this.name, {
    required this.isExtensionType,
    required this.isEnum,
    required this.representationIsValue,
  });

  final String name;
  final bool isExtensionType;
  final bool isEnum;
  final bool representationIsValue;
  final Set<String> staticMethods = {};

  /// The source of every `throw` not naming an `Error`, so a failure can quote what it found.
  final List<String> nonErrorThrows = [];
}

/// Collects the types declared in one compilation unit, using only AST primitives stable across
/// analyzer versions.
class _TypeCollector extends RecursiveAstVisitor<void> {
  final List<_ValueType> types = [];
  _ValueType? _current;

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    final source = node.toSource();

    _enter(
      _ValueType(
        _nameFrom(source, r'extension\s+type\s+(?:const\s+)?([A-Za-z_$][\w$]*)'),
        isExtensionType: true,
        isEnum: false,
        representationIsValue: RegExp(r'\._\([^)]*\bvalue\b[^)]*\)').hasMatch(source),
      ),
      () => super.visitExtensionTypeDeclaration(node),
    );
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) => _enter(
    _ValueType(
      _nameFrom(node.toSource(), r'class\s+([A-Za-z_$][\w$]*)'),
      isExtensionType: false,
      isEnum: false,
      representationIsValue: true,
    ),
    () => super.visitClassDeclaration(node),
  );

  @override
  void visitEnumDeclaration(EnumDeclaration node) => _enter(
    _ValueType(
      _nameFrom(node.toSource(), r'enum\s+([A-Za-z_$][\w$]*)'),
      isExtensionType: false,
      isEnum: true,
      representationIsValue: true,
    ),
    () => super.visitEnumDeclaration(node),
  );

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isStatic) _current?.staticMethods.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    final thrown = node.expression.toSource();
    if (!_errorThrow.hasMatch(thrown)) _current?.nonErrorThrows.add(thrown);
    super.visitThrowExpression(node);
  }

  void _enter(_ValueType type, void Function() visitBody) {
    types.add(type);
    _current = type;
    visitBody();
    _current = null;
  }
}

String _nameFrom(String source, String pattern) =>
    RegExp(pattern).firstMatch(source)?.group(1) ?? '<unknown>';
