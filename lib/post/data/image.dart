import 'package:cached_network_image/cached_network_image.dart';
import 'package:e1547/post/post.dart';
import 'package:flutter/material.dart';

enum PostImageSize {
  preview,
  sample,
  file,
}

Future<void> preloadPostImage({
  required BuildContext context,
  required Post post,
  required PostImageSize size,
}) async {
  String? url;
  switch (size) {
    case PostImageSize.preview:
      url = post.preview.url;
      break;
    case PostImageSize.sample:
      url = post.sample.url;
      break;
    case PostImageSize.file:
      url = post.file.url;
      break;
  }
  if (url != null) {
    await precacheImage(
      CachedNetworkImageProvider(url),
      context,
    );
  }
}

mixin PostImagePreloader<T extends StatefulWidget> on State<T> {
  Future<void> preloadPostImages({
    required int index,
    required List<Post> posts,
    required PostImageSize size,
    int reach = 2,
  }) async {
    for (int i = -(reach + 1); i < reach; i++) {
      if (!mounted) {
        break;
      }
      int target = index + 1 + i;
      if (0 < target && target < posts.length) {
        Post post = posts[target];
        if (post.type == PostType.image && post.file.url != null) {
          await preloadPostImage(context: context, post: post, size: size);
        }
      }
    }
  }
}
