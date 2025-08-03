import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Untuk mendapatkan nama user dan menyimpan status vote
import 'package:firebase_database/firebase_database.dart'; // Untuk menampilkan dan mengupdate polling
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName; // Untuk menyimpan nama user
  final User? currentUser = FirebaseAuth.instance.currentUser; // User yang sedang login

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Panggil fungsi untuk mengambil nama user
  }

  // Fungsi untuk mengambil nama user dari Firestore
  Future<void> _fetchUserName() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            _userName = (userDoc.data() as Map<String, dynamic>)['name'] ?? 'User';
          });
        }
      } catch (e) {
        print('Error fetching user name: $e');
        setState(() {
          _userName = 'User'; // Fallback jika gagal mengambil nama
        });
      }
    } else {
      setState(() {
        _userName = 'Tamu'; // Jika tidak ada user login
      });
    }
  }

  // Fungsi untuk logout
  Future<void> _logout() async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  // Fungsi untuk melakukan voting pada polling
  Future<void> _voteOnPoll(String pollId, String optionKey, String pollTitle, String optionText) async {
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda harus login untuk memilih polling.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Referensi ke dokumen user di Firestore untuk menyimpan status vote
    // Mengubah struktur penyimpanan vote user di subkoleksi
    DocumentReference userPollVoteRef = FirebaseFirestore.instance
        .collection('user_votes')
        .doc(currentUser!.uid)
        .collection('polls_voted') // Subkoleksi baru
        .doc(pollId); // Dokumen untuk setiap polling yang divote

    try {
      // Periksa apakah user sudah memilih polling ini
      DocumentSnapshot userVoteDoc = await userPollVoteRef.get();
      if (userVoteDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah memilih polling ini.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return; // Hentikan jika sudah memilih
      }

      // 1. Update jumlah vote di Realtime Database
      final DatabaseReference optionRef = FirebaseDatabase.instance
          .ref('polls/$pollId/options/$optionKey/votes');

      // Ambil nilai saat ini dan increment
      final DataSnapshot currentVotesSnapshot = await optionRef.get();
      int currentVotes = (currentVotesSnapshot.value as int?) ?? 0;
      await optionRef.set(currentVotes + 1); // Langsung set nilai baru

      // 2. Simpan status vote user di Firestore (di subkoleksi)
      await userPollVoteRef.set({
        'optionVoted': optionKey,
        'votedAt': FieldValue.serverTimestamp(), // Simpan timestamp
        'pollTitle': pollTitle, // Simpan judul polling untuk kemudahan
        'optionText': optionText, // Simpan teks opsi yang dipilih
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilihan Anda berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saat voting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pilihan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Halaman Utama',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
                  // Nama user di drawer
                  Text(
                    'Halo, ${_userName ?? 'Loading...'}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    currentUser?.email ?? 'Tidak ada email',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder(
          stream: FirebaseDatabase.instance.ref('polls').onValue, // Mendengarkan polling
          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(
                child: Text(
                  'Belum ada polling yang tersedia.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            } else {
              Map<dynamic, dynamic> pollsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              List<Map<dynamic, dynamic>> polls = [];
              pollsMap.forEach((key, value) {
                polls.add({'id': key, ...value});
              });

              polls.sort((a, b) {
                int timestampA = a['createdAt'] ?? 0;
                int timestampB = b['createdAt'] ?? 0;
                return timestampB.compareTo(timestampA);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: polls.length,
                itemBuilder: (context, index) {
                  final poll = polls[index];
                  final String pollId = poll['id'];
                  final String title = poll['title'] ?? 'Judul Tidak Tersedia';
                  final Map<dynamic, dynamic> options = poll['options'] ?? {};

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
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF673AB7),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Menampilkan opsi polling sebagai RadioListTile untuk voting
                          Column(
                            children: options.entries.map((entry) {
                              final String optionKey = entry.key;
                              final String optionText = entry.value['text'] ?? 'Opsi Tidak Tersedia';

                              return FutureBuilder<DocumentSnapshot>(
                                // Mengambil data vote dari subkoleksi
                                future: FirebaseFirestore.instance.collection('user_votes').doc(currentUser!.uid).collection('polls_voted').doc(pollId).get(),
                                builder: (context, voteSnapshot) {
                                  String? userVotedOption;
                                  if (voteSnapshot.hasData && voteSnapshot.data!.exists) {
                                    userVotedOption = (voteSnapshot.data!.data() as Map<String, dynamic>)['optionVoted'] as String?;
                                  }

                                  bool hasVoted = userVotedOption != null;
                                  bool isSelected = userVotedOption == optionKey;

                                  return RadioListTile<String>(
                                    title: Text(
                                      optionText,
                                      style: TextStyle(
                                        color: hasVoted && !isSelected ? Colors.grey : Colors.black,
                                      ),
                                    ),
                                    value: optionKey,
                                    groupValue: hasVoted ? userVotedOption : null,
                                    onChanged: hasVoted ? null : (String? value) {
                                      if (value != null) {
                                        // Meneruskan judul dan teks opsi ke _voteOnPoll
                                        _voteOnPoll(pollId, value, title, optionText);
                                      }
                                    },
                                    activeColor: const Color(0xFF673AB7),
                                  );
                                },
                              );
                            }).toList(),
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
      ),
    );
  }
}
