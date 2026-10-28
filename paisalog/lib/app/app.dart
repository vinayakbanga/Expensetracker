/// Root application widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

class PaisaLogApp extends ConsumerWidget {
  const PaisaLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PaisaLog',
      debugShowCheckedModeBanner: false,
      theme: PaisaTheme.light,
      darkTheme: PaisaTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}

