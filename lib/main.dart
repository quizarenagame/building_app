import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final PocketBase pb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  pb = PocketBase(
    'https://api.pgem.ir',
    authStore: AsyncAuthStore(
      save: (String data) async { await prefs.setString('pb_auth', data); },
      initial: prefs.getString('pb_auth'),
      clear: () async { await prefs.remove('pb_auth'); },
    ),
  );
  runApp(BuildingApp());
}

class BuildingApp extends StatelessWidget {
  BuildingApp({super.key});
  /// حالت تم سراسری؛ با دکمهٔ نوار بالای داشبورد تغییر می‌کند.
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// بررسی روشن/تاریک مؤثر (ThemeMode.system را هم در نظر می‌گیرد)
  static bool isEffectiveDark(BuildContext context, ThemeMode mode) {
    if (mode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  /// تغییر فوری تم با اولین کلیک (حالت system هم به‌درستی هندل می‌شود)
  static void toggleTheme(BuildContext context) {
    themeMode.value = isEffectiveDark(context, themeMode.value) ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF12A889);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'سامانه مدیریت ساختمان',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xFFF5F7F8),
          fontFamily: 'Roboto',
          cardTheme: CardTheme(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          cardTheme: CardTheme(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        ),
        themeMode: mode,
        home: Directionality(textDirection: TextDirection.rtl, child: _initialHome()),
      ),
    );
  }
}

Widget _initialHome() {
  if (!pb.authStore.isValid) return const LoginFlow();
  final record = pb.authStore.record;
  final data = record?.data ?? const <String, dynamic>{};
  final firstName = (data['name'] ?? '').toString().trim();
  final lastName = (data['last_name'] ?? data['lastname'] ?? '').toString().trim();
  final fullName = [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
  final roleValue = (data['role'] ?? '').toString().trim();
  return DashboardPage(
    name: fullName.isEmpty ? (record?.id ?? '') : fullName,
    role: roleValue == 'مدیر' ? 'مدیر' : 'ساکن',
    buildingName: (data['building_name'] ?? '').toString(),
    ownership: (data['ownership'] ?? 'ساکن').toString(),
    showMyBuildings: data['show_my_buildings'] == true,
  );
}

String _latinDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var result = value;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
  }
  return result;
}


/// Parse Persian/Arabic/Latin digits and common thousands separators into Toman.
int? parseTomanAmount(String value) {
  var normalized = _latinDigits(value).replaceAll('٬', '').replaceAll(',', '').replaceAll('،', '').replaceAll(' ', '').replaceAll('تومان', '');
  normalized = normalized.replaceAll('٫', '.');
  if (normalized.contains('.') || normalized.isEmpty || !RegExp(r'^\d+$').hasMatch(normalized)) return null;
  return int.tryParse(normalized);
}

String formatTomanAmount(int amount) {
  final raw = amount.toString();
  final grouped = raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${_latinDigitsToPersian(grouped)} تومان';
}

String _latinDigitsToPersian(String value) {
  const latin = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = value;
  for (var i = 0; i < 10; i++) { result = result.replaceAll(latin[i], persian[i]); }
  return result;
}

extension StringPersianDigits on String {
  String toPersianDigits() => _latinDigitsToPersian(this);
}

enum _LoginStep { welcome, phone, otp, account, success, managerChoice, dashboard }

const List<MapEntry<String, List<String>>> _iranProvinceCities = [
  MapEntry('آذربایجان شرقی', ['تبریز', 'مراغه', 'مرند', 'اهر', 'جلفا']),
  MapEntry('آذربایجان غربی', ['ارومیه', 'خوی', 'میاندوآب', 'مهاباد', 'بوکان', 'سلماس']),
  MapEntry('اردبیل', ['اردبیل', 'پارس‌آباد', 'مشگین‌شهر', 'خلخال', 'گرمی']),
  MapEntry('اصفهان', ['اصفهان', 'کاشان', 'خمینی‌شهر', 'نجف‌آباد', 'شهرضا', 'شاهین‌شهر']),
  MapEntry('البرز', ['کرج', 'فردیس', 'نظرآباد', 'هشتگرد', 'محمدشهر']),
  MapEntry('ایلام', ['ایلام', 'دهلران', 'ایوان', 'آبدانان', 'مهران']),
  MapEntry('بوشهر', ['بوشهر', 'برازجان', 'گناوه', 'کنگان', 'عسلویه', 'خورموج']),
  MapEntry('تهران', ['تهران', 'ری', 'شمیرانات', 'اسلام‌شهر', 'شهریار', 'ورامین', 'پاکدشت']),
  MapEntry('چهارمحال و بختیاری', ['شهرکرد', 'بروجن', 'فارسان', 'لردگان', 'فرخ‌شهر']),
  MapEntry('خراسان جنوبی', ['بیرجند', 'قائن', 'طبس', 'فردوس', 'نهبندان']),
  MapEntry('خراسان رضوی', ['مشهد', 'نیشابور', 'سبزوار', 'تربت حیدریه', 'کاشمر', 'قوچان']),
  MapEntry('خراسان شمالی', ['بجنورد', 'شیروان', 'اسفراین', 'جاجرم', 'آشخانه']),
  MapEntry('خوزستان', ['اهواز', 'آبادان', 'خرمشهر', 'دزفول', 'ماهشهر', 'بهبهان']),
  MapEntry('زنجان', ['زنجان', 'ابهر', 'خرمدره', 'قیدار', 'سلطانیه']),
  MapEntry('سمنان', ['سمنان', 'شاهرود', 'دامغان', 'گرمسار', 'مهدی‌شهر']),
  MapEntry('سیستان و بلوچستان', ['زاهدان', 'چابهار', 'زابل', 'ایرانشهر', 'سراوان', 'خاش']),
  MapEntry('فارس', ['شیراز', 'مرودشت', 'جهرم', 'فسا', 'کازرون', 'لارستان']),
  MapEntry('قزوین', ['قزوین', 'تاکستان', 'الوند', 'آبیک', 'بوئین‌زهرا']),
  MapEntry('قم', ['قم']),
  MapEntry('کردستان', ['سنندج', 'سقز', 'مریوان', 'بانه', 'قروه', 'کامیاران']),
  MapEntry('کرمان', ['کرمان', 'سیرجان', 'رفسنجان', 'جیرفت', 'بم', 'زرند']),
  MapEntry('کرمانشاه', ['کرمانشاه', 'اسلام‌آباد غرب', 'هرسین', 'کنگاور', 'پاوه', 'جوانرود']),
  MapEntry('کهگیلویه و بویراحمد', ['یاسوج', 'دهدشت', 'گچساران', 'لیکک']),
  MapEntry('گلستان', ['گرگان', 'گنبدکاووس', 'علی‌آباد کتول', 'بندرترکمن', 'آق‌قلا']),
  MapEntry('گیلان', ['رشت', 'بندر انزلی', 'لاهیجان', 'لنگرود', 'تالش', 'رودسر']),
  MapEntry('لرستان', ['خرم‌آباد', 'بروجرد', 'دورود', 'الیگودرز', 'کوهدشت']),
  MapEntry('مازندران', ['ساری', 'بابل', 'آمل', 'قائم‌شهر', 'چالوس', 'تنکابن']),
  MapEntry('مرکزی', ['اراک', 'ساوه', 'خمین', 'محلات', 'دلیجان', 'شازند']),
  MapEntry('هرمزگان', ['بندرعباس', 'قشم', 'کیش', 'میناب', 'بندرلنگه']),
  MapEntry('همدان', ['همدان', 'ملایر', 'نهاوند', 'تویسرکان', 'اسدآباد']),
  MapEntry('یزد', ['یزد', 'میبد', 'اردکان', 'بافق', 'مهریز', 'تفت']),
];


/// کلید شناور واحد برای تغییر تم در تمام مراحل برنامه.
class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: BuildingApp.themeMode,
    builder: (context, mode, _) => IconButton.filledTonal(
      tooltip: BuildingApp.isEffectiveDark(context, mode) ? 'تم روشن' : 'تم تاریک',
      icon: Icon(BuildingApp.isEffectiveDark(context, mode) ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      onPressed: () => BuildingApp.toggleTheme(context),
    ),
  );
}

class LoginFlow extends StatefulWidget {
  const LoginFlow({super.key});
  @override
  State<LoginFlow> createState() => _LoginFlowState();
}

