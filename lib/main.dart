import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(BuildingApp());

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
        home: const Directionality(textDirection: TextDirection.rtl, child: LoginFlow()),
      ),
    );
  }
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

enum _LoginStep { welcome, phone, otp, account, success, dashboard }

class LoginFlow extends StatefulWidget {
  const LoginFlow({super.key});
  @override
  State<LoginFlow> createState() => _LoginFlowState();
}

class _LoginFlowState extends State<LoginFlow> {
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
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _unitController = TextEditingController();
  String? _ownership;
  String? _role;
  Timer? _timer;
  int _secondsLeft = 0;
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
    _provinceController.dispose();
    _cityController.dispose();
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
      case _LoginStep.phone: setState(() => _step = _LoginStep.welcome); break;
      case _LoginStep.otp:
        _timer?.cancel();
        setState(() => _step = _LoginStep.phone);
        break;
      case _LoginStep.account: setState(() => _step = _LoginStep.otp); break;
      case _LoginStep.success: setState(() => _step = _LoginStep.account); break;
      case _LoginStep.welcome:
      case _LoginStep.dashboard: break;
    }
  }

  void _submitPhone() {
    if (!(_phoneKey.currentState?.validate() ?? false)) return;
    _phoneController.text = _latinDigits(_phoneController.text).trim();
    _otpController.clear();
    setState(() => _step = _LoginStep.otp);
    _startCountdown();
  }

  void _verifyOtp() {
    if (!(_otpKey.currentState?.validate() ?? false)) return;
    if (_latinDigits(_otpController.text.trim()) != '123456') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد واردشده صحیح نیست. کد آزمایشی: 123456')));
      return;
    }
    _timer?.cancel();
    setState(() => _step = _LoginStep.account);
  }

  void _submitAccount() {
    if (!(_accountKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = _LoginStep.success);
  }

  String get _stepTitle => switch (_step) {
    _LoginStep.phone => 'شماره همراه',
    _LoginStep.otp => 'تأیید شماره',
    _LoginStep.account => 'ساخت حساب کاربری',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    if (_step == _LoginStep.dashboard) return DashboardPage(name: _nameController.text.trim(), role: _role ?? 'ساکن', buildingName: _buildingController.text.trim(), ownership: _ownership ?? 'ساکن', onSwitch: () => setState(() => _step = _LoginStep.account));
    final showBar = _step == _LoginStep.phone || _step == _LoginStep.otp || _step == _LoginStep.account || _step == _LoginStep.success;
    return Scaffold(
      appBar: showBar ? AppBar(
        leading: IconButton(tooltip: 'بازگشت', onPressed: _goBack, icon: const Icon(Icons.arrow_forward_rounded)),
        title: Text(_stepTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: BuildingApp.themeMode,
            builder: (context, mode, _) => IconButton(
              tooltip: BuildingApp.isEffectiveDark(context, mode) ? 'تم روشن' : 'تم تاریک',
              icon: Icon(BuildingApp.isEffectiveDark(context, mode) ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              onPressed: () => BuildingApp.toggleTheme(context),
            ),
          ),
        ],
      ) : null,
      body: SafeArea(
        top: !showBar,
        child: Stack(children: [
          PositionedDirectional(
            top: 8,
            end: 12,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: BuildingApp.themeMode,
              builder: (context, mode, _) => IconButton.filledTonal(
                tooltip: BuildingApp.isEffectiveDark(context, mode) ? 'تم روشن' : 'تم تاریک',
                icon: Icon(BuildingApp.isEffectiveDark(context, mode) ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                onPressed: () => BuildingApp.toggleTheme(context),
              ),
            ),
          ),
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
        ]),
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
      Text('کد تأیید در این نسخه به‌صورت آزمایشی نمایش داده می‌شود؛ پیامک واقعی ارسال نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.8)),
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
      Text('کد شش‌رقمی برای شماره ${_phoneController.text} (نمایشی) ارسال شد.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.8)),
      const SizedBox(height: 15),
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF4DD), borderRadius: BorderRadius.circular(15)), child: const Text('حالت آزمایشی: پیامک واقعی ارسال نمی‌شود. کد ثابت ورود: ۱۲۳۴۵۶', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF805A17), fontSize: 12, height: 1.7, fontWeight: FontWeight.w600))),
      const SizedBox(height: 25),
      TextFormField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLength: 6,
        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, letterSpacing: 12),
        decoration: _inputDecoration(hint: '••••••', counterText: ''),
        validator: (value) => _latinDigits(value ?? '').length == 6 ? null : 'کد تأیید باید ۶ رقم باشد.',
        onFieldSubmitted: (_) => _verifyOtp(),
      ),
      const SizedBox(height: 18),
      _primaryButton(label: 'تأیید و ادامه', onPressed: _verifyOtp),
      const SizedBox(height: 14),
      Center(child: TextButton.icon(
        onPressed: _secondsLeft == 0 ? _startCountdown : null,
        icon: const Icon(Icons.refresh_rounded, size: 19),
        label: Text(_secondsLeft == 0 ? 'ارسال دوباره کد آزمایشی' : 'ارسال دوباره تا ${_secondsLeft} ثانیه دیگر'),
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
      TextFormField(controller: _provinceController, textCapitalization: TextCapitalization.words,
        decoration: _inputDecoration(hint: 'مثلاً تهران', prefix: const Icon(Icons.map_outlined)),
        validator: (v) => (v?.trim().length ?? 0) >= 2 ? null : 'استان را وارد کنید.'),
      const SizedBox(height: 16),
      _fieldLabel('شهر'), const SizedBox(height: 7),
      TextFormField(controller: _cityController, textCapitalization: TextCapitalization.words,
        decoration: _inputDecoration(hint: 'مثلاً تهران', prefix: const Icon(Icons.location_city_outlined)),
        validator: (v) => (v?.trim().length ?? 0) >= 2 ? null : 'شهر را وارد کنید.'),
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
    setState(() { _role = role; _step = _LoginStep.dashboard; });
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
    Expanded(child: _FeatureItem(icon: Icons.miscellaneous_services_outlined, title: 'خدمات')),
    Expanded(child: _FeatureItem(icon: Icons.handyman_outlined, title: 'درخواست‌ها')),
    Expanded(child: _FeatureItem(icon: Icons.campaign_outlined, title: 'اطلاعیه‌ها')),
    Expanded(child: _FeatureItem(icon: Icons.receipt_long_outlined, title: 'امور مالی')),
  ]);
}
class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.title});
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
  _Member(this.name, this.role, this.ownership);
  final String name;
  final String role;
  final String ownership;
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
  _Building(this.name);
  String name;
  /// هر طبقه: شماره طبقه -> تعداد واحدها
  final Map<int, int> floors = {};
  /// شماره واحدهای واقعی هر طبقه؛ امکان شماره‌گذاری پیوسته بین طبقات.
  final Map<int, List<int>> floorUnits = {};
  /// واحد اشغال‌شده: "طبقه/واحد" -> عضو
  final Map<String, _Member> occupants = {};
  _ChargeSettingTopic? chargeSettingTopic;
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
    this.onSwitch,
  });
  final String name;
  final String role;
  final String buildingName;
  final String ownership;
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body = switch (selectedTab) {
      0 => _isManager ? _ManagerHome(building: _joinedBuilding, managerName: widget.name, onBuildingChanged: (building) => setState(() { _joinedBuilding = building; })) : _ResidentHome(
          building: _joinedBuilding,
          name: widget.name,
          myFloor: _myFloor,
          myUnit: _myUnit,
          ownership: widget.ownership,
          onJoined: (building, floor, unit) => setState(() { _joinedBuilding = building; _myFloor = floor; _myUnit = unit; }),
        ),
      _ => _PlaceholderTab(index: selectedTab),
    };
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سلام، ${widget.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_isManager ? 'نقش شما: مدیر ساختمان' : 'نقش شما: ساکن', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ]),
        leading: ValueListenableBuilder<ThemeMode>(
          valueListenable: BuildingApp.themeMode,
          builder: (context, mode, _) => IconButton(
            tooltip: BuildingApp.isEffectiveDark(context, mode) ? 'تم روشن' : 'تم تاریک',
            icon: Icon(BuildingApp.isEffectiveDark(context, mode) ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => BuildingApp.toggleTheme(context),
          ),
        ),
        actions: [
          if (!_isManager && _joinedBuilding != null)
            IconButton(
              tooltip: 'خروج از ساختمان',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => setState(() { _joinedBuilding = null; _myFloor = null; _myUnit = null; }),
            ),
          if (widget.onSwitch != null)
            IconButton(tooltip: 'ویرایش حساب', icon: const Icon(Icons.tune_rounded), onPressed: widget.onSwitch),
        ],
      ),
      body: SafeArea(child: body),
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
  const _ManagerHome({required this.building, required this.managerName, required this.onBuildingChanged});
  final _Building? building;
  final String managerName;
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
    // واحد مدیر: در اولین واحد پایین‌ترین طبقه قرار می‌گیرد و با بج طلایی برای همه نمایش داده می‌شود.
    if (b.floors.isNotEmpty) {
      final firstFloor = b.floors.keys.reduce((a, c) => a < c ? a : c);
      final firstUnit = (b.floorUnits[firstFloor] ?? const <int>[]).first;
      if (!b.isOccupied(firstFloor, firstUnit)) {
        b.assign(firstFloor, firstUnit, _Member(widget.managerName, 'مدیر', 'مدیر'));
      }
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

  Future<void> _createChargeTopic() async {
    final b = _building;
    if (b == null) return;
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

  Future<void> _openChargeTopic(_Building b, {required bool isManager}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ChargeTopicPage(building: b, isManager: isManager)));
    if (mounted) setState(() {});
  }

  InputDecoration _deco(BuildContext context, String hint, IconData icon) => InputDecoration(
    hintText: hint, prefixIcon: Icon(icon),
    filled: true, fillColor: Theme.of(context).colorScheme.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.8)),
  );

  @override
  Widget build(BuildContext context) {
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
        if (b != null) ...[
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: () => _openBuildingDetail(b),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.apartment_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                  Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('نمای ساختمان', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Expanded(child: Text('تعیین شارژ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
            const SizedBox(height: 8),
            Text(b.chargeSettingTopic == null ? 'برای ساختمان «${b.name}» موضوع تعیین شارژ بسازید.' : 'موضوع فعال: ${b.chargeSettingTopic!.title}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            if (b.monthlyCharge != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('شارژ ماهانهٔ هر واحد: ${formatTomanAmount(b.monthlyCharge!)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _createChargeTopic, icon: const Icon(Icons.add_circle_outline), label: Text(b.chargeSettingTopic == null ? 'ایجاد موضوع شارژ' : 'ایجاد موضوع جدید')),
            if (b.chargeSettingTopic != null) OutlinedButton.icon(onPressed: () => _openChargeTopic(b, isManager: true), icon: const Icon(Icons.open_in_new), label: const Text('بازکردن موضوع')),
          ]))),
          const SizedBox(height: 16),
        ],
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
          onUnitTap: (floor, unit) => _joinUnit(found, floor, unit),
          highlightMemberName: widget.name,
        ),
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
          if (building.monthlyCharge != null) ...[
            const SizedBox(height: 7),
            Text('شارژ ماهانه: ${formatTomanAmount(building.monthlyCharge!)}', style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold)),
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

  bool get _isManagerOfBuilding => b.occupants.values.any((m) => m.name == widget.managerName && m.role == 'مدیر') || true;

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

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final labels = [
      'درخواست‌ها به‌زودی در نسخهٔ کامل فعال می‌شود.',
      'اطلاعیه‌ها به‌زودی در نسخهٔ کامل فعال می‌شود.',
      'امور مالی به‌زودی در نسخهٔ کامل فعال می‌شود.',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 46,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              labels[index - 1],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'این نسخه یک نمونهٔ محلی است و بدون سرور کار می‌کند.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
