import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

// --- 0. NAPRAWA SSL ---
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl_PL', null);
  HttpOverrides.global = MyHttpOverrides();
  runApp(const UekScheduleApp());
}

// --- 1. MOTYW APLIKACJI ---
class UekScheduleApp extends StatelessWidget {
  const UekScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plan UEK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFBB86FC),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFBB86FC),
          secondary: Color(0xFF03DAC6),
          surface: Color(0xFF1E1E1E),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// --- 2. MODEL DANYCH ---
class ClassItem {
  final String date;    
  final String time;    
  final String subject;
  final String type;
  final String teacher;
  final String room;
  final String? meetingUrl;
  final String? note;

  ClassItem({
    required this.date,
    required this.time,
    required this.subject,
    required this.type,
    required this.teacher,
    required this.room,
    this.meetingUrl,
    this.note,
  });

  DateTime? getStartDateTime() {
    try {
      final parts = time.replaceAll(RegExp(r'[^\d:-]'), '').split('-');
      final startPart = parts[0].trim().split(':');
      final datePart = DateTime.parse(date);
      return DateTime(datePart.year, datePart.month, datePart.day, int.parse(startPart[0]), int.parse(startPart[1]));
    } catch (e) { return null; }
  }

  DateTime? getEndDateTime() {
    try {
      final parts = time.replaceAll(RegExp(r'[^\d:-]'), '').split('-');
      final endPart = parts[1].trim().split(':');
      final datePart = DateTime.parse(date);
      return DateTime(datePart.year, datePart.month, datePart.day, int.parse(endPart[0]), int.parse(endPart[1]));
    } catch (e) { return null; }
  }

  int checkTimeStatus() {
    final start = getStartDateTime();
    final end = getEndDateTime();
    final now = DateTime.now();
    if (start == null || end == null) return 1;
    if (now.isAfter(end)) return -1; 
    if (now.isAfter(start) && now.isBefore(end)) return 0; 
    return 1;
  }
}

// --- 3. LOGIKA POBIERANIA ---
class ScheduleService {
  