class _LoginFlowState extends State<LoginFlow> {
       DateTime? _lastPressedAt;
  _LoginStep _step = _LoginStep.welcome;
  final _phoneKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _accountKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedProvince;
  String? _selectedCity;
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _unitController = TextEditingController();
  String? _ownership;
  String? _role;
  bool _showMyBuildings = false;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _goBack() {
  switch (_step) {
    case _LoginStep.phone:
      setState(() => _step = _LoginStep.welcome);
      break;

    case _LoginStep.otp:
      _timer?.cancel();
      setState(() => _step = _LoginStep.phone);
      break;

    case _LoginStep.account:
      setState(() => _step = _LoginStep.otp);
      break;

    case _LoginStep.success:
      setState(() => _step = _LoginStep.account);
      break;

    case _LoginStep.managerChoice:
      setState(() => _step = _LoginStep.account);
      break;

    case _LoginStep.dashboard:
      setState(() => _step =
          _role == 'مدیر' ? _LoginStep.managerChoice : _LoginStep.account);
      break;

    case _LoginStep.welcome:
      final now = DateTime.now();
      if (_lastPressedAt == null ||
          now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
        _lastPressedAt = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('برای خروج دوباره کلید بازگشت را فشار دهید'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        SystemNavigator.pop();
      }
      break;
  }
}

  Future<void> _resendOtp() async {
    if (_isSendingOtp) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    
    setState(() => _isSendingOtp = true);
    try {
      final response = await pb.send<Map<String, dynamic>>(
        '/api/send-otp',
        method: 'POST',
        body: {'phone': phone},
      );
      if (!mounted) return;
      if (response['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ارسال مجدد کد تأیید ناموفق بود. لطفاً دوباره تلاش کنید.')),
        );
        return;
      }
      _otpController.clear();
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد تأیید مجدداً ارسال شد.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ارسال پیامک انجام نشد. اتصال خود را بررسی و دوباره تلاش کنید.')),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _submitPhone() async {
    if (_isSendingOtp || !(_phoneKey.currentState?.validate() ?? false)) return;
    _phoneController.text = _latinDigits(_phoneController.text).replaceAll(' ', '').trim();
    setState(() => _isSendingOtp = true);
    try {
      final response = await pb.send<Map<String, dynamic>>(
        '/api/send-otp',
        method: 'POST',
        body: {'phone': _phoneController.text},
      );
      if (!mounted) return;
      if (response['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ارسال کد تأیید ناموفق بود. لطفاً دوباره تلاش کنید.')));
        return;
      }
      _otpController.clear();
      setState(() => _step = _LoginStep.otp);
      _startCountdown();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ارسال پیامک انجام نشد. اتصال خود را بررسی و دوباره تلاش کنید.')));
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
  if (_isVerifyingOtp || !(_otpKey.currentState?.validate() ?? false)) return;
  final phone = _phoneController.text.trim();
  final code = _latinDigits(_otpController.text.trim());
  setState(() => _isVerifyingOtp = true);
  try {
    final response = await pb.send<Map<String, dynamic>>(
      '/api/verify-otp',
      method: 'POST',
      body: {'phone': phone, 'code': code},
    );
    if (!mounted) return;
    if (response['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد تأیید صحیح نیست یا منقضی شده است.')));
      return;
    }
    final token = response['token'];
    final rawRecord = response['record'];
    if (token is! String || token.isEmpty || rawRecord is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پاسخ ورود از سرور کامل نیست. لطفاً دوباره تلاش کنید.')));
      return;
    }
    final recordJson = Map<String, dynamic>.from(rawRecord);
    final record = RecordModel.fromJson(recordJson);
    pb.authStore.save(token, record);
    _timer?.cancel();
    final existingName = (record.data['name'] ?? '').toString().trim();
    final existingLastName = (record.data['last_name'] ?? record.data['lastname'] ?? '').toString().trim();
    final existingRole = (record.data['role'] ?? '').toString().trim();
    if (existingName.isNotEmpty || existingLastName.isNotEmpty) {
      _nameController.text = existingName;
      _lastNameController.text = existingLastName;
      _role = existingRole == 'مدیر' ? 'مدیر' : 'ساکن';
      _ownership = (record.data['ownership'] ?? 'ساکن').toString();
      _buildingController.text = (record.data['building_name'] ?? '').toString();
      if (mounted) setState(() => _step = _LoginStep.dashboard);
    } else {
      if (mounted) setState(() => _step = _LoginStep.account);
    }
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بررسی کد تأیید انجام نشد. لطفاً دوباره تلاش کنید.')));
  } finally {
    if (mounted) setState(() => _isVerifyingOtp = false);
  }
}


 Future<void> _submitAccount() async {
  if (!(_accountKey.currentState?.validate() ?? false)) return;
  FocusScope.of(context).unfocus();

  final phone = _phoneController.text.trim();
  final name = _nameController.text.trim();
  final lastName = _lastNameController.text.trim();
  final role = _role; // "مدیر" یا "ساکن"
  final ownership = _ownership; // "مالک" یا "مستأجر"
  final buildingName = _buildingController.text.trim();

  try {
    // ارسال اطلاعات حساب به اندپوینت سروری که ساختیم
    final response = await pb.send<Map<String, dynamic>>(
      '/api/update-profile',
      method: 'POST',
      body: {
        'phone': phone,
        'name': name,
        'last_name': lastName,
        'role': role,
        'ownership': ownership,
        'building_name': buildingName,
      },
    );

    if (response['success'] == true) {
      // به‌روزرسانی محلی AuthStore در پاکت‌بیس با رکورد جدید برگشتی از سرور
      if (response['record'] != null) {
        final recordJson = response['record'] as Map<String, dynamic>;
        // استفاده از توکن فعال موجود در authStore کلاینت
        final currentToken = pb.authStore.token;
        if (currentToken.isNotEmpty) {
          final record = RecordModel.fromJson(recordJson);
          pb.authStore.save(currentToken, record);
        }
      }

      if (!mounted) return;
      setState(() => _step = _LoginStep.success);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['error'] ?? 'خطا در ذخیره پروفایل')),
      );
    }
  } catch (err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطای ارتباط با سرور: $err')),
    );
  }
}


    if (response['success'] == true) {
      // به‌روزرسانی محلی AuthStore در پاکت‌بیس با رکورد جدید برگشتی از سرور
      if (response['record'] != null) {
        final recordJson = response['record'] as Map<String, dynamic>;
        // استفاده از توکن فعال موجود در authStore کلاینت
        final currentToken = pb.authStore.token;
        if (currentToken.isNotEmpty) {
          final record = RecordModel.fromJson(recordJson);
          pb.authStore.save(currentToken, record);
        }
      }

      if (!mounted) return;
      setState(() => _step = _LoginStep.success);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['error'] ?? 'خطا در ذخیره پروفایل')),
      );
    }
  } catch (err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطای ارتباط با سرور: $err')),
    );
  }
}

      if (!mounted) return;
      setState(() => _step = _LoginStep.success);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['error'] ?? 'خطا در ذخیره پروفایل')),
      );
    }
  } catch (err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطای ارتباط با سرور: $err')),
    );
  }
}

  String get _stepTitle => switch (_step) {
    _LoginStep.phone => 'شماره همراه',
    _LoginStep.otp => 'تأیید شماره',
    _LoginStep.account => 'ساخت حساب کاربری',
    _LoginStep.managerChoice => 'انتخاب نقش مدیر',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    if (_step == _LoginStep.dashboard) {
      // داشبورد هم داخل PopScope است تا دکمهٔ برگشت گوشی به جای خروج، به مرحلهٔ حساب برگردد
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) { if (!didPop) _goBack(); },
        child: Scaffold(
          body: SafeArea(
            child: DashboardPage(name: _nameController.text.trim(), role: _role ?? 'ساکن', buildingName: _buildingController.text.trim(), ownership: _ownership ?? 'ساکن', showMyBuildings: _showMyBuildings, onSwitch: () => setState(() => _step = _LoginStep.account)),
          ),
        ),
      );
    }
    final showBar = _step == _LoginStep.phone || _step == _LoginStep.otp || _step == _LoginStep.account || _step == _LoginStep.success || _step == _LoginStep.managerChoice;
    // در همهٔ مراحل (حتی welcome) canPop=false تا سیستم/دکمهٔ برگشت گوشی هرگز از برنامه خارج نشود
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { if (!didPop) _goBack(); },
      child: Scaffold(
      appBar: showBar ? AppBar(
        leading: IconButton(tooltip: 'بازگشت', onPressed: _goBack, icon: const Icon(Icons.arrow_forward_rounded)),
        title: Text(_stepTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ) : null,
      body: SafeArea(
        top: !showBar,
        child: Stack(children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  child: _buildStep(context),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 12,
            child: _ThemeToggle(),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _LoginStep.welcome: return _welcome(context);
      case _LoginStep.phone: return _phoneForm(context);
      case _LoginStep.otp: return _otpForm(context);
      case _LoginStep.account: return _accountForm(context);
      case _LoginStep.success: return _success(context);
      case _LoginStep.managerChoice: return _managerChoice(context);
      case _LoginStep.dashboard: return const SizedBox.shrink();
    }
  }

  Widget _brandMark({double size = 86}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF117D70), Color(0xFF19B794)]),
      borderRadius: BorderRadius.circular(size * .31),
      boxShadow: [BoxShadow(color: const Color(0xFF11947A).withOpacity(.22), blurRadius: 24, offset: const Offset(0, 12))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .31),
      child: Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    ),
  );

  Widget _welcome(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 42),
      Center(child: _brandMark()),
      const SizedBox(height: 25),
      const Text('به خانه‌تان خوش آمدید', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.5)),
      const SizedBox(height: 8),
      Text('سامانه مدیریت ساختمان؛ همه‌چیز برای زندگی آسوده‌تر', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14, height: 1.8)),
      const SizedBox(height: 34),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: colors.primaryContainer.withOpacity(.42), borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Icon(Icons.verified_user_outlined, color: colors.primary, size: 25),
          const SizedBox(width: 12),
          const Expanded(child: Text('با شماره همراه وارد شده یا حساب کاربری بسازید', style: TextStyle(fontSize: 13, height: 1.7))),
        ]),
      ),
      const SizedBox(height: 26),
      _primaryButton(label: 'شروع و ورود با شماره همراه', onPressed: () => setState(() => _step = _LoginStep.phone)),
      const SizedBox(height: 15),
      Text('ساده، امن و مخصوص ساکنان ساختمان', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
      const SizedBox(height: 36),
      const _MiniFeatures(),
    ]);
  }

  Widget _phoneForm(BuildContext context) => Form(
    key: _phoneKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 26),
      _stepIcon(Icons.phone_iphone_rounded),
      const SizedBox(height: 22),
      const Text('شماره همراهتان را وارد کنید', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      Text('برای ادامه، شماره موبایل ایران خود را بنویسید.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.7)),
      const SizedBox(height: 28),
      _fieldLabel('شماره موبایل'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        maxLength: 11,
        decoration: _inputDecoration(hint: '09123456789', prefix: const Icon(Icons.call_outlined), counterText: ''),
        validator: (value) {
          final phone = _latinDigits(value ?? '').replaceAll(' ', '');
          return RegExp(r'^09\d{9}$').hasMatch(phone) ? null : 'شماره باید با 09 شروع شود و ۱۱ رقم باشد.';
        },
        onFieldSubmitted: (_) => _submitPhone(),
      ),
      const SizedBox(height: 20),
      _primaryButton(label: 'دریافت کد تأیید', onPressed: _submitPhone),
      const SizedBox(height: 15),
      Text('پس از ارسال، کد تأیید از طریق پیامک برای شما فرستاده می‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.8)),
    ]),
  );

  Widget _otpForm(BuildContext context) => Form(
    key: _otpKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 15),
      _stepIcon(Icons.lock_outline_rounded),
      const SizedBox(height: 20),
      const Text('کد تأیید را وارد کنید', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      Text('کد تأیید ۴ رقمی برای شماره ${_phoneController.text} پیامک شد.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.8)),
      const SizedBox(height: 15),
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF4DD), borderRadius: BorderRadius.circular(15)), child: const Text('کد ۴ رقمی از طریق پیامک برای شمارهٔ شما ارسال می‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF805A17), fontSize: 12, height: 1.7, fontWeight: FontWeight.w600))),
      const SizedBox(height: 25),
      TextFormField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLength: 4,
        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, letterSpacing: 12),
        decoration: _inputDecoration(hint: '••••', counterText: ''),
        validator: (value) => _latinDigits(value ?? '').length == 4 ? null : 'کد تأیید باید ۴ رقم باشد.',
        onFieldSubmitted: (_) => _verifyOtp(),
      ),
      const SizedBox(height: 18),
      _primaryButton(label: 'تأیید و ادامه', onPressed: _verifyOtp),
      const SizedBox(height: 14),
      Center(child: TextButton.icon(
        onPressed: _secondsLeft == 0 && !_isSendingOtp ? _resendOtp : null,
        icon: const Icon(Icons.refresh_rounded, size: 19),
        label: Text(_isSendingOtp ? 'در حال ارسال پیامک...' : (_secondsLeft == 0 ? 'ارسال دوباره کد پیامکی' : 'ارسال دوباره تا ${_secondsLeft} ثانیه دیگر')),
      )),
      Center(child: TextButton(onPressed: () { _timer?.cancel(); setState(() => _step = _LoginStep.phone); }, child: const Text('ویرایش شماره همراه'))),
    ]),
  );

  Widget _accountForm(BuildContext context) => Form(
    key: _accountKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      _stepIcon(Icons.person_add_alt_1_rounded),
      const SizedBox(height: 17),
      const Text('ساخت حساب کاربری', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('برای ادامه، اطلاعات خود را کامل وارد کنید.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.7)),
      const SizedBox(height: 22),
      _fieldLabel('نام'), const SizedBox(height: 7),
      TextFormField(controller: _nameController, textCapitalization: TextCapitalization.words,
        decoration: _inputDecoration(hint: 'مثلاً سارا', prefix: const Icon(Icons.badge_outlined)),
        validator: (v) => (v?.trim().length ?? 0) >= 2 ? null : 'نام را وارد کنید.'),
      const SizedBox(height: 16),
      _fieldLabel('نام خانوادگی'), const SizedBox(height: 7),
      TextFormField(controller: _lastNameController, textCapitalization: TextCapitalization.words,
        decoration: _inputDecoration(hint: 'مثلاً احمدی', prefix: const Icon(Icons.badge_outlined)),
        validator: (v) => (v?.trim().length ?? 0) >= 2 ? null : 'نام خانوادگی را وارد کنید.'),
      const SizedBox(height: 16),
      _fieldLabel('رمز عبور'), const SizedBox(height: 7),
      TextFormField(
        controller: _passwordController,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        obscureText: _hidePassword,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _inputDecoration(
          hint: 'فقط رقم', prefix: const Icon(Icons.lock_outline_rounded),
          suffix: IconButton(
            tooltip: _hidePassword ? 'نمایش رمز' : 'پنهان کردن رمز',
            icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
          ),
        ),
        validator: (v) => (v?.trim().length ?? 0) >= 4 ? null : 'رمز عبور باید حداقل ۴ رقم باشد.',
      ),
      const SizedBox(height: 16),
      _fieldLabel('تأیید رمز عبور'), const SizedBox(height: 7),
      TextFormField(
        controller: _confirmPasswordController,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        obscureText: _hideConfirmPassword,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _inputDecoration(
          hint: 'تکرار رمز عبور', prefix: const Icon(Icons.lock_outline_rounded),
          suffix: IconButton(
            tooltip: _hideConfirmPassword ? 'نمایش رمز' : 'پنهان کردن رمز',
            icon: Icon(_hideConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
          ),
        ),
        validator: (v) => (v?.trim() == _passwordController.text.trim()) ? null : 'رمز عبور و تأیید آن یکسان نیستند.',
      ),
      const SizedBox(height: 16),
      _fieldLabel('استان'), const SizedBox(height: 7),
      DropdownButtonFormField<String>(
        value: _selectedProvince,
        decoration: _inputDecoration(hint: 'مثلاً تهران', prefix: const Icon(Icons.map_outlined)),
        items: _iranProvinceCities.map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.key))).toList(),
        onChanged: (value) => setState(() { _selectedProvince = value; _selectedCity = null; }),
        validator: (v) => v != null ? null : 'استان را وارد کنید.'),
      const SizedBox(height: 16),
      _fieldLabel('شهر'), const SizedBox(height: 7),
      DropdownButtonFormField<String>(
        key: ValueKey(_selectedProvince),
        value: _selectedCity,
        decoration: _inputDecoration(hint: 'مثلاً تهران', prefix: const Icon(Icons.location_city_outlined)),
        items: _iranProvinceCities.where((entry) => entry.key == _selectedProvince).expand((entry) => entry.value).map((city) => DropdownMenuItem<String>(value: city, child: Text(city))).toList(),
        onChanged: _selectedProvince == null ? null : (value) => setState(() => _selectedCity = value),
        validator: (v) => v != null ? null : 'شهر را وارد کنید.'),
      const SizedBox(height: 22),
      _primaryButton(label: 'ادامه', onPressed: _submitAccount),
      const SizedBox(height: 12),
      Text('شماره همراه تأییدشده: ${_phoneController.text}', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ]),
  );

  Widget _success(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 32),
      Center(child: Container(width: 86, height: 86, decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.person_outline, size: 48, color: colors.primary))),
      const SizedBox(height: 20),
      const Text('انتخاب نقش', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('${_nameController.text.trim()}، نقش خود را انتخاب کنید.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, height: 1.8)),
      const SizedBox(height: 26),
      FilledButton.icon(onPressed: () => _selectRole('مدیر'), icon: const Icon(Icons.manage_accounts_outlined), label: const Text('مدیر')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => _selectRole('ساکن'), icon: const Icon(Icons.people_outline), label: const Text('ساکنین')),
      const SizedBox(height: 18),
      Text('نسخهٔ نمایشی است؛ اطلاعات حساب به سرور ارسال یا ذخیره نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.7)),
    ]);
  }

  void _selectRole(String role) {
    setState(() {
      _role = role;
      _showMyBuildings = false;
      _step = role == 'مدیر' ? _LoginStep.managerChoice : _LoginStep.dashboard;
    });
  }

  Widget _managerChoice(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 32),
      _stepIcon(Icons.manage_accounts_outlined),
      const SizedBox(height: 20),
      const Text('مدیریت ساختمان', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('سلام ${_nameController.text.trim()}! یک گزینه را انتخاب کنید.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, height: 1.8)),
      const SizedBox(height: 26),
      FilledButton.icon(
        onPressed: () => setState(() { _showMyBuildings = false; _step = _LoginStep.dashboard; }),
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text('ایجاد ساختمان جدید'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => setState(() { _showMyBuildings = true; _step = _LoginStep.dashboard; }),
        icon: const Icon(Icons.apartment_rounded),
        label: const Text('ساختمان تحت مدیریت من'),
      ),
      const SizedBox(height: 18),
      Text('نسخهٔ نمایشی است؛ اطلاعات به سرور ارسال یا ذخیره نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.7)),
    ]);
  }

  Widget _stepIcon(IconData icon) => Center(child: Container(width: 66, height: 66, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.65), borderRadius: BorderRadius.circular(22)), child: Icon(icon, size: 31, color: Theme.of(context).colorScheme.primary)));
  Widget _fieldLabel(String value) => Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
  InputDecoration _inputDecoration({required String hint, Widget? prefix, Widget? suffix, String? counterText}) => InputDecoration(
    hintText: hint, prefixIcon: prefix, suffixIcon: suffix, counterText: counterText,
    filled: true, fillColor: Theme.of(context).colorScheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.8)),
    errorMaxLines: 2,
  );
  Widget _primaryButton({required String label, required VoidCallback onPressed}) => SizedBox(height: 54, child: FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), child: Text(label)));
}

