import 'package:flutter/material.dart';

import 'demo_home_page.dart';
import 'demo_l10n.dart';
import 'demo_util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DemoL10n.load(); // 读取上次选择的语言(默认英文)
  runApp(const MXDemoApp());
}

class MXDemoApp extends StatelessWidget {
  const MXDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MXLogger Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kBrandColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: kBrandColor, brightness: Brightness.dark),
      ),
      home: const LandingPage(),
    );
  }
}

/// 落地页(对齐 iOS demo 的 Main.storyboard 落地页)
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return L10nScope(builder: _build);
  }

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardBg(context),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 8, 12, 0),
                  child: LanguageToggleButton(),
                ),
              ),
              const Spacer(flex: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/mxlogger_logo.png',
                    width: 96, height: 96),
              ),
              const SizedBox(height: 28),
              Text('MXLogger',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: primaryText(context))),
              const SizedBox(height: 10),
              Text(tr('landing.subtitle'),
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 15, color: secondaryText(context))),
              const Spacer(flex: 4),
              SizedBox(
                width: 240,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandColor,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const DemoHomePage())),
                  child: Text(tr('landing.enter'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Flutter Demo · flutter_mxlogger 2.0.0',
                  style: TextStyle(fontSize: 12, color: tertiaryText(context))),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