  static String extractGroupId(String input) {
    if (input.contains("id=")) {
      final uri = Uri.parse(input);
      String? idParam = uri.queryParameters['id'];
      if (idParam != null) return idParam;
    }
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static Future<List<ClassItem>> fetchSchedule(String username, String password, String groupId, int period) async {
    final cleanId = extractGroupId(groupId);
    if (cleanId.isEmpty) throw Exception("Niepoprawne ID grupy!");

    final Uri url = Uri.https('planzajec.uek.krakow.pl', '/index.php', {
      'typ': 'G', 'id': cleanId, 'okres': period.toString(),
    });

    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    try {
      final response = await http.get(url, headers: {'authorization': basicAuth});
      if (response.statusCode == 200) {
        return _parseHtml(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 401) {
        throw Exception("Błędny login lub hasło!");
      } else {
        throw Exception("Błąd serwera: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Błąd połączenia: $e");
    }
  }

  static List<ClassItem> _parseHtml(String htmlBody) {
    var document = parser.parse(htmlBody);
    var rows = document.querySelectorAll('table tr');
    List<ClassItem> classes = [];

    for (int i = 0; i < rows.length; i++) {
      var row = rows[i];
      var cells = row.children;

      if (cells.length >= 6 && cells[0].localName == 'td' && !row.classes.contains('uwagi')) {
        String rawTime = cells[1].text.trim();
        if (rawTime.contains('(')) rawTime = rawTime.substring(0, rawTime.indexOf('(')).trim();
        rawTime = rawTime.replaceAll(RegExp(r'^[A-ZŚĆŻŹŁ][a-z]?\s'), '');

        String? extractedUrl;
        var roomLink = cells[5].querySelector('a');
        if (roomLink != null) {
          extractedUrl = roomLink.attributes['href'];
        } else {
           var subjectLink = cells[2].querySelector('a');
           if (subjectLink != null) {
             extractedUrl = subjectLink.attributes['href'];
           }
        }
        if (extractedUrl != null && !extractedUrl.startsWith('http')) {
          extractedUrl = 'https://planzajec.uek.krakow.pl/$extractedUrl';
        }

        String? groupNote;
        if (i + 1 < rows.length) {
          var nextRow = rows[i + 1];
          var uwagiCell = nextRow.querySelector('td.uwagi');
          if (uwagiCell != null) {
            groupNote = uwagiCell.text.trim();
          }
        }

        classes.add(ClassItem(
          date: cells[0].text.trim(),
          time: rawTime,
          subject: cells[2].text.trim(),
          type: cells[3].text.trim(),
          teacher: cells[4].text.trim().replaceAll('e-Wizytówka', ''),
          room: cells[5].text.trim(),
          meetingUrl: extractedUrl,
          note: groupNote,
        ));
      }
    }
    return classes;
  }
}

// --- 4. EKRAN LOGOWANIA ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _storage = const FlutterSecureStorage();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _groupController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    String? user = await _storage.read(key: 'login');
    String? pass = await _storage.read(key: 'pass');
    String? group = await _storage.read(key: 'group_id');
    
    if (user != null) _userController.text = user;
    if (pass != null) _passController.text = pass;
    _groupController.text = group ?? '237961'; 
  }

  void _login() async {
    setState(() => _isLoading = true);
    final user = _userController.text.trim();
    final pass = _passController.text.trim();
    final groupRaw = _groupController.text.trim();

    try {
      final groupId = ScheduleService.extractGroupId(groupRaw);
      await ScheduleService.fetchSchedule(user, pass, groupId, 2);
      
      await _storage.write(key: 'login', value: user);
      await _storage.write(key: 'pass', value: pass);
      await _storage.write(key: 'group_id', value: groupId);

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SchedulePage(user: user, pass: pass, groupId: groupId)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_rounded, size: 80, color: Color(0xFFBB86FC)),
              const SizedBox(height: 30),
              const Text("UEK PLANNER", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 40),
              TextField(controller: _userController, decoration: InputDecoration(labelText: 'Login (Moodle)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: _passController, obscureText: true, decoration: InputDecoration(labelText: 'Hasło', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: _groupController, decoration: InputDecoration(labelText: 'ID Grupy lub Link', helperText: "Np. 237961", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("ZALOGUJ SIĘ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 5. GŁÓWNY EKRAN ---
class SchedulePage extends StatefulWidget {
  final String user;
  final String pass;
  final String groupId;

  const SchedulePage({required this.user, required this.pass, required this.groupId, super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late Future<Map<String, List<ClassItem>>> _scheduleFuture;
  final _storage = const FlutterSecureStorage();
  
  Map<String, List<ClassItem>> _groupedClasses = {};
  List<String> _sortedDates = [];
  
  final int _selectedPeriod = 2;
  
  bool _showCalendar = false;
  PageController? _pageController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Timer? _timer;
  late String _currentGroupId;
  
  final ScrollController _scrollController = ScrollController();
  final double hourHeight = 65.0; 
  final int startHour = 7; 
  final int endHour = 21;  

  @override
  void initState() {
    super.initState();
    _currentGroupId = widget.groupId;
    _selectedDay = _focusedDay;
    _refresh();
    
    // Timer 5 sekund dla dokładności czasu
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) setState(() {});
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    double currentHour = now.hour + (now.minute / 60.0);
    double offset = (currentHour - startHour) * hourHeight - 200; 
    if (offset < 0) offset = 0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(offset, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
    }
  }

  void _jumpToToday() {
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int index = _sortedDates.indexOf(todayStr);

    if (index != -1) {
      _pageController?.animateToPage(
        index, 
        duration: const Duration(milliseconds: 500), 
        curve: Curves.easeInOut
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        _scrollToCurrentTime();
      });
      setState(() {
        _selectedDay = DateTime.now();
        _focusedDay = DateTime.now();
        _showCalendar = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brak zajęć dzisiaj!")));
    }
  }

  Future<void> _openScheduleInBrowser() async {
    final Uri url = Uri.parse("https://planzajec.uek.krakow.pl/index.php?typ=G&id=$_currentGroupId&okres=$_selectedPeriod");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nie udało się otworzyć linku")));
    }
  }

  Future<void> _openMeetingUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nie udało się otworzyć spotkania")));
    }
  }

  void _showClassDetails(ClassItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(item.subject, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 5),
              
              if (item.note != null && item.note!.isNotEmpty)
                Text(item.note!, style: const TextStyle(fontSize: 14, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 15),
              _buildDetailRow(Icons.access_time, item.time),
              _buildDetailRow(Icons.location_on, item.room),
              _buildDetailRow(Icons.person, item.teacher),
              _buildDetailRow(Icons.class_, item.type),
              
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openScheduleInBrowser,
                      icon: const Icon(Icons.language),
                      label: const Text("Plan na WWW"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                    ),
                  ),
                  if (item.meetingUrl != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openMeetingUrl(item.meetingUrl!),
                        icon: const Icon(Icons.video_call),
                        label: const Text("Dołącz"),
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.white70))),
        ],
      ),
    );
  }

  void _logout() async {
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Wylogowanie"),
        content: const Text("Czy na pewno chcesz się wylogować?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
          TextButton(
            onPressed: () async {
              await _storage.delete(key: 'login');
              await _storage.delete(key: 'pass');
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => const LoginPage()), 
                  (route) => false
                );
              }
            }, 
            child: const Text("Wyloguj", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _scheduleFuture = _fetchAndGroupSchedule();
    });
  }

  Future<Map<String, List<ClassItem>>> _fetchAndGroupSchedule() async {
    List<ClassItem> rawList = await ScheduleService.fetchSchedule(widget.user, widget.pass, _currentGroupId, _selectedPeriod);
    Map<String, List<ClassItem>> grouped = {};
    for (var item in rawList) {
      if (!grouped.containsKey(item.date)) grouped[item.date] = [];
      grouped[item.date]!.add(item);
    }
    _groupedClasses = grouped;
    _sortedDates = grouped.keys.toList()..sort();
    
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int initialPage = 0;
    for (int i = 0; i < _sortedDates.length; i++) {
      if (_sortedDates[i].compareTo(todayStr) >= 0) {
        initialPage = i;
        break;
      }
    }
    if (_pageController != null) _pageController!.dispose();
    _pageController = PageController(initialPage: initialPage, viewportFraction: 1.0);
    
    return grouped;
  }

  List<ClassItem> _getEventsForDay(DateTime day) {
    return _groupedClasses[DateFormat('yyyy-MM-dd').format(day)] ?? [];
  }

  void _showGroupSettings() {
    TextEditingController tempController = TextEditingController(text: _currentGroupId);
    showDialog(context: context, builder: (context) {
        return AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: const Text("Ustawienia Grupy"), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Wpisz ID swojej grupy lub wklej link:", style: TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 10), TextField(controller: tempController, decoration: const InputDecoration(labelText: "ID Grupy", border: OutlineInputBorder(), prefixIcon: Icon(Icons.group)))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")), ElevatedButton(onPressed: () async { String newId = ScheduleService.extractGroupId(tempController.text); if (newId.isNotEmpty) { await _storage.write(key: 'group_id', value: newId); setState(() { _currentGroupId = newId; }); Navigator.pop(context); _refresh(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Zmieniono grupę na: $newId"))); } }, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor), child: const Text("Zapisz", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))]);
      }
    );
  }

  // --- BUDOWANIE WIDOKU DNIA ---
  Widget _buildDayTimeline(List<ClassItem> classes, bool isToday) {
    double totalHeight = (endHour - startHour + 1) * hourHeight;
    List<Widget> stackChildren = [];

    // 1. SIATKA GODZIN (50px)
    stackChildren.addAll(List.generate(endHour - startHour + 1, (index) {
      int hour = startHour + index;
      return Positioned(
          top: index * hourHeight, left: 0, right: 0,
          child: Row(children: [
            SizedBox(
                width: 50, 
                child: Text("$hour:00",
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white38, fontSize: 11))), 
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: Colors.white10))
          ]));
    }));

    // ALGORYTM KOLIZJI
    classes.sort((a, b) => (a.getStartDateTime() ?? DateTime(0)).compareTo(b.getStartDateTime() ?? DateTime(0)));
    List<List<ClassItem>> overlappingGroups = [];
    if (classes.isNotEmpty) {
      List<ClassItem> currentGroup = [classes[0]];
      for (int i = 1; i < classes.length; i++) {
        var prevItem = currentGroup.last;
        var currItem = classes[i];
        DateTime? prevStart = prevItem.getStartDateTime();
        DateTime? prevEnd = prevItem.getEndDateTime();
        DateTime? currStart = currItem.getStartDateTime();
        if (prevStart != null && prevEnd != null && currStart != null) {
          if (currStart.isBefore(prevEnd)) {
            currentGroup.add(currItem); 
          } else {
            overlappingGroups.add(currentGroup);
            currentGroup = [currItem]; 
          }
        }
      }
      overlappingGroups.add(currentGroup);
    }

    // RYSOWANIE KAFELKÓW
    for (var group in overlappingGroups) {
      int count = group.length;
      for (int i = 0; i < count; i++) {
        var item = group[i];
        
        final start = item.getStartDateTime();
        final end = item.getEndDateTime();
        if (start == null || end == null) continue;

        double startMinutesFromTop = (start.hour - startHour) * 60.0 + start.minute;
        double topOffset = (startMinutesFromTop / 60.0) * hourHeight;
        double itemHeight = (end.difference(start).inMinutes.toDouble() / 60.0) * hourHeight;

        int status = item.checkTimeStatus();
        bool isNow = status == 0;
        bool isPast = status == -1;

        final timeParts = item.time.replaceAll(' ', '').split('-');
        String startTime = timeParts[0];
        String endTime = timeParts.length > 1 ? timeParts[1] : "";
        
        double leftPos = 60.0 + (i * ((MediaQuery.of(context).size.width - 70) / count));
        double width = (MediaQuery.of(context).size.width - 70) / count;

        stackChildren.add(Positioned(
          top: topOffset,
          left: leftPos,
          width: width,
          height: itemHeight,
          child: GestureDetector(
            onTap: () => _showClassDetails(item),
            child: Opacity(
              opacity: isPast ? 0.5 : 1.0,
              child: Container(
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(6),
                  border: isNow
                      ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                      : Border(left: BorderSide(color: _getColorForType(item.type), width: 4)),
                  boxShadow: isNow ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 5)] : [],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double h = constraints.maxHeight;
                    bool isShort = h < 55; 
                    bool isTiny = h < 30;
                    bool isNarrow = count > 1;
                    
                    // Sprawdzamy czy jest notatka, żeby dostosować paddingi
                    bool hasNote = item.note != null && item.note!.isNotEmpty && !isShort;

                    // Mniejsze paddingi dla krótkich zajęć, aby uniknąć overflow
                    double verticalPadding = isTiny ? 1 : ((isShort || hasNote) ? 2 : 5);

                    return Padding(
                      // Jeśli jest notatka, zmniejszamy padding góra/dół do 2px, żeby zyskać miejsce
                      padding: EdgeInsets.fromLTRB(isNarrow ? 4 : 8, verticalPadding, isNarrow ? 4 : 8, verticalPadding),
                      child: Row(
                        children: [
                          // KOLUMNA 1: CZAS
                          SizedBox(
                            width: isNarrow ? 28 : 32, 
                            child: isTiny 
                            ? Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(startTime, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  FittedBox(fit: BoxFit.scaleDown, child: Text(startTime, style: TextStyle(fontSize: isShort ? 9 : 11, fontWeight: FontWeight.w600, color: Colors.white))),
                                  FittedBox(fit: BoxFit.scaleDown, child: Text(endTime, style: TextStyle(fontSize: isShort ? 8 : 10, color: Colors.white54))),
                                ],
                              ),
                          ),
                          
                          Container(width: 1, color: Colors.white10, margin: EdgeInsets.symmetric(horizontal: isNarrow ? 3 : 6)),

                          // KOLUMNA 2: INFO
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // --- GÓRA: NAZWA + TYP + (GRUPA) ---
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.subject, 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: isShort || isNarrow ? 10 : 12, 
                                        height: 1.0 // Zmniejszona interlinia tytułu
                                      ), 
                                      maxLines: isShort ? 1 : 2, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                    
                                    // NOTATKA (GRUPA)
                                    if (hasNote)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1.0, bottom: 1.0),
                                        child: Text(
                                          item.note!, 
                                          style: const TextStyle(fontSize: 9, color: Colors.orangeAccent, fontWeight: FontWeight.bold), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis
                                        ),
                                      ),
                                    
                                    // Odstęp (mniejszy jeśli jest notatka)
                                    SizedBox(height: (isShort || hasNote) ? 1 : 3), 

                                    // TYP ZAJĘĆ
                                    if (!isTiny) 
                                      Text(
                                        item.type, 
                                        style: TextStyle(
                                          // Jeśli jest notatka, zmniejsz czcionkę typu do 9
                                          fontSize: (isShort || isNarrow || hasNote) ? 9 : 10, 
                                          color: Colors.white54, 
                                          height: 1.0
                                        ), 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis
                                      ),
                                  ],
                                ),

                                // --- ŚRODEK: PROWADZĄCY ---
                                if (!isShort && !isNarrow) 
                                  Expanded(
                                    child: Center( // Center + Align lewo lepiej centruje w pionie bez ucinania
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person, size: 12, color: Colors.white30),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.teacher, 
                                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                                              maxLines: 1, 
                                              overflow: TextOverflow.ellipsis
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // --- DÓŁ: SALA ---
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: isShort ? 10 : 11, color: _getColorForType(item.type)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item.room, 
                                        style: TextStyle(
                                          fontSize: isShort || isNarrow ? 9 : 11, 
                                          color: Colors.white, 
                                          fontWeight: FontWeight.w500
                                        ), 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis
                                      )
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ));
      }
    }

    if (isToday) {
      final timeLine = _buildCurrentTimeLine();
      if (timeLine != null) stackChildren.add(timeLine);
    }

    return SingleChildScrollView(
      controller: isToday ? _scrollController : null,
      padding: const EdgeInsets.only(top: 20, bottom: 50),
      child: Container(
        height: totalHeight,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Stack(children: stackChildren),
      ),
    );
  }

  Widget? _buildCurrentTimeLine() {
    final now = DateTime.now();
    if (now.hour < startHour || now.hour > endHour) return null;
    double minutesFromTop = (now.hour - startHour) * 60.0 + now.minute;
    double topOffset = (minutesFromTop / 60.0) * hourHeight;
    return Positioned(top: topOffset, left: 0, right: 0, child: Row(children: [Container(width: 50, alignment: Alignment.centerRight, child: Text(DateFormat('HH:mm').format(now), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))), const SizedBox(width: 5), const Icon(Icons.circle, color: Colors.redAccent, size: 8), Expanded(child: Container(height: 2, color: Colors.redAccent))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Schedule", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(_showCalendar ? Icons.view_agenda : Icons.calendar_month), onPressed: () => setState(() => _showCalendar = !_showCalendar)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') _refresh();
              if (value == 'group') _showGroupSettings();
              if (value == 'logout') _logout();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh), title: Text('Odśwież'))),
              const PopupMenuItem<String>(value: 'group', child: ListTile(leading: Icon(Icons.settings), title: Text('Zmień Grupę'))),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Colors.redAccent), title: Text('Wyloguj', style: TextStyle(color: Colors.redAccent)))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _jumpToToday,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.today, color: Colors.black),
      ),
      body: FutureBuilder<Map<String, List<ClassItem>>>(
        future: _scheduleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Błąd: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Brak zajęć (lub zła grupa)."));

          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300), height: _showCalendar ? 380 : 0,
                child: SingleChildScrollView(child: TableCalendar(locale: 'pl_PL', firstDay: DateTime.utc(2023, 10, 1), lastDay: DateTime.utc(2026, 12, 31), focusedDay: _focusedDay, selectedDayPredicate: (day) => isSameDay(_selectedDay, day), eventLoader: _getEventsForDay, onDaySelected: (selectedDay, focusedDay) { setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; _showCalendar = false; }); String dateKey = DateFormat('yyyy-MM-dd').format(selectedDay); int index = _sortedDates.indexOf(dateKey); if (index != -1 && _pageController != null) _pageController!.jumpToPage(index); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brak zajęć w tym dniu."))); }, calendarStyle: const CalendarStyle(markerDecoration: BoxDecoration(color: Color(0xFFBB86FC), shape: BoxShape.circle), selectedDecoration: BoxDecoration(color: Color(0xFF03DAC6), shape: BoxShape.circle), todayDecoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle)), headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true))),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _sortedDates.length,
                  itemBuilder: (context, index) {
                    String dateKey = _sortedDates[index];
                    DateTime dt = DateTime.parse(dateKey);
                    String dayName = toBeginningOfSentenceCase(DateFormat('EEEE', 'pl_PL').format(dt))!;
                    String fullDate = DateFormat('d MMMM', 'pl_PL').format(dt);
                    bool isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;

                    return Column(children: [Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: isToday ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent, border: Border(bottom: BorderSide(color: Colors.white10))), child: Center(child: Column(children: [Text(dayName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isToday ? Theme.of(context).primaryColor : Colors.white)), Text(fullDate, style: const TextStyle(color: Colors.white70))]))), Expanded(child: _buildDayTimeline(_groupedClasses[dateKey]!, isToday))]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getColorForType(String type) {
    type = type.toLowerCase();
    if (type.contains('wykład')) return const Color(0xFF03DAC6);
    if (type.contains('ćwiczenia')) return Colors.orangeAccent;
    if (type.contains('lab')) return Colors.blueAccent;
    return Colors.grey;
  }
}