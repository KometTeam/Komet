/// Posts asked for in one comment-count request.
const int kCommentsInfoBatchSize = 50;

/// Splits post ids into comment-count requests of at most [size] posts,
/// so one long history does not turn into a single oversized request.
List<List<String>> commentsInfoBatches(
  List<String> postIds, {
  int size = kCommentsInfoBatchSize,
}) {
  final batches = <List<String>>[];
  for (var i = 0; i < postIds.length; i += size) {
    final end = i + size < postIds.length ? i + size : postIds.length;
    batches.add(postIds.sublist(i, end));
  }
  return batches;
}
