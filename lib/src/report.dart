/// The three report sections.
enum FindingCategory {
  /// A library under `lib/` that no entry point reaches.
  file,

  /// A top-level declaration nothing references.
  declaration,

  /// A public member of a class, mixin, enum or extension nothing references.
  member,
}

/// One piece of unused code.
class Finding {
  const Finding({
    required this.category,
    required this.kind,
    required this.name,
    required this.path,
    required this.line,
    required this.column,
    required this.lines,
    this.container,
    this.isWidget = false,
  });

  final FindingCategory category;

  /// `file`, `class`, `widget`, `enum`, `mixin`, `extension`,
  /// `extension type`, `typedef`, `function`, `variable`, `getter`,
  /// `setter`, `method`, `operator`, `field` or `constructor`.
  final String kind;

  /// The declared name; for a file, its path.
  final String name;

  /// Path relative to the project root, with forward slashes.
  final String path;

  /// 1-based position of the name.
  final int line;
  final int column;

  /// Lines removing it would save (doc comment and annotations included).
  final int lines;

  /// The enclosing class, mixin, enum or extension of a member.
  final String? container;

  /// Whether this is a Flutter widget class.
  final bool isWidget;

  /// `Container.name` for members, `name` otherwise.
  String get displayName => container == null ? name : '$container.$name';

  Map<String, Object?> toJson() => {
    'category': category.name,
    'kind': kind,
    'name': name,
    if (container != null) 'container': container,
    'path': path,
    'line': line,
    'column': column,
    'lines': lines,
    'widget': isWidget,
  };
}

/// The result of one analysis run.
class UnusedCodeReport {
  UnusedCodeReport({
    required this.root,
    required this.mode,
    required this.filesAnalyzed,
    required this.elapsed,
    required List<Finding> findings,
  }) : findings = List<Finding>.unmodifiable(
         <Finding>[...findings]..sort((a, b) {
           final byPath = a.path.compareTo(b.path);
           return byPath != 0 ? byPath : a.line.compareTo(b.line);
         }),
       );

  final String root;

  /// `app` or `package`, after auto-detection.
  final String mode;
  final int filesAnalyzed;
  final Duration elapsed;

  /// Sorted by path, then line.
  final List<Finding> findings;

  bool get isEmpty => findings.isEmpty;

  Iterable<Finding> ofCategory(FindingCategory c) =>
      findings.where((f) => f.category == c);

  Iterable<Finding> get widgets => findings.where((f) => f.isWidget);

  int get removableLines => findings.fold(0, (sum, f) => sum + f.lines);

  Map<String, int> get counts => {
    'files': ofCategory(FindingCategory.file).length,
    'declarations': ofCategory(FindingCategory.declaration).length,
    'members': ofCategory(FindingCategory.member).length,
    'widgets': widgets.length,
    'total': findings.length,
  };
}
