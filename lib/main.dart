import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// TODO: put YOUR GitHub username here
const apiUrl =
    'https://raw.githubusercontent.com/Leslie-24/classync/main/courses.json';

void main() {
  runApp(const ClassyncApp());
}

class ClassyncApp extends StatelessWidget {
  const ClassyncApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Classync',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF245C43),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F5),
          foregroundColor: Color(0xFF183B2B),
          elevation: 0,
        ),
      ),
      home: const WeekScreen(),
    );
  }
}
class Course{
  final String name;
  final String day;
  final String start;
  final String end;

  const Course({
    required this.name,
    required this.day,
    required this.start,
    required this.end,
  });

  // NEW: build a Course from the JSON the server sends
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'] as String,
      day: json['day'] as String,
      start: json['start'] as String,
      end: json['end'] as String,
    );
  }

  // NEW: turn a Course into a Map, to save it on the phone
  Map<String, dynamic> toJson() {
    return {'name': name, 'day': day, 'start': start, 'end': end};
  }
}

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  String selectedDay = 'Monday';

  // CHANGED: no more hard-coded courses, they come from the API
  List<Course> courses = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    start();
  }

  // NEW: saved courses first; the server only the very first time
  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('courses');

    if (saved != null) {
      final list = jsonDecode(saved) as List;
      setState(() {
        courses = list
            .map((x) => Course.fromJson(x as Map<String, dynamic>))
            .toList();
        loading = false;
      });
    } else {
      await load();
    }
  }

  // NEW: ask the server (same idea as the weather app)
  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode != 200) {
        throw Exception('The server answered ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['courses'] as List;
      final result = list
          .map((x) => Course.fromJson(x as Map<String, dynamic>))
          .toList();
      setState(() {
        courses = result;
        loading = false;
      });
      await saveCourses();
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Could not load your courses. Check your internet connection.';
      });
    }
  }

  // NEW: save the whole list on the phone (call after every change)
  Future<void> saveCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final list = courses.map((course) => course.toJson()).toList();
    await prefs.setString('courses', jsonEncode(list));
  }

  // NEW: open the add / edit screen. existing == null means adding.
  Future<void> openForm(Course? existing) async {
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => CourseFormScreen(
          course: existing,
          initialDay: selectedDay,
          days: days,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      if (result is Course) {
        if (existing == null) {
          courses.add(result);
        } else {
          courses[courses.indexOf(existing)] = result;
        }
        selectedDay = result.day;
      } else if (result == 'delete') {
        courses.remove(existing);
      }
    });
    await saveCourses();
  }

  int get weeklyMinutes {
    int total = 0;

    for (final course in courses) {
      total += toMinutes(course.end) - toMinutes(course.start);
    }

    return total;
  }

  int get dailyMinutes {
    int total = 0;

    for (final course in courses.where((c) => c.day == selectedDay)) {
      total += toMinutes(course.end) - toMinutes(course.start);
    }

    return total;
  }

  int toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  List<Course> clashesFor(Course course){
    return courses.where((other){
      if (identical(course, other)|| other.day !=course.day){
        return false;
      }
      final courseStart = toMinutes(course.start);
      final courseEnd = toMinutes(course.end);
      final otherStart = toMinutes(other.start);
      final otherEnd = toMinutes(other.end);
      return courseStart < otherEnd && otherStart < courseEnd;
    }).toList();
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) return '${remainingMinutes}m';
    if (remainingMinutes == 0) return '${hours}h';

    return '${hours}h ${remainingMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final dayCourses = courses
        .where((course) => course.day == selectedDay)
        .toList()
      ..sort(
            (a, b) => toMinutes(a.start).compareTo(toMinutes(b.start)),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 28),
            SizedBox(width: 10),
            Text(
              'Classync',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      // NEW: button to add a course
      floatingActionButton: (loading || error != null)
          ? null
          : FloatingActionButton(
              onPressed: () => openForm(null),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        // NEW: the three states: loading, error, data
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'YOUR WEEK, IN SYNC.',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                color: Color(0xFF56816A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Class schedule',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF183B2B),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF245C43),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL CLASS TIME',
                          style: TextStyle(
                            color: Color(0xFFD1E7D8),
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatDuration(weeklyMinutes),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Choose a day',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final selected = selectedDay == day;

                  return ChoiceChip(
                    label: Text(day.substring(0, 3)),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => selectedDay = day);
                    },
                    selectedColor: const Color(0xFF245C43),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF245C43)
                            : const Color(0xFFE1E7E2),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDay,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF183B2B),
                    ),
                  ),
                ),
                Text(
                  formatDuration(dailyMinutes),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF56816A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (dayCourses.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'No classes on $selectedDay',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              )
            else
              ...dayCourses.map(

(course) {
  final clashes = clashesFor(course);
  final hasClash = clashes.isNotEmpty;

  return GestureDetector(
    onTap: () => openForm(course),
    child: Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: hasClash ? const Color(0xFFFFEEEE) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border(
        left: BorderSide(
          color: hasClash ? Colors.red : const Color(0xFF6AA581),
          width: 4,
        ),
      ),
    ),
    child: Row(
      children: [
        Icon(
          hasClash
              ? Icons.warning_amber_rounded
              : Icons.access_time_rounded,
          color: hasClash ? Colors.red : const Color(0xFF56816A),
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasClash ? Colors.red.shade800 : Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${course.start} – ${course.end}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              if (hasClash) ...[
                const SizedBox(height: 8),
                Text(
                  'Clashes with ${clashes.map((c) => c.name).join(', ')}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          formatDuration(
            toMinutes(course.end) - toMinutes(course.start),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: hasClash ? Colors.red : const Color(0xFF56816A),
          ),
        ),
      ],
    ),
  ));
},
    ),
    const SizedBox(height: 80),
    ]
        ),
      ),
    );
  }
}

