import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// How the project's public API is treated.
enum ProjectMode {
  /// Decide from the project layout: an app has `lib/main*.dart` or
  /// `publish_to: none` in its pubspec, anything else is a package.
  auto,

  /// Only `lib/main*.dart` (plus `bin/`, tests and configured entries) are
  /// entry points. Every public declaration must be used somewhere.
  app,

  /// Every public library directly under `lib/` is an entry point, and the
  /// declarations it exports are public API, so they are never reported.
  package,
}

/// Annotations that keep a declaration alive even with no reference: code
/// generators, dependency injection, routing and the VM entry-point pragma.
const defaultKeepAnnotations = <String>{
  'pragma',
  'JsonKey',
  'JsonValue',
  'JsonEnum',
  'JsonSerializable',
  'JsonConverter',
  'freezed',
  'Freezed',
  'unfreezed',
  'riverpod',
  'Riverpod',
  'ProviderFor',
  'HiveType',
  'HiveField',
  'RoutePage',
  'AutoRouterConfig',
  'TypedGoRoute',
  'TypedShellRoute',
  'TypedStatefulShellRoute',
  'TypedStatefulShellBranch',
  'injectable',
  'Injectable',
  'singleton',
  'Singleton',
  'lazySingleton',
  'LazySingleton',
  'module',
  'preResolve',
  'factoryMethod',
  'Named',
  'GenerateMocks',
  'GenerateNiceMocks',
  'Preview',
  'UseCase',
  'widgetbook',
};

/// Member names that are called by a framework or a code-generation
/// convention rather than from user code.
const defaultIgnoredNames = <String>[
  r'^(main|build|createState|initState|dispose|didUpdateWidget)$',
  r'^(didChangeDependencies|deactivate|activate|reassemble)$',
  r'^(debugFillProperties|toJson|fromJson|toMap|fromMap|copyWith)$',
  r'^(props|stringify)$',
];

/// File name patterns of generated code: never reported, but every
/// reference they contain counts.
const defaultGeneratedPatterns = <String>[
  '**.g.dart',
  '**.freezed.dart',
  '**.gr.dart',
  '**.config.dart',
  '**.mocks.dart',
  '**.gen.dart',
  '**.pb.dart',
  '**.pbenum.dart',
  '**.pbjson.dart',
  '**.pbserver.dart',
  '**.chopper.dart',
  '**.reflectable.dart',
];

Glob _glob(String pattern) => Glob(pattern, context: p.posix);

/// Thrown for an unreadable or malformed configuration.
class ConfigException implements Exception {
  ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Effective configuration: `unused_code.yaml` merged with CLI flags.
class UnusedCodeConfig {
  UnusedCodeConfig({
    List<String> exclude = const [],
    List<String> entryPoints = const [],
    List<String> ignoreNames = const [],
    Iterable<String> keepAnnotations = const [],
    this.countTestUsage = true,
    this.mode = ProjectMode.auto,
  }) : excludeGlobs = [for (final g in exclude) _glob(g)],
       entryGlobs = [for (final g in entryPoints) _glob(g)],
       generatedGlobs = [for (final g in defaultGeneratedPatterns) _glob(g)],
       ignoreNamePatterns = [
         for (final p in [...defaultIgnoredNames, ...ignoreNames]) RegExp(p),
       ],
       keepAnnotations = {...defaultKeepAnnotations, ...keepAnnotations};

  /// Reads [file] if it exists; otherwise returns the defaults.
  factory UnusedCodeConfig.load(File file) {
    if (!file.existsSync()) return UnusedCodeConfig();
    final Object? doc;
    try {
      doc = loadYaml(file.readAsStringSync());
    } on YamlException catch (e) {
      throw ConfigException('${file.path}: ${e.message}');
    }
    return UnusedCodeConfig.fromYaml(doc, source: file.path);
  }

  /// Builds a configuration from a parsed YAML document. Keys may sit at the
  /// top level or under an `unused_code:` section.
  factory UnusedCodeConfig.fromYaml(Object? doc, {String source = 'config'}) {
    if (doc == null) return UnusedCodeConfig();
    if (doc is! Map) {
      throw ConfigException('$source: expected a map at the top level');
    }
    final section = doc['unused_code'] ?? doc;
    if (section is! Map) {
      throw ConfigException('$source: `unused_code` must be a map');
    }
    List<String> list(String key) {
      final value = section[key];
      if (value == null) return const [];
      if (value is String) return [value];
      if (value is List) return [for (final v in value) '$v'];
      throw ConfigException('$source: `$key` must be a string or a list');
    }

    final countTests = section['count_test_usage'];
    if (countTests != null && countTests is! bool) {
      throw ConfigException('$source: `count_test_usage` must be true/false');
    }
    final modeName = section['mode'];
    final mode = modeName == null
        ? ProjectMode.auto
        : ProjectMode.values.firstWhere(
            (m) => m.name == modeName,
            orElse: () => throw ConfigException(
              '$source: `mode` must be auto, app or package',
            ),
          );
    try {
      return UnusedCodeConfig(
        exclude: list('exclude'),
        entryPoints: list('entry_points'),
        ignoreNames: list('ignore_names'),
        keepAnnotations: list('keep_annotations'),
        countTestUsage: countTests as bool? ?? true,
        mode: mode,
      );
    } on FormatException catch (e) {
      throw ConfigException('$source: ${e.message}');
    }
  }

  final List<Glob> excludeGlobs;
  final List<Glob> entryGlobs;
  final List<Glob> generatedGlobs;
  final List<RegExp> ignoreNamePatterns;
  final Set<String> keepAnnotations;
  final bool countTestUsage;
  final ProjectMode mode;

  /// Returns a copy with CLI values layered on top.
  UnusedCodeConfig merge({
    List<String> exclude = const [],
    List<String> entryPoints = const [],
    List<String> ignoreNames = const [],
    bool? countTestUsage,
    ProjectMode? mode,
  }) {
    final merged = UnusedCodeConfig(
      countTestUsage: countTestUsage ?? this.countTestUsage,
      mode: mode == null || mode == ProjectMode.auto ? this.mode : mode,
      keepAnnotations: keepAnnotations,
    );
    merged.excludeGlobs
      ..addAll(excludeGlobs)
      ..addAll(exclude.map(_glob));
    merged.entryGlobs
      ..addAll(entryGlobs)
      ..addAll(entryPoints.map(_glob));
    merged.ignoreNamePatterns
      ..clear()
      ..addAll(ignoreNamePatterns)
      ..addAll(ignoreNames.map(RegExp.new));
    return merged;
  }

  /// Whether [name] (or `Container.name`) matches an ignore pattern.
  bool isIgnoredName(String name, {String? container}) {
    for (final p in ignoreNamePatterns) {
      if (p.hasMatch(name)) return true;
      if (container != null && p.hasMatch('$container.$name')) return true;
    }
    return false;
  }
}