class _MiniFeatures extends StatelessWidget {
  const _MiniFeatures();
  @override
  Widget build(BuildContext context) => Row(children: const [
    Expanded(child: _MiniFeatureItem(icon: Icons.miscellaneous_services_outlined, title: 'خدمات')),
    Expanded(child: _MiniFeatureItem(icon: Icons.handyman_outlined, title: 'درخواست‌ها')),
    Expanded(child: _MiniFeatureItem(icon: Icons.campaign_outlined, title: 'اطلاعیه‌ها')),
    Expanded(child: _MiniFeatureItem(icon: Icons.receipt_long_outlined, title: 'امور مالی')),
  ]);
}
class _MiniFeatureItem extends StatelessWidget {
  const _MiniFeatureItem({required this.icon, required this.title});
  final IconData icon; final String title;
  @override
  Widget build(BuildContext context) => Column(children: [Icon(icon, color: Theme.of(context).colorScheme.primary, size: 23), const SizedBox(height: 7), Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11))]);
}


/// ---------------------------------------------------------------------------
/// فضای اشتراکی درون‌حافظه‌ای (فقط درون همین اجرای برنامه مشترک است؛
/// همگام‌سازی چنددستگاهی نیاز به پیاده‌سازی سرور دارد.)
/// ---------------------------------------------------------------------------
class AppSharedState {
  AppSharedState._();
  static final AppSharedState instance = AppSharedState._();

  final Map<String, _Building> buildings = {};

  String _key(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  _Building? findByName(String name) {
    final key = _key(name);
    for (final entry in buildings.entries) {
      if (_key(entry.value.name) == key) return entry.value;
    }
    return null;
  }

  _Building buildingByName(String name) {
    final displayName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    return findByName(displayName) ?? (buildings[_key(displayName)] = _Building(displayName));
  }

  bool exists(String name) => findByName(name) != null;
}

class _Member {
  _Member(this.name, this.role, this.ownership, {this.phone = '', this.waterDebt = 0, DateTime? movedInAt})
      : movedInAt = movedInAt ?? DateTime.now();
  final String name;
  final String role;
  final String ownership;
  final String phone;
  final int waterDebt;
  final DateTime movedInAt;
}

class _BuildingPoll {
  _BuildingPoll({required this.title, required this.description, required this.deadline, this.financialAmount = 0})
      : createdAt = DateTime.now();
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime deadline;
  final int financialAmount;
  bool financialDistributionApplied = false;
  final Map<String, String> votesByUnitId = {};
  bool get isActive => DateTime.now().isBefore(deadline);
  int get agreeCount => votesByUnitId.values.where((v) => v == 'موافقم').length;
  int get disagreeCount => votesByUnitId.values.where((v) => v == 'مخالفم').length;
  int get abstainCount => votesByUnitId.values.where((v) => v == 'ممتنع').length;
  int get totalVotes => votesByUnitId.length;
  bool get passed => totalVotes > 0 && agreeCount > totalVotes / 2;
  double percentage(int count) => totalVotes == 0 ? 0 : count * 100 / totalVotes;
}

String _formatPersianDateTime(DateTime value) {
  final raw = '${value.year.toString().padLeft(4, '0')}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return _latinDigitsToPersian(raw);
}

class _ChargeProposal {
  _ChargeProposal({required this.amount, required this.unitId, required this.authorName});
  final int amount;
  final String unitId;
  final String authorName;
}

class _ChargeSettingTopic {
  _ChargeSettingTopic(this.title);
  final String title;
  /// پیشنهادهای ثبت‌شده با اطلاعات نویسنده (برای همه قابل نمایش).
  final List<_ChargeProposal> proposals = [];
  /// رأی هر واحد ناشناس است: unitId -> مبلغ انتخابی. UI فقط تعداد کل رأی‌ها را می‌بیند.
  final Map<String, int> votesByUnitId = {};

  /// Alias for [approvedAmount] so existing UI references like topic.finalizedAmount work.
  int? get finalizedAmount => approvedAmount;

  int get proposalCount => proposals.length;
  bool hasProposalFrom(String unitId) => proposals.any((p) => p.unitId == unitId);

  /// محاسبهٔ خودکار مبلغ تصویب‌شده: میانهٔ همهٔ رأی‌ها؛ اگر رأیی نباشد، میانهٔ مبلغ پیشنهادها.
  int? get approvedAmount {
    final votes = votesByUnitId.values.toList()..sort();
    final source = votes.isNotEmpty
        ? votes
        : proposals.map((p) => p.amount).toList()..sort();
    if (source.isEmpty) return null;
    final n = source.length;
    return n.isOdd ? source[n ~/ 2] : ((source[n ~/ 2 - 1] + source[n ~/ 2]) / 2).round();
  }

  int votesFor(int amount) => votesByUnitId.values.where((v) => v == amount).length;

  bool propose(int amount, String unitId, String authorName) {
    if (proposals.any((p) => p.amount == amount)) return false;
    proposals.add(_ChargeProposal(amount: amount, unitId: unitId, authorName: authorName));
    return true;
  }

  bool vote(String unitId, int amount) {
    if (votesByUnitId.containsKey(unitId)) return false;
    if (!proposals.any((p) => p.amount == amount)) return false;
    votesByUnitId[unitId] = amount;
    return true;
  }
}

class _Building {
  _Building(this.name, {this.createdBy});
  String name;
  /// حساب مدیری که ساختمان را ایجاد کرده؛ مستقل از انتخاب/اشغال هر واحد.
  String? createdBy;
  /// هر طبقه: شماره طبقه -> تعداد واحدها
  final Map<int, int> floors = {};
  /// شماره واحدهای واقعی هر طبقه؛ امکان شماره‌گذاری پیوسته بین طبقات.
  final Map<int, List<int>> floorUnits = {};
  /// واحد اشغال‌شده: "طبقه/واحد" -> عضو
  final Map<String, _Member> occupants = {};
  _ChargeSettingTopic? chargeSettingTopic;
  final List<_BuildingPoll> polls = [];
  final Map<String, int> financialDebtByUnitId = {};
  int get totalUnitCount => floors.values.fold<int>(0, (sum, count) => sum + count);
  int financialDebtFor(String unitId) => financialDebtByUnitId[unitId] ?? 0;
  void settlePolls() {
    for (final poll in polls) {
      if (!poll.isActive && !poll.financialDistributionApplied) {
        poll.financialDistributionApplied = true;
        if (poll.financialAmount > 0 && poll.passed && totalUnitCount > 0) {
          final perUnit = poll.financialAmount ~/ totalUnitCount;
          for (final floorEntry in floorUnits.entries) {
            for (final unit in floorEntry.value) {
              final id = unitId(floorEntry.key, unit);
              financialDebtByUnitId[id] = (financialDebtByUnitId[id] ?? 0) + perUnit;
            }
          }
        }
      }
    }
  }
  int? get monthlyCharge => chargeSettingTopic?.approvedAmount;
  String unitId(int floor, int unit) => '$floor/$unit';

  bool isOccupied(int floor, int unit) => occupants.containsKey('$floor/$unit');
  _Member? occupantOf(int floor, int unit) => occupants['$floor/$unit'];

  String? assign(int floor, int unit, _Member member) {
    final key = '$floor/$unit';
    if (occupants.containsKey(key)) return 'این واحد قبلاً به ${occupants[key]!.name} اختصاص یافته است.';
    occupants[key] = member;
    return null;
  }

  bool addFloor(int floor, int units, {bool continueNumbering = false}) {
    if (floors.containsKey(floor) || units < 1) return false;
    final previousMax = floorUnits.values.expand((values) => values).fold<int>(0, (max, value) => value > max ? value : max);
    final first = continueNumbering ? previousMax + 1 : 1;
    floors[floor] = units;
    floorUnits[floor] = List<int>.generate(units, (index) => first + index);
    return true;
  }

  /// تغییر نام ساختمان؛ کلید درون‌حافظه‌ای هم به‌روزرسانی می‌شود تا جست‌وجو درست کار کند.
  String rename(String newName) {
    final normalized = newName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return name;
    final oldKey = AppSharedState.instance._key(name);
    final newKey = AppSharedState.instance._key(normalized);
    if (AppSharedState.instance.buildings[oldKey] == this && oldKey != newKey && !AppSharedState.instance.buildings.containsKey(newKey)) {
      AppSharedState.instance.buildings.remove(oldKey);
      AppSharedState.instance.buildings[newKey] = this;
    }
    name = normalized;
    return name;
  }

  /// به‌روزرسانی شمارهٔ واحدهای یک طبقه با فهرست جدید.
  bool updateFloorUnits(int floor, List<int> newUnits) {
    if (!floors.containsKey(floor) || newUnits.isEmpty) return false;
    final distinct = newUnits.toSet().toList();
    floorUnits[floor] = distinct;
    floors[floor] = distinct.length;
    return true;
  }

  /// به‌روزرسانی تعداد واحد طبقه؛ واحدها دوباره شماره‌گذاری می‌شوند و
  /// اشغال‌ها تا حد امکان حفظ می‌شوند.
  bool updateUnits(int floor, int newCount) {
    if (!floors.containsKey(floor) || newCount < 1) return false;
    final current = floorUnits[floor] ?? List<int>.generate(floors[floor]!, (i) => i + 1);
    final keep = current.take(newCount).toList();
    var next = keep.isEmpty ? 1 : keep.reduce((a, b) => a > b ? a : b) + 1;
    while (keep.length < newCount) {
      while (floorUnits.values.expand((v) => v).contains(next) || keep.contains(next)) next++;
      keep.add(next);
      next++;
    }
    // حذف اشغال واحدهایی که دیگر وجود ندارند
    occupants.removeWhere((key, _) {
      final parts = key.split('/');
      return parts.length == 2 && int.tryParse(parts[0]) == floor && !keep.contains(int.tryParse(parts[1]));
    });
    floorUnits[floor] = keep;
    floors[floor] = keep.length;
    return true;
  }
}

/// ---------------------------------------------------------------------------
/// داشبورد پس از ورود؛ بسته به نقش، مدیریت ساختمان یا جست‌وجو و انتخاب واحد
/// ---------------------------------------------------------------------------
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.name,
    required this.role,
    required this.buildingName,
    required this.ownership,
    this.showMyBuildings = false,
    this.onSwitch,
  });
  final String name;
  final String role;
  final String buildingName;
  final String ownership;
  final bool showMyBuildings;
  final VoidCallback? onSwitch;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedTab = 0;
  _Building? _joinedBuilding;
  int? _myFloor;
  int? _myUnit;

  bool get _isManager => widget.role == 'مدیر';

  @override
  void initState() {
    super.initState();
    // عضویت ساکن تنها پس از جست‌وجو و انتخاب یک واحد انجام می‌شود.
    // فیلد نام ساختمان ثبت‌نام نباید ساختمان کاذب بسازد یا کاربر را خودکار عضو کند.
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _logout() async {
    pb.authStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: LoginFlow()),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body = switch (selectedTab) {
      0 => _isManager ? _ManagerHome(building: _joinedBuilding, managerName: widget.name, showMyBuildings: widget.showMyBuildings, onBuildingChanged: (building) => setState(() { _joinedBuilding = building; })) : _ResidentHome(
          building: _joinedBuilding,
          name: widget.name,
          myFloor: _myFloor,
          myUnit: _myUnit,
          ownership: widget.ownership,
          onJoined: (building, floor, unit) => setState(() { _joinedBuilding = building; _myFloor = floor; _myUnit = unit; }),
        ),
      _ => _FeatureHub(index: selectedTab, isManager: _isManager),
    };
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سلام، ${widget.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_isManager ? 'نقش شما: مدیر ساختمان' : 'نقش شما: ساکن', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ]),
        actions: [
          if (!_isManager && _joinedBuilding != null)
            IconButton(
              tooltip: 'خروج از ساختمان',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => setState(() { _joinedBuilding = null; _myFloor = null; _myUnit = null; }),
            ),
          if (widget.onSwitch != null)
            IconButton(tooltip: 'ویرایش حساب', icon: const Icon(Icons.tune_rounded), onPressed: widget.onSwitch),
          IconButton(tooltip: 'خروج از حساب کاربری', icon: const Icon(Icons.logout_rounded), onPressed: _logout),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: _ThemeToggle(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'خدمات'),
          NavigationDestination(icon: Icon(Icons.handyman_outlined), label: 'درخواست‌ها'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'اطلاعیه‌ها'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'امور مالی'),
        ],
      ),
    );
  }
}

