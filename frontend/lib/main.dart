import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bitirme Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF232025),
        primaryColor: Color(0xFF6C4AB6),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF6C4AB6),
          secondary: Color(0xFFB983FF),
          background: Color(0xFF232025),
        ),
        cardColor: Color(0xFF2D2836),
        textTheme: TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 18, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white),
        ),
        fontFamily: 'Montserrat',
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static List<Widget> _pages = <Widget>[
    ChatPage(),
    YemekhanePage(),
    RingSchedulePage(),
    AnnouncementPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFF2D2836),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.campaign), label: ''),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Color(0xFFB983FF),
          unselectedItemColor: Colors.white,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
        ),
      ),
    );
  }
}

// --- YEMEKHANE ---
class MealDay {
  final String date;
  final List<String> meals;
  final int? calories;
  MealDay({required this.date, required this.meals, this.calories});
  factory MealDay.fromJson(Map<String, dynamic> json) {
    return MealDay(
      date: json['date'],
      meals: List<String>.from(json['meals']),
      calories: json['calories'],
    );
  }
}

class YemekhaneService {
  static const String apiUrl = 'http://localhost:8000/meals'; // Gerekirse IP ile değiştir

  static Future<List<MealDay>> fetchMeals() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode != 200) throw Exception('Yemek listesi alınamadı');
    final data = json.decode(response.body);
    return (data['meals'] as List).map((e) => MealDay.fromJson(e)).toList();
  }
}

class YemekhanePage extends StatefulWidget {
  @override
  State<YemekhanePage> createState() => _YemekhanePageState();
}

class _YemekhanePageState extends State<YemekhanePage> {
  late Future<List<MealDay>> _mealsFuture;

  @override
  void initState() {
    super.initState();
    _mealsFuture = YemekhaneService.fetchMeals();
  }

  String _getDayLabel(int index) {
    if (index == 0) return 'Bugün';
    if (index == 1) return 'Yarın';
    return 'Ertesi Gün';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF232025),
      appBar: AppBar(
        backgroundColor: Color(0xFF232025),
        elevation: 0,
        title: Text('Yemekhane', style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: false,
        toolbarHeight: 70,
      ),
      body: FutureBuilder<List<MealDay>>(
        future: _mealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Color(0xFFB983FF)));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Menü bulunamadı'));
          }
          final meals = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: meals.length,
            itemBuilder: (context, i) {
              final day = meals[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: i == 0 ? 0 : 24, bottom: 8),
                    child: Text(
                      _getDayLabel(i),
                      style: TextStyle(
                        color: Color(0xFFB983FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF2D2836),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...day.meals.map((m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text('• $m', style: TextStyle(fontSize: 18, color: Color(0xFFB983FF))),
                        )),
                        if (day.meals.isEmpty)
                          Text('Menü bulunamadı', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                        SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: day.calories != null
                              ? Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6C4AB6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text('${day.calories} Kalori', style: TextStyle(color: Colors.white, fontSize: 14)),
                                )
                              : SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// --- RING ---
class RingSchedulePage extends StatefulWidget {
  @override
  _RingSchedulePageState createState() => _RingSchedulePageState();
}

class _RingSchedulePageState extends State<RingSchedulePage> {
  String _scheduleText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final text = await rootBundle.loadString('lib/ring_saatleri.txt');
    setState(() {
      _scheduleText = text;
      _loading = false;
    });
  }

  Map<String, List<String>> _groupByHour(List<String> lines) {
    final Map<String, List<String>> hourMap = {};
    final reg = RegExp(r'^(\d{2}):(\d{2}) ?(.*)');
    for (final line in lines) {
      final match = reg.firstMatch(line);
      if (match != null) {
        final hour = match.group(1)!;
        final minute = match.group(2)!;
        final desc = match.group(3)!.trim();
        final value = desc.isNotEmpty ? "$minute $desc" : minute;
        hourMap.putIfAbsent(hour, () => []).add(value);
      }
    }
    return hourMap;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFB983FF)));
    }
    final sections = _scheduleText.split(RegExp(r'\n(?=Hafta içi|Cumartesi|Pazar)'));
    final tabs = <String>[];
    final contents = <List<String>>[];
    for (final section in sections) {
      final lines = section.trim().split('\n');
      if (lines.isNotEmpty) {
        tabs.add(lines.first);
        contents.add(lines.skip(1).where((l) => l.trim().isNotEmpty).toList());
      }
    }
    return Scaffold(
      backgroundColor: Color(0xFF232025),
      appBar: AppBar(
        backgroundColor: Color(0xFF232025),
        elevation: 0,
        title: Text('Ring Saatleri', style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: false,
        toolbarHeight: 70,
      ),
      body: DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Color(0xFF2D2836),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                tabs: tabs.map((t) => Tab(child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))).toList(),
                indicator: BoxDecoration(
                  color: Color(0xFF6C4AB6),
                  borderRadius: BorderRadius.circular(24),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFFB983FF),
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: contents.map((lines) {
                  final hourMap = _groupByHour(lines);
                  final hourKeys = hourMap.keys.toList()..sort();
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: hourKeys.length,
                    itemBuilder: (context, i) {
                      final hour = hourKeys[i];
                      final items = hourMap[hour]!;
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Color(0xFF2D2836),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              alignment: Alignment.center,
                              margin: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFF6C4AB6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(hour, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: items.map((item) => Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFB983FF).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(item, style: TextStyle(color: Color(0xFFB983FF), fontSize: 16)),
                                  )).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DUYURULAR ---
class Announcement {
  final String title;
  final String content;
  Announcement({required this.title, required this.content});
  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      title: json['title'],
      content: json['content'],
    );
  }
}

class AnnouncementService {
  static const String apiUrl = 'http://localhost:8000/announcements';
  static Future<List<Announcement>> fetchAnnouncements() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode != 200) throw Exception('Duyurular alınamadı');
    final data = json.decode(response.body);
    return (data['announcements'] as List).map((e) => Announcement.fromJson(e)).toList();
  }
}

