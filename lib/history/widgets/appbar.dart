import 'package:e1547/history/history.dart';
import 'package:e1547/interface/interface.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistorySelectionAppBar extends StatelessWidget with AppBarBuilderWidget {
  @override
  final PreferredSizeWidget child;

  const HistorySelectionAppBar({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionAppBar<History>(
      child: child,
      titleBuilder: (context, data) => data.selections.length == 1
          ? Text(data.selections.first.getName(context))
          : Text('${data.selections.length} entries'),
      actionBuilder: (context, data) => [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            context
                .read<HistoriesService>()
                .removeAll(data.selections.toList());
            data.onChanged({});
          },
        ),
      ],
    );
  }
}
