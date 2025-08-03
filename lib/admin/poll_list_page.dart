import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Realtime Database
import 'edit_poll_page.dart'; // Import halaman edit polling
import 'poll_detail_page.dart'; // Import halaman detail polling yang baru

class PollListPage extends StatefulWidget {
  const PollListPage({super.key});

  @override
  State<PollListPage> createState() => _PollListPageState();
}

class _PollListPageState extends State<PollListPage> {
  late DatabaseReference _pollsRef; // Referensi ke node 'polls' di Realtime Database

  @override
  void initState() {
    super.initState();
    _pollsRef = FirebaseDatabase.instance.ref('polls'); // Inisialisasi referensi
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daftar Polling',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF673AB7),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: _pollsRef.onValue, // Mendengarkan perubahan data secara real-time
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Text(
                'Belum ada polling yang dibuat.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          } else {
            // Data polling berhasil diambil
            Map<dynamic, dynamic> pollsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            List<Map<dynamic, dynamic>> polls = [];
            pollsMap.forEach((key, value) {
              // Menambahkan pollId ke dalam data polling
              polls.add({'id': key, ...value});
            });

            // Urutkan polling berdasarkan tanggal pembuatan terbaru
            polls.sort((a, b) {
              int timestampA = a['createdAt'] ?? 0;
              int timestampB = b['createdAt'] ?? 0;
              return timestampB.compareTo(timestampA); // Terbaru di atas
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
                        // Menampilkan opsi polling
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: options.entries.map((entry) {
                            final optionText = entry.value['text'] ?? 'Opsi Tidak Tersedia';
                            final votes = entry.value['votes'] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                '- $optionText ($votes suara)',
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 15),
                        Row( // Gunakan Row untuk menempatkan tombol bersebelahan
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon( // Tombol Detail
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PollDetailPage(pollId: pollId, pollTitle: title),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.info_outline, color: Colors.white),
                              label: const Text(
                                'Detail',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent, // Warna untuk tombol detail
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10), // Spasi antara tombol
                            ElevatedButton.icon( // Tombol Edit
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditPollPage(pollId: pollId, pollData: poll),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text(
                                'Edit', // Ubah teks menjadi 'Edit' agar lebih singkat
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
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
