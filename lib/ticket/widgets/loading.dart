import 'package:e1547/interface/interface.dart';
import 'package:flutter/material.dart';

class ReportLoadingOverlay extends StatelessWidget {
  const ReportLoadingOverlay({
    required this.child,
    required this.isLoading,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: CrossFade(
            showChild: isLoading,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
