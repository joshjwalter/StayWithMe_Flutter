import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
//import 'home.dart';
import 'alarm.dart';
import 'settings.dart';

void main() {
  tzdata.initializeTimeZones();
  // Use UTC as the local timezone location. DateTime values used for
  // notification scheduling are absolute instants, so UTC is correct and
  // avoids relying on the unreliable timeZoneName abbreviation (e.g. "PDT")
  // which is not a valid IANA tz database key.
  tz.setLocalLocation(tz.UTC);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Flutter is fun!'),
        ),

        bottomNavigationBar: NavigationBottom(),
      ),
    );
  }
}

class NavigationBottom extends StatefulWidget {
  const NavigationBottom({super.key});

  @override
  State<NavigationBottom> createState() => _NavigationBottomState();
}

class _NavigationBottomState extends State<NavigationBottom> {
  int currentPageIndex = 0;
  bool debugMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.alarm), label: "Alarm"),
          NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
        ],
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
      ),
      body: IndexedStack(
        index: currentPageIndex,
        children: [
          const Center(
            child: Text("Home"),
          ), // Make these three widgets of completely built out pages so i can just import
          AlarmPage(debugModeEnabled: debugMode),
          SettingsPage(
            debugMode: debugMode,
            onDebugModeChanged: (bool value) {
              setState(() {
                debugMode = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
