import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/app_localizations.dart';

void main() {
  tearDown(() {
    GamerLockerLocale.current.value = null;
  });

  test('Portuguese keeps the original interface text', () {
    GamerLockerLocale.current.value = const Locale('pt', 'BR');

    expect(gl('Criar conta'), 'Criar conta');
    expect(gl('Contas ilimitadas'), 'Contas ilimitadas');
  });

  test('English translates static interface text', () {
    GamerLockerLocale.current.value = const Locale('en', 'US');

    expect(gl('Criar conta'), 'Create account');
    expect(gl('Contas ilimitadas'), 'Unlimited accounts');
    expect(gl('Segurança e recuperação'), 'Security and recovery');
  });

  test('English translates dynamic interface text', () {
    GamerLockerLocale.current.value = const Locale('en', 'US');

    expect(
      gl('3 contas no seu GamerLocker.'),
      '3 accounts in your GamerLocker.',
    );
    expect(gl('Segurança 86%'), 'Security 86%');
  });
}
