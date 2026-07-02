import 'package:flutter/material.dart';

import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _url.text = sl<ApiClient>().baseUrl;
    sl<TokenStorage>().apiKey().then((k) {
      if (mounted && k != null) _key.text = k;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tokens = sl<TokenStorage>();
    final api = sl<ApiClient>();
    await tokens.setApiKey(_key.text);
    await tokens.setBaseUrlOverride(_url.text);
    api.baseUrl = _url.text.trim();
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    await _save();
    try {
      final res = await sl<ApiClient>().get('/health');
      final ok = res is Map && res['status'] == 'ok';
      setState(() => _status = ok ? '✓ Подключено' : 'Ответ: $res');
    } on ApiException catch (e) {
      setState(() => _status = '✗ $e');
    } catch (e) {
      setState(() => _status = '✗ $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Подключение к серверу HTR'),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'API URL',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            decoration: const InputDecoration(
              labelText: 'API ключ (Bearer)',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            autocorrect: false,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _test,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Проверить и сохранить'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
