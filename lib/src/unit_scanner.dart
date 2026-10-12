import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';

import 'config.dart';
import 'element_keys.dart';
import 'report.dart';

final _ignoreLine = RegExp(r'unused_code:ignore(?!_file)\b');

/// A declaration that could be reported, with the facts needed to decide.
class Declared {
  Declared({
    required this.key,
    required this.category,
    required this.kind,
    required this.name,
    required this.line,
    required this.column,
    required this.lines,
    required this.keepReason,
    required this.visibleForTesting,
    this.container,
    this.containerKey,
    this.isWidget = false,
  });

  final String key;
  final FindingCategory category;
  final String kind;
  final String name;
  final String? container;
  final String? containerKey;
  final int line;
  final int column;
  final int lines;
  final bool isWidget;

  /// Why it is never reported (override, annotation, ...), or `null`.
  final String? keepReason;
  final bool visibleForTesting;
}

/// What one compilation unit declares and references.
class UnitScan {
  UnitScan(this.path);

  final String path;

  /// Keys this unit references (self references aside), grouped by the
  /// top-level declaration the reference sits in. References outside any
  /// declaration (library annotations) are under the `null` owner.
  final Map<String?, Set<String>> references = {};

  /// Absolute paths reached through `import`, `export` and `part`
  /// (every conditional-import branch included).
  final Set<String> edges = {};

  final List<Declared> declarations = [];

  /// Declarations kept alive by an annotation, an ignore comment or a
  /// conventional name: liveness starts from them.
  final Set<String> rootKeys = {};
}

/// Walks one resolved unit, recording references and (when [collect] is
/// true) the declarations it could report.
class UnitScanner extends GeneralizingAstVisitor<void> {
  UnitScanner({
    required this.unit,
    required this.config,
    required this.collect,
    required String content,
    required String path,
    Map<String, List<String>>? inheritedCache,
  }) : _inheritedCache = inheritedCache ?? {},
       scan = UnitScan(path),
       _lineInfo = unit.lineInfo,
       _ignoredLines = _markerLines(content);

  final CompilationUnit unit;
  final UnusedCodeConfig config;
  final bool collect;
  final UnitScan scan;
  final LineInfo _lineInfo;
  final Set<int> _ignoredLines;

  /// Keys of the declarations enclosing the node being visited.
  final List<String> _stack = [];

  /// Keys of containers whose members are all kept (by annotation or
  /// ignore comment), so their members are not even collected.
  final Set<String> _keptContainers = {};

  /// Shared across the units of one run: supertype lookups are not free.
  final Map<String, List<String>> _inheritedCache;

  static Set<int> _markerLines(String content) {
    final lines = <int>{};
    var line = 1;
    for (final text in content.split('\n')) {
      if (_ignoreLine.hasMatch(text)) lines.add(line);
      line++;
    }
    return lines;
  }

  /// Scans [unit] and returns the result.
  UnitScan run() {
    for (final directive in unit.directives) {
      _collectEdges(directive);
    }
    unit.accept(this);
    return scan;
  }

  void _collectEdges(Directive directive) {
    void add(DirectiveUri? uri) {
      if (uri is DirectiveUriWithSource) scan.edges.add(uri.source.fullName);
    }

    if (directive is ImportDirective) {
      add(directive.libraryImport?.uri);
    } else if (directive is ExportDirective) {
      add(directive.libraryExport?.uri);
    } else if (directive is PartDirective) {
      add(directive.partInclude?.uri);
    } else if (directive is PartOfDirective) {
      final library = unit.declaredFragment?.element;
      if (library != null) {
        scan.edges.add(library.firstFragment.source.fullName);
      }
    }
    if (directive is NamespaceDirective) {
      for (final c in directive.configurations) {
        add(c.resolvedUri);
      }
    }
  }

  @override
  void visitNode(AstNode node) {
    // Doc comments and directives (`show`/`hide` names, barrel exports) are
    // not uses.
    if (node is Comment || node is Directive) return;
    if (node is ConstructorFieldInitializer) {
      // `: field = value` initialises the field; it is not a read.
      node.expression.accept(this);
      return;
    }

    _recordReferences(node);

    String? pushed;
    if (node is Declaration) {
      final element = node.declaredFragment?.element;
      final key = keyOf(element);
      if (key != null && element != null) {
        if (collect) _declare(node, element, key);
        _stack.add(key);
        pushed = key;
      }
    }
    node.visitChildren(this);
    if (pushed != null) _stack.removeLast();
  }

  void _recordReferences(AstNode node) {
    switch (node) {
      case Identifier(:final element):
        _use(element);
      case NamedType(:final element):
        _use(element);
      case Annotation(:final element):
        _use(element);
      case ConstructorName(:final element):
        _use(element);
      case SuperConstructorInvocation(:final element):
        _use(element);
      case RedirectingConstructorInvocation(:final element):
        _use(element);
      case DotShorthandConstructorInvocation(:final element):
        _use(element);
      case FunctionExpressionInvocation(:final element):
        _use(element);
      case PatternField(:final element):
        _use(element);
      case RelationalPattern(:final element):
        _use(element);
      case ExtensionOverride(:final element):
        _use(element);
      case EnumConstantDeclaration(:final constructorElement):
        _use(constructorElement);
      default:
    }
    if (node is MethodReferenceExpression) _use(node.element);
    if (node is CompoundAssignmentExpression) {
      _use(node.readElement);
      _use(node.writeElement);
    }
  }

