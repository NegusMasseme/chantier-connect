import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/database.dart';
import 'data/store.dart';
import 'data/store_scope.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final db = await AppDatabase.open();
  final store = AppStore(db);
  await store.load();
  runApp(CarnetChantierApp(store: store));
}

class CarnetChantierApp extends StatelessWidget {
  const CarnetChantierApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      notifier: store,
      child: MaterialApp(
        title: 'Chantier Connect',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    );
  }
}
