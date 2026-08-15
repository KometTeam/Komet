import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/webapp.dart';
import '../../../core/storage/spoofing_service.dart';
import '../../../core/utils/link_opener.dart';
import '../../../main.dart' show api;
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/error_view.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/webview_permission_prompt.dart';
import 'web_app_bridge.dart';

class WebAppScreen extends StatefulWidget {
  final String title;
  final Future<WebAppLaunch> Function() loader;
  final String entryPoint;
  final bool privateChannel;
  final WebAppMobileIdVerifier? mobileIdVerifier;
  final List<UserScript>? extraUserScripts;
  final void Function(InAppWebViewController controller)? onWebViewCreated;
  final void Function(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  )?
  onConsoleMessage;
  final void Function(InAppWebViewController controller, WebUri? url)?
  onLoadStart;
  final Future<WebAppLaunch> Function(String url)? onExternalCallback;
  final bool closeAfterExternalCallback;
  final bool preferSystemUserAgent;
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
    this.entryPoint = WebAppEntryPoint.webApp,
    this.privateChannel = false,
    this.mobileIdVerifier,
    this.extraUserScripts,
    this.onWebViewCreated,
    this.onConsoleMessage,
    this.onLoadStart,
    this.onExternalCallback,
    this.closeAfterExternalCallback = false,
    this.preferSystemUserAgent = false,
    this.shouldOverrideUrlLoading,
  });

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  InAppWebViewController? _controller;
  WebAppBridge? _bridge;
  WebAppLaunch? _launch;
  String? _loadError;
  String _userAgent = '';
  double _progress = 0;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bridge?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _launch = null;
      _bridge?.dispose();
      _bridge = null;
    });
    try {
      // Тот же UA, что уходит в sessionInit (из handshake-устройства ядра),
      // чтобы веб-аппы видели нативный клиент; фолбэк — браузерный UA спуфа.
      // Для веб-аппов с внешней авторизацией (Госуслуги/ЕСИА) клиентский UA
      // ядра отбраковывается антифродом — там нужен UA настоящего WebView.
      _userAgent = '';
      if (widget.preferSystemUserAgent) {
        try {
          _userAgent = await InAppWebViewController.getDefaultUserAgent();
        } catch (_) {}
      }
      if (_userAgent.isEmpty) {
        _userAgent =
            api.session?.userAgent() ??
            await SpoofingService.getWebViewUserAgent() ??
            '';
      }
      final launch = await widget.loader();
      if (!mounted) return;
      setState(() {
        _launch = launch;
        _bridge = _createBridge(launch.botId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  WebAppBridge _createBridge(int botId) => WebAppBridge(
    botId: botId,
    entryPoint: widget.entryPoint,
    privateChannel: widget.privateChannel,
    mobileIdVerifier: widget.mobileIdVerifier,
    contextResolver: () => mounted ? context : null,
    viewportResolver: () => _viewport,
    onClose: _closeFromWebApp,
  );

  void _closeFromWebApp() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<bool> _handleBack() async {
    final bridge = _bridge;
    if (bridge != null && bridge.handlesBackButton) {
      bridge.notifyBackPressed();
      return false;
    }
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    if (bridge != null && bridge.needsCloseConfirmation && mounted) {
      return showConfirmDialog(
        context,
        title: widget.title,
        message: 'Закрыть мини-приложение?',
        confirmLabel: 'Закрыть',
      );
    }
    return true;
  }

  Future<NavigationActionPolicy?> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    final callback = widget.onExternalCallback;
    if (callback != null && uri?.queryParameters['externalCallback'] == '1') {
      try {
        final launch = await callback(uri.toString());
        if (!mounted) return NavigationActionPolicy.CANCEL;
        if (widget.closeAfterExternalCallback) {
          Navigator.of(context).pop(launch);
          return NavigationActionPolicy.CANCEL;
        }
        setState(() {
          _launch = launch;
          _loadError = null;
        });
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(launch.url)),
        );
      } catch (e) {
        if (mounted) setState(() => _loadError = e.toString());
      }
      return NavigationActionPolicy.CANCEL;
    }
    final handler = widget.shouldOverrideUrlLoading;
    if (handler == null) return NavigationActionPolicy.ALLOW;
    return handler(controller, action, _launch?.url);
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
    final bridge = _bridge;
    if (launch == null || bridge == null) {
      return const Center(child: SmallSpinner(size: 36));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerDown: (_) => bridge.registerGesture(),
          child: _buildWebView(launch, bridge),
        );
      },
    );
  }

  Widget _buildWebView(WebAppLaunch launch, WebAppBridge bridge) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(launch.url)),
      initialUserScripts: UnmodifiableListView<UserScript>([
        bridge.userScript,
        ...?widget.extraUserScripts,
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
        supportZoom: false,
        transparentBackground: true,
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: true,
        supportMultipleWindows: true,
        allowFileAccess: false,
        useShouldOverrideUrlLoading: true,
        userAgent: _userAgent,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        bridge.attach(controller);
        widget.onWebViewCreated?.call(controller);
      },
      onPermissionRequest: (controller, request) =>
          askWebViewPermission(context, request),
      onCreateWindow: (controller, action) async {
        final url = action.request.url?.toString();
        if (url != null && url.isNotEmpty && mounted) {
          await openExternalUrl(context, url);
        }
        return false;
      },
      onConsoleMessage: widget.onConsoleMessage,
      onLoadStart: widget.onLoadStart,
      shouldOverrideUrlLoading: _handleNavigation,
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
