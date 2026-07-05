import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/webapp.dart';
import '../../../core/storage/spoofing_service.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/error_view.dart';
import '../../widgets/webview_permission_prompt.dart';

class WebAppScreen extends StatefulWidget {
  final String title;
  final Future<WebAppLaunch> Function() loader;
  final List<UserScript>? extraUserScripts;
  final void Function(InAppWebViewController controller)? onWebViewCreated;
  final void Function(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  )?
  onConsoleMessage;
  final void Function(InAppWebViewController controller, WebUri? url)?
  onLoadStart;
  final Future<NavigationActionPolicy?> Function(
    InAppWebViewController controller,
    NavigationAction navigationAction,
    String? currentUrl,
  )?
  shouldOverrideUrlLoading;

  const WebAppScreen({
    super.key,
    required this.title,
    required this.loader,
    this.extraUserScripts,
    this.onWebViewCreated,
    this.onConsoleMessage,
    this.onLoadStart,
    this.shouldOverrideUrlLoading,
  });

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  InAppWebViewController? _controller;
  WebAppLaunch? _launch;
  String? _loadError;
  String _userAgent = '';
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
      _userAgent = await SpoofingService.getWebViewUserAgent() ?? '';
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
              onPressed: _launch == null ? null : () => _controller?.reload(),
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
      return ErrorView(message: _loadError!, onRetry: _load);
    }
    final launch = _launch;
    if (launch == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(launch.url)),
      initialUserScripts: widget.extraUserScripts == null
          ? null
          : UnmodifiableListView<UserScript>(widget.extraUserScripts!),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
        supportZoom: false,
        transparentBackground: true,
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: true,
        useShouldOverrideUrlLoading: widget.shouldOverrideUrlLoading != null,
        userAgent: _userAgent,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        widget.onWebViewCreated?.call(controller);
      },
      onPermissionRequest: (controller, request) =>
          askWebViewPermission(context, request),
      onConsoleMessage: widget.onConsoleMessage,
      onLoadStart: widget.onLoadStart,
      shouldOverrideUrlLoading: widget.shouldOverrideUrlLoading == null
          ? null
          : (controller, action) => widget.shouldOverrideUrlLoading!(
              controller,
              action,
              launch.url,
            ),
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
