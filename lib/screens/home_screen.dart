import 'package:flutter/material.dart';
import 'kasir_screen.dart';
import 'presensi_screen.dart';
import 'tren_screen.dart';
import 'aksi_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isAuthenticated = false;

  List<Widget> get _widgetOptions => <Widget>[
    const KasirScreen(),
    const PresensiScreen(),
    TrenScreen(),
    _getAksiContent(),
    const Center(child: Text('Pengaturan')), // Placeholder
  ];

  Widget _getAksiContent() {
    if (!_isAuthenticated) {
      return LoginScreen(
        onLoginSuccess: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
        onBack: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      );
    }
    return AksiScreen(
      onBack: () {
        setState(() {
          _selectedIndex = 0;
          _isAuthenticated = false;
        });
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      // Jika keluar dari Menu Aksi (index 3), reset status login
      if (_selectedIndex == 3 && index != 3) {
        _isAuthenticated = false;
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mengecek apakah ukuran layar cukup besar untuk mode Desktop (laptop/tablet landscape)
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Colors.orange),
                  unselectedIconTheme: const IconThemeData(color: Colors.grey),
                  selectedLabelTextStyle: const TextStyle(color: Colors.orange),
                  destinations: const <NavigationRailDestination>[
                    NavigationRailDestination(
                      icon: Icon(Icons.calculate_outlined),
                      selectedIcon: Icon(Icons.calculate),
                      label: Text('Kasir'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_ind_outlined),
                      selectedIcon: Icon(Icons.assignment_ind),
                      label: Text('Presensi'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.trending_up_outlined),
                      selectedIcon: Icon(Icons.trending_up),
                      label: Text('Tren'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.flash_on_outlined),
                      selectedIcon: Icon(Icons.flash_on),
                      label: Text('Aksi'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Pengaturan'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _widgetOptions[_selectedIndex]),
              ],
            )
          : _widgetOptions[_selectedIndex],
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.calculate_outlined),
                  activeIcon: Icon(Icons.calculate),
                  label: 'Kasir',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_ind_outlined),
                  activeIcon: Icon(Icons.assignment_ind),
                  label: 'Presensi',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up_outlined),
                  activeIcon: Icon(Icons.trending_up),
                  label: 'Tren',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.flash_on_outlined),
                  activeIcon: Icon(Icons.flash_on),
                  label: 'Aksi',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Pengaturan',
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.orange,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              onTap: _onItemTapped,
            ),
    );
  }
}
