import 'dart:convert';
import 'dart:io';

import 'package:flutter_unused_code/flutter_unused_code.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/fixture.dart';

void main() {
  late Fixture fixture;

  setUpAll(() {
    fixture = Fixture.create({
      'lib/main.dart': "import 'a.dart';\n\nvoid main() => used();\n",
      'lib/a.dart': 'void used() {}\n\nvoid unused() {}\n',
      'lib/legacy.dart': 'class Legacy {}\n',
    });
  });

  tearDownAll(() => fixture.delete());

  Future<(int, String, String)> run(List<String> args) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runCli(args, out: out, err: err);
    return (code, out.toString(), err.toString());
  }

  test('text report, exit 0 without --fail-on-unused', () async {
    final (code, out, _) = await run([fixture.root]);
    expect(code, ExitCodes.ok);
    expect(out, contains('lib/a.dart\n  3:6      unused function unused'));
    expect(out, contains('lib/legacy.dart\n  unused file'));
  });

  test('--fail-on-unused exits 1 when something is found', () async {
    final (code, _, _) = await run([fixture.root, '--fail-on-unused']);
    expect(code, ExitCodes.unusedFound);
  });

  test('--fail-on-unused exits 0 when everything is excluded', () async {
    final (code, out, _) = await run([
      fixture.root,
      '--fail-on-unused',
      '-e',
      'lib/legacy.dart',
      '--ignore-name',
      '^unused\$',
    ]);
    expect(code, ExitCodes.ok);
    expect(out, startsWith('No unused code found.'));
  });

  test('--format json', () async {
    final (_, out, _) = await run([fixture.root, '-f', 'json']);
    final json = jsonDecode(out) as Map<String, Object?>;
    expect((json['counts']! as Map)['total'], 2);
  });

  test('reads unused_code.yaml from the project, or --config', () async {
    final config = File('${fixture.root}/unused_code.yaml')
      ..writeAsStringSync('unused_code:\n  exclude: [lib/legacy.dart]\n');
    try {
      final (_, out, _) = await run([fixture.root, '-f', 'json']);
      expect(((jsonDecode(out) as Map)['counts'] as Map)['total'], 1);
    } finally {
      config.deleteSync();
    }
    final other = File('${fixture.dir.path}/other.yaml')
      ..writeAsStringSync('ignore_names: [^unused]\n');
    final (_, out, _) = await run([
      fixture.root,
      '-f',
      'json',
      '--config',
      other.path,
    ]);
    expect(((jsonDecode(out) as Map)['counts'] as Map)['total'], 1);
  });

  test('usage errors exit 64', () async {
    expect((await run(['--format', 'xml'])).$1, ExitCodes.usage);
    expect((await run(['a', 'b'])).$1, ExitCodes.usage);
    expect((await run(['/definitely/not/here'])).$1, ExitCodes.usage);
    expect(
      (await run([fixture.root, '--config', '/nope.yaml'])).$1,
      ExitCodes.usage,
    );
    expect(
      (await run([fixture.root, '--ignore-name', '('])).$1,
      ExitCodes.usage,
    );
  });

  test('a directory without a pubspec exits 66', () async {
    final (code, _, err) = await run([fixture.dir.path]);
    expect(code, ExitCodes.setup);
    expect(err, contains('No pubspec.yaml'));
  });

  test('--help and --version', () async {
    final (code, out, _) = await run(['--help']);
    expect(code, ExitCodes.ok);
    expect(out, contains('Usage: unused_code'));
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final (_, version, _) = await run(['--version']);
    expect(version.trim(), 'unused_code ${pubspec['version']}');
  });
}
