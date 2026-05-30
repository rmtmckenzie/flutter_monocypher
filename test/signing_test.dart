import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:flutter_monocypher/flutter_monocypher.dart';

void main() {
  group('Signing Tests', () {
    late Random random;

    setUp(() {
      random = Random(42); // Seeded random for deterministic tests
    });

    test('cryptoGenerateSignPair generates valid key pairs', () {
      final keyPair = cryptoGenerateSignPair(random);
      
      expect(keyPair.publicKey, isNotNull);
      expect(keyPair.publicKey.length, 32);
      
      expect(keyPair.secretKey, isNotNull);
      expect(keyPair.secretKey.length, 64);

      // Verify that calling it again with a different seed state produces a different pair
      final keyPair2 = cryptoGenerateSignPair(random);
      expect(keyPair.publicKey, isNot(equals(keyPair2.publicKey)));
      expect(keyPair.secretKey, isNot(equals(keyPair2.secretKey)));
    });

    test('cryptoSign generates a valid 64-byte signature', () {
      final keyPair = cryptoGenerateSignPair(random);
      final message = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      
      final signature = cryptoSign(message, keyPair.secretKey);
      
      expect(signature, isNotNull);
      expect(signature.length, 64);
    });

    test('cryptoSignVerify successfully verifies a valid signature', () {
      final keyPair = cryptoGenerateSignPair(random);
      final message = Uint8List.fromList([10, 20, 30, 40]);
      
      final signature = cryptoSign(message, keyPair.secretKey);
      
      final isValid = cryptoSignVerify(signature, keyPair.publicKey, message);
      expect(isValid, isTrue);
    });

    test('cryptoSignVerify rejects invalid messages', () {
      final keyPair = cryptoGenerateSignPair(random);
      final message = Uint8List.fromList([10, 20, 30, 40]);
      final alteredMessage = Uint8List.fromList([10, 20, 30, 41]);
      
      final signature = cryptoSign(message, keyPair.secretKey);
      
      final isValid = cryptoSignVerify(signature, keyPair.publicKey, alteredMessage);
      expect(isValid, isFalse);
    });

    test('cryptoSignVerify rejects altered signatures', () {
      final keyPair = cryptoGenerateSignPair(random);
      final message = Uint8List.fromList([10, 20, 30, 40]);
      
      final signature = cryptoSign(message, keyPair.secretKey);
      final alteredSignature = Uint8List.fromList(signature);
      alteredSignature[0] ^= 1; // Flip one bit
      
      final isValid = cryptoSignVerify(alteredSignature, keyPair.publicKey, message);
      expect(isValid, isFalse);
    });

    test('cryptoSignVerify rejects incorrect public keys', () {
      final keyPair1 = cryptoGenerateSignPair(random);
      final keyPair2 = cryptoGenerateSignPair(random);
      final message = Uint8List.fromList([10, 20, 30, 40]);
      
      final signature = cryptoSign(message, keyPair1.secretKey);
      
      final isValid = cryptoSignVerify(signature, keyPair2.publicKey, message);
      expect(isValid, isFalse);
    });

    test('signs and verifies empty message successfully', () {
      final keyPair = cryptoGenerateSignPair(random);
      final message = Uint8List(0);
      
      final signature = cryptoSign(message, keyPair.secretKey);
      expect(signature.length, 64);
      
      final isValid = cryptoSignVerify(signature, keyPair.publicKey, message);
      expect(isValid, isTrue);
    });

    test('signing with invalid secret key length throws assertion error', () {
      final shortSecretKey = Uint8List(63);
      final longSecretKey = Uint8List(65);
      final message = Uint8List.fromList([1, 2, 3]);

      expect(() => cryptoSign(message, shortSecretKey), throwsA(isA<AssertionError>()));
      expect(() => cryptoSign(message, longSecretKey), throwsA(isA<AssertionError>()));
    });

    test('verification with invalid signature or public key length throws assertion error', () {
      final keyPair = cryptoGenerateSignPair(random);
      final message = Uint8List.fromList([1, 2, 3]);
      final signature = cryptoSign(message, keyPair.secretKey);

      final shortSignature = Uint8List(63);
      final longSignature = Uint8List(65);
      final shortPublicKey = Uint8List(31);
      final longPublicKey = Uint8List(33);

      expect(() => cryptoSignVerify(shortSignature, keyPair.publicKey, message), throwsA(isA<AssertionError>()));
      expect(() => cryptoSignVerify(longSignature, keyPair.publicKey, message), throwsA(isA<AssertionError>()));
      expect(() => cryptoSignVerify(signature, shortPublicKey, message), throwsA(isA<AssertionError>()));
      expect(() => cryptoSignVerify(signature, longPublicKey, message), throwsA(isA<AssertionError>()));
    });
  });
}
