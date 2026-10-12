import 'dart:convert';

import 'package:flutter_unused_code/flutter_unused_code.dart';
import 'package:test/test.dart';

UnusedCodeReport _report() => UnusedCodeReport(
  root: '/project',
  mode: 'app',
  filesAnalyzed: 12,
  elapsed: const Duration(milliseconds: 1530),
  findings: const [
    Finding(
      category: FindingCategory.member,
      kind: 'method',
      name: 'unused',
      container: 'Service',
      path: 'lib/service.dart',
      line: 14,
      column: 8,
      lines: 3,
    ),
    Finding(
      category: FindingCategory.file,
      kind: 'file',
      name: 'lib/a, b.dart',
      path: 'lib/a, b.dart',
      line: 1,
      column: 1,
      lines: 40,
    ),
    Finding(
      category: FindingCategory.declaration,
      kind: 'widget',
      name: 'OldBanner',
      path: 'lib/service.dart',
      line: 2,
      column: 7,
      lines: 20,
      isWidget: true,
    ),
  ],
);

void main() {
  test('findings are sorted by path, then line', () {
    expect(_report().findings.map((f) => f.displayName), [
      'lib/a, b.dart',
      'OldBanner',
      'Service.unused',
    ]);
  });

  test('counts and removable lines', () {
    final r = _report();
    expect(r.counts, {
      'files': 1,
      'declarations': 1,
      'members': 1,
      'widgets': 1,
      'total': 3,
    });
    expect(r.removableLines, 63);
  });

  test('text groups by file and lists widgets', () {
    final text = formatReport(_report(), OutputFormat.text);
    expect(
      text,
      contains('lib/service.dart\n  2:7      unused widget OldBanner'),
    );
    expect(text, contains('  14:8     unused method Service.unused (3 lines)'));
    expect(text, contains('lib/a, b.dart\n  unused file (40 lines)'));
    expect(
      text,
      contains('Unused widgets (1):\n  OldBanner  lib/service.dart:2'),
    );
    expect(
      text,
      contains(
        '1 unused file, 1 unused declaration (1 widget), 1 unused member'
        ' - ~63 removable lines',
      ),
    );
    expect(text, contains('Analyzed 12 files (app mode) in 1.5s.'));
    expect(text, isNot(contains('\x1B[')));
  });

  test('text can be colored', () {
    expect(
      formatReport(_report(), OutputFormat.text, color: true),
      contains('\x1B['),
    );
  });

  test('empty report', () {
    final empty = UnusedCodeReport(
      root: '/p',
      mode: 'app',
      filesAnalyzed: 1,
      elapsed: Duration.zero,
      findings: const [],
    );
    expect(
      formatReport(empty, OutputFormat.text),
      startsWith('No unused code'),
    );
    expect(formatReport(empty, OutputFormat.markdown), contains('No unused'));
  });

  test('json is complete and parseable', () {
    final json =
        jsonDecode(formatReport(_report(), OutputFormat.json))
            as Map<String, Object?>;
    expect(json['mode'], 'app');
    expect(json['elapsedMs'], 1530);
    expect(json['removableLines'], 63);
    expect((json['counts']! as Map)['widgets'], 1);
    final findings = json['findings']! as List<Object?>;
    expect(findings.last, {
      'category': 'member',
      'kind': 'method',
      'name': 'unused',
      'container': 'Service',
      'path': 'lib/service.dart',
      'line': 14,
      'column': 8,
      'lines': 3,
      'widget': false,
    });
  });

  test('markdown has a summary table and per-file sections', () {
    final md = formatReport(_report(), OutputFormat.markdown);
    expect(md, contains('| Members | 1 |'));
    expect(md, contains('### `lib/service.dart`'));
    expect(md, contains('- L2 **unused widget** `OldBanner` (20 lines)'));
  });

  test('github annotations escape properties', () {
    final lines = formatReport(_report(), OutputFormat.github).split('\n');
    expect(
      lines.first,
      '::warning file=lib/a%2C b.dart,line=1,col=1,title=unused file::'
      'Unused file: no entry point imports it.',
    );
    expect(
      lines[2],
      '::warning file=lib/service.dart,line=14,col=8,title=unused method::'
      'Unused method Service.unused.',
    );
  });
}
