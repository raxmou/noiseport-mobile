import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:chopper/chopper.dart';
import 'package:get_it/get_it.dart';

import '../services/noiseport_settings_helper.dart';
import '../services/noiseport_user_helper.dart';
import '../components/error_snackbar.dart';

class NoiseportSettingsScreen extends StatefulWidget {
  const NoiseportSettingsScreen({Key? key}) : super(key: key);

  static const routeName = '/settings/noiseport';

  @override
  State<NoiseportSettingsScreen> createState() => _NoiseportSettingsScreenState();
}

class _NoiseportSettingsScreenState extends State<NoiseportSettingsScreen> {
  late TextEditingController _serverIpController;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final settings = NoiseportSettingsHelper.noiseportSettings;
    
    // Get default server IP from Jellyfin server if not already set
    String defaultServerIp = settings.noiseportServerIp;
    if (defaultServerIp.isEmpty) {
      defaultServerIp = _getDefaultNoiseportServerIp();
    }
    
    _serverIpController = TextEditingController(text: defaultServerIp);
  }
  
  /// Gets the default NoisePort server IP based on the connected Jellyfin server
  String _getDefaultNoiseportServerIp() {
    try {
      final noiseportUserHelper = GetIt.instance<NoiseportUserHelper>();
      final currentUser = noiseportUserHelper.currentUser;
      
      if (currentUser == null) {
        return '';
      }
      
      final baseUrl = currentUser.baseUrl;
      final uri = Uri.parse(baseUrl);
      
      // Return just the IP/host without port
      return uri.host;
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    ChopperClient? healthClient;
    try {
      final serverIp = _serverIpController.text.trim();
      
      if (serverIp.isEmpty) {
        setState(() {
          _testResult = 'Please enter a server IP address';
          _testSuccess = false;
          _isTesting = false;
        });
        return;
      }

      // Create Chopper client for the health check
      healthClient = ChopperClient(
        baseUrl: Uri.parse('http://$serverIp:8010'),
      );

      // Make the GET request to the health endpoint
      final response = await healthClient.get(
        Uri.parse('/api/v1/system/health'),
      );

      if (!mounted) return;

      if (response.isSuccessful) {
        setState(() {
          _testResult = 'Connection successful! Server is reachable.';
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
          _testResult = 'Failed to connect: HTTP ${response.statusCode}';
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
      healthClient?.dispose();
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  void _saveSettings() {
    NoiseportSettingsHelper.setNoiseportServerIp(_serverIpController.text.trim());

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
        title: const Text('Noiseport Server Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Configure your Noiseport server connection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _serverIpController,
              decoration: const InputDecoration(
                labelText: 'Server IP Address',
                hintText: '100.98.104.55',
                border: OutlineInputBorder(),
                helperText: 'Usually a Tailscale VPN IP starting with 100.',
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_protected_setup),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
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
                        _testSuccess == true ? Icons.check_circle : Icons.error,
                        color: _testSuccess == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testSuccess == true ? Colors.green : Colors.red,
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
                          'About Noiseport',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Noiseport is a server that provides Spotify integration features. '
                      'The IP address is typically a Tailscale VPN IP starting with "100." '
                      'This setting is used for Spotify token authentication and download requests.',
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
