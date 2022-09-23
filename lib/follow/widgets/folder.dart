import 'package:e1547/client/client.dart';
import 'package:e1547/follow/follow.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class FollowsFolderPage extends StatefulWidget {
  const FollowsFolderPage({super.key});

  @override
  State<FollowsFolderPage> createState() => _FollowsFolderPageState();
}

class _FollowsFolderPageState extends State<FollowsFolderPage> {
  final RefreshController refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<FollowsService>().update());
  }

  Future<void> updateRefresh() async {
    FollowsService follows = context.read<FollowsService>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (follows.updating && mounted) {
        if (refreshController.headerMode?.value == RefreshStatus.idle) {
          await refreshController.requestRefresh(
            needCallback: false,
            duration: const Duration(milliseconds: 100),
          );
          await follows.finish;
          if (mounted) {
            ScrollController? scrollController =
                PrimaryScrollController.of(context);
            if (scrollController?.hasClients ?? false) {
              scrollController?.animateTo(
                0,
                duration: defaultAnimationDuration,
                curve: Curves.easeInOut,
              );
            }
            if (follows.error == null) {
              refreshController.refreshCompleted();
            } else {
              refreshController.refreshFailed();
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FollowsService>(
      builder: (context, follows, child) => ListenableListener(
        listener: updateRefresh,
        listenable: follows,
        child: SheetActions(
          controller: SheetActionController(),
          child: AnimatedBuilder(
            animation: follows,
            builder: (context, child) => RefreshablePageLoader(
              onEmpty: const Text('No follows'),
              onLoading: const Text('Loading follows'),
              onError: const Text('Failed to load follows'),
              isError: false,
              isLoading: false,
              isEmpty: follows.items.isEmpty,
              refreshController: refreshController,
              refreshHeader: RefreshablePageDefaultHeader(
                refreshingText:
                    'Refreshing ${follows.progress} / ${follows.items.length}...',
              ),
              builder: (context, child) => TileLayout(child: child),
              child: (context) => AlignedGridView.count(
                primary: true,
                padding: defaultActionListPadding,
                addAutomaticKeepAlives: false,
                itemCount: follows.items.length,
                itemBuilder: (context, index) => FollowTile(
                  follow: follows.items[index],
                ),
                crossAxisCount: TileLayout.of(context).crossAxisCount,
              ),
              appBar: const DefaultAppBar(
                title: Text('Follows'),
                actions: [ContextDrawerButton()],
              ),
              refresh: () async {
                try {
                  await follows.update(force: true);
                  refreshController.refreshCompleted();
                } on DioError {
                  refreshController.refreshFailed();
                }
              },
              drawer: const NavigationDrawer(),
              endDrawer: ContextDrawer(
                title: const Text('Follows'),
                children: [
                  if (context.findAncestorWidgetOfExactType<
                          FollowsSwitcherPage>() !=
                      null)
                    const FollowSwitcherTile(),
                  const FollowEditingTile(),
                  const Divider(),
                  const FollowMarkReadTile(),
                ],
              ),
              floatingActionButton: Builder(
                builder: (context) => AnimatedBuilder(
                  animation: SheetActions.of(context)!,
                  builder: (context, child) => FloatingActionButton(
                    onPressed: SheetActions.of(context)!.action ??
                        () {
                          SheetActions.of(context)!.show(
                            context,
                            ControlledTextWrapper(
                              submit: (value) {
                                value = value.trim();
                                Follow result = Follow(tags: value);
                                if (value.isNotEmpty) {
                                  follows.add(result);
                                }
                              },
                              actionController: SheetActions.of(context)!,
                              builder: (context, controller, submit) =>
                                  TagInput(
                                controller: controller,
                                textInputAction: TextInputAction.done,
                                labelText: 'Add to follows',
                                submit: submit,
                              ),
                            ),
                          );
                        },
                    child: Icon(SheetActions.of(context)!.isShown
                        ? Icons.check
                        : Icons.add),
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
