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
  bool _isDeleting = false; // Status loading untuk tombol delete

  @override
  void initState() {
    super.initState();
    _pollsRef = FirebaseDatabase.instance.ref('polls'); // Inisialisasi referensi
  }

  // Fungsi untuk menghapus polling
  Future<void> _deletePoll(String pollId, String pollTitle) async {
    // Tampilkan dialog konfirmasi sebelum menghapus
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus Polling'),
          content: Text('Apakah Anda yakin ingin menghapus polling "$pollTitle"? Tindakan ini tidak dapat dibatalkan.'),
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
        // Hapus polling dari Realtime Database
        await _pollsRef.child(pollId).remove();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Polling berhasil dihapus!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus polling: $e'),
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

  // Fungsi untuk memeriksa apakah polling sedang aktif berdasarkan waktu (sama seperti di HomePage)
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

      if (endTime.isBefore(startTime)) { // Polling melintasi tengah malam
        if (now.isAfter(startTime) && now.isBefore(DateTime(now.year, now.month, now.day, 23, 59, 59))) {
          return true;
        }
        if (now.isAfter(DateTime(now.year, now.month, now.day, 0, 0, 0)) && now.isBefore(endTime)) {
          return true;
        }
        return false;
      } else { // Polling dalam satu hari
        return now.isAfter(startTime) && now.isBefore(endTime);
      }
    } catch (e) {
      print('Error parsing poll time: $e');
      return false;
    }
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
                final String startTimeStr = poll['startTime'] ?? '00:00'; // Ambil waktu mulai
                final String endTimeStr = poll['endTime'] ?? '23:59';     // Ambil waktu berakhir
                final Map<dynamic, dynamic> options = poll['options'] ?? {};

                bool isActive = _isPollActive(startTimeStr, endTimeStr); // Cek status aktif

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
                        // Tampilkan status dan rentang waktu
                        Text(
                          'Status: ${isActive ? 'Aktif' : 'Tidak Aktif'} ($startTimeStr - $endTimeStr)',
                          style: TextStyle(
                            fontSize: 14,
                            color: isActive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
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
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
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
                                'Edit',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _isDeleting ? null : () => _deletePoll(pollId, title),
                              icon: const Icon(Icons.delete, color: Colors.white),
                              label: const Text(
                                'Hapus',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
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
