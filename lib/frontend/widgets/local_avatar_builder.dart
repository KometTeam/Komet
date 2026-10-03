import 'package:flutter/widgets.dart';

import '../../core/storage/local_contact_avatars.dart';

class LocalAvatarBuilder extends StatelessWidget {
  const LocalAvatarBuilder({
    super.key,
    required this.userId,
    required this.builder,
  });

  final int userId;
  final Widget Function(BuildContext context, ImageProvider? local) builder;

  @override
  Widget build(BuildContext context) {
    if (userId <= 0) return builder(context, null);
    final store = LocalContactAvatars.instance;
    return ValueListenableBuilder<int>(
      valueListenable: store.revision,
      builder: (context, _, _) => builder(context, store.imageFor(userId)),
    );
  }
}
