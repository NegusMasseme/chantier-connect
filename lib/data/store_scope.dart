import 'package:flutter/widgets.dart';

import 'store.dart';

/// Donne accès au store partout et reconstruit les écrans à chaque changement.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore super.notifier, required super.child});

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Lecture sans abonnement (dans les callbacks).
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
