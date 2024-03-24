import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';

class HotPage extends StatefulWidget {
  const HotPage({super.key});

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage> with RouterDrawerEntryWidget {
  @override
  Widget build(BuildContext context) {
    return PostProvider(
      query: TagMap({'tags': 'order:rank'}),
      child: Consumer<PostController>(
        builder: (context, controller, child) =>
            PostsControllerHistoryConnector(
          controller: controller,
          child: PostsPage(
            appBar: const ContextSizedAppBar(
              title: Text('Hot'),
            ),
            controller: controller,
          ),
        ),
      ),
    );
  }
}
