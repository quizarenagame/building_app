import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
        home: Builder(builder: (context) => Directionality(textDirection: TextDirection.rtl, child: _initialHome(context))),
      ),
    );
  }
}

String _normalizeRole(String? value) => const {'مدیر', 'ساکن', 'خدماتی'}.contains(value) ? value! : 'ساکن';

Widget _initialHome(BuildContext context) {
  if (!pb.authStore.isValid) return const LoginFlow();
  final record = pb.authStore.record;
  final data = record?.data ?? const <String, dynamic>{};
  final firstName = (data['name'] ?? '').toString().trim();
  final lastName = (data['last_name'] ?? data['lastname'] ?? '').toString().trim();
  final fullName = [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
  final roleValue = (data['role'] ?? '').toString().trim();
  return DashboardPage(
    name: fullName.isEmpty ? (record?.id ?? '') : fullName,
    role: _normalizeRole(roleValue),
    buildingName: (data['building_name'] ?? '').toString(),
    ownership: (data['ownership'] ?? 'ساکن').toString(),
    showMyBuildings: data['show_my_buildings'] == true,
    onSwitch: () {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: LoginFlow(startAtAccount: true)),
      ));
    },
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

String _normalizeSearchText(String value) => _latinDigits(value)
    .replaceAll('ي', 'ی').replaceAll('ك', 'ک')
    .replaceAll(RegExp(r'[\u200c\s]+'), ' ')
    .trim().toLowerCase();


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
  MapEntry('آذربایجان شرقی', ['تبریز', 'آبش احمد', 'آذرشهر', 'اسکو', 'اهر', 'الخچی', 'باسمنج', 'بستان آباد', 'بناب', 'ترکمانچای', 'تسوج', 'تیکمه داش', 'جلفا', 'چاراویماق', 'چهاردانگه', 'خاروانا', 'خدا آفرین', 'خسروشاه', 'خواجه', 'سراب', 'سراجو', 'سهند', 'سیه رود', 'شادیان', 'شبستر', 'صوفیان', 'عجب شیر', 'فندقلو', 'قلعه چای', 'کاغذکنان', 'کشکسرای', 'کلیبر', 'کندوان', 'گرمادوز', 'گوگان', 'لیلان', 'مراغه', 'مرند', 'ملکان', 'ممقان', 'منجوان', 'مهربان', 'میانه', 'نظر کهریزی', 'هریس', 'هشترود', 'هوراند', 'ورزقان', 'یامچی']),
  MapEntry('آذربایجان غربی', ['ارس', 'ارومیه', 'اشنویه', 'انزل', 'ایواوغلی', 'باروق', 'بازرگان', 'بکتاش', 'بوکان', 'پلدشت', 'پیرانشهر', 'تخت سلیمان', 'تکاب', 'چالدران', 'چهاربرج', 'حاجیلار', 'خلیفان', 'خوی', 'دشتک', 'ربط', 'سردشت', 'سلماس', 'سیلوانه', 'سیمینه', 'شاهین دژ', 'شوط', 'صفائیه', 'صومای برادوست', 'فیرورق', 'فیروزآباد', 'قره ضیاءالدین', 'قره قوین', 'قطور', 'کشاورز', 'کوهسار', 'لاجان', 'ماکو', 'محمدیار', 'مهاباد', 'میاندوآب', 'نالوس', 'نختالو', 'نقده', 'نوشین شهر', 'وزینه']),
  MapEntry('اردبیل', ['ارشق', 'اسلام آباد', 'اصلاندوز', 'انگوت', 'بران', 'بیله سوار', 'پارس آباد', 'ثمرین', 'خلخال', 'خورش رستم', 'دره رود', 'سبلان', 'سرعین', 'شاهرود', 'عنبران', 'فیروز', 'قشلاق دشت', 'قصابه', 'کوثر', 'کوراییم', 'گرمی', 'مرادلو', 'مشگین شهر', 'موران', 'نمین', 'نیر', 'هیر', 'ویلکیج']),
  MapEntry('اصفهان', ['اصفهان', 'آران و بیدگل', 'ابریشم', 'اردستان', 'اژیه', 'انارک', 'بادرود', 'باغ بهادران', 'برخوار', 'برزک', 'بوئین و میاندشت', 'پادنا', 'پادنا علیا', 'پیربکران', 'تیران', 'جرقویه', 'چادگان', 'چنارود', 'حبیب آباد', 'خمینی شهر', 'خوانسار', 'خور', 'داران', 'دهاقان', 'علویجه', 'رامشه', 'رودشت', 'زنده رود', 'زواره', 'زیبا شهر', 'سمیرم', 'سیستان', 'شاهین شهر', 'شهرضا', 'عسگران', 'فریدونهشر', 'فلاورجان', 'فولادشهر', 'قمصر', 'قهدریجان', 'کاشان', 'کرچمبو', 'موهپایه', 'کویرات', 'گلپایگان', 'لنجان', 'مبارکه', 'مهاباد', 'موگوئی', 'میمه', 'نائین', 'نجف آباد', 'نطنز', 'نیاسر', 'هرند', 'وردشت', 'ورزنه']),
  MapEntry('البرز', ['کرج', 'آسارا', 'اشتهارد', 'پلنگ آباد', 'تنکمان', 'چهارباغ', 'رامجین', 'طالقان', 'فردیس', 'کوهسار', 'گرمدره', 'ماهدشت', 'محمدشهر', 'مشکین دشت', 'نظرآباد', 'هشتگرد']),
  MapEntry('ایلام', ['آبدانان', 'ایلام', 'ایوان', 'بدره', 'بولی', 'جزمان', 'چرداول', 'چوار', 'دره شهر', 'دشت عباس', 'دهلران', 'زاگرس', 'زرنه', 'زرین آباد', 'سراب باغ', 'سراب میمه', 'سیروان', 'سیوان', 'شباب', 'صالح آباد', 'کارزان', 'کلات', 'گچی', 'ماژین', 'ملکشاهی', 'مهران', 'موسیان', 'هلیلان', 'هندمینی']),
  MapEntry('بوشهر', ['آبپخش', 'آبدان', 'ارم', 'امام حسن', 'اهرم', 'برازجان', 'بردخون', 'بندر دیر', 'بندرکنگان', 'بندر گناوه', 'بوشکان', 'بوشهر', 'جم', 'چاه مبارک', 'چغادک', 'خارک', 'خارکو', 'خورموج', 'دلوار', 'دیلم', 'ریز', 'ریگ', 'سعدآباد', 'سیراف', 'شبانکاره', 'شنبه و طسوج', 'عسلویه', 'کاکی', 'وحدتیه']),
  MapEntry('تهران', ['تهران', 'آبسرد', 'آبعلی', 'آفتاب', 'احمدآباد مستوفی', 'ارجمند', 'اسلامشهر', 'اندیشه', 'باغستان', 'باقرشهر', 'بهارستان', 'بومهن', 'پاکدشت', 'پردیس', 'پرند', 'پیشوا', 'تلو', 'جاجرود', 'جلیل آباد', 'جوادآباد', 'جوقین', 'چهاردانگه', 'قیامدشت', 'دماوند', 'رباط کریم', 'رودهن', 'سرخه حصار', 'شاهدشهر', 'شریف آباد', 'شمشک', 'شهریار', 'صباشهر', 'صفادشت', 'فردوسیه', 'فشاپویه', 'برازجان']),
  MapEntry('چهارمحال و بختیاری', ['اردل', 'ارمند', 'باباحیدر', 'بازفت', 'بروجن', 'بلداجی', 'بن', 'جونقان', 'خانمیرزا', 'رودشت', 'زاینده رود', 'سامان', 'شهرکرد', 'شیدا', 'صمصامی', 'فارسان', 'فرخ شهر', 'فلارد', 'کوهرنگ', 'کیار', 'گندمان', 'لاران', 'لردگان', 'منج', 'میانکوه', 'ناغان']),
  MapEntry('خراسان جنوبی', ['آیسک', 'ارسک', 'اسلامیه', 'بشروئیه', 'بیرجند', 'جلگه ماژان', 'خوسف', 'درح', 'درمیان', 'دستگردان', 'دیهوک', 'زهان', 'زیرکوه', 'سده', 'سربیشه', 'سرداران', 'سرایان', 'شاخنات', 'شاسکوه', 'شوسف', 'طبس', 'فردوس', 'قائن', 'قهستان', 'گزیک', 'مود', 'نهبندان', 'نیمبلوک']),
  MapEntry('خراسان رضوی', ['بوژگان', 'پائین جام', 'تایباد', 'تربت جام', 'تربت حیدریه', 'جغتای', 'جلگه رخ', 'جلگه زوزن', 'جنت آباد', 'جنگل', 'جوین', 'چاپشلو', 'چناران', 'خلیل آباد', 'خواف', 'خوشاب', 'داورزن', 'درگز', 'رادکان', 'رشتخوار', 'رضویه', 'روداب', 'زاوه', 'زاوین', 'زبرخان', 'سبزوار', 'سرخس', 'سرولایت', 'سلامی', 'سلیمان', 'سنگان', 'سیدآباد', 'شادمهر', 'شامکان', 'شاندیز', 'ششتمد', 'ششطراز', 'شهرآباد', 'صالح آباد', 'طاغنکوه', 'طرقبه', 'عطاملک', 'فرح دشت', 'فریمان', 'فیروزه', 'قاسم آباد', 'قلندر آباد', 'قوچان', 'کاخک', 'کاشمر', 'کدکن', 'کلات', 'کوهسرخ', 'گلبهار', 'گلمکان', 'گناباد', 'لطف آباد', 'مرزداران', 'مشکان', 'ملک آباد', 'مه ولات', 'میان جلگه', 'میان ولایت', 'نصرآباد', 'نوخندان', 'نوده انقلاب', 'نیشابور', 'هزارمسجد', 'هلالی', 'یونسی']),
  MapEntry('خراسان شمالی', ['سرحد', 'سملقان', 'سنخواست', 'شیروان', 'صفی آباد', 'غلامان', 'فاروج', 'قوشخانه', 'گرمخان', 'گرمه', 'مانه']),
  MapEntry('خوزستان', ['اهواز', 'آبادان', 'آغاجاری', 'امیدیه', 'اندیکا', 'اندیمشک', 'ایذه', 'باغملک', 'باوی', 'بندر امام خمینی', 'بندر ماهشهر', 'بهبهان', 'چمران', 'حمیدیه', 'خرمشهر', 'دزپارت', 'دزفول', 'دشت آزادگان', 'رامشیر', 'رامهرمز', 'سوسنگرد', 'شادگان', 'شوش', 'شوشتر', 'کارون', 'کرخه', 'گتوند', 'لالی', 'مسجد سلیمان', 'هفتگل', 'هندیجان', 'هویزه']),
  MapEntry('زنجان', ['ابهر', 'افشار', 'انگوران', 'ایجرود', 'باغ حلی', 'بزینه رود', 'چورزق', 'حلب', 'خرمدره', 'دوتپه', 'زنجان', 'زنجانرود', 'سجاس رود', 'سلطانیه', 'صائین قلعه', 'طارم', 'قره پشتلو', 'قیدار', 'گیلوان', 'ماهنشان']),
  MapEntry('سمنان', ['دامغان', 'سرخه', 'سمنان', 'شاهرود', 'شهمیرزاد', 'کالپوش', 'کهن آباد', 'گرمسار', 'مهدی شهر', 'میامی', 'هفدر']),
  MapEntry('سیستان و بلوچستان', ['آشار', 'آهوران', 'ایرانشهر', 'ایرندگان', 'باهوکلات', 'بزمان', 'بم پشت', 'بمپور', 'بنت', 'بیرک', 'پارود', 'پسکوه', 'پشتکوه', 'پلان', 'پیپ', 'پیرسهراب', 'پیشین', 'تفتان', 'تلنگ', 'تیمورآباد', 'جالق', 'جزنیک', 'جلگه چاه هاشم', 'چابهار', 'خاش', 'خمک', 'دامن', 'دشتیاری', 'دلگان', 'راسک', 'ریگ ملک', 'زابل', 'زاهدان', 'زرآباد', 'زهک', 'ساربوک', 'سراوان', 'سرباز', 'سیب و سوران', 'صابری', 'فنوج', 'قرقری', 'قصرقند', 'کاروان', 'کرباسک', 'کلاتان', 'کله گان', 'کنارک', 'کهیر', 'کورین', 'کیشگور', 'گتیج', 'گوهرکوه', 'لادیز', 'لاشار', 'مهرستان', 'مهرگان', 'میرجاوه', 'مینان', 'نازیل', 'نسکند', 'نصرت آباد', 'نیک شهر', 'نیمروز', 'هامون', 'هیدوچ', 'هیرمند']),
  MapEntry('فارس', ['شیراز', 'آباده', 'ارد', 'ارژن', 'ارسنجان', 'استهبان', 'اسیر', 'اشکنان', 'افرز', 'اقلید', 'اوز', 'ایزدخواست', 'باغ صفا', 'بانش', 'بختگان', 'بنارویه', 'بهمن صغاد', 'بوانات', 'بیدشهر', 'بیرم', 'بیضا', 'پاسارگاد', 'پشتکوه', 'جره و بالاده', 'جنت', 'جهرم', 'جوزار', 'جویم', 'چاه ورز', 'حسن آباد', 'حنا', 'خرامه', 'خرم بید', 'خشت', 'خفر', 'خنج', 'خور', 'خیرگو', 'داراب', 'درودزن', 'دشمن زیاری', 'دهرم', 'راهگان', 'رحمت آباد', 'رستاق', 'رستم', 'رونیز', 'زرقان', 'زرین دشت', 'سپیدان', 'سده', 'سرچهان', 'سروستان', 'سورنا', 'سیاخ دارنگون', 'سیدان', 'سیمکان', 'ششده و قره بلاغ', 'شیبکوه', 'صحرای باغ', 'صدرا', 'طسوج', 'علامرودشت', 'فراشبند', 'فسا', 'فسارود', 'فورگ', 'فیروزآباد', 'قطرویه', 'قیروکارزین', 'کازرون', 'کامفیروز', 'کر', 'کربال', 'کردیان', 'کنار تخته و کمار', 'کوار', 'کوه چنار', 'کوهمره', 'کوهنجان', 'گراش', 'گله دار', 'لار', 'لامرد', 'ماهورمیلاتی', 'محمله', 'مرودشت', 'مزایجان', 'مشهد مرغاب', 'مهر', 'میمند', 'نوبندگان', 'نورآباد ممسنی', 'نی ریز', 'همایجان', 'وراوی']),
  MapEntry('قزوین', ['آبگرم', 'آبیک', 'آوج', 'اسفرورین', 'اقبالیه', 'الموت', 'الوند', 'بشاریات', 'بوئین زهرا', 'تاکستان', 'خرمدشت', 'دشتابی', 'رامند', 'شال', 'ضیاءآباد', 'طارم', 'قزوین', 'کوهین', 'محمدیه']),
  MapEntry('قم', ['پردیسان', 'جعفرآباد', 'خلجستان', 'سلفچگان', 'فردو', 'قاهان', 'قم', 'قمرود', 'قنوات', 'کهک']),
  MapEntry('کردستان', ['سنندج', 'سیروان', 'قروه', 'کامیاران', 'کرانی', 'کرفتو', 'کلاترزان', 'مریوان', 'موچش', 'نمشیر', 'ننور']),
  MapEntry('کرمان', ['آسمینون', 'ارزوئیه', 'اسفندقه', 'اسماعیلی', 'انار', 'بافت', 'بردسیر', 'بلورد', 'بلوک', 'بم', 'بهرمان', 'پاریز', 'جازموریان', 'جبالبارز', 'جیرفت', 'چاه داد خدا', 'چاه مرید', 'چترود', 'حور', 'خبر', 'درب بهشت', 'دهبکری', 'دهج', 'رابر', 'راور', 'راین', 'رفسنجان', 'رودبار', 'ریگان', 'زرند', 'زیدآباد', 'سیرجان', 'شهداد', 'شهربابک', 'صوغان', 'عنبرآباد', 'فاریاب', 'فردوس', 'فهرج', 'قلعه گنج', 'کرمان', 'کشکوئیه', 'کهنوج', 'کوهبنان', 'کوهساران', 'کیانشهر', 'گلباف', 'گلزار', 'گلستان', 'گنبکی', 'لاله زار', 'ماهان', 'منوجان', 'نرمانشیر', 'نگار', 'نگین کویر', 'هنزا', 'یزدان شهر']),
  MapEntry('کرمانشاه', ['ازگله', 'اسلام‌آباد غرب', 'باوله', 'باینگان', 'بیستون', 'بیلوار', 'پاوه', 'ثلالث باباجانی', 'جوانرود', 'حمیل', 'دالاهو', 'دشت ذهاب', 'دینور', 'روانسر', 'زمکان', 'سرپل ذهاب', 'سنقر', 'سومار', 'شاهو', 'صحنه', 'فیروزآباد', 'قصرشیرین', 'قلعه شاهین', 'کرمانشاه', 'کلاشی', 'کلیائی', 'کنگاور', 'کوزران', 'گهواره', 'گوآور', 'گیلانغرب', 'ماهیدشت', 'نوسود', 'هرسین']),
  MapEntry('کهگیلویه و بویراحمد', ['باشت', 'بوستان', 'پاتاوه', 'چاروسا', 'چرام', 'چیتاب', 'دهدشت', 'دوگنبدان', 'دیشموک', 'زیلائی', 'سپیدار', 'سرآسیاب یوسفی', 'سرفاریاب', 'سوق', 'سی سخت', 'قلعه ممبی', 'لنده', 'لوداب', 'لیکک', 'مارگون', 'موگرمون', 'یاسوج']),
  MapEntry('گلستان', ['آزادشهر', 'آق قلا', 'القجر ', 'انبارآلوم', 'اینچه برون', 'بندر ترکمن', 'بندر گز', 'تاتار علیا', 'جلین', 'خان ببین', 'دلند', 'دوزین', 'رامیان', 'سرخنکلاته', 'سنگدوین', 'سیجوال', 'سیمین شهر', 'صادق آباد', 'علی آباد کتول', 'فاضل آباد', 'فراغی', 'قرق', 'کردکوی', 'کلاله', 'گالیکش', 'گرگان', 'گلی داغ', 'گمیشان', 'گنبد کاووس', 'مراوه', 'مزرعه کتول', 'مینودشت', 'نگین شهر', 'نوده خاندوز', 'نوکنده', 'ینقاق']),
  MapEntry('گیلان', ['آستارا', 'آستانه اشرفیه ', 'احمدسرگوراب', 'اسالم', 'اطاقور', 'املش', 'بره سر', 'بندرانزلی', 'پره سر', 'پیربازار', 'تالش', 'توتکابن', 'تولم شهر', 'جیرنده', 'چابکسر', 'چاف و چمخاله', 'چوبر', 'حویق', 'خشکبیجار', 'خمام', 'دیلمان', 'رانکوه', 'رحیم آباد', 'رستم آباد', 'رشت', 'رضوانشهر', 'رودبار', 'رودبنه', 'رودسر', 'زیباکنار', 'سنگر', 'سیاهکل', 'شاندرمن', 'شفت', 'شلمان', 'صومعه سرا', 'ضیابر', 'طاهرگوراب', 'فومن', 'کلاچای', 'کوچصفهان', 'کومله', 'کیاشهر', 'گوراب زرمیخ', 'لاهیجان', 'لشت نشا', 'لنگرود', 'لوشان', 'لولمان', 'لوندویل', 'لیسار', 'ماسال', 'ماسوله', 'ماکلوان', 'منجیل', 'واجارگاه']),
  MapEntry('لرستان', ['ازنا', 'اشترینان', 'الشتر', 'الیگودرز', 'بربرود', 'بروجرد', 'بیرانوند', 'پاپی', 'پلدختر', 'جاپلق', 'چگنی', 'خاوه', 'خرم آباد', 'درب گنبد', 'دورود', 'ذلقی', 'رومشکان', 'زاغه', 'ززوماهرو', 'سوری', 'سیلاخور', 'شاهیوند', 'شیروان', 'طرهان', 'فیروزآباد', 'کاکاوند', 'کوهدشت', 'کوهنانی', 'معمولان', 'نورآباد', 'ویسیان']),
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
  const LoginFlow({super.key, this.startAtAccount = false});
  final bool startAtAccount;
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
  bool _fromDashboard = false;

  @override
  void initState() {
    super.initState();
    if (widget.startAtAccount) {
      _fromDashboard = true;
      _step = _LoginStep.account;
      final record = pb.authStore.record;
      if (record != null) {
        _phoneController.text = (record.data['phone'] ?? '').toString();
        _nameController.text = (record.data['name'] ?? '').toString();
        _lastNameController.text = (record.data['last_name'] ?? record.data['lastname'] ?? '').toString();
        final role = (record.data['role'] ?? '').toString();
        _role = _normalizeRole(role);
        _ownership = (record.data['ownership'] ?? 'ساکن').toString();
        _buildingController.text = (record.data['building_name'] ?? '').toString();
        _showMyBuildings = record.data['show_my_buildings'] == true;
      }
    }
  }

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
      setState(() => _step = _LoginStep.phone);
      break;
    case _LoginStep.account:
      setState(() {
        _step = _fromDashboard ? _LoginStep.dashboard : _LoginStep.otp;
        _fromDashboard = false;
      });
      break;
    case _LoginStep.success:
      // بعد از موفقیت، کاربر نباید به صفحه ساخت حساب برگردد.
      // می‌توانید آن را به خوش‌آمدگویی هدایت کنید یا خروج از برنامه بگذارید:
      SystemNavigator.pop(); 
      break;
    case _LoginStep.managerChoice:
      setState(() {
        _step = _fromDashboard ? _LoginStep.dashboard : _LoginStep.account;
        _fromDashboard = false;
      });
      break;
    case _LoginStep.dashboard:
      // در صفحه داشبورد اصلی، دکمه برگشت نباید به مراحل ثبت نام برگردد.
      // معمولاً در داشبورد با زدن دکمه برگشت، یا از برنامه خارج می‌شوند یا هشدار خروج نشان داده می‌شود:
      SystemNavigator.pop();
      break;
    case _LoginStep.welcome:
      SystemNavigator.pop();
      break;
  }
}


  Future<void> _resendOtp() async {
    if (_isSendingOtp) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() => _isSendingOtp = true);
    unawaited(_sendOtpInBackground(phone, isResend: true));
  }

  Future<void> _submitPhone() async {
    if (_isSendingOtp || !(_phoneKey.currentState?.validate() ?? false)) return;
    _phoneController.text = _latinDigits(_phoneController.text).replaceAll(' ', '').trim();
    final phone = _phoneController.text;
    setState(() {
      _isSendingOtp = true;
      _step = _LoginStep.otp;
    });
    _otpController.clear();
    _startCountdown();
    // Do not keep the user waiting for the network before showing the OTP screen.
    unawaited(_sendOtpInBackground(phone));
  }

  Future<void> _sendOtpInBackground(String phone, {bool isResend = false}) async {
    try {
      final response = await pb.send<Map<String, dynamic>>(
        '/api/send-otp',
        method: 'POST',
        body: {'phone': phone},
      );
      if (!mounted) return;
      if (response['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isResend
              ? 'ارسال مجدد کد تأیید ناموفق بود. لطفاً دوباره تلاش کنید.'
              : 'ارسال کد تأیید ناموفق بود. لطفاً دوباره تلاش کنید.'),
        ));
        return;
      }
      if (isResend) {
        _otpController.clear();
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کد تأیید مجدداً ارسال شد.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isResend
            ? 'ارسال پیامک انجام نشد. اتصال خود را بررسی و دوباره تلاش کنید.'
            : 'ارسال پیامک انجام نشد. اتصال خود را بررسی و دوباره تلاش کنید.'),
      ));
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
      _role = _normalizeRole(existingRole);
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
      // The server is the source of truth. Persist its refreshed auth record locally as
      // well, so the restored session uses the edited profile after an app restart.
      final currentToken = pb.authStore.token;
      final currentRecord = pb.authStore.record;
      if (currentToken.isNotEmpty && currentRecord != null) {
        final returnedRecord = response['record'];
        final updatedRecord = returnedRecord is Map
            ? RecordModel.fromJson(Map<String, dynamic>.from(returnedRecord))
            : currentRecord;
        if (returnedRecord is! Map) {
          updatedRecord.data.addAll({
            'phone': phone,
            'name': name,
            'last_name': lastName,
            'role': role,
            'ownership': ownership,
            'building_name': buildingName,
          });
        }
        pb.authStore.save(currentToken, updatedRecord);
      }

      if (!mounted) return;
      // پس از ذخیره، صفحهٔ ویرایش باز می‌ماند تا کاربر پیام را ببیند و خودش بازگردد.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('تغییرات با موفقیت ذخیره شد'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
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
            child: DashboardPage(name: _nameController.text.trim(), role: _role ?? 'ساکن', buildingName: _buildingController.text.trim(), ownership: _ownership ?? 'ساکن', showMyBuildings: _showMyBuildings, onSwitch: () => setState(() { _fromDashboard = true; _step = _LoginStep.account; }), onRoleChanged: (role) => setState(() => _role = role)),
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
      _primaryButton(label: 'ثبت تغییرات', onPressed: _submitAccount),
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
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => _selectRole('خدماتی'), icon: const Icon(Icons.handyman_outlined), label: const Text('نیروی خدماتی')),
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

  _Building buildingByName(String name, {String address = ''}) {
    final displayName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    _Building? existing;
    for (final item in buildings.values) { if (_key(item.name) == _key(displayName) && (address.isEmpty || _key(item.address) == _key(address))) { existing = item; break; } }
    if (existing != null) return existing;
    final key = '${_key(displayName)}|${_key(address)}';
    return buildings.putIfAbsent(key, () => _Building(displayName, address: address.trim()));
  }

  List<_Building> search(String query) {
    final q = _normalizeSearchText(query);
    if (q.isEmpty) return [];
    return buildings.values.where((b) {
      final searchable = _normalizeSearchText('${b.name} ${b.province} ${b.city} ${b.address}');
      final code = _normalizeSearchText(b.buildingCode);
      return searchable.contains(q) || (code.isNotEmpty && code.contains(q));
    }).toList();
  }

  bool exists(String name) => findByName(name) != null;
}

