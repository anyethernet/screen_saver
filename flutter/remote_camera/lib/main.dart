import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_model.dart';
import 'home_page.dart';
import 'l10n.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel();
  await model.load();
  runApp(RemoteCameraApp(model: model));
}

class RemoteCameraApp extends StatelessWidget {
  const RemoteCameraApp({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final text = S(model.language);
        return AppScope(
          model: model,
          child: MaterialApp(
            title: text.appName,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: Locale(model.language),
            supportedLocales: const [Locale('en'), Locale('ko')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: HomePage(model: model),
          ),
        );
      },
    );
  }
}
