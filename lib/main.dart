import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const BuildingApp());

class BuildingApp extends StatelessWidget {
  const BuildingApp({super.key});

  // کنترلر سراسری برای تغییر تم در کل برنامه
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF12A889);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
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
        );
      },
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
  final _unitController = TextEditingController();
  final _passwordController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _hidePassword = true;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _passwordController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد واردشده صحیح نیست. کد آزمایشی: ۱۲۳۴۵۶')));
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

  Widget _themeToggleButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'حالت روشن' : 'حالت تاریک',
      onPressed: () {
        BuildingApp.themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
      },
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _LoginStep.dashboard) return const DashboardPage();
    final showBar = _step == _LoginStep.phone || _step == _LoginStep.otp || _step == _LoginStep.account || _step == _LoginStep.success;
    return Scaffold(
      appBar: AppBar(
        leading: showBar ? IconButton(tooltip: 'بازگشت', onPressed: _goBack, icon: const Icon(Icons.arrow_forward_rounded)) : null,
        title: showBar ? Text(_stepTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)) : null,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        // انتقال دکمه تم به بالا سمت راست
        actions: [
          _themeToggleButton(context),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: !showBar,
        child: Center(
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

  // استفاده مستقیم از عکس آیکون اپ در صفحه اول
  Widget _brandMark({double size = 96}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: const Color(0xFF11947A).withOpacity(.25), blurRadius: 24, offset: const Offset(0, 12))],
    ),
    child: Center(
      child: ClipOval(
        child: Image.asset(
          'assets/app_icon.png',
          width: size * 0.85,
          height: size * 0.85,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.apartment_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: size * 0.5,
          ),
        ),
      ),
    ),
  );

  Widget _welcome(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 10),
      // قرار دادن دکمه تغییر تم در بالا سمت راست در صفحه خوش‌آمدگویی (چون فاقد AppBar است)
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _themeToggleButton(context),
        ],
      ),
      const SizedBox(height: 10),
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
          const Expanded(child: Text('با شماره همراه خود وارد شوید یا حساب کاربری‌تان را بسازید.', style: TextStyle(fontSize: 13, height: 1.7))),
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
      const Text('حساب خود را بسازید', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('اطلاعات پایه را وارد کنید تا به پنل ساختمان بروید.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.7)),
      const SizedBox(height: 22),
      _fieldLabel('نام و نام خانوادگی'), const SizedBox(height: 7),
      TextFormField(controller: _nameController, textCapitalization: TextCapitalization.words, decoration: _inputDecoration(hint: 'مثلاً سارا احمدی', prefix: const Icon(Icons.badge_outlined)), validator: (v) => (v?.trim().length ?? 0) >= 3 ? null : 'نام و نام خانوادگی را وارد کنید.'),
      const SizedBox(height: 15),
      _fieldLabel('شماره واحد / آپارتمان'), const SizedBox(height: 7),
      TextFormField(controller: _unitController, keyboardType: TextInputType.number, decoration: _inputDecoration(hint: 'مثلاً ۱۲', prefix: const Icon(Icons.door_front_door_outlined)), validator: (v) => (v?.trim().isNotEmpty ?? false) ? null : 'شماره واحد را وارد کنید.'),
      const SizedBox(height: 15),
      _fieldLabel('رمز عبور'), const SizedBox(height: 7),
      TextFormField(
        controller: _passwordController,
        obscureText: _hidePassword,
        decoration: _inputDecoration(hint: 'حداقل ۶ نویسه', prefix: const Icon(Icons.lock_outline_rounded), suffix: IconButton(tooltip: _hidePassword ? 'نمایش رمز' : 'مخفی‌سازی رمز', onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
        validator: (v) => (v?.length ?? 0) >= 6 ? null : 'رمز عبور باید دست‌کم ۶ نویسه باشد.',
      ),
      const SizedBox(height: 23),
      _primaryButton(label: 'ساخت حساب کاربری', onPressed: _submitAccount),
      const SizedBox(height: 12),
      Text('شماره همراه تأییدشده: ${_phoneController.text}', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ]),
  );

  Widget _success(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 45),
      Center(child: Container(width: 98, height: 98, decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 54, color: colors.primary))),
      const SizedBox(height: 26),
      const Text('حساب شما آماده است!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text('${_nameController.text.trim()}، خوش آمدید. ثبت‌نام آزمایشی با موفقیت انجام شد.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, height: 1.8)),
      const SizedBox(height: 32),
      _primaryButton(label: 'ورود به داشبورد ساختمان', onPressed: () => setState(() => _step = _LoginStep.dashboard)),
      const SizedBox(height: 12),
      Text('این نسخه نمایشی است؛ اطلاعات حساب به سرور ارسال یا ذخیره نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.7)),
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
    Expanded(child: _FeatureItem(icon: Icons.account_balance_wallet_rounded, title: 'امور مالی')),
    Expanded(child: _FeatureItem(icon: Icons.notifications_rounded, title: 'اطلاعیه‌ها')),
    Expanded(child: _FeatureItem(icon: Icons.assignment_rounded, title: 'درخواست‌ها')),
    Expanded(child: _FeatureItem(icon: Icons.room_service_rounded, title: 'خدمات')),
  ]);
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.title});
  final IconData icon; final String title;
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 46, height: 46,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
    ),
    const SizedBox(height: 7),
    Text(title, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedTab = 0;

  Widget _themeToggleButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'حالت روشن' : 'حالت تاریک',
      onPressed: () {
        BuildingApp.themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
      },
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              sliver: SliverList.list(children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سلام، خوش آمدید 👋', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
                    const SizedBox(height: 6),
                    const Text('سامانه مدیریت ساختمان', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ])),
                  _themeToggleButton(context),
                  const SizedBox(width: 8),
                  CircleAvatar(radius: 24, backgroundColor: colors.primaryContainer, child: Icon(Icons.apartment_rounded, color: colors.primary)),
                ]),
                const SizedBox(height: 22),
                _BuildingCard(colors: colors),
                const SizedBox(height: 26),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('وضعیت ساختمان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('امروز، ۲۵ خرداد', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                ]),
                const SizedBox(height: 14),
                Row(children: const [
                  Expanded(child: _MetricCard(icon: Icons.account_balance_wallet_outlined, label: 'شارژ ماهانه', value: 'پرداخت شده', tint: Color(0xFF12A889), chip: 'تسویه')),
                  SizedBox(width: 12),
                  Expanded(child: _MetricCard(icon: Icons.build_outlined, label: 'درخواست‌های باز', value: '۲ مورد', tint: Color(0xFFE99A32), chip: 'در انتظار')),
                ]),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('دسترسی سریع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () {}, child: const Text('مشاهده همه')),
                ]),
                const SizedBox(height: 8),
                _QuickActions(colors: colors),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('اطلاعیه‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _StatusChip(text: '۲ جدید', color: colors.primary),
                ]),
                const SizedBox(height: 12),
                _NoticeCard(colors: colors),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'مالی'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'اطلاعیه‌ها'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'پروفایل'),
        ],
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({required this.colors});
  final ColorScheme colors;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF117D70), Color(0xFF19B794)]),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: const Color(0xFF11947A).withOpacity(.20), blurRadius: 22, offset: const Offset(0, 10))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مجتمع مسکونی', style: TextStyle(color: Colors.white70, fontSize: 13)),
          SizedBox(height: 5),
          Text('برج آسمان', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
        ]),
        Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.location_city_rounded, color: Colors.white)),
      ]),
      const SizedBox(height: 20),
      Divider(color: Colors.white.withOpacity(.25), height: 1),
      const SizedBox(height: 14),
      Row(children: const [
        Icon(Icons.door_front_door_outlined, color: Colors.white70, size: 18),
        SizedBox(width: 7), Text('واحد ۱۲ • طبقه ۴', style: TextStyle(color: Colors.white, fontSize: 13)),
        Spacer(), Icon(Icons.people_alt_outlined, color: Colors.white70, size: 18),
        SizedBox(width: 6), Text('۴۸ واحد', style: TextStyle(color: Colors.white, fontSize: 13)),
      ]),
    ]),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.value, required this.tint, required this.chip});
  final IconData icon; final String label, value, chip; final Color tint;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: tint.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: tint, size: 21)),
      _StatusChip(text: chip, color: tint),
    ]),
    const SizedBox(height: 16), Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
  ])));
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});
  final String text; final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)));
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.colors});
  final ColorScheme colors;
  @override
  Widget build(BuildContext context) => Row(children: [
    _Action(icon: Icons.credit_card_rounded, title: 'پرداخت شارژ', colors: colors),
    _Action(icon: Icons.handyman_outlined, title: 'ثبت درخواست', colors: colors),
    _Action(icon: Icons.local_parking_outlined, title: 'پارکینگ', colors: colors),
    _Action(icon: Icons.more_horiz_rounded, title: 'سایر', colors: colors),
  ]);
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.colors});
  final IconData icon; final String title; final ColorScheme colors;
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: () {}, borderRadius: BorderRadius.circular(16), child: Column(children: [
    Container(width: 54, height: 54, decoration: BoxDecoration(color: colors.primaryContainer.withOpacity(.7), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: colors.primary, size: 24)),
    const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
  ])));
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.colors});
  final ColorScheme colors;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: colors.tertiaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.water_drop_outlined, color: colors.tertiary)),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('سرویس دوره‌ای مخزن آب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))), Text('۱۰:۳۰', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11))]),
      const SizedBox(height: 6), Text('سرویس مخزن روز پنجشنبه انجام می‌شود. لطفاً در مصرف آب صرفه‌جویی فرمایید.', style: TextStyle(color: colors.onSurfaceVariant, height: 1.5, fontSize: 12)),
    ])),
  ])));
}