String _buildingCacheKey(_Building b) {
  final identity = b.recordId?.isNotEmpty == true ? b.recordId! : '${b.name.trim()}|${b.address.trim()}';
  return 'b_floors_${Uri.encodeComponent(identity)}';
}

Map<String, dynamic> _buildingStructure(_Building b) => <String, dynamic>{
  'floors': {for (final e in b.floors.entries) e.key.toString(): e.value},
  'floor_units': {for (final e in b.floorUnits.entries) e.key.toString(): e.value},
  'occupants': {for (final e in b.occupants.entries) e.key: {
    'name': e.value.name, 'role': e.value.role, 'ownership': e.value.ownership,
    'phone': e.value.phone, 'waterDebt': e.value.waterDebt,
    'movedInAt': e.value.movedInAt.toIso8601String(),
  }},
};

void _applyBuildingStructure(_Building b, dynamic raw) {
  dynamic value = raw;
  if (value is String && value.trim().isNotEmpty) {
    try { value = jsonDecode(value); } catch (_) { return; }
  }
  if (value is! Map) return;
  final data = Map<String, dynamic>.from(value);
  final rawFloors = data['floors'];
  if (rawFloors is Map) {
    for (final entry in rawFloors.entries) {
      final floor = int.tryParse(entry.key.toString());
      final count = int.tryParse(entry.value.toString());
      if (floor == null || count == null || floor < 1 || count < 1 || count > 50) continue;
      if (!b.floors.containsKey(floor)) b.addFloor(floor, count);
      else if ((b.floorUnits[floor]?.length ?? 0) != count) b.updateUnits(floor, count);
    }
  }
  final rawUnits = data['floor_units'] ?? data['floorUnits'];
  if (rawUnits is Map) {
    for (final entry in rawUnits.entries) {
      final floor = int.tryParse(entry.key.toString());
      final unitsRaw = entry.value;
      if (floor == null || !b.floors.containsKey(floor) || unitsRaw is! List) continue;
      final units = unitsRaw.map((v) => int.tryParse(v.toString())).whereType<int>().where((v) => v > 0).toList();
      if (units.isNotEmpty) b.updateFloorUnits(floor, units);
    }
  }
  final rawOccupants = data['occupants'];
  if (rawOccupants is Map && b.occupants.isEmpty) {
    for (final entry in rawOccupants.entries) {
      final item = entry.value;
      if (item is! Map) continue;
      final d = Map<String, dynamic>.from(item);
      final date = DateTime.tryParse((d['movedInAt'] ?? '').toString());
      b.occupants[entry.key.toString()] = _Member(
        (d['name'] ?? '').toString(), (d['role'] ?? 'ساکن').toString(),
        (d['ownership'] ?? 'ساکن').toString(), phone: (d['phone'] ?? '').toString(),
        waterDebt: int.tryParse((d['waterDebt'] ?? 0).toString()) ?? 0, movedInAt: date,
      );
    }
  }
}