String htmlToPlainText(String html) {
  final document = html_parser.parse(html);
  return document.body?.text.trim() ?? '';
}

class AnnouncementPage extends StatefulWidget {
  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  late Future<List<Announcement>> _annFuture;
  @override
  void initState() {
    super.initState();
    _annFuture = AnnouncementService.fetchAnnouncements();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF232025),
      appBar: AppBar(
        backgroundColor: Color(0xFF232025),
        elevation: 0,
        title: Text('Duyurular', style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: false,
        toolbarHeight: 70,
      ),
      body: FutureBuilder<List<Announcement>>(
        future: _annFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Color(0xFFB983FF)));
          }
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            return Center(child: Text('Duyuru bulunamadı'));
          }
          final anns = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: anns.length,
            itemBuilder: (context, i) {
              final ann = anns[i];
              return Container(
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF2D2836),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ann.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFB983FF))),
                    SizedBox(height: 8),
                    Text(htmlToPlainText(ann.content), style: TextStyle(fontSize: 16, color: Colors.white)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- CHAT ---
class ChatMessage {
  final String role;
  final String content;
  ChatMessage({required this.role, required this.content});
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'],
      content: json['content'],
    );
  }
}

class ChatService {
  static const String apiUrl = 'http://localhost:8000/chat';
  static Future<List<ChatMessage>> sendMessage(String message, {String userId = 'default'}) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({"user_id": userId, "message": message}),
    );
    if (response.statusCode != 200) throw Exception('Chat başarısız');
    final data = json.decode(response.body);
    return (data['history'] as List).map((e) => ChatMessage.fromJson(e)).toList();
  }
}

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _loading = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _controller.clear();
      _loading = true;
    });
    try {
      // Geçici olarak loading mesajı ekle
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: '...'));
      });
      final history = await ChatService.sendMessage(text);
      setState(() {
        _messages = history;
      });
    } catch (e) {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.role == 'assistant' && _messages.last.content == '...') {
          _messages.removeLast();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mesaj gönderilemedi.')));
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF232025),
      appBar: AppBar(
        backgroundColor: Color(0xFF232025),
        elevation: 0,
        title: Text('Chatbot', style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: false,
        toolbarHeight: 70,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final isUser = msg.role == 'user';
                final isLoadingMsg = msg.role == 'assistant' && msg.content == '...';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? Color(0xFF6C4AB6) : Color(0xFF2D2836),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: isLoadingMsg
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFFB983FF),
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            msg.content,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      filled: true,
                      fillColor: Color(0xFF2D2836),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Color(0xFFB983FF)),
                  onPressed: _loading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
