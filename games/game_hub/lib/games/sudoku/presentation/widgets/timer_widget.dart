import 'package:flutter/material.dart';

class TimerWidget extends StatelessWidget {
  const TimerWidget({super.key, required this.elapsed});
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
