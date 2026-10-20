import 'package:sembast_web/sembast_web.dart';

import 'app_database.dart';

Future<AppDatabase> openAppDatabase() =>
    AppDatabase.open(databaseFactoryWeb, 'mywallet');