/// ------------------------------- مدیر -------------------------------
class _ManagerHome extends StatefulWidget {
  const _ManagerHome({required this.building, required this.managerName, required this.showMyBuildings, required this.onBuildingChanged});
  final _Building? building;
  final String managerName;
  final bool showMyBuildings;
  final ValueChanged<_Building> onBuildingChanged;
  @override
  State<_ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<_ManagerHome> {
  late final TextEditingController _nameController = TextEditingController();
  final _createFormKey = GlobalKey<FormState>();
  final _floorController = TextEditingController();
  final _unitsController = TextEditingController();
  bool _continueUnitNumbers = false;

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
    _unitsController.dispose();
    super.dispose();
  }
  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }


  _Building? get _building => widget.building;

  /// یک فرم واحد: ساختمان را ایجاد/به‌روزرسانی می‌کند و طبقات آن را می‌سازد.
  void _createBuildingWithFloors() {
    if (!(_createFormKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final floorCount = int.parse(_latinDigits(_floorController.text.trim()));
    final unitsPerFloor = int.parse(_latinDigits(_unitsController.text.trim()));
    final isNew = !AppSharedState.instance.exists(name);
    final b = AppSharedState.instance.buildingByName(name);
    // مالکیت مدیریتی با ایجاد ساختمان ثبت می‌شود؛ مدیر به هیچ واحدی خودکار
    // منتسب نمی‌شود و در صورت تمایل می‌تواند بعداً در یک واحد مستقر شود.
    if (isNew || b.createdBy == null) b.createdBy = widget.managerName;
    _nameController.text = b.name;
    widget.onBuildingChanged(b);
    if (b.floors.isNotEmpty && !isNew) {
      _toast('ساختمان «${b.name}» از قبل ساخته شده است؛ با کلیک روی نام آن وارد شوید.');
      return;
    }
    for (var i = 0; i < floorCount; i++) {
      final floorNumber = (b.floors.keys.fold<int>(0, (m, f) => f > m ? f : m)) + 1;
      if (!b.addFloor(floorNumber, unitsPerFloor, continueNumbering: _continueUnitNumbers)) break;
    }
    widget.onBuildingChanged(b);
    _toast('ساختمان «${b.name}» با ${floorCount.toPersianDigits()} طبقه ساخته شد. با کلیک روی نام آن وارد نمای ساختمان شوید.');
  }

  Future<void> _renameBuilding() async {
    final b = _building;
    if (b == null) return;
    final controller = TextEditingController(text: b.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ویرایش نام ساختمان'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'نام جدید ساختمان')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            final value = controller.text.trim();
            if (value.length >= 2) Navigator.pop(dialogContext, value);
          }, child: const Text('ذخیره')),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.trim() == b.name) return;
    setState(() => b.rename(newName.trim()));
    _nameController.text = b.name;
    widget.onBuildingChanged(b);
    _toast('نام ساختمان به «${b.name}» تغییر کرد.');
  }

  Future<void> _editFloor(int floor) async {
    final b = _building;
    if (b == null) return;
    final unitsNow = b.floors[floor]!;
    final controller = TextEditingController(text: '$unitsNow');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ویرایش طبقه ${floor.toPersianDigits()}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'تعداد واحد در این طبقه'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            final n = int.tryParse(_latinDigits(controller.text.trim()));
            if (n != null && n >= 1 && n <= 50) Navigator.pop(dialogContext, n);
          }, child: const Text('ذخیره')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result == unitsNow) return;
    setState(() => b.updateUnits(floor, result));
    widget.onBuildingChanged(b);
    _toast('طبقه ${floor.toPersianDigits()} به ${result.toPersianDigits()} واحد به‌روزرسانی شد.');
  }

  /// نمای جزئیات ساختمان؛ با کلیک روی نام ساختمان باز می‌شود.
  Future<void> _openBuildingDetail(_Building b) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _BuildingDetailPage(building: b, managerName: widget.managerName)));
    if (mounted) setState(() {});
  }

  InputDecoration _deco(BuildContext context, String hint, IconData icon) => InputDecoration(
    hintText: hint, prefixIcon: Icon(icon),
    filled: true, fillColor: Theme.of(context).colorScheme.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.8)),
  );

  Widget _myBuildingsList(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final buildings = AppSharedState.instance.buildings.values
        .where((b) => b.createdBy == widget.managerName ||
            b.occupants.values.any((m) => m.name == widget.managerName))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('ساختمان تحت مدیریت من', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        if (buildings.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('ساختمانی تحت مدیریت شما ثبت نشده است.', textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant)),
            ),
          )
        else
          ...buildings.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: InkWell(
                onTap: () => _openBuildingDetail(b),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(width: 46, height: 46,
                      decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.apartment_rounded, color: colors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    Icon(Icons.chevron_left_rounded, color: colors.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showMyBuildings) return _myBuildingsList(context);
    final b = _building;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _createFormKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.apartment_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('ایجاد ساختمان و طبقات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 6),
                Text('نام ساختمان، طبقات و تعداد واحدها را در همین یک فرم وارد کنید.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: _deco(context, 'نام ساختمان (مثلاً برج آسمان)', Icons.location_city_outlined),
                  validator: (v) => (v?.trim().length ?? 0) >= 2 ? null : 'نام ساختمان حداقل ۲ حرف باشد.',
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _floorController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: _deco(context, 'تعداد طبقات', Icons.format_list_numbered_rounded),
                      validator: (v) {
                        final n = int.tryParse(_latinDigits((v ?? '').trim()));
                        return (n != null && n >= 1 && n <= 200) ? null : 'بین ۱ تا ۲۰۰';
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitsController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: _deco(context, 'واحد در هر طبقه', Icons.door_sliding_outlined),
                      validator: (v) {
                        final n = int.tryParse(_latinDigits((v ?? '').trim()));
                        return (n != null && n >= 1 && n <= 50) ? null : 'بین ۱ تا ۵۰';
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text('شماره‌گذاری واحدها', style: TextStyle(fontWeight: FontWeight.w600)),
                RadioListTile<bool>(contentPadding: EdgeInsets.zero, dense: true, value: false, groupValue: _continueUnitNumbers,
                  onChanged: (value) => setState(() => _continueUnitNumbers = value ?? false),
                  title: const Text('شروع از ۱ در هر طبقه')),
                RadioListTile<bool>(contentPadding: EdgeInsets.zero, dense: true, value: true, groupValue: _continueUnitNumbers,
                  onChanged: (value) => setState(() => _continueUnitNumbers = value ?? true),
                  title: const Text('ادامه از شمارهٔ آخر طبقهٔ قبل')),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _createBuildingWithFloors,
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('ایجاد ساختمان'),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        if (b == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Icon(Icons.foundation_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                const Text('هنوز ساختمانی ایجاد نشده است', textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('ابتدا نام ساختمان را وارد و ایجاد کنید.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ]),
            ),
          )
        else ...[
          InkWell(
            onTap: () => _openBuildingDetail(b),
            borderRadius: BorderRadius.circular(22),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.apartment_rounded, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${b.floors.length.toPersianDigits()} طبقه — ${b.floors.values.fold<int>(0, (sum, n) => sum + n).toPersianDigits()} واحد', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BuildingLayout(building: b, highlightMemberName: widget.managerName),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
          child: const Text('توجه: این نسخه یک نمونهٔ محلی است؛ داده‌ها فقط در حافظهٔ همین اجرای برنامه نگه داشته می‌شوند و نمایش اعضای سایر دستگاه‌ها نیازمند اتصال به سرور است.', style: TextStyle(fontSize: 12, height: 1.7)),
        ),
      ],
    );
  }
}

/// ------------------------------- ساکن -------------------------------
class _ResidentHome extends StatefulWidget {
  const _ResidentHome({
    required this.building,
    required this.name,
    required this.myFloor,
    required this.myUnit,
    required this.ownership,
    required this.onJoined,
  });
  final _Building? building;
  final String name;
  final int? myFloor;
  final int? myUnit;
  final String ownership;
  final void Function(_Building building, int floor, int unit) onJoined;
  @override
  State<_ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<_ResidentHome> {
  final _searchKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  String? _foundBuildingName;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }


  void _search() {
    final name = _searchController.text.trim();
    if (name.isEmpty) return;
    final building = AppSharedState.instance.findByName(name);
    if (building == null) {
      setState(() => _foundBuildingName = null);
      _toast('ساختمانی با نام «$name» در این نسخهٔ محلی یافت نشد.', error: true);
      return;
    }
    setState(() => _foundBuildingName = building.name);
  }

  void _joinUnit(_Building b, int floor, int unit) {
    if (b.isOccupied(floor, unit)) {
      _toast('واحد ${unit.toPersianDigits()} طبقه ${floor.toPersianDigits()} قبلاً به ${b.occupantOf(floor, unit)!.name} اختصاص یافته است.', error: true);
      return;
    }
    final err = b.assign(floor, unit, _Member(widget.name, 'ساکن', widget.ownership));
    if (err != null) {
      _toast(err, error: true);
      return;
    }
    widget.onJoined(b, floor, unit);
    _toast('خوش آمدید! شما در واحد ${unit.toPersianDigits()} طبقه ${floor.toPersianDigits()} «${b.name}» قرار گرفتید.');
  }

  Future<void> _showResidentUnit(_Building building, int floor, int unit) async {
    final member = building.occupantOf(floor, unit);
    if (member == null) {
      final join = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('واحد ${unit.toPersianDigits()} — طبقه ${floor.toPersianDigits()}'),
        content: const Text('وضعیت واحد: خالی\nبرای سکونت در این واحد ثبت‌نام می‌کنید؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بستن')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('انتخاب این واحد'))],
      ));
      if (join == true && mounted) _joinUnit(building, floor, unit);
      return;
    }
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('اطلاعات واحد ${unit.toPersianDigits()}'),
      content: _MemberInfoContent(building: building, member: member, unitId: building.unitId(floor, unit)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.building != null && widget.myFloor != null) {
      final b = widget.building!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.home_work_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('واحد شما در «${b.name}»', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ]),
              const SizedBox(height: 10),
              Text('طبقه ${widget.myFloor!.toPersianDigits()} — واحد ${widget.myUnit!.toPersianDigits()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Row(children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(widget.name.isNotEmpty ? widget.name.characters.first : '؟', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.name.isNotEmpty ? widget.name : 'بدون نام', style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 6),
              Text(widget.ownership, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _BuildingLayout(building: b, highlightMemberName: widget.name),
        const SizedBox(height: 12),
        _ResidentChargeCard(building: b, unitId: b.unitId(widget.myFloor!, widget.myUnit!), onChanged: () { if (mounted) setState(() {}); }),
        const SizedBox(height: 12),
        _ResidentPollsCard(building: b, unitId: b.unitId(widget.myFloor!, widget.myUnit!), onChanged: () { if (mounted) setState(() {}); }),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
          child: const Text('توجه: این نسخه یک نمونهٔ محلی است؛ نمایش اعضای سایر دستگاه‌ها فقط در حافظهٔ همین اجرای برنامه است و برای همگام‌سازی واقعی نیازمند سرور می‌باشد.', style: TextStyle(fontSize: 12, height: 1.7)),
        ),
      ]);
    }

    // جست‌وجوی ساختمان و انتخاب واحد
    final found = _foundBuildingName == null ? null : AppSharedState.instance.findByName(_foundBuildingName!);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _searchKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('جست‌وجوی ساختمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 6),
              Text('نام ساختمانی را که مدیر ایجاد کرده است وارد کنید.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'مثلاً برج آسمان',
                  prefixIcon: const Icon(Icons.travel_explore_rounded),
                  suffixIcon: IconButton(icon: const Icon(Icons.search_rounded), onPressed: _search),
                  filled: true, fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.8)),
                ),
                onFieldSubmitted: (_) => _search(),
              ),
              if (AppSharedState.instance.buildings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('ساختمان‌های محلی موجود:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in AppSharedState.instance.buildings.keys)
                      ActionChip(label: Text(name), onPressed: () {
                        _searchController.text = name;
                        setState(() => _foundBuildingName = name);
                      }),
                  ],
                ),
              ],
            ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (found != null) ...[
        Text('واحدهای ساختمان «${found.name}» را ببینید و روی واحد خالی بزنید:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        _BuildingLayout(
          building: found,
          onUnitTap: (floor, unit) => _showResidentUnit(found, floor, unit),
          highlightMemberName: widget.name,
        ),
        const SizedBox(height: 12),
        _ResidentPollsCard(building: found, unitId: null, onChanged: () { if (mounted) setState(() {}); }),
      ],
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
        child: const Text('توجه: این نسخه یک نمونهٔ محلی است؛ اطلاعات فقط در حافظهٔ همین اجرای برنامه ذخیره می‌شود و برای همگام‌سازی بین کاربران واقعی نیازمند اتصال به سرور است.', style: TextStyle(fontSize: 12, height: 1.7)),
      ),
    ]);
  }
}

/// ------------------------- نمای طبقات و واحدها -------------------------

class _ChargeTopicPage extends StatefulWidget {
  const _ChargeTopicPage({required this.building, required this.isManager, this.unitId, this.unitOwnerName});
  final _Building building;
  final bool isManager;
  final String? unitId;
  final String? unitOwnerName;
  @override State<_ChargeTopicPage> createState() => _ChargeTopicPageState();
}

class _ChargeTopicPageState extends State<_ChargeTopicPage> {
  final _amountController = TextEditingController();
  String? _error;
  _ChargeSettingTopic get topic => widget.building.chargeSettingTopic!;
  @override void dispose() { _amountController.dispose(); super.dispose(); }

