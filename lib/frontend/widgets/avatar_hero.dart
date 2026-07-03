import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AvatarHero extends StatelessWidget {
  final Object tag;
  final String name;
  final String? imageUrl;
  final Widget child;

  const AvatarHero({
    super.key,
    required this.tag,
    required this.name,
    required this.imageUrl,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (context, animation, direction, fromContext, toContext) =>
          _AvatarHeroFlight(name: name, imageUrl: imageUrl),
      child: child,
    );
  }
}

class _AvatarHeroFlight extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _AvatarHeroFlight({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primaryContainer,
      ),
      child: hasImage
          ? Image(
              image: CachedNetworkImageProvider(url),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
