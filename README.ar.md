[English](README.md)

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

<div dir="rtl">

`dart analyze` بيقولك على الكود الـ private اللي محدش بيستخدمه وبس. الأداة دي بتلاقيلك الباقي:
الفايلات اللي محدش بيعملها import، والكلاسات والفانكشنز اللي اتنست، والـ methods والـ fields
الـ public اللي محدش بينادي عليها، والـ widgets اللي اتعملت ومحدش استخدمها. مش regex: بتحلل
المشروع بنفس الـ analyzer بتاع Dart وبتبني graph حقيقي للـ references.

## ✨ بتلاقي إيه

| النوع | يعني |
|---|---|
| 📄 فايل مش مستخدم | فايل في `lib/` مفيش entry point بيوصله لا بـ import ولا export ولا part |
| 🧱 declaration مش مستخدم | class / enum / mixin / extension / extension type / typedef / function / variable على مستوى الفايل |
| 🔧 member مش مستخدم | method / getter / setter / field / static / named constructor / operator، public |
| 🖼 widget مش مستخدم | نفس الـ declarations بس widgets، متعلّم عليها لوحدها في التقرير |

ولكل حاجة بتقولك الفايل والسطر وكام سطر هيتشال لو مسحتها (الـ doc comment والـ annotations محسوبين).

## 🧠 بتشتغل إزاي

- 🔍 بتعمل resolve لكل فايل Dart في المشروع بـ `AnalysisContextCollection`، وبتمشي على الـ AST
  وتسجل كل reference لـ element حقيقي (مش اسم): identifiers، types، constructors، operators،
  `super.named()`، dot shorthands، object patterns، الـ annotations، و`call()` الضمني.
- 🗺 **الفايلات:** بتبدأ من الـ entry points وتمشي على `import` / `export` / `part`، وكل فرع في الـ
  conditional imports (`if (dart.library.io) ...`). اللي متوصلوش = فايل مش مستخدم.
- ♻️ **mark-and-sweep:** الـ reference بيتحسب بس لو الكود اللي هو فيه نفسه عايش. يعني:
  - الـ recursion والكلاس اللي بيشاور على نفسه مش استخدام.
  - widget محدش بيستخدمه بس الـ `State` بتاعته بتقول `State<MyWidget>` ← برضه هيطلع مش مستخدم.
  - حاجة مستخدمة بس من كود ميت أو فايل مش متوصل ← ميتة هي كمان.
- 🧪 **الـ entry points:** `lib/main*.dart`، و`bin/`، و`test/`، و`integration_test/`، و`tool/`، وأي glob
  تحطه في الـ config. لو المشروع **package** (مفيش `lib/main*.dart` ولا `publish_to: none`)
  بيبقى كل `lib/*.dart` entry point، واللي بيتعمله export منهم API عام فمش بيتقال عليه مش مستخدم.

## 🛡 بتتجنب الـ false positives إزاي

- ✅ الـ overrides و الـ members اللي بتعمل implement لـ interface (حتى من غير `@override`).
- ✅ نداء member من subclass بيحسب للـ declaration الأصلي في الـ superclass/interface.
- ✅ callbacks بتاعة Flutter: `build`، `createState`، `initState`، `dispose`، `didUpdateWidget`،
  `didChangeDependencies`، … و conventions زي `toJson` / `fromJson` / `toMap` / `fromMap` / `copyWith` / `props`.
- ✅ الكود الـ generated (`*.g.dart`، `*.freezed.dart`، `*.gr.dart`، `*.config.dart`، `*.mocks.dart`،
  `*.gen.dart`، أو أي فايل أوله `GENERATED CODE`): الـ references اللي فيه بتتحسب، بس عمره ما بيتقال عليه مش مستخدم.
- ✅ `@pragma('vm:entry-point')`، وannotations الـ code-gen والـ DI والـ routing: `@JsonKey`، `@JsonSerializable`،
  `@freezed`، `@riverpod`، `@HiveField`، `@RoutePage`، `@TypedGoRoute`، `@injectable`، `@singleton`، …
- ✅ `@visibleForTesting`: مع `--no-test-usage` الـ tests مبتحافظش على أي حاجة غير اللي عليها
  `@visibleForTesting`.
