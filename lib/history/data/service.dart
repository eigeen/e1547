import 'package:collection/collection.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/denylist/denylist.dart';
import 'package:e1547/history/history.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/pool/pool.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/reply/reply.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/topic/topic.dart';
import 'package:e1547/user/user.dart';
import 'package:e1547/wiki/wiki.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';

class HistoriesService extends ChangeNotifier {
  HistoriesService({
    required this.settings,
    required this.client,
    required this.denylist,
    String? path,
  }) : _database = HistoriesDatabase.connect(path: path) {
    client.addListener(notifyListeners);
    settings.writeHistory.addListener(notifyListeners);
    settings.trimHistory.addListener(notifyListeners);
  }

  final Settings settings;
  final Client client;
  final DenylistService denylist;

  final HistoriesDatabase _database;

  set enabled(bool value) => settings.writeHistory.value = value;

  bool get enabled => settings.writeHistory.value;

  set trimming(bool value) => settings.trimHistory.value = value;

  bool get trimming => settings.trimHistory.value;

  String get host => client.host;

  final int trimAmount = 5000;
  final Duration trimAge = const Duration(days: 90);

  final Mutex _lock = Mutex();

  @override
  void dispose() {
    client.removeListener(notifyListeners);
    settings.writeHistory.removeListener(notifyListeners);
    settings.trimHistory.removeListener(notifyListeners);
    super.dispose();
  }

  Future<int> length() async => _database.length(host: host);

  Stream<int> watchLength() => _database.watchLength(host: host);

  Future<List<DateTime>> dates() async => _database.dates(host: host);

  Future<History> get(int id) async => _database.get(id);

  Stream<History> watch(int id) => _database.watch(id);

  Future<List<History>> page({
    required int page,
    int? limit,
    DateTime? day,
    String? linkRegex,
    String? titleRegex,
    String? subtitleRegex,
  }) async =>
      _database.page(
        page: page,
        limit: limit,
        host: host,
        day: day,
        linkRegex: linkRegex,
        titleRegex: titleRegex,
        subtitleRegex: subtitleRegex,
      );

  Future<List<History>> getAll({
    DateTime? day,
    String? linkRegex,
    String? titleRegex,
    String? subtitleRegex,
    int? limit,
  }) async =>
      _database.getAll(
        host: host,
        day: day,
        linkRegex: linkRegex,
        titleRegex: titleRegex,
        subtitleRegex: subtitleRegex,
        limit: limit,
      );

  Stream<List<History>> watchAll({
    DateTime? day,
    String? linkRegex,
    String? titleRegex,
    String? subtitleRegex,
    int? limit,
  }) =>
      _database.watchAll(
        host: host,
        day: day,
        linkRegex: linkRegex,
        titleRegex: titleRegex,
        subtitleRegex: subtitleRegex,
        limit: limit,
      );

  Future<void> add(HistoryRequest item) async => _lock.protect(
        () async {
      if (!enabled) {
        return;
      }
      if ((await _database.getRecent(host: host)).any((e) =>
      e.link == item.link &&
          e.title == item.title &&
          e.subtitle == item.subtitle &&
          const DeepCollectionEquality()
              .equals(e.thumbnails, item.thumbnails))) {
        return;
      }
      if (trimming) {
        await trim();
      }
      return _database.add(host, item);
    },
  );

  Future<void> addAll(List<HistoryRequest> items) async =>
      _lock.protect(() async => _database.addAll(host, items));

  Future<void> remove(History item) async =>
      _lock.protect(() async => _database.remove(item));

  Future<void> removeAll(List<History> items) async =>
      _lock.protect(() async => _database.removeAll(items));

  List<String> _getThumbnails(List<Post>? posts) =>
      posts
          ?.where((e) => !e.isDeniedBy(denylist.items))
          .map((e) => e.sample.url)
          .where((e) => e != null)
          .cast<String>()
          .take(4)
          .toList() ??
          [];