// NEW: add / edit screen. Closes with a Course (save) or with 'delete'.
class CourseFormScreen extends StatefulWidget {
  const CourseFormScreen({
    super.key,
    this.course,
    required this.initialDay,
    required this.days,
  });

  final Course? course; // null = adding a new course
  final String initialDay;
  final List<String> days;

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  late final TextEditingController nameController;
  late final TextEditingController startController;
  late final TextEditingController endController;
  late String day;
  String? error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.course?.name ?? '');
    startController = TextEditingController(text: widget.course?.start ?? '');
    endController = TextEditingController(text: widget.course?.end ?? '');
    day = widget.course?.day ?? widget.initialDay;
  }

  @override
  void dispose() {
    nameController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  // Lab 1: text 'HH:MM' -> minutes. null when the text is not a valid time.
  int? parseTime(String text) {
    final parts = text.trim().split(':');
    if (parts.length != 2) return null;

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    if (hours < 0 || hours > 23) return null;
    if (minutes < 0 || minutes > 59) return null;

    return hours * 60 + minutes;
  }

  // Lab 1: minutes -> text 'HH:MM'
  String timeToText(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  void save() {
    final name = nameController.text.trim();
    final start = parseTime(startController.text);
    final end = parseTime(endController.text);

    if (name.isEmpty) {
      setState(() => error = 'Please type the course name.');
      return;
    }
    if (start == null) {
      setState(() => error = 'Start time must look like 08:00 (hours 00-23, minutes 00-59).');
      return;
    }
    if (end == null) {
      setState(() => error = 'End time must look like 10:30 (hours 00-23, minutes 00-59).');
      return;
    }
    if (end <= start) {
      setState(() => error = 'The end time must be after the start time.');
      return;
    }

    Navigator.pop(
      context,
      Course(
        name: name,
        day: day,
        start: timeToText(start),
        end: timeToText(end),
      ),
    );
  }

  Future<void> confirmDelete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: Text('Delete ${widget.course!.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (sure == true && mounted) {
      Navigator.pop(context, 'delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.course != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit course' : 'Add course'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Course name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Day'),
          DropdownButton<String>(
            value: day,
            isExpanded: true,
            items: widget.days
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (value) {
              setState(() => day = value!);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: 'Start (08:00)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: 'End (10:00)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: save,
            child: Text(editing ? 'Save changes' : 'Add course'),
          ),
        ],
      ),
    );
  }
}
