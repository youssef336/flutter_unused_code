# Example

A small Dart app with some dead code, and what `unused_code` reports for it.

## Project

```text
todo_app/
├── pubspec.yaml
└── lib/
    ├── main.dart
    ├── legacy/old_sync.dart
    └── src/
        ├── todo.dart
        └── todo_store.dart
```

`pubspec.yaml` (`publish_to: none` and `lib/main.dart` make it an app, so `lib/main.dart` is the
entry point):

```yaml
name: todo_app
publish_to: none
environment:
  sdk: ^3.11.0
```

`lib/main.dart`:

```dart
import 'src/todo.dart';
import 'src/todo_store.dart';

void main() {
  final store = TodoStore()..add(Todo('Buy milk'));
  print(store.items.length);
}
```

`lib/src/todo.dart`:

```dart
class Todo {
  Todo(this.title, {this.priority = 0});

  final String title;
  final int priority;

  Todo copyWith({String? title}) => Todo(title ?? this.title);

  String get shortTitle =>
      title.length > 10 ? '${title.substring(0, 10)}...' : title;
}

String formatTodo(Todo todo) => '- ${todo.title}';
```

`lib/src/todo_store.dart`:

```dart
import 'todo.dart';

class TodoStore {
  final List<Todo> items = [];

  void add(Todo todo) => items.add(todo);

  void clearCompleted() {
    items.clear();
  }
}
```

`lib/legacy/old_sync.dart` (nothing imports it):

```dart
import '../src/todo.dart';

Future<void> syncTodos(List<Todo> todos) async {
  for (final todo in todos) {
    print(todo.title);
  }
}
```

## Run it

```bash
dart pub global activate flutter_unused_code
cd todo_app
dart pub get          # the analyzer needs resolved packages
unused_code --no-color
```

```text
lib/legacy/old_sync.dart
  unused file (8 lines)

lib/src/todo.dart
  5:13     unused field Todo.priority (1 line)
  9:14     unused getter Todo.shortTitle (2 lines)
  13:8     unused function formatTodo (1 line)

lib/src/todo_store.dart
  8:8      unused method TodoStore.clearCompleted (3 lines)

1 unused file, 1 unused declaration (0 widgets), 3 unused members - ~15 removable lines
Analyzed 4 files (app mode) in 1.8s.
```

`copyWith` is not reported because it is a known convention. `Todo.priority` is reported because
it is only ever set through `this.priority`, never read.

## In CI

`--fail-on-unused` turns the report into a gate (exit code `1` when anything is unused):

```bash
unused_code --format github --fail-on-unused
```

## Configure

`unused_code.yaml` next to `pubspec.yaml`:

```yaml
unused_code:
  exclude:
    - lib/legacy/**
  ignore_names:
    - ^Todo\.priority$
```

With it, the unused file and `Todo.priority` are no longer reported:

```text
lib/src/todo.dart
  9:14     unused getter Todo.shortTitle (2 lines)
  13:8     unused function formatTodo (1 line)

lib/src/todo_store.dart
  8:8      unused method TodoStore.clearCompleted (3 lines)

0 unused files, 1 unused declaration (0 widgets), 2 unused members - ~6 removable lines
```