  String _composeSearchSubtitle(Map<String, String> items) => items.entries
      .take(5)
      .map((e) => '* "${e.value.replaceAll(r'"', '\'')}":${e.key}')
      .join('\n');

  Future<void> addPost(Post post) async => add(
    HistoryRequest(
      visitedAt: DateTime.now(),
      link: post.link,
      thumbnails: _getThumbnails([post]),
      subtitle: post.description.nullWhenEmpty,
    ),
  );

  Future<void> addPostSearch(String search, {
    List<Post>? posts,
  }) async =>
      add(
        HistoryRequest(
          visitedAt: DateTime.now(),
          link: Tagset.parse(search).link,
          thumbnails: _getThumbnails(posts),
        ),
      );

  Future<void> addPool(Pool pool, {List<Post>? posts}) async => add(
    HistoryRequest(
      visitedAt: DateTime.now(),
      link: pool.link,
      thumbnails: _getThumbnails(posts),
      title: pool.name,
      subtitle: pool.description.nullWhenEmpty,
    ),
  );

  Future<void> addPoolSearch(String search, {
    List<Pool>? pools,
  }) async =>
      add(
        HistoryRequest(
          visitedAt: DateTime.now(),
          link: Uri(
            path: '/pools',
            queryParameters:
            search.isNotEmpty ? {'search[name_matches]': search} : null,
          ).toString(),
          subtitle: pools?.isNotEmpty ?? false
              ? _composeSearchSubtitle({
            for (final value in pools!) value.link: tagToTitle(value.name)
          })
              : null,
        ),
      );

  Future<void> addTopic(Topic topic, {
    List<Reply>? replies,
  }) async =>
      add(
        HistoryRequest(
          visitedAt: DateTime.now(),
          link: '/forum_topics/${topic.id}',
          title: topic.title,
          subtitle: replies?.first.body,
        ),
      );

  Future<void> addTopicSearch(String search, {
    List<Topic>? topics,
  }) async =>
      add(
        HistoryRequest(
          visitedAt: DateTime.now(),
          link: Uri(
            path: '/forum_topics',
            queryParameters:
            search.isNotEmpty ? {'search[title_matches]': search} : null,
          ).toString(),
          subtitle: topics?.isNotEmpty ?? false
              ? _composeSearchSubtitle(
            {for (final value in topics!) value.link: value.title},
          )
              : null,
        ),
      );

  Future<void> addUser(User user, {Post? avatar}) async => add(
    HistoryRequest(
      visitedAt: DateTime.now(),
      link: '/users/${user.name}',
      thumbnails: [if (avatar?.sample.url != null) avatar!.sample.url!],
    ),
  );

  Future<void> addWiki(Wiki wiki) async => add(
    HistoryRequest(
      visitedAt: DateTime.now(),
      link: '/wiki_pages/${wiki.title}',
      subtitle: wiki.body.nullWhenEmpty,
    ),
  );

  Future<void> addWikiSearch(String search, {List<Wiki>? wikis}) async => add(
    HistoryRequest(
      visitedAt: DateTime.now(),
      link: Uri(
        path: '/wiki_pages',
        queryParameters:
        search.isNotEmpty ? {'search[title]': search} : null,
      ).toString(),
      subtitle: wikis?.isNotEmpty ?? false
          ? _composeSearchSubtitle(
          {for (final value in wikis!) value.link: value.title})
          : null,
    ),
  );

  Future<void> trim() async =>
      _database.trim(host: client.host, maxAmount: trimAmount, maxAge: trimAge);
}

class HistoriesServiceProvider extends SubChangeNotifierProvider3<Settings,
    Client, DenylistService, HistoriesService> {
  HistoriesServiceProvider({String? path, super.child, super.builder})
      : super(
          create: (context, settings, client, denylist) => HistoriesService(
            path: path,
            settings: settings,
            client: client,
            denylist: denylist,
          ),
          selector: (context) => [path],
        );
}