void _applyBuildingRecord(_Building b, RecordModel record) {
  final data = record.data;
  b.recordId = record.id;
  b.createdBy = (data['created_by'] ?? b.createdBy ?? '').toString();
  final code = (data['building_code'] ?? '').toString().trim();
  if (code.isNotEmpty) b.buildingCode = code;
  final address = (data['address'] ?? '').toString().trim();
  if (address.isNotEmpty) b.address = address;
  b.province = (data['province'] ?? data['state'] ?? b.province).toString().trim();
  b.city = (data['city'] ?? data['town'] ?? b.city).toString().trim();
  final structure = data['floors_data'];
  if (structure != null) _applyBuildingStructure(b, structure);
  if (b.floors.isEmpty && data['floors'] != null) _applyBuildingStructure(b, {'floors': data['floors']});
}

Future<void> _persistBuilding(_Building b) async {
  final structure = _buildingStructure(b);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_buildingCacheKey(b), jsonEncode({
      'name': b.name, 'address': b.address, 'building_code': b.buildingCode,
      'province': b.province, 'city': b.city,
      'recordId': b.recordId, 'created_by': b.createdBy, 'floors_data': structure,
    }));
  } catch (_) {}
  final id = b.recordId;
  if (id == null || id.isEmpty || !pb.authStore.isValid) return;
  // Keep the JSON structure canonical on servers with a JSON field. For older
  // collections, the local durable cache still protects all floor/unit data.
  try {
    await pb.collection('buildings').update(id, body: {'floors_data': structure});
  } catch (_) {
    try { await pb.collection('buildings').update(id, body: {'floors': structure['floors']}); } catch (_) {}
  }
}

Future<_Building?> _restoreCachedBuilding(String cacheKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    final d = Map<String, dynamic>.from(data);
    final name = (d['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final b = AppSharedState.instance.buildingByName(name, address: (d['address'] ?? '').toString());
    b.recordId = (d['recordId'] ?? '').toString().isEmpty ? null : d['recordId'].toString();
    b.createdBy = (d['created_by'] ?? '').toString().isEmpty ? null : d['created_by'].toString();
    b.buildingCode = (d['building_code'] ?? '').toString();
    b.province = (d['province'] ?? '').toString();
    b.city = (d['city'] ?? '').toString();
    _applyBuildingStructure(b, d['floors_data']);
    return b;
  } catch (_) { return null; }
}

String _cleanMemberPhone(String phone) => _latinDigits(phone.replaceAll(RegExp(r'\s+|-'), '')).trim();

String _residentMembershipKey(String userId) => 'resident_membership_$userId';

Future<void> _cacheResidentMembership(String userId, _Building building, int floor, int unit) async {
  if (userId.isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_residentMembershipKey(userId), jsonEncode({
      'building_id': building.recordId, 'building_name': building.name,
      'address': building.address, 'building_code': building.buildingCode,
      'floor': floor, 'unit': unit,
    }));
  } catch (_) {}
}

