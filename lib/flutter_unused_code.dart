/// Finds dead code in Dart and Flutter projects: unused files, top-level
/// declarations, public members and widgets, from a resolved reference
/// graph.
library;

export 'src/cli.dart' show ExitCodes, runCli;
export 'src/config.dart' show ConfigException, ProjectMode, UnusedCodeConfig;
export 'src/formatters.dart' show OutputFormat, formatReport;
export 'src/report.dart' show Finding, FindingCategory, UnusedCodeReport;
export 'src/unused_code_analyzer.dart'
    show AnalysisSetupException, UnusedCodeAnalyzer;
export 'src/version.dart' show packageVersion;
