import 'package:flutter/material.dart';

class PowerSlider extends StatelessWidget {
  const PowerSlider({
    super.key,
    required this.power,
    required this.onChanged,
  });

  final double power; // 0.0 – 1.0
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Lực', style: TextStyle(color: Colors.white, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 160,
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                thumbColor: _powerColor(power),
                activeTrackColor: _powerColor(power),
                inactiveTrackColor: Colors.white24,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: power,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        Text(
          '${(power * 100).round()}%',
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Color _powerColor(double p) {
    if (p < 0.4) return Colors.greenAccent;
    if (p < 0.7) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
