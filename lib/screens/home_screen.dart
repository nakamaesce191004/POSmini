import 'package:flutter/material.dart';
import 'kasir_screen.dart';
import 'presensi_screen.dart';
import 'settlement_screen.dart';
import 'aksi_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  final VoidCallback? onLogout;
  const HomeScreen({super.key, required this.role, this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _widgetOptions {
    if (widget.role == 'kasir') {
      return <Widget>[
        const KasirScreen(),
        const PresensiScreen(),
        const SettlementScreen(),
      ];
    }
    return <Widget>[
      const KasirScreen(),
      const PresensiScreen(),
      const SettlementScreen(),
      AksiScreen(
        onBack: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      ),
      SettingsScreen(onLogout: widget.onLogout),
    ];
  }


  void _onItemTapped(int index) {
    if (widget.role == 'kasir' && index == 3) {
      if (widget.onLogout != null) widget.onLogout!();
      return;
    }
    setState(() {
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
                  destinations: <NavigationRailDestination>[
                    const NavigationRailDestination(
                      icon: Icon(Icons.calculate_outlined),
                      selectedIcon: Icon(Icons.calculate),
                      label: Text('Kasir'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.assignment_ind_outlined),
                      selectedIcon: Icon(Icons.assignment_ind),
                      label: Text('Presensi'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.trending_up_outlined),
                      selectedIcon: Icon(Icons.trending_up),
                      label: Text('Settlement'),
                    ),
                    if (widget.role == 'admin') ...[
                      const NavigationRailDestination(
                        icon: Icon(Icons.flash_on_outlined),
                        selectedIcon: Icon(Icons.flash_on),
                        label: Text('Aksi'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Pengaturan'),
                      ),
                    ],
                  ],
                  trailing: widget.role == 'kasir' 
                    ? Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: IconButton(
                              icon: const Icon(Icons.logout, color: Colors.red),
                              onPressed: widget.onLogout,
                              tooltip: 'Keluar',
                            ),
                          ),
                        ),
                      )
                    : null,
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _widgetOptions[_selectedIndex]),
              ],
            )
          : _widgetOptions[_selectedIndex],
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                const BottomNavigationBarItem(
                  icon: Icon(Icons.calculate_outlined),
                  activeIcon: Icon(Icons.calculate),
                  label: 'Kasir',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_ind_outlined),
                  activeIcon: Icon(Icons.assignment_ind),
                  label: 'Presensi',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up_outlined),
                  activeIcon: Icon(Icons.trending_up),
                  label: 'Settlement',
                ),
                if (widget.role == 'admin') ...[
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.flash_on_outlined),
                    activeIcon: Icon(Icons.flash_on),
                    label: 'Aksi',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Pengaturan',
                  ),
                ],
                if (widget.role == 'kasir') ...[
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.logout, color: Colors.red),
                    label: 'Keluar',
                  ),
                ],
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
