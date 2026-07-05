class UploadStatus {
  final bool active;
  final int sent;
  final int total;

  const UploadStatus({this.active = false, this.sent = 0, this.total = 0});

  bool get awaitingResponse => active && total > 0 && sent >= total;
  double? get progressValue =>
      (!active || total == 0 || awaitingResponse) ? null : sent / total;
}
