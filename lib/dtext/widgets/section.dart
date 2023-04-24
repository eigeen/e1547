import 'package:e1547/interface/interface.dart';
import 'package:flutter/material.dart';

class SectionWrap extends StatelessWidget {
  const SectionWrap({
    required Key super.key,
    required this.child,
    this.title,
    this.expanded = false,
  });

  final Widget child;
  final String? title;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).canvasColor,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: ExpandableNotifier(
              controller: Expandables.of(context, key!, expanded: expanded),
              child: ExpandableTheme(
                data: ExpandableThemeData(
                  iconColor: Theme.of(context).iconTheme.color,
                ),
                child: ExpandablePanel(
                  header: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      title?.replaceAllMapped(RegExp(r'\n'), (_) => '') ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  collapsed: const SizedBox.shrink(),
                  expanded: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [child],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: dimTextColor(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
