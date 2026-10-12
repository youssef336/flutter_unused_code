## 0.1.0

First release.

- Resolved reference graph built with `package:analyzer` (no regex).
- Reports unused files (unreachable from entry points through imports,
  exports, parts and every conditional-import branch), unused top-level
  declarations, unused public members, and unused widgets as a highlighted
  subset.
- Liveness is mark-and-sweep: a reference only counts when the code it sits
  in is alive, so a widget kept "alive" only by its own `State` class is
  reported.
- False-positive guards: overrides and interface implementations, Flutter
  lifecycle callbacks, `toJson`/`fromJson`/`copyWith` conventions, generated
  code (`*.g.dart`, `*.freezed.dart`, ...) counted as references but never
  reported, `@pragma('vm:entry-point')`, code-generation annotations,
  `@visibleForTesting`, `// unused_code:ignore` and
  `// unused_code:ignore_file`.
- `unused_code.yaml`: `exclude`, `entry_points`, `ignore_names`,
  `keep_annotations`, `count_test_usage`, `mode`.
- Output: text (grouped by file, with removable-line estimate), `json`,
  `markdown`, `github` annotations; `--fail-on-unused` for CI.
