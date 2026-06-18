import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/webapp.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/webview_permission_prompt.dart';

class WebAppScreen extends StatefulWidget {
  final String title;
  final Future<WebAppLaunch> Function() loader;

  const WebAppScreen({
    super.key,
    required this.title,
    required this.loader,
  });

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  InAppWebViewController? _controller;
  WebAppLaunch? _launch;
  String? _loadError;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _launch = null;
    });
    try {
      final launch = await widget.loader();
      if (!mounted) return;
      setState(() => _launch = launch);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  Future<bool> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _handleBack()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: const ConnectionSpinner(),
        appBar: AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Symbols.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Symbols.refresh),
              onPressed: _launch == null
                  ? null
                  : () => _controller?.reload(),
            ),
          ],
          bottom: _progress > 0 && _progress < 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: _buildBody(cs),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loadError != null) {
      return _ErrorView(message: _loadError!, onRetry: _load);
    }
    final launch = _launch;
    if (launch == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(launch.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
        supportZoom: false,
        transparentBackground: true,
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: true,
      ),
      onWebViewCreated: (controller) => _controller = controller,
      onPermissionRequest: (controller, request) =>
          askWebViewPermission(context, request),
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        setState(() => _progress = progress / 100);
      },
      onReceivedError: (controller, request, error) {
        if (!mounted) return;
        if (request.isForMainFrame ?? false) {
          setState(() => _loadError = error.description);
        }
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.cloud_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
