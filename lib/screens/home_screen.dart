import 'package:flutter/material.dart';

import 'backup_screen.dart';
import 'file_manager_screen.dart';
import 'utilitarios_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          FileManagerScreen(
            aoIrParaUtilitarios: () => setState(() => _indice = 1),
            aoIrParaBackup: () => setState(() => _indice = 2),
          ),
          const UtilitariosScreen(),
          const BackupScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (i) => setState(() => _indice = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open),
            label: 'Arquivos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dns),
            label: 'Disco',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backup),
            label: 'Backup',
          ),
        ],
      ),
    );
  }
}