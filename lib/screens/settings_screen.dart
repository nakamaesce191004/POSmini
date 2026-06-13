import 'package:flutter/material.dart';
import 'printer_settings_screen.dart';
import 'user_account_screen.dart';
import 'smtp_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback? onLogout;
  const SettingsScreen({super.key, this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildSectionHeader('Keamanan'),
          _buildSettingItem(
            context,
            icon: Icons.person_outline,
            title: 'Manajemen Akun',
            subtitle: 'Atur username dan password Admin/Kasir',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserAccountScreen())),
          ),
          
          const Divider(height: 32, indent: 20, endIndent: 20),
          
          _buildSectionHeader('Perangkat'),
          _buildSettingItem(
            context,
            icon: Icons.print_outlined,
            title: 'Printer',
            subtitle: 'Atur koneksi printer bluetooth/thermal',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrinterSettingsScreen())),
          ),
          _buildSettingItem(
            context,
            icon: Icons.email_outlined,
            title: 'Email SMTP',
            subtitle: 'Konfigurasi email untuk kirim OTP reset password',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SmtpSettingsScreen())),
          ),
          
          const Divider(height: 32, indent: 20, endIndent: 20),
          
          _buildSectionHeader('Aplikasi'),
          _buildSettingItem(
            context,
            icon: Icons.info_outline,
            title: 'Tentang Aplikasi',
            subtitle: 'Versi 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Kasir Pintar POS',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.calculate, size: 48, color: Colors.orange),
                children: [
                  const Text('Aplikasi Point of Sale (POS) sederhana untuk manajemen toko.'),
                ],
              );
            },
          ),
          
          if (onLogout != null) ...[
            const Divider(height: 32, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Keluar?'),
                      content: const Text('Anda akan dikembalikan ke layar login.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onLogout!();
                          },
                          child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari Aplikasi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.orange),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}
