import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:convert/convert.dart';
import 'package:flutter_monocypher/flutter_monocypher.dart' as flutter_monocypher;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monocypher Ed25519 Signer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
          primary: Colors.cyanAccent,
          surface: const Color(0xFF1E293B), // Slate 800
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155), width: 1), // Slate 700
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF475569)), // Slate 600
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)), // Slate 400
        ),
      ),
      home: const SigningScreen(),
    );
  }
}

class SigningScreen extends StatefulWidget {
  const SigningScreen({super.key});

  @override
  State<SigningScreen> createState() => _SigningScreenState();
}

class _SigningScreenState extends State<SigningScreen> {
  final _messageController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _signatureController = TextEditingController();

  flutter_monocypher.CryptoSignKeyPair? _keyPair;
  bool _isSignatureValid = false;
  String _validationStatusMessage = 'Enter public key and signature to verify.';

  @override
  void initState() {
    super.initState();
    
    // Add listeners for real-time verification when any relevant field changes
    _messageController.addListener(_verifySignature);
    _publicKeyController.addListener(_verifySignature);
    _signatureController.addListener(_verifySignature);

    // Generate an initial keypair so the app has one ready
    _generateNewKeyPair();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _publicKeyController.dispose();
    _secretKeyController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  void _generateNewKeyPair() {
    try {
      final random = Random.secure();
      final keyPair = flutter_monocypher.cryptoGenerateSignPair(random);
      setState(() {
        _keyPair = keyPair;
        _publicKeyController.text = hex.encode(keyPair.publicKey);
        _secretKeyController.text = hex.encode(keyPair.secretKey);
      });
    } catch (e) {
      _showSnackBar('Error generating key pair: $e', isError: true);
    }
  }

  void _signMessage() {
    final messageText = _messageController.text;
    final secretKeyHex = _secretKeyController.text.trim();

    if (secretKeyHex.length != 128) {
      _showSnackBar('Secret key must be 128 hex characters (64 bytes).', isError: true);
      return;
    }

    try {
      final secretKeyBytes = Uint8List.fromList(hex.decode(secretKeyHex));
      final messageBytes = utf8.encode(messageText);

      final signature = flutter_monocypher.cryptoSign(messageBytes, secretKeyBytes);
      
      setState(() {
        _signatureController.text = hex.encode(signature);
      });
      _showSnackBar('Message signed successfully!');
    } catch (e) {
      _showSnackBar('Signing failed: $e', isError: true);
    }
  }

  void _verifySignature() {
    final signatureHex = _signatureController.text.trim();
    final publicKeyHex = _publicKeyController.text.trim();
    final messageText = _messageController.text;

    if (signatureHex.isEmpty || publicKeyHex.isEmpty) {
      setState(() {
        _isSignatureValid = false;
        _validationStatusMessage = 'Provide both public key and signature to verify.';
      });
      return;
    }

    try {
      if (signatureHex.length != 128) {
        setState(() {
          _isSignatureValid = false;
          _validationStatusMessage = 'Signature must be exactly 128 hex characters (64 bytes).';
        });
        return;
      }

      if (publicKeyHex.length != 64) {
        setState(() {
          _isSignatureValid = false;
          _validationStatusMessage = 'Public key must be exactly 64 hex characters (32 bytes).';
        });
        return;
      }

      final signatureBytes = Uint8List.fromList(hex.decode(signatureHex));
      final publicKeyBytes = Uint8List.fromList(hex.decode(publicKeyHex));
      final messageBytes = utf8.encode(messageText);

      final isValid = flutter_monocypher.cryptoSignVerify(
        signatureBytes,
        publicKeyBytes,
        messageBytes,
      );

      setState(() {
        _isSignatureValid = isValid;
        _validationStatusMessage = isValid
            ? 'Signature is VALID for this message and public key!'
            : 'Signature is INVALID. The message, key, or signature does not match.';
      });
    } on FormatException catch (_) {
      setState(() {
        _isSignatureValid = false;
        _validationStatusMessage = 'Invalid hex characters in signature or public key.';
      });
    } catch (e) {
      setState(() {
        _isSignatureValid = false;
        _validationStatusMessage = 'Verification error: $e';
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text(
              'Monocypher Ed25519 Signer',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Key Management Card
              _buildKeyManagementCard(),
              const SizedBox(height: 20),

              // Signing Card
              _buildSigningCard(),
              const SizedBox(height: 20),

              // Verification Status Card
              _buildVerificationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyManagementCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Ed25519 Key Pair',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _generateNewKeyPair,
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.black),
                  label: const Text(
                    'Generate New',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildKeyTextField(
              label: 'Public Key (32 bytes / 64 hex)',
              controller: _publicKeyController,
              onChanged: (val) {
                setState(() {
                  _keyPair = null;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildKeyTextField(
              label: 'Secret Key (64 bytes / 128 hex)',
              controller: _secretKeyController,
              isSecret: true,
              onChanged: (val) {
                setState(() {
                  _keyPair = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyTextField({
    required String label,
    required TextEditingController controller,
    bool isSecret = false,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: Colors.cyanAccent),
              onPressed: () => _copyToClipboard(controller.text, isSecret ? 'Secret Key' : 'Public Key'),
              tooltip: 'Copy to clipboard',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: null,
          minLines: 1,
          style: const TextStyle(
            fontFamily: 'Courier',
            fontSize: 13,
            color: Color(0xFFE2E8F0),
            letterSpacing: 0.5,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSigningCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Sign Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Message to Sign',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type your message here...',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _signMessage,
              icon: const Icon(Icons.create, color: Colors.black, size: 18),
              label: const Text(
                'Sign Message',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard() {
    final statusColor = _isSignatureValid ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusBgColor = _isSignatureValid ? const Color(0xFF064E3B) : const Color(0xFF450A0A);
    final statusBorderColor = _isSignatureValid ? const Color(0xFF047857) : const Color(0xFF991B1B);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user, color: Colors.cyanAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Signature Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildKeyTextField(
              label: 'Signature (64 bytes / 128 hex - editable)',
              controller: _signatureController,
            ),
            const SizedBox(height: 20),
            // Verification Status Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusBorderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSignatureValid ? Icons.check_circle : Icons.error,
                    color: statusColor,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignatureValid ? 'VALID SIGNATURE' : 'VERIFICATION FAIL',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _validationStatusMessage,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
