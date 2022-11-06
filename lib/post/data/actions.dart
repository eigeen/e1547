import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_video_player/cached_video_player.dart';
import 'package:crypto/crypto.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_storage/saf.dart';

extension PostTagging on Post {
  bool hasTag(String tag) {
    if (tag.contains(':')) {
      String identifier = tag.split(':')[0];
      String value = tag.split(':')[1];
      switch (identifier) {
        case 'rating':
          if (rating == Rating.values.asNameMap()[value] ||
              value == rating.title.toLowerCase()) {
            return true;
          }
          break;
        case 'id':
          if (id == int.tryParse(value)) {
            return true;
          }
          break;
        case 'type':
          if (file.ext.toLowerCase() == value.toLowerCase()) {
            return true;
          }
          break;
        case 'pool':
          if (pools.contains(int.tryParse(value))) {
            return true;
          }
          break;
        case 'uploader':
        case 'userid':
        case 'user':
          if (uploaderId.toString() == value) {
            return true;
          }
          break;
        case 'score':
          bool greater = value.contains('>');
          bool smaller = value.contains('<');
          bool equal = value.contains('=');
          int? score = int.tryParse(value.replaceAll(RegExp(r'[<>=]'), ''));
          if (score != null) {
            if (greater) {
              if (equal) {
                if (this.score.total >= score) {
                  return true;
                }
              } else {
                if (this.score.total > score) {
                  return true;
                }
              }
            }
            if (smaller) {
              if (equal) {
                if (this.score.total <= score) {
                  return true;
                }
              } else {
                if (this.score.total < score) {
                  return true;
                }
              }
            }
            if ((!greater && !smaller) && this.score.total == score) {
              return true;
            }
          }
          break;
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

      line.split(' ').where((tag) => tagToRaw(tag).isNotEmpty).forEach((tag) {
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
      });

      bool denied = deny.every(hasTag);
      bool allowed = allow.any(hasTag);
      bool optional = any.isEmpty || any.any(hasTag);

      if (denied && optional && !allowed) {
        deniers.add(line);
      }
    }
    if (deniers.isEmpty) {
      return null;
    }
    return deniers;
  }

  bool isIgnored() => (file.url == null && !flags.deleted) || file.ext == 'swf';
}

extension PostDownloading on Post {
  Future<void> download({
    required Settings settings,
    required AppInfo appInfo,
  }) async {
    try {
      File download = await DefaultCacheManager().getSingleFile(file.url!);
      if (Platform.isAndroid) {
        Uint8List downloadBytes = await download.readAsBytes();
        String downloadMime = await _throwOnNull(lookupMimeType(download.path),
            'Could not determine MIME of download!');
        Uri target = Uri.parse(settings.downloadPath.value);
        if (!await isPersistedUri(target)) {
          target = await _throwOnNull(
            openDocumentTree(initialUri: target),
            'No SAF folder was chosen!',
          );
          settings.downloadPath.value = target.toString();
        }
        DocumentFile dir = await _throwOnNull(
            target.toDocumentFile(), 'Could not open SAF folder!');
        if (target.path == '/tree/primary${Uri.encodeComponent(':Pictures')}') {
          DocumentFile? subdir = await dir.findFile(appInfo.appName);
          if (subdir != null &&
              await _throwOnNull(
                subdir.isDirectory,
                'Could not determine App SAF directory',
              )) {
            dir = subdir;
          } else {
            dir = await _throwOnNull(
              dir.createDirectory(appInfo.appName),
              'Could not create App SAF folder!',
            );
          }
        }
        DocumentFile? file = await dir.findFile(_downloadName());
        if (file != null) {
          Digest downloadMd5 = md5.convert(downloadBytes);
          Digest fileMd5 = md5.convert(await _throwOnNull(
            file.getContent(Uri.base),
            'Could not read SAF file!',
          ));
          if (downloadMd5 != fileMd5) {
            file.writeToFileAsBytes(
              bytes: downloadBytes,
            );
          }
        } else {
          file = await _throwOnNull(
            dir.createFile(
              mimeType: downloadMime,
              displayName: _downloadName(),
              bytes: downloadBytes,
            ),
            'Could not create SAF file!',
          );
        }
      } else if (Platform.isIOS) {
        await ImageGallerySaver.saveFile(download.path);
      } else {
        String directory = (await getDownloadsDirectory())!.path;
        File target = File(join(directory, _downloadName()));
        if (!await target.exists() ||
            md5.convert(await download.readAsBytes()) !=
                md5.convert(await target.readAsBytes())) {
          await download.copy(target.path);
        }
      }
    } catch (exception) {
      throw PostDownloadException.from(exception);
    }
  }

  String _downloadName() {
    String filename = '';
    List<String> artists = filterArtists(tags['artist']!);
    if (artists.isNotEmpty) {
      filename = '${artists.join(', ')} - ';
    }
    filename += '$id.${file.ext}';
    return filename;
  }

  Future<T> _throwOnNull<T>(FutureOr<T?> future, String message) async {
    T? result = await future;
    if (result == null) {
      throw PostDownloadException(message);
    }
    return result;
  }
}

class PostDownloadException implements Exception {
  PostDownloadException(String this.message) : inner = null;

  PostDownloadException.from(Object this.inner) : message = null;

  final String? message;
  final Object? inner;

  @override
  String toString() {
    if (message != null) {
      return "$runtimeType: $message";
    }
    if (inner != null) {
      if (inner is PostDownloadException) {
        return inner.toString();
      }
      return "$runtimeType: $inner";
    }
    return '$runtimeType: unknown cause!';
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
        if (Platform.isAndroid || Platform.isIOS) {
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
  VideoConfig? get videoConfig => type == PostType.video && file.url != null
      ? VideoConfig(
          url: file.url!,
          size: file.size,
        )
      : null;

  CachedVideoPlayerController? getVideo(BuildContext context) {
    if (videoConfig != null) {
      return VideoHandler.of(context).getVideo(videoConfig!);
    }
    return null;
  }

  Future<void> loadVideo(BuildContext context) async {
    if (videoConfig != null) {
      await VideoHandler.of(context).loadVideo(videoConfig!);
    }
  }

  Future<void> disposeVideo(BuildContext context) async {
    if (videoConfig != null) {
      await VideoHandler.of(context).disposeVideo(videoConfig!);
    }
  }
}

extension PostLinking on Post {
  String get link => getPostLink(id);
}

String getPostLink(int id) => '/posts/$id';
