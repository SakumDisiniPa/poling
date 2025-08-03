import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'edit_user_page.dart'; // Import halaman edit user

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
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
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton.icon(
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
                              'Edit User',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange, // Warna untuk tombol edit
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
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
