import 'package:flutter/material.dart';
import 'package:gwid/app_sizes.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Звонки')),
      body: const Center(child: Text('Звонки скоро будут доступны')),
    );
  }
}
