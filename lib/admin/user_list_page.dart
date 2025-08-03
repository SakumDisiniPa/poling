import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth (untuk referensi, meskipun delete Auth di sini terbatas)
import 'edit_user_page.dart'; // Import halaman edit user

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  bool _isDeleting = false; // Status loading untuk tombol delete

  // Fungsi untuk menghapus user
  Future<void> _deleteUser(String userId, String userName) async {
    // Tampilkan dialog konfirmasi sebelum menghapus
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus User'),
          content: Text('Apakah Anda yakin ingin menghapus user "$userName"? Tindakan ini tidak dapat dibatalkan.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Batal hapus
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Konfirmasi hapus
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() {
        _isDeleting = true; // Tampilkan loading
      });

      try {
        // Hapus dokumen user dari Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();

        // Catatan Penting:
        // Menghapus user dari Firebase Authentication (akun login)
        // TIDAK BISA langsung dilakukan dari aplikasi client-side untuk user lain.
        // Hanya user itu sendiri yang bisa menghapus akunnya sendiri dari client-side.
        // Untuk admin menghapus akun user lain, kamu perlu menggunakan Firebase Admin SDK
        // yang berjalan di lingkungan backend yang aman (misalnya Firebase Cloud Functions).
        // Jika kamu perlu fungsionalitas ini, kamu harus mengimplementasikan Cloud Function.

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User berhasil dihapus dari Firestore!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDeleting = false; // Sembunyikan loading
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daftar User',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF673AB7), // Warna ungu
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(), // Mendengarkan perubahan data user
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada user terdaftar.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          } else {
            // Data user berhasil diambil
            final users = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userDoc = users[index];
                final userData = userDoc.data() as Map<String, dynamic>;
                final String userId = userDoc.id; // UID user
                final String name = userData['name'] ?? 'Nama Tidak Tersedia';
                final String email = userData['email'] ?? 'Email Tidak Tersedia';
                final String role = userData['role'] ?? 'Tidak Diketahui';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF673AB7),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Email: $email',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Role: ${role.toUpperCase()}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 15),
                        Row( // Gunakan Row untuk menempatkan tombol bersebelahan
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigasi ke halaman edit user
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditUserPage(userId: userId, userData: userData),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text(
                                'Edit',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange, // Warna untuk tombol edit
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10), // Spasi antara tombol
                            // Tombol Hapus User
                            ElevatedButton.icon(
                              onPressed: _isDeleting ? null : () => _deleteUser(userId, name), // Panggil fungsi delete
                              icon: const Icon(Icons.delete, color: Colors.white),
                              label: const Text(
                                'Hapus',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red, // Warna untuk tombol hapus
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