  void _propose() {
    final amount = parseTomanAmount(_amountController.text);
    final unitId = widget.unitId ?? '';
    if (unitId.isEmpty) return;
    if (amount == null || amount < 100000 || amount > 10000000 || amount % 100000 != 0) {
      setState(() => _error = 'مبلغ باید بین ۱۰۰ هزار تا ۱۰ میلیون تومان و مضربی از ۱۰۰ هزار باشد.'); return;
    }
    if (!topic.propose(amount, unitId, widget.unitOwnerName ?? 'واحد $unitId')) {
      setState(() => _error = 'این مبلغ قبلاً پیشنهاد شده است.'); return;
    }
    setState(() { _amountController.clear(); _error = null; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پیشنهاد شما برای همه نمایش داده شد.')));
  }

  @override Widget build(BuildContext context) {
    final approved = topic.approvedAmount;
    final myVote = widget.unitId == null ? null : topic.votesByUnitId[widget.unitId!];
    return Scaffold(
      appBar: AppBar(title: Text(topic.title), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(Icons.how_to_vote_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Expanded(child: Text('موضوع تعیین شارژ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)))]),
          const SizedBox(height: 8),
          const Text('پیشنهادهای همه به‌صورت عمومی نمایش داده می‌شود، اما رأی هر واحد محرمانه می‌ماند. مبلغ تصویب‌شده به‌صورت خودکار و منصفانه با میانهٔ رأی‌ها محاسبه می‌شود.', style: TextStyle(color: Color(0xFF6B7280), height: 1.7)),
          if (approved != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('شارژ ماهانهٔ تصویب‌شده (میانه): ${formatTomanAmount(approved)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF12A889))))
          else const Padding(padding: EdgeInsets.only(top: 12), child: Text('هنوز رأی یا پیشنهادی ثبت نشده است.')),
        ]))),
        const SizedBox(height: 12),
        if (widget.unitId != null && !topic.votesByUnitId.containsKey(widget.unitId!))
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('پیشنهاد مبلغ جدید', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
            TextField(controller: _amountController, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'مبلغ به تومان', hintText: 'مثلاً ۲٬۵۰۰٬۰۰۰', suffixText: 'تومان', border: OutlineInputBorder())),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
            const SizedBox(height: 10), FilledButton.icon(onPressed: _propose, icon: const Icon(Icons.add), label: const Text('ثبت پیشنهاد')),
          ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('پیشنهادهای ثبت‌شده (عمومی)', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4),
          Text('${topic.proposalCount.toPersianDigits()} پیشنهاد و ${topic.votesByUnitId.length.toPersianDigits()} رأی ثبت‌شده', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (topic.proposals.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('هنوز مبلغی پیشنهاد نشده است.')),
          for (final p in topic.proposals) _proposalRow(p),
          if (widget.unitId != null && myVote == null && topic.proposals.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('برای ثبت رأی، یکی از پیشنهادهای بالا را انتخاب کنید (رأی شما ناشناس است).', style: TextStyle(fontSize: 12)),
          ],
          if (myVote != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('رأی این واحد ثبت شده است؛ رأی‌ها ناشناس نمایش داده می‌شوند.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ]))),
      ]),
    );
  }

  Widget _proposalRow(_ChargeProposal p) {
    final votes = topic.votesFor(p.amount);
    final isApproved = topic.approvedAmount == p.amount;
    final myVote = widget.unitId == null ? null : topic.votesByUnitId[widget.unitId!];
    final canVote = !widget.isManager && widget.unitId != null && myVote == null;
    return RadioListTile<int>(
      contentPadding: EdgeInsets.zero,
      value: p.amount,
      groupValue: myVote,
      onChanged: canVote ? (v) {
        final ok = topic.vote(widget.unitId!, p.amount);
        setState(() {});
        if (ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رأی ناشناس شما ثبت شد.')));
      } : null,
      title: Text('${formatTomanAmount(p.amount)} — ${p.authorName}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${votes.toPersianDigits()} رأی ناشناس${isApproved ? ' • مبلغ تصویب‌شده (میانه)' : ''}'),
      secondary: Icon(isApproved ? Icons.emoji_events_outlined : Icons.payments_outlined, color: isApproved ? Theme.of(context).colorScheme.primary : null),
    );
  }
}

class _ResidentChargeCard extends StatefulWidget {
  const _ResidentChargeCard({required this.building, required this.unitId, required this.onChanged});
  final _Building building; final String unitId; final VoidCallback onChanged;
  @override State<_ResidentChargeCard> createState() => _ResidentChargeCardState();
}
class _ResidentChargeCardState extends State<_ResidentChargeCard> {
  Future<void> _open() async { await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ChargeTopicPage(building: widget.building, isManager: false, unitId: widget.unitId, unitOwnerName: widget.building.occupants[widget.unitId]?.name))); if (mounted) { setState(() {}); widget.onChanged(); } }
  @override Widget build(BuildContext context) {
    final topic = widget.building.chargeSettingTopic;
    if (topic == null) return const SizedBox.shrink();
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 8), Text(topic.finalizedAmount == null ? 'موضوع فعال است؛ پیشنهاد دهید و رأی بدهید.' : 'شارژ ماهانهٔ واحد شما: ${formatTomanAmount(topic.finalizedAmount!)}'),
      const SizedBox(height: 10), OutlinedButton.icon(onPressed: _open, icon: const Icon(Icons.open_in_new), label: const Text('مشاهده و مشارکت')),
    ])));
  }
}

class _MemberInfoContent extends StatelessWidget {
  const _MemberInfoContent({required this.building, required this.member, this.unitId});
  final _Building building;
  final _Member member;
  final String? unitId;
  @override Widget build(BuildContext context) {
    final charge = building.monthlyCharge;
    Widget row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 112, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(value))]));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row('نام', member.name), row('شماره تماس', member.phone.isEmpty ? 'ثبت نشده' : member.phone),
      row('بدهی شارژ', charge == null ? 'شارژ مصوب نشده' : formatTomanAmount(charge)),
      if (unitId != null && building.financialDebtFor(unitId!) > 0) row('سهم بدهی مالی', formatTomanAmount(building.financialDebtFor(unitId!))),
      row('بدهی آب', formatTomanAmount(member.waterDebt)), row('نوع مالکیت', member.ownership),
      row('تاریخ و ساعت سکونت', _formatPersianDateTime(member.movedInAt)),
    ]);
  }
}

class _ResidentPollsCard extends StatefulWidget {
  const _ResidentPollsCard({required this.building, required this.unitId, required this.onChanged});
  final _Building building; final String? unitId; final VoidCallback onChanged;
  @override State<_ResidentPollsCard> createState() => _ResidentPollsCardState();
}
class _ResidentPollsCardState extends State<_ResidentPollsCard> {
  Future<void> _participate(_BuildingPoll poll) async {
    final unitId = widget.unitId;
    if (unitId == null) return;
    widget.building.settlePolls();
    final previous = poll.votesByUnitId[unitId];
    final choice = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(poll.title),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(poll.description.isEmpty ? 'توضیحی ثبت نشده است.' : poll.description), const SizedBox(height: 12),
        Text('ایجاد: ${_formatPersianDateTime(poll.createdAt)}'),
        Text('مهلت تا ${_formatPersianDateTime(poll.deadline)}'),
        if (poll.financialAmount > 0) Text('بار مالی: ${formatTomanAmount(poll.financialAmount)}'),
        if (previous != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('رأی شما ثبت شده است؛ آرای افراد به‌صورت ناشناس نگهداری می‌شوند.')),
        if (!poll.isActive) ...[
          const Divider(),
          Text('نتیجه: ${poll.passed ? 'تصویب شد' : 'تصویب نشد'}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('موافق: ${poll.agreeCount.toPersianDigits()} (${poll.percentage(poll.agreeCount).toStringAsFixed(1).toPersianDigits()}٪)'),
          Text('مخالف: ${poll.disagreeCount.toPersianDigits()} (${poll.percentage(poll.disagreeCount).toStringAsFixed(1).toPersianDigits()}٪)'),
          Text('ممتنع: ${poll.abstainCount.toPersianDigits()} (${poll.percentage(poll.abstainCount).toStringAsFixed(1).toPersianDigits()}٪)'),
          if (poll.passed && poll.financialAmount > 0) Text('سهم هر واحد: ${formatTomanAmount(widget.building.totalUnitCount == 0 ? 0 : poll.financialAmount ~/ widget.building.totalUnitCount)}'),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
        if (previous == null && poll.isActive) ...[
          OutlinedButton(onPressed: () => Navigator.pop(ctx, 'موافقم'), child: const Text('موافقم')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, 'مخالفم'), child: const Text('مخالفم')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'ممتنع'), child: const Text('ممتنع')),
        ],
      ],
    ));
    if (choice != null && poll.isActive && previous == null) {
      setState(() => poll.votesByUnitId[unitId] = choice);
      widget.building.settlePolls();
      widget.onChanged();
    }
  }
  @override Widget build(BuildContext context) {
    widget.building.settlePolls();
    final active = widget.building.polls.where((p) => p.isActive).toList();
    final history = widget.building.polls.where((p) => !p.isActive).toList();
    if (active.isEmpty && history.isEmpty) return const SizedBox.shrink();
    Widget pollTile(_BuildingPoll poll) {
      final mine = widget.unitId != null && poll.votesByUnitId.containsKey(widget.unitId);
      final resultText = poll.isActive
          ? 'مهلت: ${_formatPersianDateTime(poll.deadline)}${mine ? ' • رأی شما ثبت شد' : ''}'
          : 'نتیجه: ${poll.passed ? 'تصویب شد' : 'تصویب نشد'} • ${poll.agreeCount.toPersianDigits()} موافق (${poll.percentage(poll.agreeCount).toStringAsFixed(1).toPersianDigits()}٪) • ${poll.disagreeCount.toPersianDigits()} مخالف (${poll.percentage(poll.disagreeCount).toStringAsFixed(1).toPersianDigits()}٪)';
      return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(poll.isActive ? Icons.poll_outlined : Icons.task_alt_outlined), title: Text(poll.title), subtitle: Text(resultText), trailing: const Icon(Icons.chevron_left), onTap: () => _participate(poll));
    }
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (active.isNotEmpty) ...[
        Row(children: [Icon(Icons.how_to_vote_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Text('نظرسنجی‌های فعال', style: TextStyle(fontWeight: FontWeight.bold))]),
        for (final poll in active) pollTile(poll),
      ],
      if (history.isNotEmpty) ...[
        const Divider(),
        const Text('سوابق نظرسنجی‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final poll in history) ...[
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('ایجاد: ${_formatPersianDateTime(poll.createdAt)}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          pollTile(poll),
        ],
      ],
      if (widget.unitId == null && active.isNotEmpty) Text('برای رأی‌دادن، ابتدا واحد خود را انتخاب کنید.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const Text('آرا ناشناس هستند؛ نتایج فقط به‌صورت تعداد و درصد نمایش داده می‌شوند.', style: TextStyle(fontSize: 11)),
    ])));
  }
}

class _BuildingLayout extends StatelessWidget {
  const _BuildingLayout({required this.building, this.onUnitTap, this.highlightMemberName, this.onFloorActions});
  final _Building building;
  final void Function(int floor, int unit)? onUnitTap;
  final String? highlightMemberName;
  final void Function(int floor)? onFloorActions;

  @override
  Widget build(BuildContext context) {
    if (building.floors.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Icon(Icons.calendar_view_day_outlined, size: 38, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            const Text('هنوز طبقه‌ای اضافه نشده است', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(onUnitTap == null ? 'از بخش «افزودن طبقه» استفاده کنید.' : 'مدیر این ساختمان هنوز طبقه‌ای نساخته است.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          ]),
        ),
      );
    }
    final sortedFloors = building.floors.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final floor in sortedFloors) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.stairs_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('طبقه ${floor.toPersianDigits()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${building.floors[floor]!.toPersianDigits()} واحد', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (onFloorActions != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'ویرایش این طبقه',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.edit_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      onPressed: () => onFloorActions!(floor),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final unit in (building.floorUnits[floor] ?? List<int>.generate(building.floors[floor]!, (i) => i + 1)))
                      _UnitTile(
                        building: building,
                        floor: floor,
                        unit: unit,
                        onTap: onUnitTap == null ? null : () => onUnitTap!(floor, unit),
                        highlightMemberName: highlightMemberName,
                      ),
                  ],
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.building, required this.floor, required this.unit, required this.onTap, required this.highlightMemberName});
  final _Building building;
  final int floor;
  final int unit;
  final VoidCallback? onTap;
  final String? highlightMemberName;

  @override
  Widget build(BuildContext context) {
    final member = building.occupantOf(floor, unit);
    final isMine = member != null && highlightMemberName != null && member.name == highlightMemberName;
    final isManagerUnit = member != null && member.role == 'مدیر';
    final colors = Theme.of(context).colorScheme;
    final occupied = member != null;
    final tileColor = isManagerUnit
        ? const Color(0xFFFFC107).withOpacity(.28)
        : (occupied ? colors.primaryContainer.withOpacity(.45) : colors.surfaceVariant.withOpacity(.6));
    final tileBorder = isManagerUnit
        ? const Color(0xFFFFB300).withOpacity(.85)
        : (occupied ? colors.primary.withOpacity(.4) : colors.outlineVariant);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tileBorder, width: isManagerUnit ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(occupied ? Icons.meeting_room_rounded : Icons.meeting_room_outlined, size: 18, color: occupied ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text('واحد ${unit.toPersianDigits()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
          const SizedBox(height: 6),
          const SizedBox(height: 5),
          if (occupied)
            Row(children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: isManagerUnit ? const Color(0xFFFFB300) : colors.primary,
                child: Text(
                  member!.name.characters.isNotEmpty ? member.name.characters.first : '؟',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(member.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isManagerUnit ? const Color(0xFF8A5A00) : (isMine ? colors.primary : colors.onSurface), fontWeight: isManagerUnit || isMine ? FontWeight.bold : FontWeight.w500))),
            ]),
          if (isManagerUnit) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFF5C3D00)),
                SizedBox(width: 3),
                Text('واحد مدیر', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5C3D00))),
              ]),
            ),
          ]
          else
            Text('خالی — برای انتخاب بزنید', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          if (building.financialDebtFor(building.unitId(floor, unit)) > 0) ...[
            const SizedBox(height: 5),
            Text('سهم بدهی مالی: ${formatTomanAmount(building.financialDebtFor(building.unitId(floor, unit)))}', style: TextStyle(fontSize: 10, color: colors.error, fontWeight: FontWeight.bold)),
          ],
          if (building.monthlyCharge != null) ...[
            const SizedBox(height: 7),
            Text('شارژ مصوب: ${formatTomanAmount(building.monthlyCharge!)}', style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold)),
          ],
        ]),
      ),
    );
  }
}

