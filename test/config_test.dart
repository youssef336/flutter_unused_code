import 'dart:io';

import 'package:flutter_unused_code/flutter_unused_code.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('defaults', () {
    final c = UnusedCodeConfig();
    expect(c.countTestUsage, isTrue);
    expect(c.mode, ProjectMode.auto);
    expect(c.isIgnoredName('build'), isTrue);
    expect(c.isIgnoredName('toJson'), isTrue);
    expect(c.isIgnoredName('buildBody'), isFalse);
    expect(c.keepAnnotations, containsAll(['riverpod', 'JsonKey', 'pragma']));
    expect(
      c.generatedGlobs.any((g) => g.matches('lib/a/b.freezed.dart')),
      isTrue,
    );
  });

  test('reads keys under unused_code: or at the top level', () {
    for (final doc in [
      'unused_code:\n  exclude: lib/old/**\n  mode: package\n',
      'exclude: [lib/old/**]\nmode: package\n',
    ]) {
      final c = UnusedCodeConfig.fromYaml(loadYaml(doc));
      expect(c.excludeGlobs.single.matches('lib/old/x.dart'), isTrue);
      expect(c.mode, ProjectMode.package);
    }
  });

  test('all options', () {
    final c = UnusedCodeConfig.fromYaml(
      loadYaml('''
unused_code:
  entry_points: [lib/bg/*.dart]
  ignore_names: ['^debug', 'Fake\$']
  keep_annotations: [Keep]
  count_test_usage: false
'''),
    );
    expect(c.entryGlobs.single.matches('lib/bg/worker.dart'), isTrue);
    expect(c.isIgnoredName('debugDump'), isTrue);
    expect(c.isIgnoredName('save', container: 'RepoFake'), isFalse);
    expect(c.isIgnoredName('ApiFake'), isTrue);
    expect(c.keepAnnotations, contains('Keep'));
    expect(c.countTestUsage, isFalse);
  });

  test('matches Container.name patterns', () {
    final c = UnusedCodeConfig(ignoreNames: [r'^Legacy\.']);
    expect(c.isIgnoredName('run', container: 'Legacy'), isTrue);
    expect(c.isIgnoredName('run', container: 'Modern'), isFalse);
  });

  test('CLI values layer over the file', () {
    final c = UnusedCodeConfig(
      exclude: ['a/**'],
      ignoreNames: ['^x'],
      mode: ProjectMode.package,
    ).merge(exclude: ['b/**'], ignoreNames: ['^y'], countTestUsage: false);
    expect(c.excludeGlobs.length, 2);
    expect(c.isIgnoredName('xa'), isTrue);
    expect(c.isIgnoredName('ya'), isTrue);
    expect(c.isIgnoredName('build'), isTrue);
    expect(c.mode, ProjectMode.package);
    expect(c.countTestUsage, isFalse);
  });

  test('rejects malformed values', () {
    for (final doc in [
      '- a\n- b\n',
      'unused_code: 3\n',
      'exclude: {a: 1}\n',
      'count_test_usage: yes please\n',
      'mode: library\n',
    ]) {
      expect(
        () => UnusedCodeConfig.fromYaml(loadYaml(doc)),
        throwsA(isA<ConfigException>()),
        reason: doc,
      );
    }
  });

  test('load handles missing and broken files', () {
    final dir = Directory.systemTemp.createTempSync('unused_code_cfg_');
    try {
      expect(
        UnusedCodeConfig.load(File('${dir.path}/none.yaml')).countTestUsage,
        isTrue,
      );
      final broken = File('${dir.path}/broken.yaml')..writeAsStringSync('a: [');
      expect(
        () => UnusedCodeConfig.load(broken),
        throwsA(isA<ConfigException>()),
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
