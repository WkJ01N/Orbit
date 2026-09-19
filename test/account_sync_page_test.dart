import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/settings/account_sync_page.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'package:orbit/services/account_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets('account page stays usable offline at 320 px in $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(locale: locale, home: const AccountSyncPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccountSyncPage), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop authentication actions are capped at 480 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(locale: Locale('en'), home: AccountSyncPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(FilledButton).first).width, 480);
    expect(tester.getSize(find.byType(OutlinedButton).first).width, 480);
  });

  testWidgets('signed-in account page exposes automatic sync controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSyncProvider.overrideWith(_SignedInAccountSyncNotifier.new),
        ],
        child: const MaterialApp(locale: Locale('en'), home: AccountSyncPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Automatic sync'), findsNWidgets(2));
    expect(find.text('When Orbit starts'), findsOneWidget);
    expect(find.text('Any network'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration and code dialogs preserve input on outside taps', (
    tester,
  ) async {
    final service = _FakeAccountService();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountServiceProvider.overrideWithValue(service),
          accountSyncProvider.overrideWith(_TestAccountSyncNotifier.new),
        ],
        child: const MaterialApp(locale: Locale('en'), home: AccountSyncPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Display name (optional)'), findsOneWidget);
    expect(
      find.text('8–20 characters with at least one letter and one number.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'orbit@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Display name (optional)'),
      'Orbit user',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'orbit123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'orbit123',
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('orbit@example.com'), findsOneWidget);

    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pump();
    await tester.pump();
    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('Verification code'), findsOneWidget);

    for (var second = 0; second < 60; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    expect(service.resendCount, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _FakeAccountService implements AccountService {
  int resendCount = 0;

  @override
  bool get configured => true;

  @override
  Future<SyncAccount?> restoreSession() async => null;

  @override
  Future<SyncAccount> signIn(String email, String password) async =>
      SyncAccount(uid: 'user-1', email: email);

  @override
  Future<VerificationChallenge> signUp(
    String email,
    String password, {
    String? username,
  }) async => VerificationChallenge(
    (_) async => SyncAccount(uid: 'user-1', email: email, username: username),
    resend: () async => resendCount++,
  );

  @override
  Future<PasswordResetChallenge> beginPasswordReset(String email) async =>
      PasswordResetChallenge((_, _) async {}, resend: () async {});

  @override
  Future<SyncAccount> updateProfile(
    SyncAccount account, {
    required String username,
    AccountAvatarUpload? avatar,
  }) async => SyncAccount(
    uid: account.uid,
    email: account.email,
    username: username,
    avatarFileId: account.avatarFileId,
  );

  @override
  Future<String?> avatarDownloadUrl(String? fileId) async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount(String password) async {}
}

class _TestAccountSyncNotifier extends AccountSyncNotifier {
  @override
  Future<SyncStatus> build() async => const SyncStatus();
}

class _SignedInAccountSyncNotifier extends AccountSyncNotifier {
  @override
  Future<SyncStatus> build() async => const SyncStatus(
    phase: SyncPhase.idle,
    account: SyncAccount(uid: 'user-1', email: 'orbit@example.com'),
  );
}
