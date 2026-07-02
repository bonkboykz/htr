import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class HtrApp extends StatelessWidget {
  const HtrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HTR',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: appRouter,
    );
  }
}
