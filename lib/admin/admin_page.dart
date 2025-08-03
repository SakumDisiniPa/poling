import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import untuk Firebase Authentication
import '../login_page.dart'; // Import halaman login untuk navigasi setelah logout
import 'add_user_form.dart'; // Import widget AddUserForm
import 'create_poll_page.dart'; // Import halaman untuk membuat polling
import 'poll_list_page.dart'; // Import halaman untuk daftar polling
import 'user_list_page.dart'; // Import halaman baru untuk daftar user

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Fungsi untuk logout
  Future<void> _logout() async {
    // Menampilkan dialog konfirmasi sebelum logout
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari Admin Panel?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Tidak jadi logout
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Konfirmasi logout
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Kembali ke halaman login setelah logout
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white), // Teks putih
        ),
        backgroundColor: const Color(0xFF673AB7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Icon drawer putih
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF673AB7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 50,
                    width: 50,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Color(0xFF673AB7)),
              title: const Text('Tambah User'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.how_to_vote, color: Color(0xFF673AB7)),
              title: const Text('Buat Polling'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePollPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: Color(0xFF673AB7)),
              title: const Text('Daftar Polling'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PollListPage()),
                );
              },
            ),
            ListTile( // Tambahkan ListTile baru untuk Daftar User
              leading: const Icon(Icons.people, color: Color(0xFF673AB7)),
              title: const Text('Daftar User'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserListPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: _logout, // Panggil fungsi logout
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah User Baru',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF673AB7),
                ),
              ),
              const SizedBox(height: 20),
              const AddUserForm(), // Widget untuk menambah user
            ],
          ),
        ),
      ),
    );
  }
}
