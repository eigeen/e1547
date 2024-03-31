import 'package:e1547/client/client.dart';
import 'package:e1547/follow/follow.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sub/flutter_sub.dart';

class FollowsSubscriptionsPage extends StatelessWidget {
  const FollowsSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RouterDrawerEntry<FollowsSubscriptionsPage>(
      child: ValueListenableBuilder(
        valueListenable: context.watch<Settings>().filterUnseenFollows,
        builder: (context, filterUnseenFollows, child) =>
            SubChangeNotifierProvider<Client, FollowController>(
          create: (context, value) => FollowController(
            client: value,
            types: [FollowType.update, FollowType.notify],
            filterUnseen: filterUnseenFollows,
          ),
          keys: (context) => [filterUnseenFollows],
          child: child,
        ),
        child: Consumer<FollowController>(
          builder: (context, controller, _) => SubEffect(
            effect: () {
              // remove this when the paged grid view is implemented
              controller.getNextPage();
              final client = context.read<Client>();
              if (client.hasFeature(FollowFeature.database)) {
                client.follows.sync();
              }
              return null;
            },
            keys: [controller],
            child: SelectionLayout<Follow>(
              items: controller.items,
              child: PromptActions(
                child: RefreshableDataPage.builder(
                  controller: controller,
                  builder: (context, child) => TileLayout(child: child),
                  child: (context) => PagedAlignedGridView<int, Follow>.count(
                    pagingController: controller.paging,
                    primary: true,
                    padding: defaultActionListPadding,
                    addAutomaticKeepAlives: false,
                    builderDelegate: defaultPagedChildBuilderDelegate(
                      pagingController: controller.paging,
                      itemBuilder: (context, item, index) =>
                          FollowTile(follow: item),
                      onEmpty: const IconMessage(
                        title: Text('No subscriptions'),
                        icon: Icon(Icons.clear),
                      ),
                      onError: const IconMessage(
                        title: Text('Failed to load subscriptions'),
                        icon: Icon(Icons.warning_amber),
                      ),
                    ),
                    crossAxisCount: TileLayout.of(context).crossAxisCount,
                  ),
                  appBar: const FollowSelectionAppBar(
                    child: DefaultAppBar(
                      title: Text('Subscriptions'),
                      actions: [ContextDrawerButton()],
                    ),
                  ),
                  drawer: const RouterDrawer(),
                  endDrawer: const ContextDrawer(
                    title: Text('Subscriptions'),
                    children: [
                      FollowEditingTile(),
                      Divider(),
                      FollowFilterReadTile(),
                      FollowMarkReadTile(),
                      Divider(),
                      FollowForceSyncTile(),
                    ],
                  ),
                  floatingActionButton: AddTagFloatingActionButton(
                    title: 'Add to subscriptions',
                    onSubmit: (value) async {
                      value = value.trim();
                      if (value.isEmpty) return;
                      await context.read<Client>().follows.create(
                            tags: value,
                            type: FollowType.update,
                          );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
