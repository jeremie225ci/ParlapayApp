// lib/restart_wigdet.dart
import 'package:flutter/material.dart';

class RestartWidget extends StatefulWidget {
  final Widget child;
  
  const RestartWidget({Key? key, required this.child}) : super(key: key);

  // Método estático para reiniciar la app
  static void restartApp(BuildContext context) {
    final state = context.findAncestorStateOfType<_RestartWidgetState>();
    if (state != null) {
      state.restartApp();
    }
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}