import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CustomEvent {
  final String id; // Unique ID
  final String date; // yyyy-MM-dd
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String title;
  final String type; // 'Egzamin', 'Kolokwium', 'Inne'
  final String room;
  final String note;

  CustomEvent({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.type,
    required this.room,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'title': title,
    'type': type,
    'room': room,
    'note': note,
  };

  factory CustomEvent.fromJson(Map<String, dynamic> json) => CustomEvent(
    id: json['id'],
    date: json['date'],
    startTime: json['startTime'],
    endTime: json['endTime'],
    title: json['title'],
    type: json['type'],
    room: json['room'],
    note: json['note'],
  );
}

class CustomEventsService {
  static Future<List<CustomEvent>> getEvents(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'events_$groupId';
    final String? data = prefs.getString(key);

    if (data == null) return [];

    List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => CustomEvent.fromJson(e)).toList();
  }

  static Future<void> saveEvent(String groupId, CustomEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'events_$groupId';

    List<CustomEvent> current = await getEvents(groupId);
    // Check if update or new
    int index = current.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      current[index] = event;
    } else {
      current.add(event);
    }

    String jsonStr = jsonEncode(current.map((e) => e.toJson()).toList());
    await prefs.setString(key, jsonStr);
  }

  static Future<void> deleteEvent(String groupId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'events_$groupId';

    List<CustomEvent> current = await getEvents(groupId);
    current.removeWhere((e) => e.id == eventId);

    String jsonStr = jsonEncode(current.map((e) => e.toJson()).toList());
    await prefs.setString(key, jsonStr);
  }
}
