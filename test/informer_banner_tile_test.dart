import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/informer_banner_tile.dart';
import 'package:komet/models/animoji.dart';
import 'package:komet/models/informer_banner.dart';

const _banner = InformerBanner(
  id: 'synthetic-banner',
  title: 'Synthetic title',
  description: 'Synthetic description',
  settings: BannerSettings.textAnimation,
  type: BannerType.link,
  url: 'https://example.invalid/synthetic',
);

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders the banner content and reports presentation once', (
    tester,
  ) async {
    var presentations = 0;

    await tester.pumpWidget(
      _app(
        InformerBannerTile(
          banner: _banner,
          onPresented: (_) => presentations++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Synthetic title'), findsOneWidget);
    expect(find.text('Synthetic description'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('informer-banner-fallback-icon')),
      findsOneWidget,
    );
    expect(presentations, 1);

    await tester.pumpWidget(
      _app(
        InformerBannerTile(
          banner: _banner,
          onPresented: (_) => presentations++,
        ),
      ),
    );
    await tester.pump();

    expect(presentations, 1);
  });

  testWidgets('handles body and close actions independently', (tester) async {
    var taps = 0;
    var closes = 0;

    await tester.pumpWidget(
      _app(
        InformerBannerTile(
          banner: _banner,
          onTap: () => taps++,
          onClose: () => closes++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('informer-banner-synthetic-banner')),
    );
    await tester.pump();
    expect(taps, 1);
    expect(closes, 0);

    await tester.tap(
      find.byKey(const ValueKey('informer-banner-close-synthetic-banner')),
    );
    await tester.pump();
    expect(taps, 1);
    expect(closes, 1);
  });

  testWidgets('honors close visibility and resolves the configured animoji', (
    tester,
  ) async {
    int? requestedId;
    const banner = InformerBanner(
      id: 'synthetic-themed-banner',
      title: 'Synthetic themed title',
      settings: BannerSettings.hideCloseButton | BannerSettings.iconThemeColor,
      animojiId: 42,
    );

    await tester.pumpWidget(
      _app(
        InformerBannerTile(
          banner: banner,
          animojiLoader: (id) async {
            requestedId = id;
            return const Animoji(id: 42, emoji: '🧪');
          },
        ),
      ),
    );
    await tester.pump();

    expect(requestedId, 42);
    expect(
      find.byKey(const ValueKey('informer-banner-animoji')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('informer-banner-close-synthetic-themed-banner'),
      ),
      findsNothing,
    );
    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}
