import 'package:analyzer/dart/element/element.dart';

/// A stable identity for a declaration, independent of which analysis
/// context or library cycle produced the element object.
///
/// Top-level: `<library uri>|<name>`. Member: `<library uri>|<Owner>|<name>`,
/// with `<name>=` for setters and `ctor:<name>` for constructors. Implicit
/// getters and setters of a field or top-level variable map to the variable.
String? keyOf(Element? element) {
  if (element == null) return null;
  var e = element.baseElement;
  if (e is PropertyAccessorElement && !e.isOriginDeclaration) {
    e = e.variable.baseElement;
  }
  final library = e.library;
  if (library == null) return null;
  final enclosing = e.enclosingElement;
  final name = memberName(e);
  if (name == null) return null;
  if (enclosing is LibraryElement) return '${library.uri}|$name';
  if (enclosing is InstanceElement) {
    final owner = containerKey(enclosing);
    return owner == null ? null : '$owner|$name';
  }
  return null;
}

/// The key of a class, mixin, enum, extension or extension type.
String? containerKey(InstanceElement element) {
  final e = element.baseElement;
  final library = e.library;
  final name = e.name ?? '<unnamed@${e.firstFragment.offset}>';
  return '${library.uri}|$name';
}

/// The name part of a key: `x`, `x=` for a setter, `ctor:x` for a
/// constructor (`ctor:new` for the unnamed one).
String? memberName(Element e) {
  if (e is ConstructorElement) return 'ctor:${e.name ?? 'new'}';
  if (e is SetterElement) {
    final name = e.name;
    return name == null ? null : '$name=';
  }
  return e.lookupName ?? e.name;
}

/// The keys of every same-named member in the supertypes of [member]'s
/// enclosing type, so a call through a subtype keeps the declaration it
/// implements alive too.
Iterable<String> inheritedKeys(Element member) sync* {
  final e = member.baseElement;
  final owner = e.enclosingElement;
  if (owner is! InterfaceElement) return;
  final name = e.name;
  if (name == null) return;
  for (final type in owner.allSupertypes) {
    final s = type.element;
    if (e is SetterElement) {
      final key = keyOf(s.getSetter(name));
      if (key != null) yield key;
      continue;
    }
    for (final candidate in <Element?>[
      s.getMethod(name),
      s.getGetter(name),
      s.getField(name),
    ]) {
      final key = keyOf(candidate);
      if (key != null) yield key;
    }
  }
}

/// Whether [member] overrides or implements something from a supertype.
bool isOverride(Element member) {
  if (member.metadata.hasOverride) return true;
  final owner = member.enclosingElement;
  if (owner is! InterfaceElement) return false;
  if (member is ExecutableElement && member.isStatic) return false;
  if (member is FieldElement && member.isStatic) return false;
  final name = member.name;
  if (name == null) return false;
  for (final type in owner.allSupertypes) {
    final s = type.element;
    if (member is SetterElement) {
      if (s.getSetter(name) != null) return true;
      continue;
    }
    if (s.getMethod(name) != null || s.getGetter(name) != null) return true;
    if (member is FieldElement && s.getSetter(name) != null) return true;
  }
  return false;
}

/// Whether [element] is a Flutter widget class.
bool isWidgetClass(Element element) {
  if (element is! ClassElement) return false;
  for (final type in element.allSupertypes) {
    final s = type.element;
    if (s.name == 'Widget' &&
        s.library.uri.toString().startsWith('package:flutter/')) {
      return true;
    }
  }
  return false;
}
