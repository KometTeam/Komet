import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gwid/app_sizes.dart';

class SferumWebViewPanel extends StatefulWidget {
  final String url;

  const SferumWebViewPanel({super.key, required this.url});

  @override
  State<SferumWebViewPanel> createState() => _SferumWebViewPanelState();
}

class _SferumWebViewPanelState extends State<SferumWebViewPanel> {
  bool _isLoading = true;
  InAppWebViewController? _webViewController;

  Future<void> _checkCanGoBack() async {}

  Future<void> _goBack() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      _checkCanGoBack();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Row(
          children: [
            Image.asset('assets/images/spermum.png', width: 28, height: 28),
            const SizedBox(width: 12),
            const Text(
              'Сферум',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Закрыть',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!Platform.isLinux)
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                useShouldOverrideUrlLoading: true,
                useOnLoadResource: false,
                useOnDownloadStart: false,
                cacheEnabled: true,
                verticalScrollBarEnabled: true,
                horizontalScrollBarEnabled: true,
                supportZoom: false,
                disableVerticalScroll: false,
                disableHorizontalScroll: false,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsBackForwardNavigationGestures: true,
                useHybridComposition: true,
                supportMultipleWindows: false,
                javaScriptCanOpenWindowsAutomatically: false,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onCreateWindow: (controller, createWindowAction) async {
                final uri = createWindowAction.request.url;
                print('🪟 Попытка открыть новое окно: $uri');
                if (uri != null) {
                  await controller.loadUrl(urlRequest: URLRequest(url: uri));
                }
                return true;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                final navigationType = navigationAction.navigationType;
                print(
                  '🔗 Попытка перехода по ссылке: $uri (тип: $navigationType)',
                );

                if (navigationType == NavigationType.LINK_ACTIVATED) {
                  return NavigationActionPolicy.ALLOW;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, url) async {
                print('🌐 WebView начало загрузки: $url');
                setState(() {
                  _isLoading = true;
                });
                try {
                  await controller.evaluateJavascript(
                    source: '''
                    if (window.open.toString().indexOf('native code') === -1) {
                      var originalOpen = window.open;
                      window.open = function(url, name, features) {
                        if (url && typeof url === 'string') {
                          window.location.href = url;
                          return null;
                        }
                        return originalOpen.apply(this, arguments);
                      };
                    }
                  ''',
                  );
                } catch (e) {
                  print(
                    '⚠️ Ошибка при выполнении JavaScript в onLoadStart: $e',
                  );
                }
              },
              onLoadStop: (controller, url) async {
                print('✅ WebView загрузка завершена: $url');
                setState(() {
                  _isLoading = false;
                });
                _checkCanGoBack();
                try {
                  await controller.evaluateJavascript(
                    source: '''
                   
                    document.body.style.overflow = 'auto';
                    document.documentElement.style.overflow = 'auto';
                    document.body.style.webkitOverflowScrolling = 'touch';
                    document.body.style.position = 'relative';
                    document.documentElement.style.position = 'relative';
                    
                  
                    (function() {
              
                      function processLink(link) {
                        if (link && link.tagName === 'A') {
                          var href = link.getAttribute('href');
                          if (href && !href.startsWith('javascript:') && !href.startsWith('mailto:')) {
                            
                            link.removeAttribute('target');
                     
                            link.addEventListener('click', function(e) {
                              var href = this.getAttribute('href');
                              if (href && !href.startsWith('javascript:') && !href.startsWith('mailto:')) {
                                e.preventDefault();
                                e.stopPropagation();
                                window.location.href = href;
                                return false;
                              }
                            }, true);
                          }
                        }
                      }
                      
                     
                      function processAllLinks() {
                        var links = document.querySelectorAll('a');
                        for (var i = 0; i < links.length; i++) {
                          processLink(links[i]);
                        }
                      }
                      
              
                      processAllLinks();
                      
                    
                      document.addEventListener('click', function(e) {
                        var target = e.target;
                   
                        while (target && target.tagName !== 'A' && target !== document.body) {
                          target = target.parentElement;
                        }
                        if (target && target.tagName === 'A') {
                          var href = target.getAttribute('href');
                          if (href && !href.startsWith('javascript:') && !href.startsWith('mailto:')) {
                          
                            target.removeAttribute('target');
                          
                            e.preventDefault();
                            e.stopPropagation();
                            window.location.href = href;
                            return false;
                          }
                        }
                      }, true);
                      
                     
                      var observer = new MutationObserver(function(mutations) {
                        mutations.forEach(function(mutation) {
                          mutation.addedNodes.forEach(function(node) {
                            if (node.nodeType === 1) { 
                              if (node.tagName === 'A') {
                                processLink(node);
                              }
                             
                              var links = node.querySelectorAll ? node.querySelectorAll('a') : [];
                              for (var i = 0; i < links.length; i++) {
                                processLink(links[i]);
                              }
                            }
                          });
                        });
                      });
                      
                    
                      observer.observe(document.body, {
                        childList: true,
                        subtree: true
                      });
                      
                    
                      var originalOpen = window.open;
                      window.open = function(url, name, features) {
                        if (url && typeof url === 'string') {
                          window.location.href = url;
                          return null;
                        }
                        return originalOpen.apply(this, arguments);
                      };
                    })();
                  ''',
                  );
                } catch (e) {
                  print('⚠️ Ошибка при выполнении JavaScript: $e');
                }
              },
              onReceivedError: (controller, request, error) {
                print('❌ WebView ошибка: ${error.description} (${error.type})');
              },
              onConsoleMessage: (controller, consoleMessage) {
                print('📝 Console: ${consoleMessage.message}');
              },
            ),
          if (Platform.isLinux)
            Container(
              color: colors.surface,
              child: const Center(
                child: Text(
                  'Веб приложения временно не доступны на линуксе,\nмы думаем как это исправить.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),

          if (_isLoading && !Platform.isLinux)
            Container(
              color: colors.surface,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
