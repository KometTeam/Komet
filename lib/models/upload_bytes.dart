class UploadBytes {
  const UploadBytes(this.sent, this.total);

  static const UploadBytes none = UploadBytes(0, 0);

  final int sent;
  final int total;

  bool get sized => total > 0;

  double get fraction => sized ? (sent / total).clamp(0.0, 1.0) : 0.0;

  @override
  bool operator ==(Object other) =>
      other is UploadBytes && other.sent == sent && other.total == total;

  @override
  int get hashCode => Object.hash(sent, total);
}
