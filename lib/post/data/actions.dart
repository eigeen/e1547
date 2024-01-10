import 'dart:async';
import 'package:e1547/app/app.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';

extension PostTagging on Post {
  bool hasTag(String tag) {
    if (tag.trim().isEmpty) return false;

    if (tag.contains(':')) {
      String identifier = tag.split(':')[0];
      String value = tag.split(':')[1];
      switch (identifier) {
        case 'id':
          if (id == int.tryParse(value)) {
            return true;
          }
          break;
        case 'rating':
          if (rating == Rating.values.asNameMap()[value] ||
              value == rating.title.toLowerCase()) {
            return true;
          }
          break;
        case 'type':
          if (file.ext.toLowerCase() == value.toLowerCase()) {
            return true;
          }
          break;
        case 'width':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(file.width);
        case 'height':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(file.height);
        case 'filesize':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(file.size);
        case 'score':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(score.total);
        case 'favcount':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(favCount);
        case 'fav':
          return isFavorited;
        case 'uploader':
        case 'user':
          // This cannot be implemented, as it requires a user lookup
          return false;
        case 'userid':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(uploaderId);
        case 'username':
          // This cannot be implemented, as it requires a user lookup
          return false;
        case 'pool':
          if (pools.contains(int.tryParse(value))) {
            return true;
          }
          break;
        case 'tagcount':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(tags.values.fold<int>(
            0,
            (previousValue, element) => previousValue + element.length,
          ));
      }
    }

    return tags.values.any((category) => category.contains(tag.toLowerCase()));
  }
}

extension PostDenying on Post {
  bool isDeniedBy(List<String> denylist) => getDeniers(denylist) != null;

  List<String>? getDeniers(List<String> denylist) {
    List<String> deniers = [];

    for (String line in denylist) {
      List<String> deny = [];
      List<String> any = [];
      List<String> allow = [];

      for (final tag in line.split(' ')) {
        if (tagToRaw(tag).isEmpty) continue;

        switch (tag[0]) {
          case '-':
            allow.add(tag.substring(1));
            break;
          case '~':
            any.add(tag.substring(1));
            break;
          default:
            deny.add(tag);
            break;
        }
      }

      bool denied = deny.isNotEmpty && deny.every(hasTag);
      bool deniedAny = any.any(hasTag);
      bool allowed = allow.isEmpty || allow.any(hasTag);

      if (!denied && !deniedAny && allowed) {
        continue;
      }

      deniers.add(line);
    }

    return deniers.isEmpty ? null : deniers;
  }
}

enum PostType {
  image,
  video,
  unsupported,
}

extension PostTyping on Post {
  PostType get type {
    switch (file.ext) {
      case 'mp4':
      case 'webm':
        if (PlatformCapabilities.hasVideos) {
          return PostType.video;
        }
        return PostType.unsupported;
      case 'swf':
        return PostType.unsupported;
      default:
        return PostType.image;
    }
  }
}

extension PostVideoPlaying on Post {
  VideoPlayer? getVideo(BuildContext context, {bool? listen}) {
    if (type == PostType.video && file.url != null) {
      VideoService service;
      if (listen ?? true) {
        service = context.watch<VideoService>();
      } else {
        service = context.read<VideoService>();
      }
      return service.getVideo(
        VideoConfig(
          url: file.url!,
          size: file.size,
        ),
      );
    }
    return null;
  }
}

extension PostLinking on Post {
  static String getPostLink(int id) => '/posts/$id';

  String get link => getPostLink(id);
}

mixin PostsActionController<KeyType> on ClientDataController<KeyType, Post> {
  Post? postById(int id) {
    int index = rawItems?.indexWhere((e) => e.id == id) ?? -1;
    if (index == -1) {
      return null;
    }
    return rawItems![index];
  }

  void replacePost(Post post) => updateItem(
        rawItems?.indexWhere((e) => e.id == post.id) ?? -1,
        post,
      );

  Future<bool> fav(Post post) async {
    assertOwnsItem(post);
    replacePost(
      post.copyWith(
        isFavorited: true,
        favCount: post.favCount + 1,
      ),
    );
    try {
      await client.addFavorite(post.id);
      evictCache();
      return true;
    } on ClientException {
      replacePost(
        post.copyWith(
          isFavorited: false,
          favCount: post.favCount - 1,
        ),
      );
      return false;
    }
  }

  Future<bool> unfav(Post post) async {
    assertOwnsItem(post);
    replacePost(
      post.copyWith(
        isFavorited: false,
        favCount: post.favCount - 1,
      ),
    );
    try {
      await client.removeFavorite(post.id);
      evictCache();
      return true;
    } on ClientException {
      replacePost(
        post.copyWith(
          isFavorited: true,
          favCount: post.favCount + 1,
        ),
      );
      return false;
    }
  }

  Future<bool> vote({
    required Post post,
    required bool upvote,
    required bool replace,
  }) async {
    assertOwnsItem(post);
    if (post.voteStatus == VoteStatus.unknown) {
      if (upvote) {
        post = post.copyWith(
          score: post.score.copyWith(
            total: post.score.total + 1,
            up: post.score.up + 1,
          ),
          voteStatus: VoteStatus.upvoted,
        );
      } else {
        post = post.copyWith(
          score: post.score.copyWith(
            total: post.score.total - 1,
            down: post.score.down + 1,
          ),
          voteStatus: VoteStatus.downvoted,
        );
      }
    } else {
      if (upvote) {
        if (post.voteStatus == VoteStatus.upvoted) {
          post = post.copyWith(
            score: post.score.copyWith(
              total: post.score.total - 1,
              down: post.score.down + 1,
            ),
            voteStatus: VoteStatus.unknown,
          );
        } else {
          post = post.copyWith(
            score: post.score.copyWith(
              total: post.score.total + 2,
              up: post.score.up + 1,
              down: post.score.down - 1,
            ),
            voteStatus: VoteStatus.upvoted,
          );
        }
      } else {
        if (post.voteStatus == VoteStatus.upvoted) {
          post = post.copyWith(
            score: post.score.copyWith(
              total: post.score.total - 2,
              up: post.score.up - 1,
              down: post.score.down + 1,
            ),
            voteStatus: VoteStatus.downvoted,
          );
        } else {
          post = post.copyWith(
            score: post.score.copyWith(
              total: post.score.total + 1,
              up: post.score.up + 1,
            ),
            voteStatus: VoteStatus.unknown,
          );
        }
      }
    }
    replacePost(post);
    try {
      await client.votePost(post.id, upvote, replace);
      evictCache();
      return true;
    } on ClientException {
      return false;
    }
  }

  Future<void> resetPost(Post post) async {
    assertOwnsItem(post);
    replacePost(await client.post(post.id, force: true));
    evictCache();
  }

  // TODO: create a PostUpdate Object instead of a Map
  Future<void> updatePost(Post post, Map<String, String?> body) async {
    assertOwnsItem(post);
    await client.updatePost(post.id, body);
    await resetPost(post);
  }
}
