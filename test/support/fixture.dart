import 'dart:convert';
import 'dart:io';

import 'package:flutter_unused_code/flutter_unused_code.dart';
import 'package:path/path.dart' as p;

/// Minimal stand-ins for the Flutter and meta packages, so fixtures can
/// declare real widgets without a Flutter SDK.
const _fakePackages = <String, Map<String, String>>{
  'flutter': {
    'lib/widgets.dart': "export 'src/widgets/framework.dart';\n",
    'lib/src/widgets/framework.dart': '''
abstract class BuildContext {}

abstract class Widget {
  const Widget();
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build(BuildContext context);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget();
  State createState();
}

abstract class State<T extends StatefulWidget> {
  T get widget => throw UnimplementedError();
  void initState() {}
  void dispose() {}
  void didUpdateWidget(T oldWidget) {}
  Widget build(BuildContext context);
}

class Text extends StatelessWidget {
  const Text(this.data);
  final String data;
  @override
  Widget build(BuildContext context) => this;
}
''',
  },
  'meta': {
    'lib/meta.dart': '''
library meta;

class _VisibleForTesting {
  const _VisibleForTesting();
}

const visibleForTesting = _VisibleForTesting();
''',
  },
  'json_annotation': {
    'lib/json_annotation.dart': '''
class JsonKey {
  const JsonKey({this.name});
  final String? name;
}
''',
  },
};

/// A throwaway package on disk with resolved dependencies.
class Fixture {
  Fixture._(this.dir);

  final Directory dir;

  String get root => p.join(dir.path, 'app');

  /// Writes [files] (paths relative to the project root) into a new
  /// project named `app`, with `flutter`, `meta` and `json_annotation`
  /// resolvable. [pubspec] defaults to an app (`publish_to: none`).
  static Fixture create(Map<String, String> files, {String? pubspec}) {
    final dir = Directory.systemTemp.createTempSync('unused_code_test_');
    final fixture = Fixture._(dir);
    final packages = <Map<String, Object>>[
      {
        'name': 'app',
        'rootUri': '../',
        'packageUri': 'lib/',
        'languageVersion': '3.9',
      },
    ];
    _fakePackages.forEach((name, sources) {
      sources.forEach((path, content) {
        _write(p.join(dir.path, 'packages', name, path), content);
      });
      packages.add({
        'name': name,
        'rootUri': '../../packages/$name/',
        'packageUri': 'lib/',
        'languageVersion': '3.9',
      });
    });
    _write(
      p.join(fixture.root, 'pubspec.yaml'),
      pubspec ?? 'name: app\npublish_to: none\nenvironment:\n  sdk: ^3.9.0\n',
    );
    _write(
      p.join(fixture.root, '.dart_tool', 'package_config.json'),
      jsonEncode({'configVersion': 2, 'packages': packages}),
    );
    files.forEach((path, content) {
      _write(p.join(fixture.root, path), content);
    });
    return fixture;
  }

  static void _write(String path, String content) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  Future<UnusedCodeReport> analyze([UnusedCodeConfig? config]) =>
      UnusedCodeAnalyzer(root, config ?? UnusedCodeConfig()).run();

  void delete() => dir.deleteSync(recursive: true);
}

/// Creates a fixture, analyzes it, deletes it.
Future<UnusedCodeReport> analyzeFiles(
  Map<String, String> files, {
  UnusedCodeConfig? config,
  String? pubspec,
}) async {
  final fixture = Fixture.create(files, pubspec: pubspec);
  try {
    return await fixture.analyze(config);
  } finally {
    fixture.delete();
  }
}

extension ReportQueries on UnusedCodeReport {
  /// `Container.name` (or `name`) of every non-file finding.
  Set<String> get names => {
    for (final f in findings)
      if (f.category != FindingCategory.file) f.displayName,
  };

  Set<String> get files => {
    for (final f in ofCategory(FindingCategory.file)) f.path,
  };

  Finding finding(String displayName) =>
      findings.firstWhere((f) => f.displayName == displayName);
}
