import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/stories/story_viewer_screen.dart';

void main() {
  group('storyViewerMenuActions', () {
    test('an own story offers save and delete', () {
      expect(storyViewerMenuActions(isOwn: true), [
        StoryViewerMenuAction.save,
        StoryViewerMenuAction.delete,
      ]);
    });

    test('a foreign story respects its server capabilities', () {
      expect(
        storyViewerMenuActions(
          isOwn: false,
          opensProfile: true,
          allowsHidingAuthor: true,
          allowsSaving: true,
          allowsComplaints: true,
        ),
        [
          StoryViewerMenuAction.profile,
          StoryViewerMenuAction.hide,
          StoryViewerMenuAction.save,
          StoryViewerMenuAction.report,
        ],
      );
      expect(storyViewerMenuActions(isOwn: false), isEmpty);
    });
  });

  group('storySeekPosition', () {
    const duration = Duration(seconds: 40);

    test('slides relative to the position where the hold started', () {
      expect(
        storySeekPosition(
          start: const Duration(seconds: 10),
          deltaX: 100,
          viewportWidth: 400,
          duration: duration,
        ),
        const Duration(seconds: 20),
      );
      expect(
        storySeekPosition(
          start: const Duration(seconds: 20),
          deltaX: -100,
          viewportWidth: 400,
          duration: duration,
        ),
        const Duration(seconds: 10),
      );
    });

    test('clamps seeking to the story boundaries', () {
      expect(
        storySeekPosition(
          start: const Duration(seconds: 5),
          deltaX: -500,
          viewportWidth: 400,
          duration: duration,
        ),
        Duration.zero,
      );
      expect(
        storySeekPosition(
          start: const Duration(seconds: 35),
          deltaX: 500,
          viewportWidth: 400,
          duration: duration,
        ),
        duration,
      );
    });
  });
}