/// Best-effort member sync. The compact core payload is retried if a deployment
/// has not yet added the optional building/floor/unit_number fields.
Future<void> _syncMemberRecord(_Building building, int floor, int unit, _Member member) async {
  if (!pb.authStore.isValid) return;
  final current = pb.authStore.record;
  final phone = _cleanMemberPhone(member.phone);
  var targetUserId = '';
  if (current != null && (phone.isEmpty || _cleanMemberPhone((current.data['phone'] ?? '').toString()) == phone)) {
    targetUserId = current.id;
  }
  if (targetUserId.isEmpty && phone.isNotEmpty) {
    try {
      final users = await pb.collection('users').getList(
        page: 1, perPage: 1,
        filter: 'phone = "${phone.replaceAll('"', '\\"')}"',
      );
      if (users.items.isNotEmpty) targetUserId = users.items.first.id;
    } catch (_) {}
  }
  if (targetUserId.isEmpty) return; // Can't create a valid PocketBase user relation.
  final unitKey = building.unitId(floor, unit);
  final requiredBody = <String, dynamic>{
    'status': 'active', 'user': targetUserId, 'unit': unitKey,
    'type': member.role, 'is_resident': member.role != 'مدیر',
  };
  final extendedBody = <String, dynamic>{
    ...requiredBody,
    if ((building.recordId ?? '').isNotEmpty) 'building': building.recordId,
    'building_name': building.name, 'floor': floor, 'unit_number': unit,
  };
  try {
    // Update an existing record for this user's unit instead of generating duplicates.
    final matches = await pb.collection('members').getList(
      page: 1, perPage: 50,
      filter: 'user = "$targetUserId" && unit = "$unitKey"',
    );
    if (matches.items.isNotEmpty) {
      try {
        await pb.collection('members').update(matches.items.first.id, body: extendedBody);
      } catch (_) {
        await pb.collection('members').update(matches.items.first.id, body: requiredBody);
      }
    } else {
      try {
        await pb.collection('members').create(body: extendedBody);
      } catch (_) {
        await pb.collection('members').create(body: requiredBody);
      }
    }
  } catch (_) {
    try { await pb.collection('members').create(body: requiredBody); } catch (_) {}
  }
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
  _ChargeSettingTopic(this.title, {DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now(),
        deadline = (createdAt ?? DateTime.now()).add(const Duration(days: 7));
  final String title;
  final DateTime createdAt;
  final DateTime deadline;
  bool get isActive => DateTime.now().isBefore(deadline);
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
    if (!isActive) return false;
    if (proposals.any((p) => p.amount == amount)) return false;
    proposals.add(_ChargeProposal(amount: amount, unitId: unitId, authorName: authorName));
    return true;
  }

  bool vote(String unitId, int amount) {
    if (!isActive) return false;
    if (votesByUnitId.containsKey(unitId)) return false;
    if (!proposals.any((p) => p.amount == amount)) return false;
    votesByUnitId[unitId] = amount;
    return true;
  }
}
class _Building {
  _Building(this.name, {this.createdBy, this.address = '', this.buildingCode = '', String province = '', String city = '', this.recordId}) : province = province, city = city;
  String name;
  String address;
  String buildingCode;
  String province = '';
  String city = '';
  String? recordId;
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
  /// بدهی آب به تفکیک واحد و شناسهٔ قبض: unitId -> {billId -> amount}.
  final Map<String, Map<String, int>> waterDebtByUnitAndBill = {};
  int totalWaterDebtFor(String unitId) => waterDebtByUnitAndBill[unitId]?.values.fold<int>(0, (a, b) => a + b) ?? 0;
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

  bool hasOccupantWithPhone(String phone, {String? excludeKey}) {
    final clean = _latinDigits(phone.replaceAll(RegExp(r'\s+|-'), '')).trim();
    if (clean.isEmpty) return false;
    for (final entry in occupants.entries) {
      if (excludeKey != null && entry.key == excludeKey) continue;
      final p = _latinDigits(entry.value.phone.replaceAll(RegExp(r'\s+|-'), '')).trim();
      if (p.isNotEmpty && p == clean) return true;
    }
    return false;
  }

  String? assign(int floor, int unit, _Member member) {
    final key = '$floor/$unit';
    if (occupants.containsKey(key)) return 'این واحد قبلاً به ${occupants[key]!.name} اختصاص یافته است.';
    if (member.phone.isNotEmpty && hasOccupantWithPhone(member.phone, excludeKey: key)) {
      return 'کاربری با این شماره تماس قبلاً در واحد دیگری ثبت شده است و امکان اشغال بیش از یک واحد وجود ندارد.';
    }
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
    this.onRoleChanged,
  });
  final String name;
  final String role;
  final String buildingName;
  final String ownership;
  final bool showMyBuildings;
  final VoidCallback? onSwitch;
  final ValueChanged<String>? onRoleChanged;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedTab = 0;
  _Building? _joinedBuilding;
  int? _myFloor;
  int? _myUnit;
  String? _roleOverride;
  bool _isChangingRole = false;
  List<String> _serviceSpecialties = <String>[];

  String get _currentRole => _roleOverride ?? widget.role;
  bool get _isManager => _currentRole == 'مدیر';

  @override
  void initState() {
    super.initState();
    _loadServiceSpecialties();
    if (_isManager && pb.authStore.isValid) {
      _loadManagerBuildings();
    } else if (!_isManager) {
      _restoreResidentMembership();
    }
  }

  String get _serviceSpecialtiesKey => 'service_specialties_${pb.authStore.record?.id ?? 'guest'}';

  Future<void> _loadServiceSpecialties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_serviceSpecialtiesKey) ?? <String>[];
      if (mounted) setState(() => _serviceSpecialties = saved);
    } catch (_) {}
  }

  Future<void> _saveServiceSpecialties(List<String> values) async {
    final cleaned = values.toSet().toList();
    if (mounted) setState(() => _serviceSpecialties = cleaned);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_serviceSpecialtiesKey, cleaned);
      // Keep specialties in the locally cached auth metadata as well.
      final token = pb.authStore.token;
      final record = pb.authStore.record;
      if (token.isNotEmpty && record != null) {
        record.data['service_specialties'] = cleaned;
        pb.authStore.save(token, record);
      }
    } catch (_) {}
  }

  Future<void> _restoreResidentMembership() async {
    final userId = pb.authStore.record?.id ?? '';
    if (userId.isEmpty) return;
    Map<String, dynamic>? membership;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_residentMembershipKey(userId));
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) membership = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    // Query the durable member record and let the server copy supersede local cache.
    if (pb.authStore.isValid) {
      try {
        final records = await pb.collection('members').getFullList(
          filter: 'user = "$userId" && status = "active"', sort: '-created', batch: 200,
        );
        if (records.isNotEmpty) {
          final data = records.first.data;
          final unitRaw = (data['unit'] ?? '').toString();
          final parts = unitRaw.split('/');
          final floor = int.tryParse((data['floor'] ?? (parts.length == 2 ? parts[0] : '')).toString());
          final unit = int.tryParse((data['unit_number'] ?? (parts.length == 2 ? parts[1] : '')).toString());
          if (floor != null && unit != null) {
            membership = {
              'building_id': data['building'] ?? data['building_id'],
              'building_name': data['building_name'], 'address': data['address'],
              'building_code': data['building_code'], 'floor': floor, 'unit': unit,
            };
          }
        }
      } catch (_) {}
    }
    if (membership == null) return;
    final floor = int.tryParse((membership!['floor'] ?? '').toString());
    final unit = int.tryParse((membership['unit'] ?? '').toString());
    if (floor == null || unit == null) return;
    _Building? building;
    final buildingId = (membership['building_id'] ?? '').toString();
    final buildingName = (membership['building_name'] ?? '').toString().trim();
    if (buildingId.isNotEmpty) {
      for (final candidate in AppSharedState.instance.buildings.values) {
        if (candidate.recordId == buildingId) { building = candidate; break; }
      }
    }
    if (building == null && buildingName.isNotEmpty) {
      building = AppSharedState.instance.buildingByName(buildingName, address: (membership['address'] ?? '').toString());
      if (building.recordId == null && buildingId.isNotEmpty) building.recordId = buildingId;
      building.buildingCode = (membership['building_code'] ?? building.buildingCode).toString();
    }
    // Fetch authoritative building structure if it isn't already known locally.
    if (building != null && building.floors.isEmpty && building.recordId != null && pb.authStore.isValid) {
      try {
        final record = await pb.collection('buildings').getOne(building.recordId!);
        _applyBuildingRecord(building, record);
      } catch (_) {}
    }
    if (building != null && building.floors.isEmpty) {
      final cached = await _restoreCachedBuilding(_buildingCacheKey(building));
      if (cached != null) _applyBuildingStructure(building, _buildingStructure(cached));
    }
    if (building == null || !building.floors.containsKey(floor) || !(building.floorUnits[floor] ?? []).contains(unit)) return;
    final member = _Member(widget.name, 'ساکن', widget.ownership,
      phone: (pb.authStore.record?.data['phone'] ?? '').toString());
    final key = building.unitId(floor, unit);
    if (!building.occupants.containsKey(key)) building.assign(floor, unit, member);
    if (mounted) setState(() { _joinedBuilding = building; _myFloor = floor; _myUnit = unit; });
    unawaited(_cacheResidentMembership(userId, building, floor, unit));
  }

  Future<void> _loadManagerBuildings() async {
    final userId = pb.authStore.record?.id;
    if (userId == null || userId.isEmpty) return;
    // Restore the durable local cache first, so management remains usable offline.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith('b_floors_'))) {
        final cached = await _restoreCachedBuilding(key);
        if (cached != null && cached.createdBy == userId) {
          AppSharedState.instance.buildings['${AppSharedState.instance._key(cached.name)}|${AppSharedState.instance._key(cached.address)}'] = cached;
        }
      }
    } catch (_) {}
    try {
      final records = await pb.collection('buildings').getFullList(
        filter: 'created_by = "$userId"', sort: '-created', batch: 200,
      );
      final loaded = <_Building>[];
      for (final record in records) {
        final name = (record.data['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final address = (record.data['address'] ?? '').toString().trim();
        final building = AppSharedState.instance.buildingByName(name, address: address);
        _applyBuildingRecord(building, record);
        final cache = await _restoreCachedBuilding(_buildingCacheKey(building));
        if (building.floors.isEmpty && cache != null) _applyBuildingStructure(building, _buildingStructure(cache));
        await _persistBuilding(building);
        loaded.add(building);
      }
      if (mounted && loaded.isNotEmpty && _joinedBuilding == null) {
        setState(() => _joinedBuilding = loaded.first);
      }
    } catch (_) {
      // The locally cached buildings above are still available offline.
      if (mounted && _joinedBuilding == null) {
        final userBuildings = AppSharedState.instance.buildings.values.where((b) => b.createdBy == userId).toList();
        if (userBuildings.isNotEmpty) setState(() => _joinedBuilding = userBuildings.first);
      }
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _changeRole(String newRole) async {
    if (_isChangingRole || newRole == _currentRole) return;
    final record = pb.authStore.record;
    if (record == null || !pb.authStore.isValid) {
      _toast('نشست کاربری معتبر نیست؛ لطفاً دوباره وارد شوید.', error: true);
      return;
    }

    setState(() => _isChangingRole = true);
    try {
      final data = record.data;
      final response = await pb.send<Map<String, dynamic>>(
        '/api/update-profile',
        method: 'POST',
        body: {
          'phone': (data['phone'] ?? '').toString(),
          'name': (data['name'] ?? '').toString(),
          'last_name': (data['last_name'] ?? data['lastname'] ?? '').toString(),
          'role': newRole,
          'ownership': (data['ownership'] ?? widget.ownership).toString(),
          'building_name': (data['building_name'] ?? widget.buildingName).toString(),
        },
      );

      if (!mounted) return;
      if (response['success'] != true || response['record'] is! Map) {
        _toast((response['error'] ?? 'به‌روزرسانی نقش انجام نشد.').toString(), error: true);
        return;
      }

      final updatedRecord = RecordModel.fromJson(
        Map<String, dynamic>.from(response['record'] as Map),
      );
      final token = pb.authStore.token;
      if (token.isEmpty) {
        _toast('نشست کاربری معتبر نیست؛ لطفاً دوباره وارد شوید.', error: true);
        return;
      }
      pb.authStore.save(token, updatedRecord);
      setState(() {
        _roleOverride = newRole;
        selectedTab = 0;
      });
      widget.onRoleChanged?.call(newRole);
      _toast('نقش شما به «$newRole» تغییر کرد.');
    } catch (err) {
      if (mounted) _toast('خطا در تغییر نقش: $err', error: true);
    } finally {
      if (mounted) setState(() => _isChangingRole = false);
    }
  }

  Future<void> _showRoleDialog() async {
    final selectedRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغییر نقش'),
        content: const Text('نقش موردنظر خود را انتخاب کنید.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'ساکن'),
            child: const Text('ساکن'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'مدیر'),
            child: const Text('مدیر'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'خدماتی'),
            icon: const Icon(Icons.handyman_outlined),
            label: const Text('نیروی خدماتی'),
          ),
        ],
      ),
    );
    if (selectedRole != null) await _changeRole(selectedRole);
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
      0 => _currentRole == 'خدماتی'
          ? _ServiceHome(name: widget.name, specialties: _serviceSpecialties, showRequestsOnly: true)
          : _FeatureHub(index: 1, isManager: _isManager, building: _joinedBuilding),
      1 => _FeatureHub(index: 2, isManager: _isManager, building: _joinedBuilding),
      2 => _currentRole == 'خدماتی'
          ? _ServiceHome(name: widget.name, specialties: _serviceSpecialties)
          : _isManager ? _ManagerHome(building: _joinedBuilding, managerName: widget.name, showMyBuildings: widget.showMyBuildings, onBuildingChanged: (building) => setState(() { _joinedBuilding = building; })) : _ResidentHome(
          building: _joinedBuilding,
          name: widget.name,
          myFloor: _myFloor,
          myUnit: _myUnit,
          ownership: widget.ownership,
          onJoined: (building, floor, unit) => setState(() { _joinedBuilding = building; _myFloor = floor; _myUnit = unit; }),
        ),
      3 => _FeatureHub(index: 3, isManager: _isManager, building: _joinedBuilding),
      4 => _SettingsPage(
          onEditAccount: widget.onSwitch ?? () {},
          onLogout: _logout,
          onRoleChange: _showRoleDialog,
          onSubscription: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _FeaturePage(
              item: const _FeatureItem('اشتراک برنامه', 'آزمایش رایگان سه‌ماهه و انتخاب طرح', Icons.workspace_premium_rounded, 'subscription'),
              building: _joinedBuilding,
            ),
          )),
          phoneNumber: (pb.authStore.record?.data['phone'] ?? 'نامشخص').toString(),
          role: _currentRole,
          specialties: _serviceSpecialties,
          onSpecialtiesChanged: _saveServiceSpecialties,
        ),
      _ => _FeatureHub(index: 1, isManager: _isManager, building: _joinedBuilding),
    };
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سلام، ${widget.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_isManager ? 'نقش شما: مدیر ساختمان' : _currentRole == 'خدماتی' ? 'نقش شما: نیروی خدماتی' : 'نقش شما: ساکن', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ]),
        actions: [
          if (!_isManager && _joinedBuilding != null)
            IconButton(
              tooltip: 'خروج از ساختمان',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => setState(() { _joinedBuilding = null; _myFloor = null; _myUnit = null; }),
            ),

        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman_rounded), label: 'درخواست‌ها'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: 'اطلاعیه‌ها'),
          NavigationDestination(icon: Icon(Icons.home_outlined, size: 30), selectedIcon: Icon(Icons.home_rounded, size: 34), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'امور مالی'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'تنظیمات'),
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
  final TextEditingController _addressController = TextEditingController();
  final _createFormKey = GlobalKey<FormState>();
  final _floorController = TextEditingController();
  final _unitsController = TextEditingController();
  bool _continueUnitNumbers = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
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

  /// ایجاد ساختمان در PocketBase و سپس به‌روزرسانی مدل محلی و طبقات.
  Future<void> _createBuildingWithFloors() async {
    if (!(_createFormKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final floorCount = int.parse(_latinDigits(_floorController.text.trim()));
    final unitsPerFloor = int.parse(_latinDigits(_unitsController.text.trim()));
    final isNew = !AppSharedState.instance.buildings.values.any((item) => item.name.trim().toLowerCase() == name.toLowerCase() && item.address.trim().toLowerCase() == address.toLowerCase());
    final b = AppSharedState.instance.buildingByName(name, address: address);
    if (isNew || b.createdBy == null) b.createdBy = pb.authStore.record?.id ?? widget.managerName;
    b.address = address;
    if (isNew && b.recordId == null) {
      final code = await _generateUniqueBuildingCode();
      b.buildingCode = code;
      try {
        final body = <String, dynamic>{'name': name, 'address': address, 'created_by': pb.authStore.record?.id, 'building_code': code};
        try {
          final record = await pb.collection('buildings').create(body: body);
          b.recordId = record.id;
          final savedCode = (record.data['building_code'] ?? '').toString().trim();
          if (savedCode.isNotEmpty) b.buildingCode = savedCode;
        } on ClientException catch (e) {
          // Older schemas may not yet contain building_code. Retry only when the
          // server explicitly reports that field as invalid/missing.
          final details = '${e.response} ${e.originalError}'.toLowerCase();
          if (e.statusCode == 400 && details.contains('building_code')) {
            final fallback = Map<String, dynamic>.from(body)..remove('building_code');
            final record = await pb.collection('buildings').create(body: fallback);
            b.recordId = record.id;
          } else {
            rethrow;
          }
        }
        _toast('ساختمان در پاکت‌بیس ذخیره شد. کد ساختمان: ${b.buildingCode.toPersianDigits()}');
      } catch (e) {
        _toast('ثبت در پاکت‌بیس انجام نشد؛ اطلاعات در حافظهٔ برنامه حفظ شد. $e', error: true);
      }
    }
    _nameController.text = b.name;
    _addressController.text = b.address;
    widget.onBuildingChanged(b);
    if (b.floors.isNotEmpty && !isNew) {
      _toast('ساختمان «${b.name}» از قبل ساخته شده است؛ با کلیک روی نام آن وارد شوید.');
      return;
    }
    for (var i = 0; i < floorCount; i++) {
      final floorNumber = (b.floors.keys.fold<int>(0, (m, f) => f > m ? f : m)) + 1;
      if (!b.addFloor(floorNumber, unitsPerFloor, continueNumbering: _continueUnitNumbers)) break;
    }
    await _persistBuilding(b);
    widget.onBuildingChanged(b);
    _toast('ساختمان «${b.name}» با ${floorCount.toPersianDigits()} طبقه ساخته شد. کد: ${b.buildingCode.toPersianDigits()}');
  }

  Future<String> _generateUniqueBuildingCode() async {
    final random = Random.secure();
    final known = AppSharedState.instance.buildings.values.map((b) => b.buildingCode).where((c) => c.isNotEmpty).toSet();
    try {
      final records = await pb.collection('buildings').getFullList(fields: 'building_code', batch: 200);
      for (final record in records) { final code = (record.data['building_code'] ?? '').toString(); if (code.isNotEmpty) known.add(code); }
    } catch (_) { /* Offline/server schema without the code field: local uniqueness still applies. */ }
    for (var attempt = 0; attempt < 1000; attempt++) {
      final candidate = (100000 + random.nextInt(900000)).toString();
      if (!known.contains(candidate)) return candidate;
    }
    return DateTime.now().microsecondsSinceEpoch.toString().substring(7, 13);
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

  Future<void> _deleteManagedBuilding(_Building building) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف ساختمان'),
        content: const Text('آیا از حذف این ساختمان اطمینان دارید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    var serverDeleted = building.recordId == null || building.recordId!.isEmpty;
    if (building.recordId != null && building.recordId!.isNotEmpty) {
      try {
        await pb.collection('buildings').delete(building.recordId!);
        serverDeleted = true;
      } catch (_) {
        // Remove from this device even when offline; server deletion can be retried later.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_buildingCacheKey(building));
    AppSharedState.instance.buildings.removeWhere((key, value) =>
        identical(value, building) ||
        (building.recordId?.isNotEmpty == true && value.recordId == building.recordId) ||
        (value.name.trim().toLowerCase() == building.name.trim().toLowerCase() &&
         value.address.trim().toLowerCase() == building.address.trim().toLowerCase()));
    if (!mounted) return;
    setState(() {});
    if (serverDeleted) {
      _toast('ساختمان «${building.name}» حذف شد.');
    } else {
      _toast('ساختمان از این دستگاه حذف شد؛ حذف از سرور به‌دلیل قطع اتصال انجام نشد.', error: true);
    }
  }

  Widget _myBuildingsSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final buildings = AppSharedState.instance.buildings.values
        .where((b) => b.createdBy == (pb.authStore.record?.id ?? widget.managerName) ||
            b.createdBy == widget.managerName || b.occupants.values.any((m) => m.name == widget.managerName))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 8, top: 8),
        child: Text('ساختمان‌های تحت مدیریت و ایجادشده', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      if (buildings.isEmpty)
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text('ساختمانی تحت مدیریت شما ثبت نشده است.', textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant)),
        ))
      else
        ...buildings.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (b.address.isNotEmpty) Text(b.address, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  ])),
                  IconButton(
                    tooltip: 'حذف ساختمان',
                    icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                    onPressed: () => _deleteManagedBuilding(b),
                  ),
                  Icon(Icons.chevron_left_rounded, color: colors.onSurfaceVariant),
                ]),
              ),
            ),
          ),
        )),
    ]);
  }

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
                TextFormField(
                  controller: _addressController,
                  decoration: _deco(context, 'آدرس کامل و الزامی ساختمان', Icons.place_outlined),
                  maxLines: 2,
                  validator: (v) => (v?.trim().length ?? 0) >= 5 ? null : 'آدرس ساختمان را کامل و الزامی وارد کنید.',
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
        _myBuildingsSection(context),
        const SizedBox(height: 8),
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
                    Text('${b.address}\nکد ساختمان: ${b.buildingCode.toPersianDigits()}\n${b.floors.length.toPersianDigits()} طبقه — ${b.floors.values.fold<int>(0, (sum, n) => sum + n).toPersianDigits()} واحد', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BuildingLayout(building: b, highlightMemberName: widget.managerName),
        ],
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
  final _joinedSearchController = TextEditingController();
  final List<_Building> _joinedBuildings = [];
  bool _isLoadingJoined = false;
  String? _foundBuildingName;
  final List<_Building> _searchResults = [];
  _Building? _selectedBuilding;
  bool _isSearching = false;
  bool _searchByBuildingName = true;
  bool _searchByUniqueCode = true;
  bool _searchByCity = true;
  bool _searchByProvince = true;

  bool _matchesSelectedSearchFields(_Building building, String query) {
    final q = _normalizeSearchText(query);
    if (q.isEmpty) return true;
    final fields = <String>[
      if (_searchByBuildingName) building.name,
      if (_searchByUniqueCode) building.buildingCode,
      if (_searchByCity) building.city,
      if (_searchByProvince) building.province,
    ];
    return fields.any((field) {
      final normalized = _normalizeSearchText(field);
      return normalized.isNotEmpty && normalized.contains(q);
    });
  }

  Widget _searchFieldFilters() => Wrap(
    spacing: 4,
    runSpacing: 0,
    children: [
      _searchFilter('بر اساس نام ساختمان', _searchByBuildingName, (value) => setState(() => _searchByBuildingName = value)),
      _searchFilter('شناسه یکتا', _searchByUniqueCode, (value) => setState(() => _searchByUniqueCode = value)),
      _searchFilter('شهر', _searchByCity, (value) => setState(() => _searchByCity = value)),
      _searchFilter('استان', _searchByProvince, (value) => setState(() => _searchByProvince = value)),
    ],
  );

  Widget _searchFilter(String label, bool selected, ValueChanged<bool> onChanged) =>
      FilterChip(label: Text(label), selected: selected, onSelected: onChanged, visualDensity: VisualDensity.compact);

  @override
  void initState() {
    super.initState();
    _loadJoinedBuildings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _joinedSearchController.dispose();
    super.dispose();
  }
  bool _isJoinedByCurrentResident(_Building building) {
    final userId = pb.authStore.record?.id ?? '';
    final phone = _cleanMemberPhone((pb.authStore.record?.data['phone'] ?? '').toString());
    return building.occupants.values.any((member) => member.role != 'مدیر' && (
      (phone.isNotEmpty && _cleanMemberPhone(member.phone) == phone) ||
      (widget.name.trim().isNotEmpty && _normalizeSearchText(member.name) == _normalizeSearchText(widget.name))
    )) || (userId.isNotEmpty && building.createdBy == userId && building.occupants.values.any((m) => m.role != 'مدیر'));
  }

  Future<void> _loadJoinedBuildings() async {
    if (_isLoadingJoined) return;
    _isLoadingJoined = true;
    final found = <String, _Building>{};
    void add(_Building building) {
      final key = building.recordId?.isNotEmpty == true
          ? 'id:${building.recordId}'
          : '${_normalizeSearchText(building.name)}|${_normalizeSearchText(building.address)}';
      found[key] = building;
    }
    for (final building in AppSharedState.instance.buildings.values) {
      if (_isJoinedByCurrentResident(building)) add(building);
    }
    final userId = pb.authStore.record?.id ?? '';
    if (userId.isNotEmpty && pb.authStore.isValid) {
      try {
        final records = await pb.collection('members').getFullList(
          filter: 'user = "$userId" && status = "active"', sort: '-created', batch: 200,
        );
        for (final memberRecord in records) {
          final data = memberRecord.data;
          final buildingId = (data['building'] ?? data['building_id'] ?? '').toString();
          final buildingName = (data['building_name'] ?? '').toString().trim();
          _Building? building;
          for (final candidate in AppSharedState.instance.buildings.values) {
            if ((buildingId.isNotEmpty && candidate.recordId == buildingId) ||
                (buildingName.isNotEmpty && _normalizeSearchText(candidate.name) == _normalizeSearchText(buildingName))) {
              building = candidate;
              break;
            }
          }
          if (building == null && buildingId.isNotEmpty) {
            try {
              final record = await pb.collection('buildings').getOne(buildingId);
              final name = (record.data['name'] ?? '').toString().trim();
              if (name.isNotEmpty) {
                building = AppSharedState.instance.buildingByName(name, address: (record.data['address'] ?? '').toString());
                _applyBuildingRecord(building, record);
                if (building.floors.isEmpty) {
                  final cache = await _restoreCachedBuilding(_buildingCacheKey(building));
                  if (cache != null) _applyBuildingStructure(building, _buildingStructure(cache));
                }
              }
            } catch (_) {}
          }
          if (building == null && buildingName.isNotEmpty) {
            building = AppSharedState.instance.buildingByName(buildingName, address: (data['address'] ?? '').toString());
            building.recordId = buildingId.isEmpty ? building.recordId : buildingId;
            building.buildingCode = (data['building_code'] ?? building.buildingCode).toString();
          }
          if (building != null) add(building);
        }
      } catch (_) {
        // Keep locally cached memberships visible while offline or when the members API is unavailable.
      }
    }
    if (mounted) setState(() {
      _joinedBuildings
        ..clear()
        ..addAll(found.values);
      _isLoadingJoined = false;
    });
    else _isLoadingJoined = false;
  }

  List<_Building> get _visibleJoinedBuildings {
    final all = <String, _Building>{};
    for (final b in [..._joinedBuildings, ...AppSharedState.instance.buildings.values.where(_isJoinedByCurrentResident)]) {
      final key = b.recordId?.isNotEmpty == true ? 'id:${b.recordId}' : '${_normalizeSearchText(b.name)}|${_normalizeSearchText(b.address)}';
      all[key] = b;
    }
    final q = _normalizeSearchText(_joinedSearchController.text);
    if (q.isEmpty) return all.values.toList();
    return all.values.where((b) => _matchesSelectedSearchFields(b, q)).toList();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }


  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() { _isSearching = true; _selectedBuilding = null; _foundBuildingName = null; });
    if (!(_searchByBuildingName || _searchByUniqueCode || _searchByCity || _searchByProvince)) {
      _toast('حداقل یک گزینهٔ جست‌وجو را انتخاب کنید.', error: true);
      return;
    }
    final results = <_Building>[];
    final seen = <String>{};
    void add(_Building b) {
      if (!_matchesSelectedSearchFields(b, query)) return;
      final key = b.recordId?.isNotEmpty == true ? b.recordId! : (b.buildingCode.isNotEmpty ? b.buildingCode : '${b.name}|${b.address}');
      if (seen.add(key)) results.add(b);
    }
    for (final b in AppSharedState.instance.buildings.values) { add(b); }
    try {
      final records = await pb.collection('buildings').getFullList(batch: 200);
      for (final record in records) {
        final data = record.data;
        final name = (data['name'] ?? '').toString().trim();
        final address = (data['address'] ?? '').toString().trim();
        final code = (data['building_code'] ?? '').toString().trim();
        final province = (data['province'] ?? data['state'] ?? '').toString().trim();
        final city = (data['city'] ?? data['town'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final b = AppSharedState.instance.buildingByName(name, address: address);
        b.address = address;
        b.province = province;
        b.city = city;
        if (code.isNotEmpty) b.buildingCode = code;
        _applyBuildingRecord(b, record);
        if (!_matchesSelectedSearchFields(b, query)) continue;
        if (b.floors.isEmpty) {
          final cache = await _restoreCachedBuilding(_buildingCacheKey(b));
          if (cache != null) _applyBuildingStructure(b, _buildingStructure(cache));
        }
        add(b);
      }
    } catch (_) {
      // Locally synced buildings remain searchable when the API is unavailable.
    }
    if (!mounted) return;
    setState(() { _isSearching = false; _searchResults..clear()..addAll(results); });
    if (results.isEmpty) _toast('ساختمانی با این مشخصات یافت نشد.', error: true);
  }

  void _selectBuilding(_Building b) {
    setState(() { _selectedBuilding = b; _foundBuildingName = b.name; });
  }

  void _joinUnit(_Building b, int floor, int unit) {
    if (b.isOccupied(floor, unit)) {
      _toast('واحد ${unit.toPersianDigits()} طبقه ${floor.toPersianDigits()} قبلاً به ${b.occupantOf(floor, unit)!.name} اختصاص یافته است.', error: true);
      return;
    }
    final member = _Member(widget.name, 'ساکن', widget.ownership,
      phone: (pb.authStore.record?.data['phone'] ?? '').toString());
    final err = b.assign(floor, unit, member);
    if (err != null) {
      _toast(err, error: true);
      return;
    }
    widget.onJoined(b, floor, unit);
    if (mounted) setState(() { if (!_joinedBuildings.contains(b)) _joinedBuildings.add(b); });
    final userId = pb.authStore.record?.id ?? '';
    if (userId.isNotEmpty) unawaited(_cacheResidentMembership(userId, b, floor, unit));
    unawaited(_persistBuilding(b));
    unawaited(_syncMemberRecord(b, floor, unit, member));
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
        _BuildingLayout(
          building: b,
          onUnitTap: (floor, unit) => _showResidentUnit(b, floor, unit),
          highlightMemberName: widget.name,
        ),
        const SizedBox(height: 12),
        _ResidentChargeCard(building: b, unitId: b.unitId(widget.myFloor!, widget.myUnit!), onChanged: () { if (mounted) setState(() {}); }),
        const SizedBox(height: 12),
        _ResidentPollsCard(building: b, unitId: b.unitId(widget.myFloor!, widget.myUnit!), onChanged: () { if (mounted) setState(() {}); }),
      ]);
    }

    // جست‌وجوی ساختمان و انتخاب واحد
    final found = _selectedBuilding ?? (_foundBuildingName == null ? null : AppSharedState.instance.findByName(_foundBuildingName!));
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
              Text('نام، استان، شهر، نشانی یا شناسهٔ یکتای ساختمان را جست‌وجو کنید.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'نام، استان، شهر یا شناسهٔ یکتا',
                  prefixIcon: const Icon(Icons.travel_explore_rounded),
                  suffixIcon: IconButton(icon: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded), onPressed: _isSearching ? null : _search),
                  filled: true, fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.8)),
                ),
                onFieldSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 8),
              _searchFieldFilters(),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('نتایج جست‌وجو — ساختمان درست را بر اساس آدرس انتخاب کنید:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                for (final candidate in _searchResults)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const Icon(Icons.apartment_rounded),
                      title: Text(candidate.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${candidate.province.isNotEmpty || candidate.city.isNotEmpty ? 'استان/شهر: ${candidate.province} ${candidate.city}\n' : ''}آدرس: ${candidate.address.isEmpty ? 'ثبت نشده' : candidate.address}\nکد ساختمان: ${candidate.buildingCode.isEmpty ? 'در دسترس نیست' : candidate.buildingCode.toPersianDigits()}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_left_rounded),
                      selected: identical(_selectedBuilding, candidate),
                      onTap: () => _selectBuilding(candidate),
                    ),
                  ),
              ],
            ]),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('ساختمان‌هایی که عضو هستید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        TextField(
          controller: _joinedSearchController,
          decoration: InputDecoration(
            hintText: 'جست‌وجو در ساختمان‌های عضو‌شده',
            prefixIcon: const Icon(Icons.filter_list_rounded),
            suffixIcon: _joinedSearchController.text.isEmpty ? null : IconButton(
              tooltip: 'پاک کردن جست‌وجو', icon: const Icon(Icons.close_rounded),
              onPressed: () { _joinedSearchController.clear(); setState(() {}); },
            ),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 8),
        Builder(builder: (context) {
          final joined = _visibleJoinedBuildings;
          if (joined.isEmpty) {
            final hasAny = _joinedBuildings.isNotEmpty || AppSharedState.instance.buildings.values.any(_isJoinedByCurrentResident);
            return Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(
              hasAny ? 'ساختمانی با این عبارت در فهرست عضویت پیدا نشد.' : (_isLoadingJoined ? 'در حال بارگذاری فهرست ساختمان‌های عضو‌شده…' : 'هنوز عضو ساختمانی نشده‌اید.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            )));
          }
          return Column(children: joined.map((building) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.apartment_rounded),
              title: Text(building.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([
                if (building.province.isNotEmpty || building.city.isNotEmpty) '${building.province}${building.province.isNotEmpty && building.city.isNotEmpty ? '، ' : ''}${building.city}',
                building.address.isEmpty ? 'آدرس ثبت نشده' : building.address,
                if (building.buildingCode.isNotEmpty) 'شناسه: ${building.buildingCode.toPersianDigits()}',
              ].join(' • ')),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _selectBuilding(building),
            ),
          )).toList());
        }),
      ]),
      const SizedBox(height: 16),
      if (found != null) ...[
        Text('ساختمان: ${found.name}\nآدرس: ${found.address.isEmpty ? 'ثبت نشده' : found.address}\nکد: ${found.buildingCode.isEmpty ? 'در دسترس نیست' : found.buildingCode.toPersianDigits()}\nواحدهای ساختمان را ببینید و روی واحد خالی بزنید:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        _BuildingLayout(
          building: found,
          onUnitTap: (floor, unit) => _showResidentUnit(found, floor, unit),
          highlightMemberName: widget.name,
        ),
        const SizedBox(height: 12),
        _ResidentPollsCard(building: found, unitId: null, onChanged: () { if (mounted) setState(() {}); }),
      ],
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
    if (!topic.isActive) {
      setState(() => _error = 'مهلت یک‌هفته‌ای رأی‌گیری به پایان رسیده است.');
      return;
    }
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
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('زمان ایجاد: ${_formatPersianDateTime(topic.createdAt)}'),
          const SizedBox(height: 4),
          Text('مهلت پاسخگویی (۱ هفته از زمان ایجاد): ${_formatPersianDateTime(topic.deadline)}'),
          const SizedBox(height: 4),
          Text('وضعیت: ${topic.isActive ? 'رأی‌گیری فعال است' : 'مهلت رأی‌گیری پایان یافته است'}', style: TextStyle(fontWeight: FontWeight.bold, color: topic.isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error)),
          if (!topic.isActive) ...[
            const SizedBox(height: 8),
            const Text('مهلت یک‌هفته‌ای رأی‌گیری به پایان رسیده است.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ],
        ]))),
        const SizedBox(height: 12),
        if (widget.unitId != null && !topic.votesByUnitId.containsKey(widget.unitId!))
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('پیشنهاد مبلغ جدید', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
            TextField(controller: _amountController, enabled: topic.isActive, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'مبلغ به تومان', hintText: 'مثلاً ۲٬۵۰۰٬۰۰۰', suffixText: 'تومان', border: OutlineInputBorder())),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
            const SizedBox(height: 10), FilledButton.icon(onPressed: topic.isActive ? _propose : null, icon: const Icon(Icons.add), label: const Text('ثبت پیشنهاد')),
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
    final canVote = topic.isActive && !widget.isManager && widget.unitId != null && myVote == null;
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
      const SizedBox(height: 8),
      Text('زمان ایجاد: ${_formatPersianDateTime(topic.createdAt)}', style: const TextStyle(fontSize: 12)),
      Text('مهلت پاسخگویی (۱ هفته از زمان ایجاد): ${_formatPersianDateTime(topic.deadline)}', style: const TextStyle(fontSize: 12)),
      Text('وضعیت: ${topic.isActive ? 'رأی‌گیری فعال است' : 'مهلت رأی‌گیری پایان یافته است'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: topic.isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error)),
      if (!topic.isActive) const Padding(padding: EdgeInsets.only(top: 6), child: Text('مهلت یک‌هفته‌ای رأی‌گیری به پایان رسیده است.', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600))),
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
      if (unitId != null) ...[
        row('مجموع بدهی آب', formatTomanAmount(building.totalWaterDebtFor(unitId!))),
        for (final bill in (building.waterDebtByUnitAndBill[unitId!] ?? const <String, int>{}).entries)
          row('قبض ${bill.key}', formatTomanAmount(bill.value)),
      ] else if (member.waterDebt > 0) row('بدهی آب', formatTomanAmount(member.waterDebt)),
      row('نوع مالکیت', member.ownership),
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
      final managerPhone = (pb.authStore.record?.data['phone'] ?? '').toString();
      if (managerPhone.isNotEmpty && b.hasOccupantWithPhone(managerPhone, excludeKey: key)) {
        _toast('این شماره تماس قبلاً در واحد دیگری از ساختمان ثبت شده است.', error: true);
        return;
      }
      if (member != null && !(member.name == widget.managerName && member.role == 'مدیر')) {
        _toast('این واحد در اختیار ${member.name} است؛ برای تغییر جایگاه او از «تغییر واحد» یا «ویرایش عضو» استفاده کنید.', error: true);
        return;
      }
      final managerMember = _Member(widget.managerName, 'مدیر', 'مدیر', phone: managerPhone);
      final previousManagerKeys = b.occupants.entries
          .where((entry) => entry.value.name == widget.managerName && entry.value.role == 'مدیر' && entry.key != key)
          .map((entry) => entry.key).toList();
      for (final previousKey in previousManagerKeys) { b.occupants.remove(previousKey); }
      final assignError = b.assign(floor, unit, managerMember);
      if (assignError != null) {
        for (final previousKey in previousManagerKeys) {
          final parts = previousKey.split('/');
          final oldFloor = int.tryParse(parts.first), oldUnit = int.tryParse(parts.last);
          if (oldFloor != null && oldUnit != null) {
            b.occupants[previousKey] = managerMember;
          }
        }
        _toast(assignError, error: true);
        return;
      }
      await _persistBuilding(b);
      await _syncMemberRecord(b, floor, unit, managerMember);
      if (mounted) setState(() {});
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
    var phoneError;
    var selectedRole = existing?.role == 'مدیر' ? 'مدیر' : 'ساکن';
    var selectedOwnership = existing?.ownership == 'مستأجر' ? 'مستأجر' : 'مالک';
    final result = await showDialog<_Member>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'ثبت ساکن' : 'ویرایش عضو'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'نام عضو')),
          TextField(controller: phoneController, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: 'شماره تماس', errorText: phoneError), onChanged: (_) { if (phoneError != null) setDialogState(() => phoneError = null); }),
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
          if (b.hasOccupantWithPhone(phone, excludeKey: key)) { setDialogState(() => phoneError = 'این شماره تماس قبلاً در واحد دیگری از ساختمان ثبت شده است.'); return; }
          if (name.isNotEmpty) Navigator.pop(dialogContext, _Member(name, selectedRole, selectedOwnership, phone: phone, waterDebt: existing?.waterDebt ?? 0, movedInAt: existing?.movedInAt ?? DateTime.now()));
        }, child: const Text('ذخیره'))],
      ),
    ));
    nameController.dispose();
    phoneController.dispose();
    if (result == null || !mounted) return;
    if (b.hasOccupantWithPhone(result.phone, excludeKey: key)) {
      _toast('این شماره تماس قبلاً در واحد دیگری از ساختمان ثبت شده است.', error: true);
      return;
    }
    final parts = key.split('/');
    final floor = int.tryParse(parts.first), unit = int.tryParse(parts.last);
    if (floor == null || unit == null) return;
    if (existing == null) {
      final assignError = b.assign(floor, unit, result);
      if (assignError != null) { _toast(assignError, error: true); return; }
    } else {
      b.occupants[key] = result;
    }
    await _persistBuilding(b);
    await _syncMemberRecord(b, floor, unit, result);
    if (mounted) setState(() {});
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
    await _persistBuilding(b);
    await _syncMemberRecord(b, int.parse(destination.split('/')[0]), int.parse(destination.split('/')[1]), member);
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

  bool get _isManagerOfBuilding => b.createdBy == (pb.authStore.record?.id ?? widget.managerName) || b.createdBy == widget.managerName || b.occupants.values.any((m) => m.name == widget.managerName && m.role == 'مدیر');

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
    await _persistBuilding(b);
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
    await _persistBuilding(b);
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
    await _persistBuilding(b);
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
    await _persistBuilding(b);
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

