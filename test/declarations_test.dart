import 'package:flutter_unused_code/flutter_unused_code.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  late UnusedCodeReport report;

  setUpAll(() async {
    report = await analyzeFiles({
      'lib/main.dart': '''
import 'package:flutter/widgets.dart';
import 'decls.dart';
import 'screens.dart';

void main() {
  final Callback cb = () {};
  cb();
  usedFunction();
  print(usedVariable);
  print(UsedClass());
  print(UsedEnum.a);
  print(const UsedScreen());
  print(UsedClass().usedMixinMethod());
  print('x'.shout);
  print(usedGetter);
  final AliasUsedOnly alias = 1;
  print(alias);
}
''',
      'lib/decls.dart': '''
typedef Callback = void Function();
typedef UnusedCallback = void Function(int);
typedef AliasUsedOnly = int;

void usedFunction() {}

/// Docs count as removable lines.
void unusedFunction() {
  unusedFunction(); // recursion is not a use
}

final usedVariable = 1;
const unusedVariable = 2, otherUnusedVariable = 3;

int get usedGetter => 1;
int get unusedGetter => 1;

mixin UsedMixin {
  int usedMixinMethod() => 1;
}
mixin UnusedMixin {}

class UsedClass with UsedMixin {}

class UnusedClass {
  UnusedClass create() => UnusedClass(); // self reference
  void member() {}
}

enum UsedEnum { a, b }
enum UnusedEnum { x }

extension UsedExtension on String {
  String get shout => toUpperCase();
}
extension UnusedExtension on int {
  int get twice => this * 2;
}
extension type UnusedId(int value) {}

class OnlyUsedByDeadCode {}

void _private() {}
''',
      'lib/dead_user.dart': '''
import 'decls.dart';

void deadUser() => print(OnlyUsedByDeadCode());
''',
      'lib/screens.dart': '''
import 'package:flutter/widgets.dart';

class UsedScreen extends StatelessWidget {
  const UsedScreen();
  @override
  Widget build(BuildContext context) => const Text('used');
}

class UnusedScreen extends StatefulWidget {
  const UnusedScreen();
  @override
  State<UnusedScreen> createState() => _UnusedScreenState();
}

class _UnusedScreenState extends State<UnusedScreen> {
  @override
  Widget build(BuildContext context) => const Text('unused');
}
''',
    });
  });

  test('reports every unused top-level kind', () {
    final kinds = {
      for (final f in report.ofCategory(FindingCategory.declaration))
        f.name: f.kind,
    };
    expect(kinds, {
      'UnusedCallback': 'typedef',
      'unusedFunction': 'function',
      'unusedVariable': 'variable',
      'otherUnusedVariable': 'variable',
      'unusedGetter': 'getter',
      'UnusedMixin': 'mixin',
      'UnusedClass': 'class',
      'UnusedEnum': 'enum',
      'UnusedExtension': 'extension',
      'UnusedId': 'extension type',
      'OnlyUsedByDeadCode': 'class',
      'UnusedScreen': 'widget',
    });
  });

  test('used declarations are not reported', () {
    for (final used in [
      'Callback',
      'AliasUsedOnly',
      'usedFunction',
      'usedVariable',
      'usedGetter',
      'UsedMixin',
      'UsedClass',
      'UsedEnum',
      'UsedExtension',
      'UsedScreen',
      'main',
    ]) {
      expect(report.names, isNot(contains(used)), reason: used);
    }
  });

  test('private declarations are left to dart analyze', () {
    expect(report.names, isNot(contains('_private')));
    expect(report.names, isNot(contains('_UnusedScreenState')));
  });

  test('members of an unused type are not repeated', () {
    expect(report.names, isNot(contains('UnusedClass.member')));
    expect(report.names, isNot(contains('UnusedClass.create')));
    expect(report.names, isNot(contains('UnusedExtension.twice')));
  });

  test('widgets are flagged as a subset', () {
    expect(report.widgets.map((f) => f.name), ['UnusedScreen']);
    expect(report.counts['widgets'], 1);
  });

  test('positions and removable lines', () {
    final f = report.finding('unusedFunction');
    expect(f.path, 'lib/decls.dart');
    expect(f.line, 8);
    expect(f.column, 6);
    expect(f.lines, 4); // doc comment + 3 lines of body
    expect(report.finding('UnusedClass').lines, 4);
  });
}
