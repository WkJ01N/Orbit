import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:path_provider/path_provider.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase 尚未初始化');
});

AppDatabase? _registeredAppDatabase;

void registerAppDatabase(AppDatabase database) {
  _registeredAppDatabase = database;
}

Future<void> closeAppDatabase() async {
  final database = _registeredAppDatabase;
  if (database == null) {
    return;
  }
  await database.close();
  _registeredAppDatabase = null;
}

Future<AppDatabase> openAppDatabase() async {
  final directory = await getApplicationSupportDirectory();
  return AppDatabase.open(directory.path);
}
