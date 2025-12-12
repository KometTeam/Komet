import 'package:flutter/material.dart';
import 'package:gwid/utils/proxy_service.dart';
import 'package:gwid/utils/proxy_settings.dart';

class ProxySettingsScreen extends StatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  State<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends State<ProxySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late ProxySettings _settings;
  bool _isLoading = true;
  bool _isTesting = false; 

  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ProxyService.instance.loadProxySettings();
    setState(() {
      _settings = settings;
      _hostController.text = _settings.host;
      _portController.text = _settings.port.toString();
      _usernameController.text = _settings.username ?? '';
      _passwordController.text = _settings.password ?? '';
      _isLoading = false;
    });
  }

  Future<void> _testProxyConnection() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    setState(() {
      _isTesting = true;
    });

    final settingsToTest = ProxySettings(
      isEnabled: true, 
      protocol: _settings.protocol,
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 8080,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    try {
      await ProxyService.instance.checkProxy(settingsToTest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Прокси доступен и работает'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final newSettings = ProxySettings(
        isEnabled: _settings.isEnabled,
        protocol: _settings.protocol,
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 8080,
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
      );

      await ProxyService.instance.saveProxySettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Настройки прокси сохранены. Перезайдите, чтобы применить.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки прокси'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading || _isTesting ? null : _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    title: const Text('Включить прокси'),
                    value: _settings.isEnabled,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(isEnabled: value);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ProxyProtocol>(
                    initialValue: _settings.protocol,
                    decoration: const InputDecoration(
                      labelText: 'Протокол',
                      border: OutlineInputBorder(),
                    ),
                    items: ProxyProtocol.values
                        .where((p) => p != ProxyProtocol.socks4)
                        .map(
                          (protocol) => DropdownMenuItem(
                            value: protocol,
                            child: Text(protocol.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _settings = _settings.copyWith(protocol: value);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Хост',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_settings.isEnabled &&
                          (value == null || value.isEmpty)) {
                        return 'Укажите хост прокси-сервера';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Порт',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_settings.isEnabled) {
                        if (value == null || value.isEmpty) {
                          return 'Укажите порт';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Некорректный номер порта';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Аутентификация (необязательно)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя пользователя',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: _isTesting ? null : _testProxyConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shield_outlined),
                    label: Text(_isTesting ? 'Проверка...' : 'Проверить'),
                  ),
                ],
              ),
            ),
    );
  }
}
