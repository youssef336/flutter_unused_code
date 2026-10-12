import 'package:flutter_unused_code/flutter_unused_code.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  late UnusedCodeReport report;

  setUpAll(() async {
    report = await analyzeFiles({
      'lib/main.dart': '''
import 'package:flutter/widgets.dart';
import 'model.dart';
import 'repo.dart';
import 'counter.dart';

void main() {
  final user = User.fromJson({'name': 'a'});
  print(user.name);
  print(user.copyWith());
  print(User.guest());
  final Repo repo = RemoteRepo();
  repo.load();
  LocalRepo().save();
  final c = Counter() + Counter();
  c.value = 3;
  print(c[0]);
  print(Counter.maxValue);
  print(Status.ok.label);
  print(const CounterView());
  final Point(:x) = Point(1, 2);
  print(x);
}
''',
      'lib/model.dart': '''
part 'model.g.dart';

class User {
  User({required this.name, required this.onlyInitialized, this.age = 0})
    : initializedInList = 1;

  User.guest() : this(name: 'guest', onlyInitialized: 0);
  User.unusedNamed() : this(name: 'x', onlyInitialized: 0);

  factory User.fromJson(Map<String, Object?> json) => _\$UserFromJson(json);

  final String name;
  final int onlyInitialized;
  final int initializedInList;
  final int age;
  int writtenOnly = 0;

  User copyWith() => this;
  Map<String, Object?> toJson() => _\$UserToJson(this);

  void unusedMethod() {}
  String get unusedGetter => name;
  static const unusedStatic = 1;
  static void unusedStaticMethod() {}

  void touch() => writtenOnly = 2;
}

class Point {
  Point(this.x, this.y);
  final int x;
  final int y;
}
''',
      'lib/model.g.dart': '''
// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'model.dart';

User _\$UserFromJson(Map<String, Object?> json) =>
    User(name: json['name']! as String, onlyInitialized: 0);

Map<String, Object?> _\$UserToJson(User instance) => {'age': instance.age};
''',
      'lib/repo.dart': '''
abstract class Repo {
  Future<void> load();
  Future<void> neverCalled();
}

class RemoteRepo implements Repo {
  @override
  Future<void> load() async {}
  // Implements the interface without @override: still not reported.
  Future<void> neverCalled() async {}
  void extra() {}
}

abstract class Store {
  void save();
}

class LocalRepo extends Store {
  @override
  void save() {}
}
''',
      'lib/counter.dart': '''
import 'package:flutter/widgets.dart';

class Counter {
  static const maxValue = 10;
  int value = 0;
  Counter operator +(Counter other) => this;
  int operator [](int i) => i;
  Counter operator -(Counter other) => this;
}

enum Status {
  ok('fine'),
  unusedValue('never');

  const Status(this.label);
  final String label;
  String get unusedEnumGetter => label;
}

class CounterView extends StatefulWidget {
  const CounterView();
  @override
  State<CounterView> createState() => CounterViewState();
}

class CounterViewState extends State<CounterView> {
  @override
  void initState() {}
  @override
  void dispose() {}
  @override
  Widget build(BuildContext context) => const Text('');
  void unusedHelper() {}
}
''',
    });
  });

  Set<String> members() => {
    for (final f in report.ofCategory(FindingCategory.member)) f.displayName,
  };

  test('reports unused methods, getters, fields, statics and constructors', () {
    expect(
      members(),
      containsAll([
        'User.unusedNamed',
        'User.unusedMethod',
        'User.unusedGetter',
        'User.unusedStatic',
        'User.unusedStaticMethod',
        'User.touch',
        'RemoteRepo.extra',
        'Counter.-',
        'Status.unusedEnumGetter',
        'CounterViewState.unusedHelper',
        'Point.y',
      ]),
    );
  });

  test('a field that is only initialised is unused', () {
    expect(members(), contains('User.onlyInitialized'));
    expect(members(), contains('User.initializedInList'));
    expect(report.finding('User.onlyInitialized').kind, 'field');
  });

  test('assignments outside the constructor count as uses', () {
    expect(members(), isNot(contains('User.writtenOnly')));
    expect(members(), isNot(contains('Counter.value')));
  });

  test('references from generated code count', () {
    expect(members(), isNot(contains('User.age')));
  });

  test('conventional and framework members are kept', () {
    for (final kept in [
      'User.fromJson',
      'User.toJson',
      'User.copyWith',
      'CounterViewState.initState',
      'CounterViewState.dispose',
      'CounterViewState.build',
      'CounterView.createState',
    ]) {
      expect(members(), isNot(contains(kept)), reason: kept);
    }
  });

  test('overrides and interface implementations are kept', () {
    expect(members(), isNot(contains('RemoteRepo.load')));
    expect(members(), isNot(contains('RemoteRepo.neverCalled')));
    expect(members(), isNot(contains('LocalRepo.save')));
  });

  test('a call through a subtype keeps the supertype declaration', () {
    expect(members(), isNot(contains('Store.save')));
    expect(members(), isNot(contains('Repo.load')));
  });

  test('an abstract member nobody calls is reported', () {
    expect(members(), contains('Repo.neverCalled'));
  });

  test('operators, statics, pattern fields and enum fields are tracked', () {
    for (final used in [
      'Counter.+',
      'Counter.[]',
      'Counter.maxValue',
      'Status.label',
      'Point.x',
      'User.guest',
      'User.name',
    ]) {
      expect(members(), isNot(contains(used)), reason: used);
    }
  });

  test('enum values and unnamed constructors are never reported', () {
    expect(members(), isNot(contains('Status.unusedValue')));
    expect(members().where((m) => m.endsWith('.new')), isEmpty);
  });
}
