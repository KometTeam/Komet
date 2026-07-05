import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PhotoViewerScreen extends StatelessWidget {
  final String baseUrl;

  const PhotoViewerScreen({super.key, required this.baseUrl});

  String get _url => baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: _url.isEmpty
                    ? const Icon(
                        Symbols.broken_image,
                        color: Colors.white54,
                        size: 64,
                      )
                    : CachedNetworkImage(
                        imageUrl: _url,
                        fit: BoxFit.contain,
                        fadeInDuration: const Duration(milliseconds: 120),
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, _, _) => const Icon(
                          Symbols.broken_image,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Symbols.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
