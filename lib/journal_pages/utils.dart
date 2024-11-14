import 'package:flutter/material.dart';

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSize extends StatefulWidget {
  final Widget child;
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    required this.onChange,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  _MeasureSizeState createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    return Container(
      key: _key,
      child: widget.child,
    );
  }

  final GlobalKey _key = GlobalKey();

  void _afterLayout(_) {
    final context = _key.currentContext;
    if (context == null) return;

    final Size newSize = context.size!;
    widget.onChange(newSize);
  }
}

class ProgressStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const ProgressStepper({
    Key? key,
    required this.currentStep,
    required this.steps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Connector lines
                Positioned.fill(
                  child: Row(
                    children: List.generate(steps.length - 1, (index) {
                      final isActive = index < currentStep;
                      return Expanded(
                        child: Container(
                          height: 2,
                          color: isActive
                              ? Colors.blue
                              : Colors.grey.withOpacity(0.5),
                        ),
                      );
                    }),
                  ),
                ),
                // Circles with numbers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(steps.length, (index) {
                    final isCompleted = index < currentStep;
                    final isActive = index == currentStep;
                    return _buildCircle(isCompleted, isActive, index + 1);
                  }),
                ),
              ],
            ),
          ),
          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.map((step) {
              final index = steps.indexOf(step);
              final isCompleted = index < currentStep;
              final isActive = index == currentStep;
              return Text(
                step,
                style: TextStyle(
                  color: isCompleted || isActive ? Colors.blue : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCircle(bool isCompleted, bool isActive, int number) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isCompleted || isActive ? Colors.blue : Colors.grey,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
