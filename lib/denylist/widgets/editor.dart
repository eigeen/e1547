import 'package:e1547/denylist/denylist.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';

class DenyListEditor extends StatefulWidget {
  const DenyListEditor();

  @override
  State<DenyListEditor> createState() => _DenyListEditorState();
}

class _DenyListEditorState extends State<DenyListEditor> {
  late TextEditingController controller = TextEditingController(
      text: context.read<DenylistService>().items.join('\n'));

  @override
  Widget build(BuildContext context) {
    return LoadingDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Blacklist'),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () =>
                tagSearchSheet(context: context, tag: 'e621:blacklist'),
          )
        ],
      ),
      builder: (context, submit) => TextField(
        controller: controller,
        keyboardType: TextInputType.multiline,
        maxLines: null,
      ),
      submit: () async {
        List<String> tags = controller.text.split('\n');
        tags = tags.trim();
        tags.removeWhere((tag) => tag.isEmpty);
        try {
          await context.read<DenylistService>().set(tags);
        } on DenylistUpdateException {
          throw const ActionControllerException(
            message: 'Failed to update blacklist!',
          );
        }
      },
    );
  }
}
