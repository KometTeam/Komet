import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EmptyChatWidget extends StatelessWidget {
  final Map<String, dynamic>? sticker;
  final VoidCallback? onStickerTap;

  const EmptyChatWidget({super.key, this.sticker, this.onStickerTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (sticker != null) ...[
            GestureDetector(
              onTap: onStickerTap,
              child: _buildSticker(sticker!),
            ),
            const SizedBox(height: 24),
          ] else ...[
            const SizedBox(
              width: 170,
              height: 170,
              child: Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Сообщений пока нет, напишите первым или отправьте этот стикер',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSticker(Map<String, dynamic> sticker) {
    final url = sticker['url'] as String?;
    final lottieUrl = sticker['lottieUrl'] as String?;
    final width = (sticker['width'] as num?)?.toDouble() ?? 170.0;
    final height = (sticker['height'] as num?)?.toDouble() ?? 170.0;

    if (lottieUrl != null && lottieUrl.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Lottie.network(
          lottieUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            if (url != null && url.isNotEmpty) {
              return Image.network(url, fit: BoxFit.contain);
            }
            return Icon(Icons.emoji_emotions, size: width, color: Colors.grey);
          },
        ),
      );
    }

    final imageUrl = url;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.emoji_emotions, size: width, color: Colors.grey);
          },
        ),
      );
    }
    return Icon(Icons.emoji_emotions, size: width, color: Colors.grey);
  }
}
