class Animoji {
  final int id;
  final String emoji;
  final int setId;
  final String? iconUrl;
  final String? lottieUrl;
  final String? lottiePlayUrl;

  const Animoji({
    required this.id,
    required this.emoji,
    this.setId = 0,
    this.iconUrl,
    this.lottieUrl,
    this.lottiePlayUrl,
  });

  static Animoji? fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'];
    final emoji = map['emoji']?.toString();
    if (id is! int || emoji == null || emoji.isEmpty) return null;
    return Animoji(
      id: id,
      emoji: emoji,
      setId: map['setId'] is int ? map['setId'] as int : 0,
      iconUrl: map['iconUrl']?.toString(),
      lottieUrl: map['lottieUrl']?.toString(),
      lottiePlayUrl: map['lottiePlayUrl']?.toString(),
    );
  }
}