class _ServiceHome extends StatelessWidget {
  const _ServiceHome({required this.name, required this.specialties, this.showRequestsOnly = false});
  final String name;
  final List<String> specialties;
  final bool showRequestsOnly;

  static const List<Map<String, String>> _requests = <Map<String, String>>[
    {'block': 'بلوک A', 'address': 'تهران، خیابان بهار، کوچه یاس', 'requester': 'مریم رضایی', 'phone': '۰۹۱۲۳۴۵۶۷۸۹', 'specialty': 'لوله‌کشی و تأسیسات', 'description': 'نشتی آب زیر سینک آشپزخانه نیاز به بررسی دارد.'},
    {'block': 'بلوک B', 'address': 'تهران، خیابان آزادی، پلاک ۲۴', 'requester': 'علی محمدی (مدیر)', 'phone': '۰۹۳۵۱۲۳۴۵۶۷', 'specialty': 'برق‌کاری ساختمان', 'description': 'چراغ‌های راهروی طبقه سوم روشن نمی‌شوند.'},
    {'block': 'بلوک C', 'address': 'کرج، گوهردشت، خیابان پنجم', 'requester': 'زهرا احمدی', 'phone': '۰۹۱۰۹۸۷۶۵۴۳', 'specialty': 'نظافت مشاعات', 'description': 'برای نظافت راه‌پله و ورودی ساختمان درخواست نیرو داریم.'},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (!showRequestsOnly) ...[
          Text('خانهٔ نیروی خدماتی', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('سلام $name، تخصص‌های ثبت‌شدهٔ شما:', style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          Card(color: colors.primaryContainer, child: Padding(
            padding: const EdgeInsets.all(16),
            child: specialties.isEmpty
                ? const Row(children: [Icon(Icons.info_outline), SizedBox(width: 10), Expanded(child: Text('هنوز تخصصی انتخاب نشده است؛ آن‌ها را از بخش تنظیمات اضافه کنید.'))])
                : Wrap(spacing: 8, runSpacing: 8, children: specialties.map((item) => Chip(avatar: const Icon(Icons.check_circle_outline, size: 18), label: Text(item))).toList()),
          )),
        ],
        Row(children: [
          Expanded(child: Text(showRequestsOnly ? 'درخواست‌های دریافتی' : 'درخواست‌های تازه', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const Icon(Icons.notifications_active_outlined, color: Colors.green),
        ]),
        const SizedBox(height: 8),
        Text('درخواست‌های نمونه از مدیران و ساکنان ساختمان‌ها', style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 12),
        ..._requests.map((request) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.apartment_rounded, color: Colors.teal), const SizedBox(width: 8), Expanded(child: Text(request['block']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), Chip(label: Text(request['specialty']!), visualDensity: VisualDensity.compact)]),
              const Divider(height: 18),
              _requestLine(Icons.location_on_outlined, 'آدرس', request['address']!),
              _requestLine(Icons.person_outline, 'درخواست‌دهنده', request['requester']!),
              _requestLine(Icons.phone_outlined, 'شماره تماس', request['phone']!),
              _requestLine(Icons.handyman_outlined, 'تخصص درخواست‌شده', request['specialty']!),
              _requestLine(Icons.notes_rounded, 'شرح درخواست', request['description']!),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: () {}, icon: const Icon(Icons.mark_chat_read_outlined), label: const Text('مشاهدهٔ درخواست'))),
            ]),
          ),
        )),
      ],
    );
  }

  static Widget _requestLine(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 19, color: Colors.teal), const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
      Expanded(child: Text(value, style: const TextStyle(height: 1.4))),
    ]),
  );
}

