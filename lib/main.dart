import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/database_gateway.dart';
import 'app/providers.dart';
import 'security/key_provider.dart';
import 'security/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDataDirectory = await getApplicationSupportDirectory();
  final gateway = EncryptedFileDatabaseGateway(
    appDataDirectory: appDataDirectory,
    keyProvider: LocalKeystoreKeyProvider(store: KeychainSecureStore()),
  );

  runApp(
    ProviderScope(
      overrides: [databaseGatewayProvider.overrideWithValue(gateway)],
      child: const MtllApp(),
    ),
  );
}