  void _use(Element? element) {
    final key = keyOf(element);
    if (key == null || element == null || _stack.contains(key)) return;
    final references = scan.references.putIfAbsent(
      _stack.isEmpty ? null : _stack.first,
      () => {},
    );
    references.add(key);
    final owner = element.baseElement.enclosingElement;
    if (owner is InstanceElement) {
      final ownerKey = containerKey(owner);
      if (ownerKey != null && !_stack.contains(ownerKey)) {
        references.add(ownerKey);
      }
      references.addAll(
        _inheritedCache.putIfAbsent(key, () => inheritedKeys(element).toList()),
      );
    }
  }

  void _declare(Declaration node, Element element, String key) {
    final owner = element.enclosingElement;
    final isMember = owner is InstanceElement;
    if (owner is! LibraryElement && !isMember) return; // locals
    final kind = _kindOf(element);
    if (kind == null) return;
    final name = element.name;
    if (name == null) return;

    final ownerKey = isMember ? containerKey(owner) : null;
    if (ownerKey != null && _keptContainers.contains(ownerKey)) return;

    // Doc comment and annotations are part of what deleting it removes; a
    // lone variable takes its whole `final x = ...;` statement with it.
    final AstNode anchor = node is VariableDeclaration
        ? _variableAnchor(node)
        : node;
    final metadata = anchor is AnnotatedNode
        ? anchor.metadata
        : const <Annotation>[];
    final nameOffset = element.firstFragment.nameOffset ?? node.offset;
    final start = _lineInfo.getLocation(anchor.offset);
    final end = _lineInfo.getLocation(anchor.end);
    final at = _lineInfo.getLocation(nameOffset);

    final keepReason = _keepReason(
      element: element,
      name: name,
      container: isMember ? owner.name : null,
      metadata: metadata,
      firstLine: start.lineNumber,
      nameLine: at.lineNumber,
    );
    if (keepReason != null) {
      scan.rootKeys.add(key);
      if (!isMember && element is InstanceElement) _keptContainers.add(key);
    }
    // Private declarations are `dart analyze`'s job; they only take part in
    // liveness.
    if (element.isPrivate) return;

    scan.declarations.add(
      Declared(
        key: key,
        category: isMember
            ? FindingCategory.member
            : FindingCategory.declaration,
        kind: kind,
        name: name,
        container: isMember ? owner.name : null,
        containerKey: ownerKey,
        line: at.lineNumber,
        column: at.columnNumber,
        lines: end.lineNumber - start.lineNumber + 1,
        isWidget: kind == 'widget',
        keepReason: keepReason,
        visibleForTesting: element.metadata.hasVisibleForTesting,
      ),
    );
  }

  AstNode _variableAnchor(VariableDeclaration node) {
    final list = node.parent;
    if (list is VariableDeclarationList && list.variables.length == 1) {
      final statement = list.parent;
      if (statement is FieldDeclaration ||
          statement is TopLevelVariableDeclaration) {
        return statement!;
      }
    }
    return node;
  }

  String? _keepReason({
    required Element element,
    required String name,
    required String? container,
    required List<Annotation> metadata,
    required int firstLine,
    required int nameLine,
  }) {
    for (var line = firstLine - 1; line <= nameLine; line++) {
      if (_ignoredLines.contains(line)) return 'ignore comment';
    }
    for (final annotation in metadata) {
      final id = annotation.name;
      final annotationName = id is PrefixedIdentifier
          ? id.identifier.name
          : id.name;
      if (annotationName == 'pragma') {
        if ((annotation.arguments?.toSource() ?? '').contains('entry-point')) {
          return 'entry-point pragma';
        }
        continue;
      }
      if (config.keepAnnotations.contains(annotationName)) {
        return '@$annotationName';
      }
    }
    if (element is TopLevelFunctionElement && name == 'main') return 'main';
    if (config.isIgnoredName(name, container: container)) return 'ignored name';
    if (container != null && isOverride(element)) return 'override';
    return null;
  }

  static String? _kindOf(Element e) {
    return switch (e) {
      ClassElement() => isWidgetClass(e) ? 'widget' : 'class',
      EnumElement() => 'enum',
      MixinElement() => 'mixin',
      ExtensionTypeElement() => 'extension type',
      ExtensionElement() => e.name == null ? null : 'extension',
      TypeAliasElement() => 'typedef',
      TopLevelFunctionElement() => 'function',
      TopLevelVariableElement() => 'variable',
      FieldElement() => e.isEnumConstant ? null : 'field',
      ConstructorElement() =>
        e.name == 'new' || e.name == null ? null : 'constructor',
      MethodElement() => e.isOperator ? 'operator' : 'method',
      GetterElement() => 'getter',
      SetterElement() => 'setter',
      _ => null,
    };
  }
}
