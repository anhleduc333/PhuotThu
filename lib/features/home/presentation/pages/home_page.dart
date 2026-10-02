import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PhuotThu')),
      body: const Center(
        child: Text(
          'Sẵn sàng cho hành trình đầu tiên',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