class _FeatureItem {
  const _FeatureItem(this.title, this.subtitle, this.icon, this.kind);
  final String title, subtitle, kind;
  final IconData icon;
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.onLogout,
    required this.onEditAccount,
    required this.onRoleChange,
    required this.onSubscription,
    required this.phoneNumber,
    required this.role,
    required this.specialties,
    required this.onSpecialtiesChanged,
  });
  final VoidCallback onLogout;
  final VoidCallback onEditAccount;
  final VoidCallback onRoleChange;
  final VoidCallback onSubscription;
  final String phoneNumber;
  final String role;
  final List<String> specialties;
  final ValueChanged<List<String>> onSpecialtiesChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  static const List<String> _availableSpecialties = <String>[
    'لوله‌کشی و تأسیسات', 'برق‌کاری ساختمان', 'نظافت مشاعات', 'سرویس آسانسور',
  ];
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.of(widget.specialties);
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.specialties != widget.specialties) {
      _selected = List<String>.of(widget.specialties);
    }
  }

  void _toggleSpecialty(String value, bool checked) {
    setState(() {
      if (checked) {
        if (!_selected.contains(value)) _selected.add(value);
      } else {
        _selected.remove(value);
      }
    });
    widget.onSpecialtiesChanged(List<String>.of(_selected));
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('تنظیمات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (widget.role == 'خدماتی') ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.handyman_outlined), SizedBox(width: 10), Text('تخصص‌های من', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))]),
              const SizedBox(height: 4),
              Text('تخصص‌های قابل ارائه را انتخاب کنید.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ..._availableSpecialties.map((specialty) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(specialty),
                value: _selected.contains(specialty),
                onChanged: (value) => _toggleSpecialty(specialty, value ?? false),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 10),
      ],
      Card(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.phone_outlined), title: Text('شماره همراه: ${widget.phoneNumber}')),
        ListTile(leading: const Icon(Icons.manage_accounts_outlined), title: const Text('ویرایش حساب کاربری'), trailing: const Icon(Icons.chevron_left_rounded), onTap: widget.onEditAccount),
        ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: const Text('خرید اشتراک برنامه'), trailing: const Icon(Icons.chevron_left_rounded), onTap: widget.onSubscription),
        ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: const Text('تغییر نقش'), trailing: const Icon(Icons.chevron_left_rounded), onTap: widget.onRoleChange),
        ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('تغییر تم روشن/تاریک'), trailing: _ThemeToggle()),
        ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('خروج از حساب کاربری'), onTap: widget.onLogout),
      ])),
    ],
  );
}