- ✅ الـ enum values والـ unnamed constructors عمرهم ما بيتقال عليهم، والـ private سايبينها لـ `dart analyze`.
- ✅ الـ field اللي بيتعمله `this.x` في الـ constructor وبس عمره ما اتقرا ← **بيتقال عليه** (ده dead فعلًا).

## 📦 التسطيب

</div>

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

<div dir="rtl">

لازم تكون عامل `flutter pub get` (أو `dart pub get`) في المشروع الأول، عشان الـ analyzer يقدر يعمل resolve.

## 🚀 الاستخدام

</div>

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

<div dir="rtl">

| الكود | يعني |
|---|---|
| `0` | تمام (أو لقى حاجات ومفيش `--fail-on-unused`) |
| `1` | لقى كود مش مستخدم ومعاك `--fail-on-unused` |
| `64` | arguments أو config غلط |
| `66` | المشروع مش متحلل (مفيش `pubspec.yaml` أو مفيش `pub get`) |

## ⚙️ الـ config

حط `unused_code.yaml` جنب الـ `pubspec.yaml` (المفاتيح ممكن تبقى تحت `unused_code:` أو على أول مستوى):

</div>

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

<div dir="rtl">

وفي الكود نفسه:

</div>

```dart
// unused_code:ignore
class KeptForReflection {}         // the class and its members are skipped

void debugOnly() {} // unused_code:ignore

// unused_code:ignore_file          (anywhere in a file: skip the whole file)
```

<div dir="rtl">

## 🤖 في الـ CI

</div>

```yaml
- run: dart pub global activate flutter_unused_code
- run: unused_code --format github --fail-on-unused
```

<div dir="rtl">

`--format github` بيطلع كل حاجة كـ annotation على السطر نفسه في الـ PR، و`--format markdown`
تقدر تحطه في `$GITHUB_STEP_SUMMARY`.

## ❓ أسئلة

- **ليه حاجة مستخدمة بتطلع إنها مش مستخدمة؟** غالبًا مستخدمة من كود هو نفسه ميت (شوف الـ
  mark-and-sweep فوق)، أو بتتنادي بطريقة مش ظاهرة في الكود (reflection، platform channel، isolate
  entry point). حط `// unused_code:ignore` أو `@pragma('vm:entry-point')` أو ضيف الفايل لـ `entry_points`.
- **الكود اللي مستخدم في الـ tests بس؟** بيتحسب مستخدم by default. لو عايز تعرف الكود اللي عايش
  بس عشان الـ tests: `--no-test-usage`.
- **الـ fields بتاعة الـ models اللي بتيجي من الـ API؟** لو field بيتملى من `fromJson` ومحدش بيقراه،
  هيطلع إنه مش مستخدم، وده صح: مسحه مش هيكسر حاجة. لو عايزه: `ignore_names` أو `// unused_code:ignore` على الكلاس.
- **package ولا app؟** بيعرف لوحده. app لو فيه `lib/main*.dart` أو `publish_to: none`، وإلا package.
  تقدر تجبره بـ `--mode`.
- **بياخد وقت قد إيه؟** مشروع Flutter فيه 160 فايل: حوالي 13 ثانية (أغلبها resolve للـ SDK والـ packages).
- **monorepo؟** شغلها على كل package لوحدها. الـ packages المتداخلة (`example/`، `packages/*`) بتتساب.

## ⚖️ الحدود

- مش بيشوف الاستخدام الديناميكي: `dynamic` calls، mirrors، `noSuchMethod`، أسماء جاية من strings،
  أو كود بيتنادي من native/platform channels.
- الحيوية على مستوى الـ declaration اللي على مستوى الفايل: لو الكلاس عايش، أي reference من أي method
  فيه بتتحسب (حتى لو الـ method دي نفسها ميتة). بيقلل الـ false positives بس ممكن يفوّت سلاسل ميتة جوه كلاس عايش.
- providers الـ Riverpod الـ generated (`fooProvider`) والـ declarations اللي جوه الكود الـ generated عمومًا مش بتتقال.
- مش بيدور على l10n keys أو assets مش مستخدمة.
- محتاج `pub get` يكون معمول، ولو فيه packages مش متحلّة النتايج ممكن تبقى غلط.
- قيم الـ enum والـ unnamed constructors والـ setters المتولدة من fields مش بتتقال لوحدها.

</div>

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
