import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'formatters.dart';
import 'unused_code_analyzer.dart';
import 'version.dart';

/// Exit codes of the CLI.
abstract final class ExitCodes {
  static const ok = 0;
  static const unusedFound = 1;
  static const usage = 64;
  static const setup = 66;
}

ArgParser buildParser() => ArgParser()
  ..addOption(
    'format',
    abbr: 'f',
    allowed: [for (final f in OutputFormat.values) f.name],
    defaultsTo: 'text',
    help: 'Output format.',
  )
  ..addFlag(
    'fail-on-unused',
    negatable: false,
    help: 'Exit with code 1 when anything unused is found (for CI).',
  )
  ..addOption(
    'config',
    abbr: 'c',
    help: 'Config file (default: <project>/unused_code.yaml).',
  )
  ..addMultiOption(
    'exclude',
    abbr: 'e',
    help: 'Glob of files never reported, relative to the project root.',
  )
  ..addMultiOption(
    'entry',
    help: 'Extra entry-point glob (e.g. "lib/workers/*.dart").',
  )
  ..addMultiOption('ignore-name', help: 'Regex of names never reported.')
  ..addOption(
    'mode',
    allowed: [for (final m in ProjectMode.values) m.name],
    help:
        'app: only lib/main*.dart is public. package: lib/*.dart and '
        'what they export are public API. Default: from the config, else auto.',
  )
  ..addFlag(
    'test-usage',
    defaultsTo: null,
    help:
        'Count references from test/ as uses. With --no-test-usage only '
        '@visibleForTesting declarations may be kept alive by tests.',
  )
  ..addFlag('color', defaultsTo: null, help: 'Colorize text output.')
  ..addFlag('version', negatable: false, help: 'Print the version.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

/// Runs the CLI; returns the process exit code.
Future<int> runCli(
  List<String> arguments, {
  StringSink? out,
  StringSink? err,
}) async {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  final parser = buildParser();
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderrSink
      ..writeln(e.message)
      ..writeln(_usage(parser));
    return ExitCodes.usage;
  }
  if (args.flag('help')) {
    stdoutSink.writeln(_usage(parser));
    return ExitCodes.ok;
  }
  if (args.flag('version')) {
    stdoutSink.writeln('unused_code $packageVersion');
    return ExitCodes.ok;
  }
  if (args.rest.length > 1) {
    stderrSink.writeln('Expected at most one project directory.');
    return ExitCodes.usage;
  }

  final root = p.normalize(
    p.absolute(args.rest.isEmpty ? '.' : args.rest.single),
  );
  if (!Directory(root).existsSync()) {
    stderrSink.writeln('Directory not found: $root');
    return ExitCodes.usage;
  }

  final UnusedCodeConfig config;
  try {
    final configPath = args.option('config');
    final file = File(configPath ?? p.join(root, 'unused_code.yaml'));
    if (configPath != null && !file.existsSync()) {
      stderrSink.writeln('Config file not found: $configPath');
      return ExitCodes.usage;
    }
    final mode = args.option('mode');
    config = UnusedCodeConfig.load(file).merge(
      exclude: args.multiOption('exclude'),
      entryPoints: args.multiOption('entry'),
      ignoreNames: args.multiOption('ignore-name'),
      countTestUsage: args['test-usage'] as bool?,
      mode: mode == null ? null : ProjectMode.values.byName(mode),
    );
  } on ConfigException catch (e) {
    stderrSink.writeln('Invalid config: $e');
    return ExitCodes.usage;
  } on FormatException catch (e) {
    stderrSink.writeln('Invalid pattern: ${e.message}');
    return ExitCodes.usage;
  }

  try {
    final report = await UnusedCodeAnalyzer(root, config).run();
    final format = OutputFormat.values.byName(args.option('format')!);
    final color =
        args['color'] as bool? ??
        (out == null && stdout.hasTerminal && stdout.supportsAnsiEscapes);
    stdoutSink.write(formatReport(report, format, color: color));
    if (args.flag('fail-on-unused') && !report.isEmpty) {
      return ExitCodes.unusedFound;
    }
    return ExitCodes.ok;
  } on AnalysisSetupException catch (e) {
    stderrSink.writeln(e.message);
    return ExitCodes.setup;
  }
}

String _usage(ArgParser parser) =>
    'Find unused files, declarations, members and widgets in a Dart or '
    'Flutter project.\n\n'
    'Usage: unused_code [options] [project-directory]\n\n'
    '${parser.usage}\n\n'
    'Exit codes: 0 ok, 1 unused code found (with --fail-on-unused), '
    '64 bad usage, 66 project not analyzable.';