/// ------------------- نمای جزئیات ساختمان -------------------
/// با کلیک روی نام ساختمان باز می‌شود؛ مدیر می‌تواند نام، طبقات و واحدها
/// را از همین صفحه ویرایش کند.
class _BuildingDetailPage extends StatefulWidget {
  const _BuildingDetailPage({required this.building, required this.managerName});
  final _Building building;
  final String managerName;
  @override
  State<_BuildingDetailPage> createState() => _BuildingDetailPageState();
}

class _BuildingDetailPageState extends State<_BuildingDetailPage> {
  _Building get b => widget.building;

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  String _unitKey(int floor, int unit) => b.unitId(floor, unit);

  Future<void> _onManagerUnitTap(int floor, int unit) async {
    final key = _unitKey(floor, unit);
    final member = b.occupants[key];
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('واحد ${unit.toPersianDigits()} — طبقه ${floor.toPersianDigits()}'),
        content: member == null
            ? const Text('این واحد خالی است. آیا می‌خواهید در این واحد مستقر شوید یا ساکن ثبت کنید؟')
            : SingleChildScrollView(child: _MemberInfoContent(building: b, member: member, unitId: key)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'no'), child: const Text('بستن')),
          if (member == null) TextButton(onPressed: () => Navigator.pop(dialogContext, 'register'), child: const Text('ثبت ساکن')),
          if (member != null) ...[
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'delete'), child: const Text('حذف عضو')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'move'), child: const Text('تغییر واحد')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'edit'), child: const Text('ویرایش عضو')),
          ],
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'self'), child: const Text('استقرار من')),
        ],
      ),
    );
    if (!mounted || action == null || action == 'no') return;
    if (action == 'self') {
      if (member != null && !(member.name == widget.managerName && member.role == 'مدیر')) {
        _toast('این واحد در اختیار ${member.name} است؛ برای تغییر جایگاه او از «تغییر واحد» یا «ویرایش عضو» استفاده کنید.', error: true);
        return;
      }
      setState(() {
        b.occupants.removeWhere((_, occupant) => occupant.name == widget.managerName && occupant.role == 'مدیر');
        b.occupants[key] = _Member(widget.managerName, 'مدیر', 'مدیر');
      });
      _toast('شما در واحد ${unit.toPersianDigits()} طبقه ${floor.toPersianDigits()} مستقر شدید.');
    } else if (action == 'register') {
      await _editOrAddMember(key, null);
    } else if (member != null && action == 'edit') {
      await _editOrAddMember(key, member);
    } else if (member != null && action == 'move') {
      await _moveMember(key, member);
    } else if (member != null && action == 'delete') {
      final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('حذف عضو'), content: Text('عضو «${member.name}» از این واحد حذف شود؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف عضو'))],
      ));
      if (confirmed == true && mounted) { setState(() => b.occupants.remove(key)); _toast('عضو از واحد تخلیه شد.'); }
    }
  }

  Future<void> _editOrAddMember(String key, _Member? existing) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final waterDebtController = TextEditingController(text: '${existing?.waterDebt ?? 0}');
    var phoneError;
    var selectedRole = existing?.role == 'مدیر' ? 'مدیر' : 'ساکن';
    var selectedOwnership = existing?.ownership == 'مستأجر' ? 'مستأجر' : 'مالک';
    final result = await showDialog<_Member>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'ثبت ساکن' : 'ویرایش عضو'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'نام عضو')),
          TextField(controller: phoneController, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: 'شماره تماس', errorText: phoneError), onChanged: (_) { if (phoneError != null) setDialogState(() => phoneError = null); }),
          TextField(controller: waterDebtController, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'بدهی آب (تومان)')),
          DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: const InputDecoration(labelText: 'نقش'),
            items: const [
              DropdownMenuItem(value: 'ساکن', child: Text('ساکن')),
              DropdownMenuItem(value: 'مدیر', child: Text('مدیر')),
            ],
            onChanged: (value) { if (value != null) setDialogState(() => selectedRole = value); },
          ),
          DropdownButtonFormField<String>(
            value: selectedOwnership,
            decoration: const InputDecoration(labelText: 'نوع سکونت / مالکیت'),
            items: const [
              DropdownMenuItem(value: 'مالک', child: Text('مالک')),
              DropdownMenuItem(value: 'مستأجر', child: Text('مستأجر')),
            ],
            onChanged: (value) { if (value != null) setDialogState(() => selectedOwnership = value); },
          ),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')), FilledButton(onPressed: () {
          final name = nameController.text.trim();
          final phone = _latinDigits(phoneController.text.trim());
          if (!RegExp(r'^09\d{9}$').hasMatch(phone)) { setDialogState(() => phoneError = 'شماره همراه باید ۱۱ رقم و با 09 شروع شود.'); return; }
          final waterDebt = int.tryParse(_latinDigits(waterDebtController.text.trim())) ?? -1;
          if (name.isNotEmpty && waterDebt >= 0) Navigator.pop(dialogContext, _Member(name, selectedRole, selectedOwnership, phone: phone, waterDebt: waterDebt, movedInAt: existing?.movedInAt ?? DateTime.now()));
        }, child: const Text('ذخیره'))],
      ),
    ));
    nameController.dispose();
    phoneController.dispose();
    waterDebtController.dispose();
    if (result == null || !mounted) return;
    setState(() => b.occupants[key] = result);
    _toast(existing == null ? 'ساکن در واحد ثبت شد.' : 'اطلاعات عضو به‌روزرسانی شد.');
  }

  Future<void> _moveMember(String fromKey, _Member member) async {
    final available = <String>[];
    for (final entry in b.floorUnits.entries) {
      for (final unit in entry.value) {
        final key = b.unitId(entry.key, unit);
        if (key != fromKey && !b.occupants.containsKey(key)) available.add(key);
      }
    }
    if (available.isEmpty) { _toast('واحد خالی دیگری برای انتقال وجود ندارد.', error: true); return; }
    final destination = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('انتقال ${member.name}'),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [
        for (final key in available) ListTile(leading: const Icon(Icons.meeting_room_outlined), title: Text('طبقه ${int.parse(key.split('/')[0]).toPersianDigits()} — واحد ${int.parse(key.split('/')[1]).toPersianDigits()}'), onTap: () => Navigator.pop(dialogContext, key)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف'))],
    ));
    if (destination == null || !mounted) return;
    setState(() { b.occupants.remove(fromKey); b.occupants[destination] = member; });
    _toast('عضو به واحد ${int.parse(destination.split('/')[1]).toPersianDigits()} طبقه ${int.parse(destination.split('/')[0]).toPersianDigits()} منتقل شد.');
  }

  Future<void> _createPoll() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final daysController = TextEditingController(text: '3');
    final financialController = TextEditingController();
    String? error;
    final result = await showDialog<_BuildingPoll>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('ایجاد نظرسنجی'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'موضوع')),
          TextField(controller: descriptionController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'توضیح')),
          TextField(controller: daysController, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'مهلت شرکت در نظرسنجی (روز)')),
          TextField(controller: financialController, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'بار مالی به تومان (اختیاری)', hintText: 'مثلاً ۳۰٬۰۰۰٬۰۰۰')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')), FilledButton(onPressed: () {
          final days = int.tryParse(_latinDigits(daysController.text.trim()));
          if (titleController.text.trim().isEmpty) { setDialogState(() => error = 'موضوع را وارد کنید.'); return; }
          if (days == null || days < 3) { setDialogState(() => error = 'مهلت نظرسنجی باید حداقل ۳ روز باشد.'); return; }
          Navigator.pop(dialogContext, _BuildingPoll(title: titleController.text.trim(), description: descriptionController.text.trim(), deadline: DateTime.now().add(Duration(days: days))));
        }, child: const Text('ایجاد نظرسنجی'))],
      ),
    ));
    titleController.dispose(); descriptionController.dispose(); daysController.dispose(); financialController.dispose();
    if (result != null && mounted) { setState(() => b.polls.insert(0, result)); _toast('نظرسنجی ایجاد شد و برای ساکنان نمایش داده می‌شود.'); }
  }

  Future<void> _createChargeTopic() async {
    final controller = TextEditingController(text: 'تعیین شارژ');
    final title = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('ایجاد موضوع شارژ'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'عنوان موضوع')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')), FilledButton(onPressed: () { final value = controller.text.trim(); if (value.isNotEmpty) Navigator.pop(dialogContext, value); }, child: const Text('ایجاد و بازکردن'))],
    ));
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    setState(() => b.chargeSettingTopic = _ChargeSettingTopic(title.trim()));
    await _openChargeTopic(b, isManager: true);
  }

  Future<void> _openChargeTopic(_Building building, {required bool isManager}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ChargeTopicPage(building: building, isManager: isManager)));
    if (mounted) setState(() {});
  }

  bool get _isManagerOfBuilding => b.createdBy == widget.managerName || b.occupants.values.any((m) => m.name == widget.managerName && m.role == 'مدیر');

  Future<void> _rename() async {
    final controller = TextEditingController(text: b.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ویرایش نام ساختمان'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'نام جدید ساختمان')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            final value = controller.text.trim();
            if (value.length >= 2) Navigator.pop(dialogContext, value);
          }, child: const Text('ذخیره')),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.trim() == b.name) return;
    setState(() => b.rename(newName.trim()));
    _toast('نام ساختمان به «${b.name}» تغییر کرد.');
  }

  Future<void> _editFloorUnits(int floor) async {
    final current = b.floorUnits[floor] ?? List<int>.generate(b.floors[floor]!, (i) => i + 1);
    final controller = TextEditingController(text: current.join('، '));
    final result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ویرایش واحدهای طبقه ${floor.toPersianDigits()}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('شمارهٔ واحدها را با ویرگول جدا کنید (مثلاً: ۱، ۲، ۳ یا ۵، ۶، ۷).', style: TextStyle(fontSize: 12, height: 1.6)),
          const SizedBox(height: 10),
          TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'شمارهٔ واحدها')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            final parts = _latinDigits(controller.text).split(RegExp(r'[,،]'));
            final units = <int>[];
            for (final part in parts) {
              final n = int.tryParse(part.trim());
              if (n == null || n < 1 || n > 999) return;
              units.add(n);
            }
            Navigator.pop(dialogContext, units);
          }, child: const Text('ذخیره')),
        ],
      ),
    );
    if (result == null) return;
    setState(() => b.updateFloorUnits(floor, result));
    _toast('واحدهای طبقه ${floor.toPersianDigits()} به‌روزرسانی شد.');
  }

  Future<void> _editFloorCount(int floor) async {
    final unitsNow = b.floors[floor]!;
    final controller = TextEditingController(text: '$unitsNow');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ویرایش تعداد واحد طبقه ${floor.toPersianDigits()}'),
        content: TextField(controller: controller, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد واحد در این طبقه')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            final n = int.tryParse(_latinDigits(controller.text.trim()));
            if (n != null && n >= 1 && n <= 50) Navigator.pop(dialogContext, n);
          }, child: const Text('ذخیره')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result == unitsNow) return;
    setState(() => b.updateUnits(floor, result));
    _toast('طبقه ${floor.toPersianDigits()} به ${result.toPersianDigits()} واحد به‌روزرسانی شد.');
  }

  Future<void> _addFloor() async {
    final floorController = TextEditingController();
    final unitsController = TextEditingController();
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن طبقه'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: floorController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'شمارهٔ طبقه')),
          const SizedBox(height: 10),
          TextField(controller: unitsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد واحد')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            final f = int.tryParse(_latinDigits(floorController.text.trim()));
            final u = int.tryParse(_latinDigits(unitsController.text.trim()));
            if (f != null && u != null && f >= 1 && f <= 200 && u >= 1 && u <= 50) Navigator.pop(dialogContext, (f, u));
          }, child: const Text('افزودن')),
        ],
      ),
    );
    if (result == null) return;
    setState(() => b.addFloor(result.$1, result.$2));
    _toast('طبقه ${result.$1.toPersianDigits()} با ${result.$2.toPersianDigits()} واحد اضافه شد.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    b.settlePolls();
    final totalUnits = b.floors.values.fold<int>(0, (sum, n) => sum + n);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(onTap: _rename, borderRadius: BorderRadius.circular(10), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(width: 6),
          Icon(Icons.edit_rounded, size: 17, color: colors.onSurfaceVariant),
        ])),
        centerTitle: true,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.apartment_rounded, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('جزئیات «${b.name}»', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            IconButton(tooltip: 'ویرایش نام ساختمان', icon: const Icon(Icons.edit_rounded, size: 20), onPressed: _rename),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _statChip(context, Icons.stairs_outlined, '${b.floors.length.toPersianDigits()} طبقه'),
            const SizedBox(width: 10),
            _statChip(context, Icons.door_sliding_outlined, '${totalUnits.toPersianDigits()} واحد'),
            const SizedBox(width: 10),
            _statChip(context, Icons.people_outline, '${b.occupants.length.toPersianDigits()} عضو'),
          ]),
          if (b.monthlyCharge != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('شارژ ماهانهٔ تصویب‌شده: ${formatTomanAmount(b.monthlyCharge!)}', style: const TextStyle(fontWeight: FontWeight.bold))),
        ]))),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(Icons.payments_outlined, color: colors.primary), const SizedBox(width: 8), const Expanded(child: Text('تعیین شارژ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
          const SizedBox(height: 8),
          Text(b.chargeSettingTopic == null ? 'برای ساختمان «${b.name}» موضوع تعیین شارژ بسازید.' : 'موضوع فعال: ${b.chargeSettingTopic!.title}', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          if (b.monthlyCharge != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('شارژ ماهانهٔ هر واحد: ${formatTomanAmount(b.monthlyCharge!)}', style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _createChargeTopic, icon: const Icon(Icons.add_circle_outline), label: Text(b.chargeSettingTopic == null ? 'ایجاد موضوع شارژ' : 'ایجاد موضوع جدید')),
          if (b.chargeSettingTopic != null) OutlinedButton.icon(onPressed: () => _openChargeTopic(b, isManager: true), icon: const Icon(Icons.open_in_new), label: const Text('بازکردن موضوع')),
        ]))),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(Icons.how_to_vote_outlined, color: colors.primary), const SizedBox(width: 8), const Expanded(child: Text('نظرسنجی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
          const SizedBox(height: 8),
          Text('نظرسنجی‌های فعال: ${b.polls.where((p) => p.isActive).length.toPersianDigits()}', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _createPoll, icon: const Icon(Icons.add_circle_outline), label: const Text('ایجاد نظرسنجی')),
          for (final poll in b.polls) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(poll.isActive ? Icons.poll_outlined : Icons.task_alt_outlined), title: Text(poll.title), subtitle: Text(poll.isActive ? 'ایجاد: ${_formatPersianDateTime(poll.createdAt)} • مهلت تا ${_formatPersianDateTime(poll.deadline)} • رأی‌دهنده: ${poll.totalVotes.toPersianDigits()}' : 'نتیجه: ${poll.passed ? 'تصویب شد' : 'تصویب نشد'} • موافق ${poll.agreeCount.toPersianDigits()} (${poll.percentage(poll.agreeCount).toStringAsFixed(1).toPersianDigits()}٪) • مخالف ${poll.disagreeCount.toPersianDigits()} (${poll.percentage(poll.disagreeCount).toStringAsFixed(1).toPersianDigits()}٪)')),
        ]))),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: _addFloor, icon: const Icon(Icons.add_rounded), label: const Text('افزودن طبقه جدید')),
        const SizedBox(height: 12),
        if (b.floors.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Icon(Icons.calendar_view_day_outlined, size: 38, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            const Text('هنوز طبقه‌ای اضافه نشده است', textAlign: TextAlign.center),
          ])))
        else
          _BuildingLayout(
            building: b,
            highlightMemberName: widget.managerName,
            onUnitTap: _onManagerUnitTap,
            onFloorActions: (floor) => showModalBottomSheet<void>(
              context: context,
              builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(leading: const Icon(Icons.format_list_numbered_rounded), title: const Text('ویرایش تعداد واحد'), onTap: () { Navigator.pop(context); _editFloorCount(floor); }),
                ListTile(leading: const Icon(Icons.tag_rounded), title: const Text('ویرایش شمارهٔ واحدها'), onTap: () { Navigator.pop(context); _editFloorUnits(floor); }),
              ])),
            ),
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
          child: const Text('توجه: داده‌ها فقط در حافظهٔ همین اجرای برنامه نگه داشته می‌شوند.', style: TextStyle(fontSize: 12, height: 1.7)),
        ),
      ]),
    );
  }

  Widget _statChip(BuildContext context, IconData icon, String label) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: colors.primaryContainer.withOpacity(.5), borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

