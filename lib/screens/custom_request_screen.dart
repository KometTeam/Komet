import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gwid/api/api_service.dart';


class RequestHistoryItem {
  final String request;
  final String response;
  final DateTime timestamp;

  RequestHistoryItem({
    required this.request,
    required this.response,
    required this.timestamp,
  });
}

class CustomRequestScreen extends StatefulWidget {
  const CustomRequestScreen({super.key});

  @override
  State<CustomRequestScreen> createState() => _CustomRequestScreenState();
}

class _CustomRequestScreenState extends State<CustomRequestScreen> {
  final _requestController = TextEditingController();
  final _scrollController = ScrollController();

  String? _response;
  String? _error;
  bool _isLoading = false;

  final List<RequestHistoryItem> _history = [];

  void _handleResponse(Map<String, dynamic> message, String originalRequest) {
    const encoder = JsonEncoder.withIndent('  ');
    final formattedResponse = encoder.convert(message);

    if (!mounted) return; 

    setState(() {
      _response = formattedResponse;
      _isLoading = false;
      _error = null;


      _history.insert(
        0,
        RequestHistoryItem(
          request: originalRequest, 
          response: formattedResponse,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _sendRequest() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    final requestText = _requestController.text.isEmpty
        ? '{}'
        : _requestController.text;
    Map<String, dynamic> requestJson;

    try {
      requestJson = jsonDecode(requestText) as Map<String, dynamic>;
    } catch (e) {
      setState(() {
        _error = 'Ошибка: Невалидный JSON в запросе.\n$e';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _response = null;
      _error = null;
    });

    StreamSubscription? subscription;
    Timer? timeoutTimer;

    try {
      final int sentSeq = ApiService.instance.sendAndTrackFullJsonRequest(
        jsonEncode(requestJson),
      );


      timeoutTimer = Timer(const Duration(seconds: 15), () {
        subscription?.cancel(); 
        if (mounted && _isLoading) {
          setState(() {
            _error = 'Ошибка: Превышено время ожидания ответа (15с).';
            _isLoading = false;
          });
        }
      });


      subscription = ApiService.instance.messages.listen((message) {

        if (message['seq'] == sentSeq) {
          timeoutTimer?.cancel(); 
          subscription?.cancel(); 
          _handleResponse(message, requestText); 
        }
      });
    } catch (e) {
      timeoutTimer?.cancel();
      subscription?.cancel();
      if (mounted) {
        setState(() {
          _error = 'Ошибка при отправке запроса: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _useHistoryItem(RequestHistoryItem item) {

    _requestController.text = item.request;
    setState(() {
      _response = item.response;
      _error = null;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom WebSocket Request')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRequestSection(),
            const SizedBox(height: 24),
            _buildResponseSection(),
            const SizedBox(height: 24),
            if (_history.isNotEmpty) _buildHistoryWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Запрос к серверу', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _requestController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            hintText: 'Введите полный JSON запроса...',
          ),
          keyboardType: TextInputType.multiline,
          maxLines: 12,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14.0),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isLoading ? null : _sendRequest,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: Text(_isLoading ? 'Ожидание...' : 'Отправить запрос'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ответ от сервера',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_response != null)
              IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                tooltip: 'Скопировать ответ',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _response!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ответ скопирован в буфер обмена'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
          ),
          child: _buildResponseContent(),
        ),
      ],
    );
  }

  Widget _buildResponseContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return SelectableText(
        _error!,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontFamily: 'monospace',
        ),
      );
    }
    if (_response != null) {
      return SelectableText(
        _response!,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      );
    }
    return Center(
      child: Text(
        'Здесь появится ответ от сервера...',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildHistoryWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('История запросов', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final item = _history[index];
            String opcode = 'N/A';
            try {
              final decoded = jsonDecode(item.request);
              opcode = decoded['opcode']?.toString() ?? 'N/A';
            } catch (_) {}

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text(opcode)),
                title: Text(
                  'Request: ${item.request.replaceAll('\n', ' ').substring(0, (item.request.length > 50) ? 50 : item.request.length)}...',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                subtitle: Text(
                  '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}',
                ),
                onTap: () => _useHistoryItem(item),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _requestController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