class _FeatureHub extends StatelessWidget {
  const _FeatureHub({required this.index, required this.isManager, this.building});
  final int index;
  final bool isManager;
  final _Building? building;

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
              ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text(index == 1 ? 'درخواست‌ها و ارتباط' : index == 2 ? 'رأی‌گیری و ارزیابی' : 'امور مالی',
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
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _FeaturePage(item: item, building: building))),
          )),
        )),
        Card(color: Theme.of(context).colorScheme.secondaryContainer, child: const Padding(
          padding: EdgeInsets.all(16), child: Text('ساختمان و اعضا\nایجاد ساختمان و طبقات (مدیر) یا جست‌وجو و عضویت در ساختمان (ساکن) از تب «خانه» در دسترس است.', style: TextStyle(height: 1.7)),
        )),
      ],
    );
  }
}

class _FeaturePage extends StatefulWidget {
  const _FeaturePage({required this.item, this.building});
  final _FeatureItem item;
  final _Building? building;
  @override
  State<_FeaturePage> createState() => _FeaturePageState();
}

class _MeterReading {
  _MeterReading(this.unitId, this.label, int previous, int current)
      : previousController = TextEditingController(text: '$previous'),
        currentController = TextEditingController(text: '$current');
  final String unitId;
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
  final TextEditingController _billIdController = TextEditingController();
  late final List<_MeterReading> _meters;
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
    'water' => ['مبلغ کل قبض (تومان)', 'شناسه قبض'],
    'subscription' => [],
    'vote' => ['عنوان موضوع رأی‌گیری', 'شرح پیشنهاد', 'هزینهٔ اجرای تصمیم (تومان)', 'مدت رأی‌گیری (روز)'],
    'evaluation' => ['توضیحات (اختیاری)'],
    'service' => ['شرح درخواست', 'زمان پیشنهادی', 'شماره تماس'],
    _ => [],
  };

  @override
  void initState() {
    super.initState();
    final units = <String>[];
    final building = widget.building;
    if (building != null) {
      final floors = building.floorUnits.keys.toList()..sort();
      for (final floor in floors) {
        final unitNumbers = [...building.floorUnits[floor]!]..sort();
        for (final unit in unitNumbers) {
          units.add(building.unitId(floor, unit));
        }
      }
    }
    _meters = List<_MeterReading>.generate(units.length, (i) {
      final unitId = units[i];
      final parts = unitId.split('/');
      final label = parts.length == 2
          ? 'طبقه ${parts[0]} — واحد ${parts[1]}'
          : 'واحد $unitId';
      return _MeterReading(unitId, label, 120 + i * 17, 135 + i * 17);
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _billIdController.dispose();
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
              controller: label == 'شناسه قبض' ? _billIdController : null,
              keyboardType: label.contains('مبلغ') || label.contains('هزینه') || label.contains('روز') ? TextInputType.number : TextInputType.text,
              textDirection: label == 'شناسه قبض' ? TextDirection.ltr : TextDirection.rtl,
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
      ('ماهانه', '۶۹۸ هزار', 'پرداخت ماه‌به‌ماه', Icons.calendar_month_outlined),
      ('سه‌ماهه', '۱ میلیون و ۵۵۰ هزار', 'پرداخت برای سه ماه', Icons.date_range_outlined),
      ('شش‌ماهه', '۳ میلیون و ۸۹۰ هزار', 'پرداخت برای شش ماه', Icons.workspace_premium_outlined),
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
    final allocations = _meters.isEmpty
        ? <int>[]
        : _meters.map((m) => usageSum == 0 ? _billAmount ~/ _meters.length : (_billAmount * m.usage / usageSum).round()).toList();
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('محاسبهٔ قبض با کنتور فرعی', detail: 'قرائت‌ها را ویرایش کنید؛ سهم هر واحد لحظه‌ای محاسبه می‌شود.', icon: Icons.water_drop_outlined),
      if (_meters.isEmpty) const Text('برای این ساختمان هنوز واحدی ثبت نشده است.'),
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
      final rawAmount = _latinDigits(_values['مبلغ کل قبض (تومان)'] ?? '')
          .replaceAll(',', '').replaceAll('٬', '').trim();
      final amount = int.tryParse(rawAmount);
      final billId = _latinDigits(_billIdController.text.trim());
      final building = widget.building;
      if (amount == null || amount <= 0) {
        _message('مبلغ قبض معتبر نیست.');
        return;
      }
      if (billId.isEmpty) {
        _message('شناسه قبض را وارد کنید.');
        return;
      }
      if (building == null || _meters.isEmpty) {
        _message('ساختمان یا واحدی برای ثبت سهم قبض انتخاب نشده است.');
        return;
      }
      final usageTotal = _meters.fold<int>(0, (sum, meter) => sum + meter.usage);
      final shares = <int>[];
      if (usageTotal > 0) {
        for (final meter in _meters) {
          shares.add((amount * meter.usage / usageTotal).round());
        }
        final difference = amount - shares.fold<int>(0, (sum, share) => sum + share);
        shares[shares.length - 1] += difference;
      } else {
        final equalShare = amount ~/ _meters.length;
        final remainder = amount % _meters.length;
        for (var i = 0; i < _meters.length; i++) {
          shares.add(equalShare + (i < remainder ? 1 : 0));
        }
      }
      for (var i = 0; i < _meters.length; i++) {
        building.waterDebtByUnitAndBill
            .putIfAbsent(_meters[i].unitId, () => <String, int>{})[billId] = shares[i];
      }
      setState(() => _billAmount = amount);
      _message('سهم‌بندی قبض $billId برای ${_meters.length} واحد ثبت شد.');
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
