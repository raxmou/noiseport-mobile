import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../services/finamp_settings_helper.dart';
import '../services/finamp_user_helper.dart';
import '../services/mpd_playback_service.dart';
import '../components/error_snackbar.dart';

class MpdSettingsScreen extends StatefulWidget {
  const MpdSettingsScreen({Key? key}) : super(key: key);

  static const routeName = '/settings/mpd';

  @override
  State<MpdSettingsScreen> createState() => _MpdSettingsScreenState();
}

class _MpdSettingsScreenState extends State<MpdSettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _passwordController;
  late bool _mpdEnabled;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final settings = FinampSettingsHelper.finampSettings;

    String defaultHost = settings.mpdHost;
    if (defaultHost.isEmpty) {
      defaultHost = _getDefaultHost();
    }

    _hostController = TextEditingController(text: defaultHost);
    _portController =
        TextEditingController(text: settings.mpdPort.toString());
    _passwordController = TextEditingController(text: settings.mpdPassword);
    _mpdEnabled = settings.mpdEnabled;
  }

  String _getDefaultHost() {
    try {
      final finampUserHelper = GetIt.instance<FinampUserHelper>();
      final currentUser = finampUserHelper.currentUser;
      if (currentUser == null) return '';
      final uri = Uri.parse(currentUser.baseUrl);
      return uri.host;
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 6600;
      final password = _passwordController.text.trim();

      if (host.isEmpty) {
        setState(() {
          _testResult = 'Please enter a host address';
          _testSuccess = false;
          _isTesting = false;
        });
        return;
      }

      final mpdService = GetIt.instance<MpdPlaybackService>();
      final success = await mpdService.testConnection(
        host,
        port,
        password: password.isNotEmpty ? password : null,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _testResult = 'Connection successful! MPD server is reachable.';
          _testSuccess = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_testResult!),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _testResult = 'Failed to connect to MPD server';
          _testSuccess = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_testResult!),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = 'Connection failed: ${e.toString()}';
          _testSuccess = false;
        });

        errorSnackbar(e, context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  void _saveSettings() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 6600;
    final password = _passwordController.text.trim();

    FinampSettingsHelper.setMpdEnabled(_mpdEnabled);
    if (!_mpdEnabled) {
      FinampSettingsHelper.setIsMpdMode(false);
    }
    FinampSettingsHelper.setMpdHost(host);
    FinampSettingsHelper.setMpdPort(port);
    FinampSettingsHelper.setMpdPassword(password);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.settingsSaved),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MPD Remote Playback'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Configure your MPD server connection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable MPD'),
              subtitle:
                  const Text('Show MPD output option in player controls'),
              value: _mpdEnabled,
              onChanged: (value) {
                setState(() {
                  _mpdEnabled = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'MPD Host',
                hintText: '192.168.1.100',
                border: OutlineInputBorder(),
                helperText: 'IP address or hostname of your MPD server',
              ),
              keyboardType: TextInputType.text,
              enabled: _mpdEnabled,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'MPD Port',
                hintText: '6600',
                border: OutlineInputBorder(),
                helperText: 'Default MPD port is 6600',
              ),
              keyboardType: TextInputType.number,
              enabled: _mpdEnabled,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'MPD Password (optional)',
                border: OutlineInputBorder(),
                helperText: 'Leave empty if no password is set',
              ),
              obscureText: true,
              enabled: _mpdEnabled,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isTesting || !_mpdEnabled) ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_protected_setup),
                    label:
                        Text(_isTesting ? 'Testing...' : 'Test Connection'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 24),
              Card(
                color: _testSuccess == true
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true
                            ? Icons.check_circle
                            : Icons.error,
                        color:
                            _testSuccess == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testSuccess == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'About MPD Remote Playback',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MPD (Music Player Daemon) allows you to play music on a remote '
                      'speaker or server instead of locally on your phone. When MPD mode '
                      'is active, playback commands and Jellyfin stream URLs are sent to '
                      'the MPD server over TCP. You can toggle between local and MPD '
                      'playback from the player screen.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
