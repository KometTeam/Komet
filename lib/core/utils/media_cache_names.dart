import '../../models/attachment.dart';

String photoCacheName(PhotoAttachment photo, String url) =>
    'photo_${photo.photoId ?? (url.hashCode & 0x7fffffff)}.jpg';

String videoCacheName(VideoAttachment video, String messageId) =>
    'video_${video.videoId ?? messageId}.mp4';
