import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/noiseport_user_helper.dart';
import 'user_selector.dart';
import 'music_screen.dart';
import 'view_selector.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  static const routeName = "/";

  @override
  Widget build(BuildContext context) {
    final noiseportUserHelper = GetIt.instance<NoiseportUserHelper>();

    if (noiseportUserHelper.currentUser == null) {
      return const UserSelector();
    } else if (noiseportUserHelper.currentUser!.currentView == null) {
      return const ViewSelector();
    } else {
      return const MusicScreen();
    }
  }
}
