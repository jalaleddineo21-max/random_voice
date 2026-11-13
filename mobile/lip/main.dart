import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'config.dart';

void main() => runApp(const RandomVoiceApp());

const bg = Color(0xFF0B0B13);
const panel = Color(0xFF171725);
const purple = Color(0xFF9270FF);
const muted = Color(0xFFAAA8BC);

class RandomVoiceApp extends StatelessWidget {
  const RandomVoiceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Voice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String language = 'همه زبان‌ها';
  String region = 'همه مناطق';
  bool searching = false;
  String status = 'آماده‌ای با یک نفر جدید آشنا بشی؟';

  Future<void> startSearch() async {
    setState(() { searching = true; status = 'در حال پیدا کردن یک نفر...'; });
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/match'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'language': language, 'region': region}),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('سرور پاسخ مناسبی نداد (${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['matched'] == true) {
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => CallPage(
            roomUrl: data['url'] as String,
            token: data['token'] as String,
            roomName: data['roomName'] as String,
          ),
        ));
      } else {
        setState(() => status = 'در صف انتظار هستی؛ به محض پیدا شدن نفر دوم وصل می‌شی.');
        // نسخه نمونه برای ساده ماندن MVP؛ polling بعداً با WebSocket جایگزین می‌شود.
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && searching) {
          setState(() => status = 'هنوز کسی با این فیلتر پیدا نشده. کمی صبر کن یا فیلترها را بازتر کن.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => status = 'اتصال به سرور برقرار نشد. آدرس backend را تنظیم کن.');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.graphic_eq_rounded, color: purple, size: 30),
                const SizedBox(width: 9),
                const Text('Random Voice', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => showAboutDialog(context: context, applicationName: 'Random Voice', applicationVersion: '0.1.0'), icon: const Icon(Icons.info_outline)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: panel, borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: purple.withOpacity(.22)),
                ),
                child: Column(children: [
                  Container(
                    width: 118, height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: purple.withOpacity(.13),
                      boxShadow: [BoxShadow(color: purple.withOpacity(.17), blurRadius: 35, spreadRadius: 4)],
                    ),
                    child: const Icon(Icons.mic_rounded, size: 58, color: purple),
                  ),
                  const SizedBox(height: 24),
                  const Text('صدای تازه، آدم تازه', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(status, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.6)),
                  const SizedBox(height: 26),
                  _filterTile(Icons.language, 'زبان', language, () async {
                    final v = await _choose(context, 'انتخاب زبان', ['همه زبان‌ها', 'فارسی', 'English', 'العربية', 'Türkçe']);
                    if (v != null) setState(() => language = v);
                  }),
                  const SizedBox(height: 10),
                  _filterTile(Icons.public, 'منطقه', region, () async {
                    final v = await _choose(context, 'انتخاب منطقه', ['همه مناطق', 'ایران', 'اروپا', 'خاورمیانه', 'آمریکای شمالی']);
                    if (v != null) setState(() => region = v);
                  }),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 58, width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: searching ? null : startSearch,
                      icon: Icon(searching ? Icons.hourglass_top : Icons.shuffle_rounded),
                      label: Text(searching ? 'در حال جست‌وجو...' : 'شروع مکالمه'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              const Text('بدون دوربین • بدون نمایش هویت عمومی • فقط مکالمه صوتی', textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterTile(IconData icon, String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: purple), const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: muted)),
          const Spacer(), Text(value), const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, color: muted),
        ]),
      ),
    );
  }

  Future<String?> _choose(BuildContext context, String title, List<String> options) {
    return showModalBottomSheet<String>(
      context: context, backgroundColor: panel,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(18), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ...options.map((e) => ListTile(title: Text(e), onTap: () => Navigator.pop(context, e))),
      ])),
    );
  }
}

class CallPage extends StatefulWidget {
  final String roomUrl, token, roomName;
  const CallPage({super.key, required this.roomUrl, required this.token, required this.roomName});
  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  Room? room;
  bool connected = false;
  bool muted = false;
  String message = 'در حال برقراری تماس...';

  @override
  void initState() { super.initState(); _connect(); }

  Future<void> _connect() async {
    try {
      final r = Room();
      await r.connect(widget.roomUrl, widget.token);
      await r.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) { await r.disconnect(); return; }
      setState(() { room = r; connected = true; message = 'متصل شدی؛ می‌تونی صحبت کنی.'; });
    } catch (_) {
      if (mounted) setState(() => message = 'اتصال صوتی ناموفق بود.');
    }
  }

  Future<void> _toggleMute() async {
    final next = !muted;
    await room?.localParticipant?.setMicrophoneEnabled(!next);
    if (mounted) setState(() => muted = next);
  }

  Future<void> _end() async {
    await room?.disconnect();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { room?.disconnect(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مکالمه ناشناس'), backgroundColor: bg),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircleAvatar(radius: 62, backgroundColor: panel, child: Icon(Icons.person_rounded, size: 68, color: purple)),
        const SizedBox(height: 25),
        Text(connected ? 'شما به یک نفر وصل شدی' : 'در حال اتصال', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: muted)),
        const SizedBox(height: 60),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _action(muted ? Icons.mic_off : Icons.mic, muted ? 'فعال‌سازی صدا' : 'بی‌صدا', _toggleMute),
          _action(Icons.call_end, 'پایان', _end, danger: true),
        ]),
      ]),
    )),
  );

  Widget _action(IconData icon, String label, VoidCallback action, {bool danger = false}) => Column(children: [
    InkWell(onTap: action, borderRadius: BorderRadius.circular(40),
      child: CircleAvatar(radius: 31, backgroundColor: danger ? Colors.red.shade700 : panel, child: Icon(icon, color: Colors.white))),
    const SizedBox(height: 8), Text(label, style: const TextStyle(color: muted, fontSize: 12)),
  ]);
}
