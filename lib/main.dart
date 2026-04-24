import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Replace with `flutterfire configure` output for production.
  await Firebase.initializeApp();

  runApp(const WisheyyApp());
}