extension _PersianDigits on int {
  String toPersianDigits() {
    const digits = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    final s = toString();
    final buffer = StringBuffer();
    for (final ch in s.codeUnits) {
      buffer.write(ch == 0x2D ? '-' : digits[ch - 48]);
    }
    return buffer.toString();
  }
}

class _FeatureItem {
  const _FeatureItem(this.title, this.subtitle, this.icon, this.kind);
  final String title, subtitle, kind;
  final IconData icon;
}

class _FeatureHub extends StatelessWidget {
  const _FeatureHub({required this.index, required this.isManager});
  final int index;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final items = index == 1
        ? <_FeatureItem>[
            const _FeatureItem('خدمات و نیروهای خدماتی', 'ثبت تخصص، مشاهدهٔ درخواست‌ها و ارزیابی خدمات', Icons.handyman_rounded, 'service'),
            const _FeatureItem('گفت‌وگوی ساختمان', 'ارتباط با ساکنان و مدیر ساختمان', Icons.forum_rounded, 'chat'),
          ]
        : index == 2
            ? <_FeatureItem>[
                const _FeatureItem('رأی‌گیری ساختمان', 'ثبت موضوع و رأی‌گیری ناشناس دربارهٔ تصمیم‌ها', Icons.how_to_vote_rounded, 'vote'),
                const _FeatureItem('ارزیابی عملکرد مدیر', 'ارزیابی دوره‌ای هر شش ماه', Icons.fact_check_rounded, 'evaluation'),
              ]
            : <_FeatureItem>[
                if (isManager) const _FeatureItem('درخواست برداشت', 'درخواست و پیگیری تسویهٔ موجودی ساختمان', Icons.account_balance_wallet_rounded, 'withdraw'),
                const _FeatureItem('قبض آب و کنتورها', 'ثبت قبض اصلی، قرائت و سهم هر واحد', Icons.water_drop_rounded, 'water'),
                const _FeatureItem('اشتراک برنامه', 'آزمایش رایگان سه‌ماهه و انتخاب طرح', Icons.workspace_premium_rounded, 'subscription'),
              ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text(index == 1 ? 'درخواست‌ها و ارتباط' : index == 2 ? 'رأی‌گیری و ارزیابی' : 'امور مالی و اشتراک',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('برای مشاهده یا ثبت اطلاعات، یکی از بخش‌های زیر را انتخاب کنید.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            leading: CircleAvatar(radius: 25, child: Icon(item.icon)),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(item.subtitle)),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _FeaturePage(item: item))),
          )),
        )),
        Card(color: Theme.of(context).colorScheme.secondaryContainer, child: const Padding(
          padding: EdgeInsets.all(16), child: Text('ساختمان و اعضا\nایجاد ساختمان و طبقات (مدیر) یا جست‌وجو و عضویت در ساختمان (ساکن) از تب «خدمات» در دسترس است.', style: TextStyle(height: 1.7)),
        )),
      ],
    );
  }
}

class _FeaturePage extends StatefulWidget {
  const _FeaturePage({required this.item});
  final _FeatureItem item;
  @override
  State<_FeaturePage> createState() => _FeaturePageState();
}

class _MeterReading {
  _MeterReading(this.label, int previous, int current)
      : previousController = TextEditingController(text: '$previous'),
        currentController = TextEditingController(text: '$current');
  final String label;
  final TextEditingController previousController;
  final TextEditingController currentController;
  int get previous => int.tryParse(previousController.text) ?? 0;
  int get current => int.tryParse(currentController.text) ?? 0;
  int get usage { final delta = current - previous; return delta < 0 ? 0 : delta; }
  void dispose() { previousController.dispose(); currentController.dispose(); }
}

