[العربية](README.ar.md)

<p align="center"><img src="https://raw.githubusercontent.com/youssef336/flutter_unused_code/main/screenshots/banner.png" alt="flutter_unused_code banner" width="100%"></p>

<h1 align="center">Flutter Unused Code</h1>

<p align="center">
  Find the dead code in any Dart or Flutter project: unused files, classes, functions, public members and widgets, from a real resolved reference graph.
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_unused_code"><img src="https://img.shields.io/pub/v/flutter_unused_code?style=for-the-badge&logo=dart&label=pub.dev" alt="pub.dev"/></a>
  <img src="https://img.shields.io/badge/Dart-3.11%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Flutter-ready-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/package-analyzer-4CAF50?style=for-the-badge" alt="analyzer">
  <img src="https://img.shields.io/badge/CLI-unused__code-555555?style=for-the-badge&logo=gnubash&logoColor=white" alt="CLI">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT">
</p>

> **English summary.** `dart analyze` only warns about unused *private* code. Flutter Unused Code
> finds the public kind too: library files no entry point reaches, top-level declarations nobody
> references, public methods / getters / fields / named constructors nobody calls, and unused widget
> classes as a highlighted subset. It uses `package:analyzer` to resolve every file and builds a real
> reference graph, then runs a mark-and-sweep from the entry points (`lib/main*.dart`, `bin/`,
> `test/`, `integration_test/`, configured globs; for a package, the public `lib/*.dart` API), so a
> widget referenced only by its own `State` class is still reported. Overrides, interface
> implementations, Flutter lifecycle callbacks, JSON conventions, generated code, `@pragma('vm:entry-point')`
> and code-gen annotations are guarded against. Output as text grouped by file with an estimate of
> removable lines, JSON, Markdown, or GitHub annotations; `--fail-on-unused` makes it a CI gate.
> A free, open-source alternative to the now-paid `check-unused-code` of DCM.

`dart analyze` only tells you about private code that nobody uses. This tool finds the rest: files
nobody imports, classes and functions that were forgotten, public methods and fields nobody calls,
and widgets that were built and never used. It is not regex: it analyzes the project with Dart's
own analyzer and builds a real reference graph.

## ✨ What it finds

| Kind | Meaning |
|---|---|
| 📄 Unused file | A file in `lib/` that no entry point reaches through an import, export or part |
| 🧱 Unused declaration | A top-level class / enum / mixin / extension / extension type / typedef / function / variable |
| 🔧 Unused member | A public method / getter / setter / field / static / named constructor / operator |
| 🖼 Unused widget | The same declarations, but widgets, highlighted separately in the report |

For each one it tells you the file, the line, and how many lines would go away if you deleted it
(the doc comment and annotations included).

## 🧠 How it works

- 🔍 It resolves every Dart file in the project with `AnalysisContextCollection`, walks the AST and
  records every reference to a real element (not a name): identifiers, types, constructors,
  operators, `super.named()`, dot shorthands, object patterns, annotations, and the implicit
  `call()`.
- 🗺 **Files:** it starts from the entry points and follows `import` / `export` / `part`, and every
  branch of conditional imports (`if (dart.library.io) ...`). Whatever is not reached = an unused
  file.
- ♻️ **Mark-and-sweep:** a reference only counts if the code it sits in is itself alive. That means:
  - Recursion and a class pointing at itself are not usage.
  - A widget nobody uses, whose `State` says `State<MyWidget>` ← is still reported as unused.
  - Something used only by dead code or by an unreached file ← is dead too.
- 🧪 **Entry points:** `lib/main*.dart`, `bin/`, `test/`, `integration_test/`, `tool/`, and any glob
  you put in the config. If the project is a **package** (no `lib/main*.dart` and no
  `publish_to: none`), every `lib/*.dart` is an entry point, and whatever they export is public
  API, so it is not reported as unused.

## 🛡 How it avoids false positives

- ✅ Overrides and members that implement an interface (even without `@override`).
- ✅ A call to a member from a subclass counts for the original declaration in the
  superclass/interface.
- ✅ Flutter callbacks: `build`, `createState`, `initState`, `dispose`, `didUpdateWidget`,
  `didChangeDependencies`, … and conventions such as `toJson` / `fromJson` / `toMap` / `fromMap` / `copyWith` / `props`.
