import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
  
import 'constants.dart';
import 'device_store.dart';
import 'devices.dart';
import 'setting.dart';
import 'pairing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool _isPostingDevices = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _postDevices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _postDevices();
    }
  }

  void _postDevices() {
    if (_isPostingDevices) {
      return;
    }
    _isPostingDevices = true;
    unawaited(
      ref
          .read(deviceListProvider.notifier)
          .postDevices()
          .catchError((error, stackTrace) {
            debugPrintStack(stackTrace: stackTrace);
          })
          .whenComplete(() {
            _isPostingDevices = false;
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(deviceListProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.text),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  color: AppColors.appbar,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: SizedBox(
                          child: SvgPicture.asset(
                            'images/AsumoLogoType.svg',
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            semanticsLabel: 'Asumo Logo',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  color: AppColors.tabbar,
                  child: TabBar(
                    indicatorColor: AppColors.activeTab,
                    labelColor: AppColors.activeTab,
                    unselectedLabelColor: AppColors.text,
                    tabs: const [
                      Tab(icon: Icon(Icons.home, size: 48)),
                      Tab(icon: Icon(Icons.build, size: 48)),
                      Tab(icon: Icon(Icons.bluetooth, size: 48)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Container(
                  color: AppColors.background,
                  child: const TabBarView(
                    children: [Devices(), Setting(), Pairing()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
