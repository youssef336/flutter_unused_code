import 'dart:convert';

import 'report.dart';

/// Output formats of the CLI.
enum OutputFormat { text, json, markdown, github }

/// Renders [report] in [format].
String formatReport(
  UnusedCodeReport report,
  OutputFormat format, {
  bool color = false,
}) => switch (format) {
  OutputFormat.text => formatText(report, color: color),
  OutputFormat.json => formatJson(report),
  OutputFormat.markdown => formatMarkdown(report),
  OutputFormat.github => formatGithub(report),
};

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

String _seconds(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);

String _label(Finding f) => switch (f.category) {
  FindingCategory.file => 'unused file',
  _ => 'unused ${f.kind}',
};

Map<String, List<Finding>> _byFile(UnusedCodeReport report) {
  final groups = <String, List<Finding>>{};
  for (final f in report.findings) {
    (groups[f.path] ??= []).add(f);
  }
  return groups;
}

String _summary(UnusedCodeReport report) {
  final c = report.counts;
  return '${_plural(c['files']!, 'unused file')}, '
      '${_plural(c['declarations']!, 'unused declaration')} '
      '(${_plural(c['widgets']!, 'widget')}), '
      '${_plural(c['members']!, 'unused member')} - '
      '~${_plural(report.removableLines, 'removable line')}';
}

/// Human-readable output grouped by file.
String formatText(UnusedCodeReport report, {bool color = false}) {
  String paint(String code, String s) => color ? '\x1B[${code}m$s\x1B[0m' : s;
  final out = StringBuffer();
  if (report.isEmpty) {
    out.writeln(paint('32', 'No unused code found.'));
  } else {
    for (final entry in _byFile(report).entries) {
      out.writeln(paint('1', entry.key));
      for (final f in entry.value) {
        final label = f.isWidget ? paint('35', 'unused widget') : _label(f);
        final isFile = f.category == FindingCategory.file;
        final parts = [
          if (!isFile) '${f.line}:${f.column}'.padRight(8),
          label,
          if (!isFile) f.displayName,
          paint('2', '(${_plural(f.lines, 'line')})'),
        ];
        out.writeln('  ${parts.join(' ')}');
      }
      out.writeln();
    }
    final widgets = report.widgets.toList();
    if (widgets.isNotEmpty) {
      out.writeln(paint('1', 'Unused widgets (${widgets.length}):'));
      for (final w in widgets) {
        out.writeln('  ${w.name}  ${w.path}:${w.line}');
      }
      out.writeln();
    }
    out.writeln(_summary(report));
  }
  out.writeln(
    paint(
      '2',
      'Analyzed ${_plural(report.filesAnalyzed, 'file')} '
          '(${report.mode} mode) in ${_seconds(report.elapsed)}s.',
    ),
  );
  return out.toString();
}

/// Machine-readable output.
String formatJson(UnusedCodeReport report) =>
    const JsonEncoder.withIndent('  ').convert({
      'root': report.root,
      'mode': report.mode,
      'filesAnalyzed': report.filesAnalyzed,
      'elapsedMs': report.elapsed.inMilliseconds,
      'counts': report.counts,
      'removableLines': report.removableLines,
      'findings': [for (final f in report.findings) f.toJson()],
    });

/// A Markdown report for PR descriptions or job summaries.
String formatMarkdown(UnusedCodeReport report) {
  final out = StringBuffer('## Unused code\n\n');
  if (report.isEmpty) {
    out.writeln('No unused code found.');
    return out.toString();
  }
  final c = report.counts;
  out
    ..writeln('| Unused | Count |')
    ..writeln('|---|---:|')
    ..writeln('| Files | ${c['files']} |')
    ..writeln('| Declarations | ${c['declarations']} |')
    ..writeln('| ... of which widgets | ${c['widgets']} |')
    ..writeln('| Members | ${c['members']} |')
    ..writeln('| Removable lines (est.) | ~${report.removableLines} |')
    ..writeln();
  for (final entry in _byFile(report).entries) {
    out.writeln('### `${entry.key}`\n');
    for (final f in entry.value) {
      if (f.category == FindingCategory.file) {
        out.writeln('- unused file (${_plural(f.lines, 'line')})');
      } else {
        final label = f.isWidget ? '**unused widget**' : _label(f);
        out.writeln(
          '- L${f.line} $label `${f.displayName}` '
          '(${_plural(f.lines, 'line')})',
        );
      }
    }
    out.writeln();
  }
  return out.toString();
}

String _escapeData(String s) =>
    s.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');

String _escapeProperty(String s) =>
    _escapeData(s).replaceAll(':', '%3A').replaceAll(',', '%2C');

/// GitHub Actions workflow commands: one warning annotation per finding.
String formatGithub(UnusedCodeReport report) {
  final out = StringBuffer();
  for (final f in report.findings) {
    final label = f.isWidget ? 'unused widget' : _label(f);
    final message = f.category == FindingCategory.file
        ? 'Unused file: no entry point imports it.'
        : 'Unused ${f.isWidget ? 'widget' : f.kind} ${f.displayName}.';
    out.writeln(
      '::warning file=${_escapeProperty(f.path)},line=${f.line},'
      'col=${f.column},title=${_escapeProperty(label)}::'
      '${_escapeData(message)}',
    );
  }
  out.writeln(_escapeData(_summary(report)));
  return out.toString();
}