- ✅ Generated code (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`, `*.mocks.dart`,
  `*.gen.dart`, or any file starting with `GENERATED CODE`): the references inside it count, but it
  is never reported as unused.
- ✅ `@pragma('vm:entry-point')`, and code-gen, DI and routing annotations: `@JsonKey`, `@JsonSerializable`,
  `@freezed`, `@riverpod`, `@HiveField`, `@RoutePage`, `@TypedGoRoute`, `@injectable`, `@singleton`, …
- ✅ `@visibleForTesting`: with `--no-test-usage`, tests keep nothing alive except what is marked
  `@visibleForTesting`.
- ✅ Enum values and unnamed constructors are never reported, and private code is left to
  `dart analyze`.
- ✅ A field that is only set with `this.x` in the constructor and never read ← **is reported**
  (it really is dead).

## 📦 Installation

```bash
# global, from pub.dev
dart pub global activate flutter_unused_code
unused_code                       # inside your project
unused_code path/to/project

# or as a dev dependency
#   dev_dependencies:
#     flutter_unused_code: ^0.1.0
dart run flutter_unused_code
```

You must run `flutter pub get` (or `dart pub get`) in the project first, so the analyzer can
resolve it.

## 🚀 Usage

```text
Usage: unused_code [options] [project-directory]

-f, --format              text (default), json, markdown, github
    --fail-on-unused      exit 1 when anything unused is found (for CI)
-c, --config              config file (default: <project>/unused_code.yaml)
-e, --exclude             glob of files never reported (repeatable)
    --entry               extra entry-point glob (repeatable)
    --ignore-name         regex of names never reported (repeatable)
    --mode                auto (default) | app | package
    --[no-]test-usage     count references from test/ (default: on)
    --[no-]color          colorize text output
```

```text
lib/core/utils/text_styles.dart
  106:26   unused field AppTextStyles.dmSansBold (5 lines)
  113:26   unused field AppTextStyles.robotoRegular (5 lines)

lib/features/profile/widgets/old_banner.dart
  7:7      unused widget OldBanner (24 lines)

lib/legacy/promo.dart
  unused file (88 lines)

Unused widgets (1):
  OldBanner  lib/features/profile/widgets/old_banner.dart:7

1 unused file, 1 unused declaration (1 widget), 2 unused members - ~122 removable lines
Analyzed 163 files (app mode) in 12.8s.
```

| Code | Meaning |
|---|---|
| `0` | OK (or it found things and `--fail-on-unused` is not set) |
| `1` | It found unused code and `--fail-on-unused` is set |
| `64` | Invalid arguments or config |
| `66` | The project could not be analyzed (no `pubspec.yaml` or no `pub get`) |

## ⚙️ Config

Put an `unused_code.yaml` next to the `pubspec.yaml` (the keys can be under `unused_code:` or at
the top level):

```yaml
unused_code:
  exclude:                 # never reported (still counted as roots)
    - lib/legacy/**
  entry_points:            # extra roots, e.g. background isolates
    - lib/workers/*.dart
  ignore_names:            # regexes, matched against `name` and `Class.name`
    - ^debug
    - ^Fake
  keep_annotations:        # your own "keep me" annotations
    - KeepAlive
  count_test_usage: true   # false: tests only keep @visibleForTesting code
  mode: auto               # auto | app | package
```

And in the code itself:

```dart
// unused_code:ignore
class KeptForReflection {}         // the class and its members are skipped

void debugOnly() {} // unused_code:ignore

// unused_code:ignore_file          (anywhere in a file: skip the whole file)
```

## 🤖 In CI

```yaml
- run: dart pub global activate flutter_unused_code
- run: unused_code --format github --fail-on-unused
```

`--format github` emits everything as an annotation on the line itself in the PR, and
`--format markdown` can be written to `$GITHUB_STEP_SUMMARY`.

## ❓ FAQ

- **Why is something that is used reported as unused?** Most likely it is used by code that is
  itself dead (see mark-and-sweep above), or it is called in a way that is not visible in the code
  (reflection, platform channel, isolate entry point). Add `// unused_code:ignore` or
  `@pragma('vm:entry-point')`, or add the file to `entry_points`.
- **What about code used only in tests?** It counts as used by default. If you want to find code
  that is alive only because of the tests: `--no-test-usage`.
- **What about model fields that come from the API?** If a field is filled from `fromJson` and
  nobody reads it, it is reported as unused, and that is correct: deleting it will not break
  anything. If you want to keep it: `ignore_names` or `// unused_code:ignore` on the class.
- **Package or app?** It figures it out on its own: app if there is a `lib/main*.dart` or
  `publish_to: none`, otherwise package. You can force it with `--mode`.
- **How long does it take?** A Flutter project with 160 files: about 13 seconds (most of it is
  resolving the SDK and the packages).
- **Monorepo?** Run it on each package separately. Nested packages (`example/`, `packages/*`) are
  skipped.

## ⚖️ Limitations

- It does not see dynamic usage: `dynamic` calls, mirrors, `noSuchMethod`, names coming from
  strings, or code called from native/platform channels.
- Liveness is per top-level declaration: if a class is alive, any reference from any method in it
  counts (even if that method itself is dead). This reduces false positives but may miss dead
  chains inside a live class.
- Generated Riverpod providers (`fooProvider`) and declarations inside generated code in general are
  not reported.
- It does not look for unused l10n keys or assets.
- It needs `pub get` to have been run, and if there are unresolved packages the results may be
  wrong.
- Enum values, unnamed constructors and setters generated from fields are not reported on their
  own.

## 🛠 Tech stack

- Dart 3.11+, [`package:analyzer`](https://pub.dev/packages/analyzer) 14.x (element model + resolved AST),
  `args`, `glob`, `yaml`, `path`.
- Unit tests with on-disk fixture projects (fake `flutter` / `meta` / `json_annotation` packages, so they
  run without a Flutter SDK); GitHub Actions on ubuntu.

## 🏗 Project structure

| File | Role |
|---|---|
| `bin/flutter_unused_code.dart` | executable (`unused_code`) |
| `lib/src/cli.dart` | flags, config loading, exit codes |
| `lib/src/config.dart` | `unused_code.yaml`, defaults (kept annotations, conventional names, generated patterns) |
| `lib/src/unused_code_analyzer.dart` | file discovery, resolution, reachability, mark-and-sweep, findings |
| `lib/src/unit_scanner.dart` | per-unit AST walk: references, declarations, keep reasons |
| `lib/src/element_keys.dart` | stable element keys, overrides, supertype propagation, widget detection |
| `lib/src/formatters.dart` | text / json / markdown / github output |
| `test/` | fixture-based tests per category and per false-positive guard |

## 🧪 Development

```bash
dart pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

## 📄 License

[MIT](LICENSE)

## 👤 Author

**Youssef Belal Zakaria** · [GitHub @youssef336](https://github.com/youssef336)

⭐ If you like this project, give it a star!
