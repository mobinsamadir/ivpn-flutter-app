// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modern_server_list_screen.dart';
import '../providers/home_provider.dart';
import '../widgets/home/connection_status_panel.dart';
import '../widgets/home/connection_info_panel.dart';
import '../utils/add_server_dialog.dart'; // <-- You need this import for the '+' button
import 'settings_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showServerList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModernServerListScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<HomeProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("iVPN"),
        elevation: 0,
        actions: [
          // --- THE MISSING '+' BUTTON ---
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Server or Subscription',
            onPressed: () {
              showAddServerDialog(context);
            },
          ),

          // -----------------------------
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Update Server List',
                    onPressed: () {
                      context.read<HomeProvider>().loadServersFromUrl();
                    },
                  ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Text(
                'iVPN Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('درباره ما'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ConnectionStatusPanel(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ListTile(
                onTap: () => _showServerList(context),
                leading: const Icon(Icons.location_on_outlined),
                title: const Text(
                  "Select Location",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const ConnectionInfoPanel(),
          ],
        ),
      ),
    );
  }
}
