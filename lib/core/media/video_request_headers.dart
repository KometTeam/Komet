/// Headers for a remote video request.
///
/// Links bound to a client (`srcAg=UNKNOWN_ANDROID` and the like) are
/// checked by the CDN against the `User-Agent` of the request, and a
/// mismatch is answered with HTTP 400. The link is issued for the Android
/// handshake identity, so the agent sent to the CDN must not name another
/// platform: the session agent is used when it reads as Android. An agent
/// built from another device (an iOS build without a spoofed profile
/// reports `OKMessages/<version> (18.6; iPhone15,2; ...)`) keeps only its
/// product token and is marked as Android. Players never fall back to
/// their own agent, which on iOS names the iPhone.
Map<String, String> videoRequestHeaders(
  Uri uri, {
  required String? sessionUserAgent,
}) {
  if (!_isAgentBound(uri)) return const {};
  final userAgent = sessionUserAgent?.trim();
  if (userAgent == null || userAgent.isEmpty) return const {};
  return {'User-Agent': cdnUserAgent(userAgent)};
}

/// The agent sent to the CDN for a session agent.
String cdnUserAgent(String sessionUserAgent) {
  final agent = sessionUserAgent.trim();
  if (_androidToken.hasMatch(agent)) return agent;
  final product = _productToken.firstMatch(agent)?.group(0);
  return '${product ?? _fallbackProduct} (Android)';
}

const _agentBoundHosts = ['okcdn.ru', 'vkuser.net'];
const _fallbackProduct = 'OKMessages';

final _androidToken = RegExp(r'\bandroid\b', caseSensitive: false);
final _productToken = RegExp(r'^[^\s/()]+/[^\s()]+');

bool _isAgentBound(Uri uri) {
  if (uri.queryParameters.containsKey('srcAg')) return true;
  final host = uri.host.toLowerCase();
  return _agentBoundHosts.any(
    (domain) => host == domain || host.endsWith('.$domain'),
  );
}