class _FeaturePageState extends State<_FeaturePage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _values = {};
  final Map<String, int> _ratings = {};
  final Map<int, String> _votes = {};
  final List<Map<String, String>> _messages = [
    {'text': 'به گفت‌وگوی ساختمان خوش آمدید.', 'mine': 'false', 'name': 'مدیر'},
    {'text': 'اطلاعیه تعمیرات مشاعات را اینجا می‌بینیم.', 'mine': 'false', 'name': 'سارا'},
    {'text': 'ممنون، زمان‌بندی را بررسی می‌کنم.', 'mine': 'true', 'name': 'شما'},
  ];
  final List<String> _withdrawals = [];
  final TextEditingController _chatController = TextEditingController();
  final List<_MeterReading> _meters = List<_MeterReading>.generate(
    6, (i) => _MeterReading('واحد ${i + 1}', 120 + i * 17, 135 + i * 17));
  String? _choice;
  bool _checked = false;
  int _billAmount = 186000;
  int _selectedService = -1;
  final Map<int, double> _providerRatings = {0: 4.8, 1: 4.6, 2: 4.9, 3: 4.7};
  final Set<int> _ratedProviders = {};
  final List<String> _criteria = const [
    'شفافیت مالی و ارائه گزارش',
    'پاسخ‌گویی به درخواست ساکنان',
    'رسیدگی به تعمیرات و نگهداری',
    'مدیریت هزینه‌ها و بودجه',
    'نظم و پیگیری امور روزمره',
    'رفتار حرفه‌ای و منصفانه',
  ];
  final List<String> _providers = const [
    'لوله‌کشی و تأسیسات', 'برق‌کاری ساختمان', 'نظافت مشاعات', 'سرویس آسانسور',
  ];
  final List<String> _providerNames = const [
    'علی رضایی', 'مهدی کریمی', 'گروه پاک‌زیست', 'فنی‌کاران ایمن',
  ];
  final List<String> _providerDetails = const [
    'تعمیر نشتی، رفع گرفتگی و سرویس پمپ آب',
    'عیب‌یابی برق، روشنایی و تابلوهای مشاع',
    'نظافت راه‌پله، پارکینگ و فضاهای عمومی',
    'بازدید دوره‌ای و تعمیر آسانسورهای مسکونی',
  ];

  List<String> get _fields => switch (widget.item.kind) {
    'withdraw' => ['مبلغ درخواستی (تومان)', 'شماره شبا', 'توضیحات برای مدیر سامانه'],
    'water' => ['مبلغ کل قبض (تومان)', 'شماره قبض یا دورهٔ مصرف'],
    'subscription' => [],
    'vote' => ['عنوان موضوع رأی‌گیری', 'شرح پیشنهاد', 'هزینهٔ اجرای تصمیم (تومان)', 'مدت رأی‌گیری (روز)'],
    'evaluation' => ['توضیحات (اختیاری)'],
    'service' => ['شرح درخواست', 'زمان پیشنهادی', 'شماره تماس'],
    _ => [],
  };

  @override
  void dispose() {
    _chatController.dispose();
    for (final meter in _meters) { meter.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.item.kind;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          CircleAvatar(radius: 26, child: Icon(widget.item.icon)), const SizedBox(width: 14),
          Expanded(child: Text(widget.item.subtitle, style: const TextStyle(height: 1.6))),
        ]))),
        const SizedBox(height: 12),
        if (kind == 'subscription') _subscriptionContent(context),
        if (kind == 'vote') _voteContent(context),
        if (kind == 'evaluation') _evaluationContent(context),
        if (kind == 'service') _serviceContent(context),
        if (kind == 'water') _waterContent(context),
        if (kind == 'withdraw') _withdrawSummary(context),
        if (kind == 'chat') _chatInterface(context),
        if (_fields.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(kind == 'vote' ? 'پیشنهاد موضوع جدید' : kind == 'withdraw' ? 'ثبت درخواست برداشت' : kind == 'water' ? 'ثبت قبض آب' : kind == 'service' ? 'ثبت درخواست خدمت' : 'ثبت ارزیابی', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ..._fields.map((label) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
              keyboardType: label.contains('مبلغ') || label.contains('هزینه') || label.contains('روز') || label.contains('شماره قبض') ? TextInputType.number : TextInputType.text,
              maxLines: label.contains('شرح') || label.contains('توضیحات') ? 3 : 1,
              decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              validator: (v) => (v == null || v.trim().isEmpty) && !label.contains('اختیاری') ? 'این مورد را وارد کنید' : null,
              onSaved: (v) => _values[label] = v?.trim() ?? '',
            ))),
            if (kind == 'water') CheckboxListTile(value: _checked, contentPadding: EdgeInsets.zero, title: const Text('تصویر قبض را پیوست کرده‌ام'), onChanged: (v) => setState(() => _checked = v ?? false)),
            FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_circle_outline), label: Text(kind == 'vote' ? 'ثبت پیشنهاد' : kind == 'withdraw' ? 'ارسال برای بررسی' : kind == 'water' ? 'محاسبه و ثبت قبض' : kind == 'service' ? 'ارسال درخواست' : 'ثبت ارزیابی')),
          ])))),
        ],
        const SizedBox(height: 18),
        Text('اطلاعات این نمونه در همین نشست برنامه نمایش داده می‌شود؛ ثبت نهایی، پرداخت یا همگام‌سازی نیازمند اتصال سرویس سمت سرور است.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _sectionTitle(String title, {String? detail, IconData icon = Icons.dashboard_customize_outlined}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (detail != null) Text(detail, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))]))]),
  );

  Widget _subscriptionContent(BuildContext context) {
    final plans = [
      ('ماهانه', '۲۹۰٬۰۰۰', 'پرداخت ماه‌به‌ماه', Icons.calendar_month_outlined),
      ('سه‌ماهه', '۷۵۰٬۰۰۰', 'صرفه‌جویی نسبت به پرداخت ماهانه', Icons.date_range_outlined),
      ('سالانه', '۲٬۷۰۰٬۰۰۰', 'بهترین ارزش؛ معادل ۲۲۵ هزار تومان در ماه', Icons.workspace_premium_outlined),
    ];
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.card_giftcard_rounded, size: 32), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('۳ ماه استفادهٔ رایگان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('بدون هزینه در دورهٔ آزمایشی؛ هر زمان قابل لغو است.')]))])),
      const SizedBox(height: 18), _sectionTitle('انتخاب طرح پس از دورهٔ آزمایشی', detail: 'همهٔ طرح‌ها شامل مدیریت ساختمان، گزارش و پشتیبانی هستند.'),
      for (var i = 0; i < plans.length; i++) _planCard(plans[i], i),
      const SizedBox(height: 8), FilledButton.icon(onPressed: _choice == null ? null : () => _message('طرح $_choice پس از دورهٔ آزمایشی انتخاب شد.'), icon: const Icon(Icons.lock_open_rounded), label: const Text('شروع دورهٔ آزمایشی رایگان')),
      const SizedBox(height: 8), const Text('یادآوری پایان دورهٔ آزمایشی پیش از شروع پرداخت نمایش داده می‌شود.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ])));
  }

  Widget _planCard((String, String, String, IconData) plan, int index) {
    final selected = _choice == plan.$1;
    return Card(color: selected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(.55) : null, child: RadioListTile<String>(value: plan.$1, groupValue: _choice, onChanged: (v) => setState(() => _choice = v), secondary: Icon(plan.$4), title: Text('طرح ${plan.$1}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${plan.$3}\n${plan.$2} تومان پس از پایان دورهٔ رایگان'), isThreeLine: true));
  }

  Widget _voteContent(BuildContext context) {
    final topics = [
      ('تعمیر آسانسور', 'برآورد هزینه: ۱۲٬۰۰۰٬۰۰۰ تومان', 24, 8),
      ('نصب دوربین ورودی', 'برآورد هزینه: ۸٬۵۰۰٬۰۰۰ تومان', 18, 11),
      ('بهسازی روشنایی پارکینگ', 'برآورد هزینه: ۳٬۲۰۰٬۰۰۰ تومان', 15, 5),
    ];
    return Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionTitle('صندوق رأی ناشناس', detail: 'رأی شما از هویت و شمارهٔ واحد جدا نگه داشته می‌شود.', icon: Icons.how_to_vote_rounded),
        Center(child: Container(width: 130, height: 112, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)), child: Stack(alignment: Alignment.center, children: [Icon(Icons.how_to_vote_rounded, size: 72, color: Theme.of(context).colorScheme.primary), Positioned(top: 20, child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(.65), borderRadius: BorderRadius.circular(5))))]))),
        const SizedBox(height: 12), const Text('برای هر موضوع فقط یک رأی ثبت کنید. نتایج تجمیعی نمایش داده می‌شوند و انتخاب فردی قابل مشاهده نیست.', textAlign: TextAlign.center, style: TextStyle(height: 1.5)),
      ]))),
      for (var i = 0; i < topics.length; i++) _ballotCard(topics[i], i),
    ]);
  }

  Widget _ballotCard((String, String, int, int) topic, int index) {
    final total = topic.$3 + topic.$4;
    final agree = total == 0 ? 0.0 : topic.$3 / total;
    final choice = _votes[index];
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text(topic.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), const Chip(label: Text('فعال'))]),
      Text(topic.$2), const SizedBox(height: 12),
      Row(children: [const Text('موافق'), const Spacer(), Text('${(agree * 100).round()}٪ موافق • ${((1 - agree) * 100).round()}٪ مخالف')]),
      const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: agree, minHeight: 12)),
      const SizedBox(height: 8), Text('آرای ثبت‌شده: $total', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: choice == null ? () => _castVote(index, 'موافقم') : null, icon: const Icon(Icons.thumb_up_alt_outlined), label: const Text('موافقم'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: choice == null ? () => _castVote(index, 'مخالفم') : null, icon: const Icon(Icons.thumb_down_alt_outlined), label: const Text('مخالفم')))]),
      if (choice != null) Text('رأی ناشناس شما ثبت شد: $choice', style: const TextStyle(fontWeight: FontWeight.w600)),
    ])));
  }

  void _castVote(int index, String answer) { setState(() => _votes[index] = answer); _message('رأی شما به‌صورت ناشناس ثبت شد.'); }

  Widget _evaluationContent(BuildContext context) {
    final average = _criteria.map((x) => _ratings[x] ?? 4).fold<int>(0, (a, b) => a + b) / _criteria.length;
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('ارزیابی شش‌ماههٔ مدیر', detail: 'دوره: شش ماه گذشته • امتیازدهی از ۱ تا ۵', icon: Icons.fact_check_outlined),
      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.star_rounded, color: Colors.amber, size: 32), const SizedBox(width: 8), Text(average.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Expanded(child: Text('میانگین ارزیابی فعلی'))])),
      const SizedBox(height: 14),
      for (final criterion in _criteria) _ratingRow(criterion),
      const SizedBox(height: 8), const Text('ارزیابی‌ها به‌صورت تجمیعی برای بهبود مدیریت استفاده می‌شوند.', style: TextStyle(height: 1.5, fontSize: 12)),
    ])));
  }

  Widget _ratingRow(String criterion) {
    final value = _ratings[criterion] ?? 4;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(criterion)), DropdownButton<int>(value: value, items: List.generate(5, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text('$n از ۵'))).toList(), onChanged: (v) => setState(() => _ratings[criterion] = v ?? 4))]));
  }

  Widget _serviceContent(BuildContext context) => Column(children: [
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('پروفایل نیروهای خدماتی', detail: 'مشاهدهٔ تخصص، امتیاز ساکنان و ثبت درخواست.', icon: Icons.engineering_outlined),
      for (var i = 0; i < _providers.length; i++) _providerCard(i),
    ]))),
    if (_selectedService >= 0) Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.assignment_turned_in_outlined), const SizedBox(width: 10), Expanded(child: Text('درخواست «${_providers[_selectedService]}» آمادهٔ ثبت است.'))]))),
  ]);

  Widget _providerCard(int i) {
    final rating = _providerRatings[i] ?? 4.5;
    return Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [CircleAvatar(child: Icon(i == 2 ? Icons.cleaning_services_outlined : Icons.person_outline)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_providers[i], style: const TextStyle(fontWeight: FontWeight.bold)), Text(_providerNames[i], style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))])), Text('★ ${rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))]),
      Padding(padding: const EdgeInsets.only(top: 9, bottom: 8), child: Text(_providerDetails[i], style: const TextStyle(height: 1.4))),
      Row(children: [const Icon(Icons.verified_outlined, size: 17), const SizedBox(width: 5), const Expanded(child: Text('پروفایل تأییدشده • پاسخ‌گو در ساعات کاری', style: TextStyle(fontSize: 11))), TextButton.icon(onPressed: () { setState(() => _selectedService = i); _message('برای ثبت نهایی، فرم درخواست را تکمیل کنید.'); }, icon: const Icon(Icons.send_outlined, size: 17), label: const Text('درخواست'))]),
      if (_ratedProviders.contains(i)) const Text('از ثبت امتیاز شما سپاسگزاریم.', style: TextStyle(fontSize: 12)),
      if (!_ratedProviders.contains(i)) Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, children: [const Text('امتیاز شما:'), for (var star = 1; star <= 5; star++) IconButton(visualDensity: VisualDensity.compact, onPressed: () => _rateProvider(i, star), icon: Icon(Icons.star, color: star <= rating.round() ? Colors.amber : Colors.grey, size: 20))]),
    ])));
  }

  void _rateProvider(int index, int stars) { final old = _providerRatings[index] ?? 4.5; setState(() { _providerRatings[index] = ((old + stars) / 2 * 10).round() / 10; _ratedProviders.add(index); }); }

  Widget _waterContent(BuildContext context) {
    final usageSum = _meters.fold<int>(0, (sum, m) => sum + m.usage);
    final allocations = _meters.map((m) => usageSum == 0 ? _billAmount ~/ _meters.length : (_billAmount * m.usage / usageSum).round()).toList();
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('محاسبهٔ قبض با کنتور فرعی', detail: 'قرائت‌ها را ویرایش کنید؛ سهم هر واحد لحظه‌ای محاسبه می‌شود.', icon: Icons.water_drop_outlined),
      Text('مبلغ قبض: ${_billAmount.toString()} تومان  •  مصرف کل: $usageSum مترمکعب', style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columnSpacing: 18, columns: const [DataColumn(label: Text('واحد')), DataColumn(label: Text('قبلی')), DataColumn(label: Text('فعلی')), DataColumn(label: Text('مصرف')), DataColumn(label: Text('سهم قبض'))], rows: List<DataRow>.generate(_meters.length, (i) {
        final meter = _meters[i];
        return DataRow(cells: [DataCell(Text(meter.label)), DataCell(_meterInput(meter.previousController, i, 'previous')), DataCell(_meterInput(meter.currentController, i, 'current')), DataCell(Text('${meter.usage}')), DataCell(Text('${allocations[i]} تومان'))]);
      }))),
      const SizedBox(height: 10),
      Row(children: [const Icon(Icons.info_outline, size: 18), const SizedBox(width: 7), Expanded(child: Text('روش محاسبه: مبلغ قبض × مصرف واحد ÷ مصرف کل. سهم‌ها بر اساس مصرف واقعی تقسیم شده‌اند.', style: const TextStyle(fontSize: 12, height: 1.5)))]),
    ])));
  }

  Widget _meterInput(TextEditingController controller, int index, String field) => SizedBox(width: 76, child: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onChanged: (_) => setState(() {})));

  Widget _withdrawSummary(BuildContext context) {
    const rows = [
      ('شارژهای ماه جاری', 1850000, Icons.home_work_outlined),
      ('قبوض پرداخت‌شده', -420000, Icons.receipt_long_outlined),
      ('هزینهٔ تعمیرات', -175000, Icons.build_outlined),
      ('ماندهٔ قبلی', 620000, Icons.account_balance_outlined),
    ];
    final balance = rows.fold<int>(0, (sum, row) => sum + row.$2);
    return Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionTitle('صورت‌حساب ساختمان', detail: 'نمونهٔ گردش مالی و ماندهٔ قابل برداشت', icon: Icons.account_balance_wallet_outlined),
        for (final row in rows) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(row.$3), title: Text(row.$1), trailing: Text('${row.$2 < 0 ? '−' : '+'}${row.$2.abs()} تومان')),
        const Divider(), ListTile(title: const Text('موجودی قابل درخواست', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('$balance تومان', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const Text('گردش مالی به تفکیک واحد', style: TextStyle(fontWeight: FontWeight.bold)),
        for (var i = 1; i <= 4; i++) _unitDebtRow(i, i * 125000 + 45000),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionTitle('درخواست‌های برداشت', detail: 'وضعیت درخواست‌های ثبت‌شده را پیگیری کنید.', icon: Icons.payments_outlined),
        if (_withdrawals.isEmpty) const Text('هنوز درخواستی ثبت نشده است.', style: TextStyle(height: 1.5)),
        for (final request in _withdrawals) ListTile(leading: const Icon(Icons.hourglass_top_rounded), title: Text(request), subtitle: const Text('در انتظار بررسی'), trailing: const Chip(label: Text('در انتظار'))),
      ]))),
    ]);
  }

  Widget _unitDebtRow(int unit, int amount) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 16, child: Text('$unit')), title: Text('واحد $unit'), subtitle: const Text('شارژ و هزینه‌های مشترک'), trailing: Text('$amount تومان'));

  Widget _chatInterface(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _sectionTitle('گفت‌وگوی ساختمان', detail: 'پیام‌های گروه و اطلاعیه‌های ساکنان', icon: Icons.forum_outlined),
        Container(height: 330, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.35), borderRadius: BorderRadius.circular(18)), child: ListView(children: [
      const Center(child: Chip(avatar: Icon(Icons.lock_outline, size: 16), label: Text('گفت‌وگوی اعضای ساختمان'))),
      for (final message in _messages) _chatBubble(message),
    ])),
    const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: _chatController, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendChat(), decoration: InputDecoration(hintText: 'پیام خود را بنویسید…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)))), const SizedBox(width: 8), IconButton.filled(onPressed: _sendChat, tooltip: 'ارسال پیام', icon: const Icon(Icons.send_rounded))]),
  ])));

  Widget _chatBubble(Map<String, String> message) {
    final mine = message['mine'] == 'true';
    final colors = Theme.of(context).colorScheme;
    return Align(alignment: mine ? Alignment.centerLeft : Alignment.centerRight, child: Container(margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), constraints: const BoxConstraints(maxWidth: 285), decoration: BoxDecoration(color: mine ? colors.primaryContainer : colors.surface, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(mine ? 4 : 16), bottomRight: Radius.circular(mine ? 16 : 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (!mine) Text(message['name'] ?? 'عضو', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary)), Text(message['text'] ?? '', style: const TextStyle(height: 1.4)), Text(TimeOfDay.now().format(context), style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant))])));
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() { _messages.add({'text': text, 'mine': 'true', 'name': 'شما'}); _chatController.clear(); });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    final kind = widget.item.kind;
    if (kind == 'water') {
      final amount = int.tryParse((_values['مبلغ کل قبض (تومان)'] ?? '').replaceAll(',', ''));
      if (amount != null && amount > 0) setState(() => _billAmount = amount);
      _message('سهم‌بندی قبض بر اساس قرائت کنتورها به‌روزرسانی شد.');
    } else if (kind == 'withdraw') {
      setState(() => _withdrawals.add('${_values['مبلغ درخواستی (تومان)'] ?? '—'} تومان • ${_values['شماره شبا'] ?? ''}'));
      _message('درخواست برداشت برای بررسی ثبت شد.');
    } else if (kind == 'vote') {
      _message('پیشنهاد «${_values['عنوان موضوع رأی‌گیری'] ?? ''}» در فهرست بررسی قرار گرفت.');
    } else if (kind == 'service') {
      _message('درخواست خدمت برای ${_selectedService >= 0 ? _providers[_selectedService] : 'ارائه‌دهنده'} ثبت شد.');
    } else {
      _message('ارزیابی شما با موفقیت ثبت شد.');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
