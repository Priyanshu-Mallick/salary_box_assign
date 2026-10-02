import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.activeIndex});
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    const labels = ['Ready', 'Location', 'Face', 'Verify'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= activeIndex;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppBrand.mint : AppBrand.surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? AppBrand.mint : AppBrand.border,
                  ),
                ),
                child: active && index < activeIndex
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppBrand.ink,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: active ? AppBrand.ink : AppBrand.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (index < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    color: index < activeIndex
                        ? AppBrand.mint
                        : AppBrand.border,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
