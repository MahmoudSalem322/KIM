import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import 'app_database.dart';

Future<AppDatabase> openAppDatabase() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return AppDatabase.open(
    databaseFactoryIo,
    '${directory.path}${Platform.pathSeparator}mywallet.db',
  );
}
