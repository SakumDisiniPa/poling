import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Penting: Tambahkan import ini untuk StreamSubscription

class PollDetailPage extends StatefulWidget {
  final String pollId;
  final String pollTitle;

  const PollDetailPage({
    super.key,
    required this.pollId,
    required this.pollTitle,
  });

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  // Fungsi untuk format tanggal dan waktu secara manual (dengan dua digit untuk jam/menit/detik)
  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Waktu Tidak Tersedia';
    final date = timestamp.toDate();
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    String day = twoDigits(date.day);
    String month = twoDigits(date.month);
    String year = date.year.toString();
    String hour = twoDigits(date.hour);
    String minute = twoDigits(date.minute);
    String second = twoDigits(date.second);

    return '$day-$month-$year, $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Polling: ${widget.pollTitle}',
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF673AB7),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Judul Polling: ${widget.pollTitle}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF673AB7),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, usersSnapshot) {
                  if (usersSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (usersSnapshot.hasError) {
                    return Center(child: Text('Error mengambil daftar user: ${usersSnapshot.error}'));
                  }
                  if (!usersSnapshot.hasData || usersSnapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Tidak ada user terdaftar.'));
                  }

                  final allUsersDocs = usersSnapshot.data!.docs;
                  final Map<String, String> allUserNames = {
                    for (var doc in allUsersDocs) doc.id: (doc.data() as Map<String, dynamic>)['name'] ?? 'Nama Tidak Tersedia'
                  };

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('user_votes').snapshots(),
                    builder: (context, votesSnapshot) {
                      if (votesSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (votesSnapshot.hasError) {
                        return Center(child: Text('Error mengambil data vote: ${votesSnapshot.error}'));
                      }

                      List<Map<String, dynamic>> votedUsers = [];
                      Set<String> votedUserIds = {}; // Untuk melacak user yang sudah vote

                      if (votesSnapshot.hasData && votesSnapshot.data!.docs.isNotEmpty) {
                        // Mengumpulkan semua Future untuk mendapatkan data vote dari subkoleksi
                        List<Future<void>> fetchVoteFutures = [];
                        for (var userVoteDoc in votesSnapshot.data!.docs) {
                          final userId = userVoteDoc.id;
                          fetchVoteFutures.add(
                            userVoteDoc.reference.collection('polls_voted').doc(widget.pollId).get().then((pollVoteDoc) {
                              if (pollVoteDoc.exists && pollVoteDoc.data() != null) {
                                final voteData = pollVoteDoc.data() as Map<String, dynamic>;
                                final String userName = allUserNames[userId] ?? 'Nama Tidak Ditemukan';
                                
                                // Pastikan tidak ada duplikasi
                                if (!votedUserIds.contains(userId)) {
                                  votedUserIds.add(userId);
                                  votedUsers.add({
                                    'userId': userId,
                                    'userName': userName,
                                    'optionText': voteData['optionText'] ?? 'Opsi Tidak Tersedia',
                                    'votedAt': voteData['votedAt'],
                                  });
                                }
                              }
                            }).catchError((e) {
                              debugPrint('Error fetching subcollection data for $userId: $e');
                            })
                          );
                        }
                        // Menunggu semua Future selesai
                        return FutureBuilder<void>(
                          future: Future.wait(fetchVoteFutures),
                          builder: (context, futureSnapshot) {
                            if (futureSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (futureSnapshot.hasError) {
                              return Center(child: Text('Error memproses vote: ${futureSnapshot.error}'));
                            }

                            // Urutkan user yang sudah vote berdasarkan waktu vote terbaru
                            votedUsers.sort((a, b) {
                              final Timestamp timestampA = a['votedAt'] ?? Timestamp.now();
                              final Timestamp timestampB = b['votedAt'] ?? Timestamp.now();
                              return timestampB.compareTo(timestampA); // Terbaru di atas
                            });

                            // Daftar user yang belum polling
                            List<String> notVotedUserNames = [];
                            allUserNames.forEach((uid, name) {
                              if (!votedUserIds.contains(uid)) {
                                notVotedUserNames.add(name);
                              }
                            });
                            notVotedUserNames.sort(); // Urutkan berdasarkan nama

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Daftar User yang Sudah Memilih:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                votedUsers.isEmpty
                                    ? const Text('Belum ada user yang memilih polling ini.')
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: votedUsers.length,
                                        itemBuilder: (context, index) {
                                          final user = votedUsers[index];
                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 10.0),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${index + 1}. Nama: ${user['userName']}', // Urutan
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    'Memilih: ${user['optionText']}',
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                  Text(
                                                    'Waktu: ${_formatDateTime(user['votedAt'] as Timestamp?)}',
                                                    style: const TextStyle(
                                                      fontSize: 12, 
                                                      color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Daftar User yang Belum Memilih:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                notVotedUserNames.isEmpty
                                    ? const Text('Semua user sudah memilih polling ini.')
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: notVotedUserNames.length,
                                        itemBuilder: (context, index) {
                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 5.0),
                                            elevation: 1,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            color: Colors.grey[100],
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Text(
                                                '${index + 1}. ${notVotedUserNames[index]}', // Urutan
                                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ],
                            );
                          },
                        );
                      }
                      return const Center(child: CircularProgressIndicator()); // Default saat votesSnapshot belum ada data
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
