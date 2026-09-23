import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'widgets/dialog_sair.dart';

void main() {
  runApp(const MLUSBAapp());
}

class MLUSBAapp extends StatelessWidget {
  const MLUSBAapp({super.key});

  static const _corAzulRoyal = Color(0xFF4169E1);

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.dark(
      primary: _corAzulRoyal,
      secondary: _corAzulRoyal,
      surface: Color(0xFF171D24),
      error: Color(0xFFEF5350),
    );

    return MaterialApp(
      title: 'MLUSB Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F1626),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16203A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          filled: true,
          fillColor: Color(0xFF1E2A4A),
          hintStyle: TextStyle(color: Color(0xFF6B7C93)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF16203A),
          selectedItemColor: _corAzulRoyal,
          unselectedItemColor: Color(0xFF6B7C93),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      locale: const Locale('pt', 'BR'),
      home: const _RaizComSaida(),
    );
  }
}

/// Tela raiz que intercepta o gesto/voltar e pergunta antes de sair.
class _RaizComSaida extends StatelessWidget {
  const _RaizComSaida();

  Future<void> _confirmarSaida(BuildContext context) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (_) => const DialogSair(),
    );
    if (sair == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmarSaida(context);
        }
      },
      child: const HomeScreen(),
    );
  }
}