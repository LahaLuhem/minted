// Test file
// ignore_for_file: prefer-match-file-name

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Enforces the value-type contract structurally.
///
/// Every value type (each public type declared anywhere under `lib/src/`
/// except `lib/src/shared/` and the per-category `failures/` directories) must
/// expose the shared spine: static `tryParse` and `parse` factories, and, for
/// an extension type, a representation named `value`. Static factories can't be
/// enforced by an abstract class in Dart (they're static and not inherited), so
/// this test is that enforcement: a new type that forgets part of the contract
/// fails the build.
///
/// An enum in that space is a *classification* (`Weekday`, `UuidVariant`), not a
/// value type, so it must declare neither door. The contract cannot be checked
/// on one, and a `parse` on an enum would read as a value type while escaping
/// every check above.
void main() {
  const notValueTypes = {'shared', 'failures'};

  final valueTypeFiles = Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (entity) =>
            entity.path.endsWith('.dart') && !entity.uri.pathSegments.any(notValueTypes.contains),
      )
      .toList();

  test('there are value-type sources to check', () {
    check(valueTypeFiles).isNotEmpty();
  });

  for (final file in valueTypeFiles) {
    final collector = _SpineCollector();
    parseString(content: file.readAsStringSync()).unit.accept(collector);

    group(file.uri.pathSegments.last, () {
      for (final type in collector.types) {
        if (type.isEnum) {
          test('${type.name} is a classification, so it declares no parse door', () {
            check(
              type.staticMethods.intersection(_contractDoors),
              because:
                  '${type.name} is an enum, so the value-type contract cannot '
                  'be enforced on it: this test only checks classes and '
                  'extension types. A parse door here would read as a value '
                  'type while escaping every check. Either model it as an '
                  'extension type or an immutable class, or keep it a '
                  'classification and build it with from / tryFrom.',
            ).isEmpty();
          });

          continue;
        }

        test('${type.name} declares static tryParse and parse', () {
          check(type.staticMethods).contains('tryParse');
          check(type.staticMethods).contains('parse');
        });

        if (type.isExtensionType) {
          test('${type.name} names its representation `value`', () {
            check(
              type.representationIsValue,
              because:
                  '${type.name} is an extension type; its representation must '
                  'be named `value` so the canonical form is `.value` '
                  'everywhere.',
            ).isTrue();
          });
        }
      }
    });
  }
}

/// The two static doors the value-type contract requires, and a classification must not declare.
const _contractDoors = {'parse', 'tryParse'};

/// A value type discovered in a source file and the spine members it declares.
class _ValueType {
  _ValueType(
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
}

/// Collects the value types declared in one compilation unit and their static
/// member names, using only AST primitives stable across analyzer versions.
class _SpineCollector extends RecursiveAstVisitor<void> {
  final List<_ValueType> types = [];
  _ValueType? _current;

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    final source = node.toSource();
    final type = _ValueType(
      _nameFrom(source, r'extension\s+type\s+(?:const\s+)?([A-Za-z_$][\w$]*)'),
      isExtensionType: true,
      isEnum: false,
      representationIsValue: RegExp(r'\._\([^)]*\bvalue\b[^)]*\)').hasMatch(source),
    );
    types.add(type);
    _current = type;
    super.visitExtensionTypeDeclaration(node);
    _current = null;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = _nameFrom(node.toSource(), r'class\s+([A-Za-z_$][\w$]*)');
    final type = _ValueType(
      name,
      isExtensionType: false,
      isEnum: false,
      representationIsValue: true,
    );
    types.add(type);
    _current = type;
    super.visitClassDeclaration(node);
    _current = null;
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final name = _nameFrom(node.toSource(), r'enum\s+([A-Za-z_$][\w$]*)');
    final type = _ValueType(
      name,
      isExtensionType: false,
      isEnum: true,
      representationIsValue: true,
    );
    types.add(type);
    _current = type;
    super.visitEnumDeclaration(node);
    _current = null;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isStatic) _current?.staticMethods.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
  }
}

String _nameFrom(String source, String pattern) =>
    RegExp(pattern).firstMatch(source)?.group(1) ?? '<unknown>';
