import 'dart:io';

import 'package:flutter_unused_code/flutter_unused_code.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

const _files = {
  'lib/main.dart': '''
import 'guarded.dart';

void main() => print(Dto(1));
''',
  'lib/guarded.dart': '''
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

@pragma('vm:entry-point')
void backgroundHandler() => helperOfEntryPoint();

void helperOfEntryPoint() {}

@pragma('vm:prefer-inline')
void inlinedButUnused() {}

// unused_code:ignore
class IgnoredClass {
  void alsoIgnored() {}
}

void ignoredOnSameLine() {} // unused_code:ignore

class Dto {
  Dto(this.id);
  final int id;

  @JsonKey(name: 'x')
  final String? renamed = null;

  @visibleForTesting
  void resetForTests() {}

  void testedOnly() {}
}

class DebugPanel {}

void notUsedAnywhere() {}
''',
  'test/dto_test.dart': '''
import 'package:app/guarded.dart';

void main() {
  Dto(1).resetForTests();
  Dto(1).testedOnly();
  print(Dto(1).id);
}
''',
};

void main() {
  test('annotations, ignore comments and test usage keep code', () async {
    final report = await analyzeFiles(_files);
    expect(report.names, {'inlinedButUnused', 'DebugPanel', 'notUsedAnywhere'});
  });

  test(
    '--no-test-usage: only @visibleForTesting survives on tests alone',
    () async {
      final report = await analyzeFiles(
        _files,
        config: UnusedCodeConfig(countTestUsage: false),
      );
      expect(report.names, contains('Dto.testedOnly'));
      expect(report.names, contains('Dto.id'));
      expect(report.names, isNot(contains('Dto.resetForTests')));
    },
  );

  test('ignore_names and keep_annotations from the config', () async {
    final report = await analyzeFiles(
      {
        ..._files,
        'lib/extra.dart': '''
class Keep {
  const Keep();
}

@Keep()
class Annotated {}
''',
        'lib/main.dart': '''
import 'guarded.dart';
import 'extra.dart';

void main() => print([Dto(1), const Keep()]);
''',
      },
      config: UnusedCodeConfig(
        ignoreNames: [r'^Debug', r'^notUsed'],
        keepAnnotations: ['Keep'],
      ),
    );
    expect(report.names, {'inlinedButUnused'});
  });

  group('package mode', () {
    late UnusedCodeReport report;

    setUpAll(() async {
      report = await analyzeFiles({
        'lib/pkg.dart': '''
export 'src/api.dart' show PublicApi;
import 'src/internal.dart';

class Facade {
  void call() => internalHelper();
  void neverCalledButPublic() {}
}
''',
        'lib/src/api.dart': '''
class PublicApi {
  void method() {}
}

class NotExported {}
''',
        'lib/src/internal.dart': '''
void internalHelper() {}
void internalDead() {}
''',
        'lib/src/orphan.dart': 'class Orphan {}\n',
      }, pubspec: 'name: app\nenvironment:\n  sdk: ^3.9.0\n');
    });

    test('is detected without lib/main.dart or publish_to: none', () {
      expect(report.mode, 'package');
    });

    test('exported API and its members are not reported', () {
      for (final api in [
        'Facade',
        'Facade.neverCalledButPublic',
        'PublicApi',
        'PublicApi.method',
      ]) {
        expect(report.names, isNot(contains(api)), reason: api);
      }
    });

    test('unexported and unreachable code is', () {
      expect(report.names, containsAll(['NotExported', 'internalDead']));
      expect(report.files, ['lib/src/orphan.dart']);
    });

    test('--mode app overrides detection', () async {
      final app = await analyzeFiles(
        {'lib/pkg.dart': 'class A {}\n', 'lib/main_dev.dart': 'void main(){}'},
        pubspec: 'name: app\nenvironment:\n  sdk: ^3.9.0\n',
        config: UnusedCodeConfig(mode: ProjectMode.app),
      );
      expect(app.mode, 'app');
      expect(app.files, ['lib/pkg.dart']);
    });
  });

  test('a project without resolved dependencies is refused', () async {
    final fixture = Fixture.create({'lib/main.dart': 'void main() {}'});
    try {
      File('${fixture.root}/.dart_tool/package_config.json').deleteSync();
      await expectLater(
        fixture.analyze(),
        throwsA(
          isA<AnalysisSetupException>().having(
            (e) => e.message,
            'message',
            contains('pub get'),
          ),
        ),
      );
    } finally {
      fixture.delete();
    }
  });
}
