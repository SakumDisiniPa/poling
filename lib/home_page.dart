import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

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
          _userName = 'User';
        });
      }
    } else {
      setState(() {
        _userName = 'Tamu';
      });
    }
  }

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

  // Fungsi untuk memeriksa apakah polling sedang aktif berdasarkan waktu
  bool _isPollActive(String startTimeStr, String endTimeStr) {
    try {
      final now = DateTime.now();
      
      final startParts = startTimeStr.split(':');
      final int startHour = int.parse(startParts[0]);
      final int startMinute = int.parse(startParts[1]);
      
      final endParts = endTimeStr.split(':');
      final int endHour = int.parse(endParts[0]);
      final int endMinute = int.parse(endParts[1]);

      final startTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
      final endTime = DateTime(now.year, now.month, now.day, endHour, endMinute);

      if (endTime.isBefore(startTime)) {
        if (now.isAfter(startTime) && now.isBefore(DateTime(now.year, now.month, now.day, 23, 59, 59))) {
          return true;
        }
        if (now.isAfter(DateTime(now.year, now.month, now.day, 0, 0, 0)) && now.isBefore(endTime)) {
          return true;
        }
        return false;
      } else {
        return now.isAfter(startTime) && now.isBefore(endTime);
      }
    } catch (e) {
      print('Error parsing poll time: $e');
      return false;
    }
  }

  // Fungsi untuk melakukan voting pada polling
  Future<void> _voteOnPoll(String pollId, String optionKey, String pollTitle, String optionText, String startTimeStr, String endTimeStr) async {
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

    // Periksa apakah polling sedang aktif
    if (!_isPollActive(startTimeStr, endTimeStr)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Polling ini tidak aktif saat ini.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    DocumentReference userPollVoteRef = FirebaseFirestore.instance
        .collection('user_votes')
        .doc(currentUser!.uid)
        .collection('polls_voted')
        .doc(pollId);

    try {
      // Ambil pilihan user sebelumnya untuk polling ini (jika ada)
      DocumentSnapshot prevVoteDoc = await userPollVoteRef.get();
      String? prevOptionKey;
      if (prevVoteDoc.exists) {
        prevOptionKey = (prevVoteDoc.data() as Map<String, dynamic>)['optionVoted'] as String?;
      }

      // Jika user mengubah pilihan
      if (prevOptionKey != null && prevOptionKey != optionKey) {
        // Kurangi vote dari pilihan sebelumnya di Realtime Database
        final DatabaseReference prevOptionRef = FirebaseDatabase.instance
            .ref('polls/$pollId/options/$prevOptionKey/votes');
        final DataSnapshot prevVotesSnapshot = await prevOptionRef.get();
        int prevVotes = (prevVotesSnapshot.value as int?) ?? 0;
        if (prevVotes > 0) {
          await prevOptionRef.set(prevVotes - 1);
        }
      }

      // Tambahkan vote ke pilihan baru
      final DatabaseReference newOptionRef = FirebaseDatabase.instance
          .ref('polls/$pollId/options/$optionKey/votes');
      final DataSnapshot newVotesSnapshot = await newOptionRef.get();
      int newVotes = (newVotesSnapshot.value as int?) ?? 0;
      await newOptionRef.set(newVotes + 1);


      // Simpan/update status vote user di Firestore
      await userPollVoteRef.set({
        'optionVoted': optionKey,
        'votedAt': FieldValue.serverTimestamp(), // Update timestamp setiap kali ganti pilihan
        'pollTitle': pollTitle,
        'optionText': optionText,
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
        iconTheme: const IconThemeData(color: Colors.white),
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
          stream: FirebaseDatabase.instance.ref('polls').onValue,
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
                  final String startTimeStr = poll['startTime'] ?? '00:00';
                  final String endTimeStr = poll['endTime'] ?? '23:59';
                  final Map<dynamic, dynamic> options = poll['options'] ?? {};

                  bool isActive = _isPollActive(startTimeStr, endTimeStr);

                  // Hitung total votes untuk polling ini
                  int totalVotes = 0;
                  options.forEach((key, value) {
                    totalVotes += (value['votes'] as int?) ?? 0;
                  });

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
                          const SizedBox(height: 5),
                          Text(
                            'Status: ${isActive ? 'Aktif' : 'Tidak Aktif'} ($startTimeStr - $endTimeStr)',
                            style: TextStyle(
                              fontSize: 14,
                              color: isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: options.entries.map((entry) {
                              final String optionKey = entry.key;
                              final String optionText = entry.value['text'] ?? 'Opsi Tidak Tersedia';
                              final int votesForOption = (entry.value['votes'] as int?) ?? 0;

                              // Hitung persentase
                              double percentage = totalVotes > 0 ? (votesForOption / totalVotes) * 100 : 0.0;
                              String percentageStr = percentage.toStringAsFixed(1); // Format 1 angka di belakang koma

                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('user_votes').doc(currentUser!.uid).collection('polls_voted').doc(pollId).get(),
                                builder: (context, voteSnapshot) {
                                  String? userVotedOption;
                                  Timestamp? lastVotedAt;

                                  if (voteSnapshot.hasData && voteSnapshot.data!.exists) {
                                    final voteData = voteSnapshot.data!.data() as Map<String, dynamic>;
                                    userVotedOption = voteData['optionVoted'] as String?;
                                    lastVotedAt = voteData['votedAt'] as Timestamp?;
                                  }

                                  bool hasVoted = userVotedOption != null;
                                  bool isSelected = userVotedOption == optionKey;

                                  String lastVoteInfo = '';
                                  if (lastVotedAt != null) {
                                    final DateTime lastVoteDateTime = lastVotedAt.toDate();
                                    String twoDigits(int n) => n.toString().padLeft(2, '0');
                                    lastVoteInfo = ' (Terakhir memilih: ${twoDigits(lastVoteDateTime.hour)}:${twoDigits(lastVoteDateTime.minute)})';
                                  }

                                  return RadioListTile<String>(
                                    title: Text(
                                      '$optionText ${hasVoted ? '($percentageStr%)' : ''} ${isSelected ? lastVoteInfo : ''}', // Tampilkan persentase jika sudah vote
                                      style: TextStyle(
                                        color: (hasVoted && !isSelected) || !isActive ? Colors.grey : Colors.black,
                                      ),
                                    ),
                                    value: optionKey,
                                    groupValue: hasVoted ? userVotedOption : null,
                                    onChanged: isActive ? (String? value) {
                                      if (value != null) {
                                        _voteOnPoll(pollId, value, title, optionText, startTimeStr, endTimeStr);
                                      }
                                    } : null,
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
