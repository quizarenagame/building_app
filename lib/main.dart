import 'dart:async';
import 'package:flutter/material.dart';

// یک متغیر سراسری برای مدیریت تم
ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

void main() => runApp(const BuildingApp());

class BuildingApp extends StatelessWidget {
  const BuildingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'سامانه مدیریت ساختمان',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF12A889), brightness: Brightness.light),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF12A889), brightness: Brightness.dark),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/app_icon.png', width: 150, height: 150),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // محاسبه سایز برای آیکون‌های داینامیک
    double iconSize = 40.0; 

    return Scaffold(
      appBar: AppBar(
        title: const Text("مدیریت ساختمان"),
        actions: [
          IconButton(
            icon: Icon(themeModeNotifier.value == ThemeMode.light ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              themeModeNotifier.value = themeModeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            },
          ),
        ],
      ),
      body: const Center(child: Text("به سامانه خوش آمدید")),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet, size: iconSize * 0.7), label: "امور مالی"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications, size: iconSize * 0.7), label: "اطلاعیه‌ها"),
          BottomNavigationBarItem(icon: Icon(Icons.request_page, size: iconSize * 0.7), label: "درخواست‌ها"),
          BottomNavigationBarItem(icon: Icon(Icons.build, size: iconSize * 0.7), label: "خدمات"),
        ],
      ),
    );
  }
}
