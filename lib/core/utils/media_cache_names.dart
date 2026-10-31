import '../../models/attachment.dart';
import 'media_cache.dart';

enum MediaCacheKind { photo, video, voice, file, kept }

const List<String> _photoPrefixes = ['photo_', 'avatar_'];
const List<String> _videoPrefixes = ['video_', 'videopreview_', 'gif_', 'story_'];
final RegExp _voiceName = RegExp(r'^-?\d+\.ogg$');

String photoCacheName(PhotoAttachment photo, String url) =>
    'photo_${photo.photoId ?? (url.hashCode & 0x7fffffff)}.jpg';

String avatarCacheName(String url) => 'avatar_${url.hashCode & 0x7fffffff}.jpg';

String videoCacheName(VideoAttachment video, String messageId) =>
    'video_${video.videoId ?? messageId}.mp4';

String videoPreviewCacheName(int? videoId) => 'videopreview_$videoId.mp4';

String gifCacheName(int photoId) => 'gif_$photoId.mp4';

String storyVideoCacheName(int ownerId, int storyId) =>
    'story_${ownerId}_$storyId.mp4';

String voiceCacheName({int? audioId, required String messageId}) =>
    '${audioId ?? messageId}.ogg';

MediaCacheKind mediaCacheKindOf(String name) {
  if (name.startsWith(MediaCache.keptPrefix)) return MediaCacheKind.kept;
  if (_photoPrefixes.any(name.startsWith)) return MediaCacheKind.photo;
  if (_videoPrefixes.any(name.startsWith)) return MediaCacheKind.video;
  if (_voiceName.hasMatch(name)) return MediaCacheKind.voice;
  return MediaCacheKind.file;
}
