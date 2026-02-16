import 'package:flutter/material.dart';
import 'home.dart';
import 'alarm.dart';
import 'settings.dart';


void main() {
  runApp( MyApp() );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Flutter is fun!')
          ),

        bottomNavigationBar: NavigationBottom(),
      
      )
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home), 
              label: 'Home'
              ),
            NavigationDestination(
              icon: Icon(Icons.alarm),
              label: "Alarm"
              ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              label: "Settings"
              )
          ],
          selectedIndex: currentPageIndex,
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
        ),
        body: <Widget>[
          Text("Home"), //Make these three widgets of completely built out pages so i can just import
          AlarmPage(),
          Text("Settings")
        ][currentPageIndex]
    );
  }
}