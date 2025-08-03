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
  final Map<String, String> _allUserNames = {}; // Cache untuk semua nama user
  final List<Map<String, dynamic>> _votedUsers = []; // Data user yang sudah vote
  List<String> _notVotedUserNames = []; // Data user yang belum vote

  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _votesSubscription;

  @override
  void initState() {
    super.initState();
    _loadAllUsersAndVotes(); // Memuat semua user dan vote
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _votesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAllUsersAndVotes() async {
    // 1. Ambil semua user terlebih dahulu dan cache namanya
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in usersSnapshot.docs) {
      _allUserNames[doc.id] = (doc.data())['name'] ?? 'Nama Tidak Tersedia';
    }

    // 2. Setup listener untuk vote user
    _votesSubscription = FirebaseFirestore.instance
        .collection('user_votes')
        .snapshots()
        .listen((votesSnapshot) async {
      await _processData(votesSnapshot);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }, onError: (error) {
      debugPrint('Error listening to user_votes: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _processData(QuerySnapshot votesSnapshot) async {
    final List<Map<String, dynamic>> tempVotedUsers = [];
    final Set<String> votedUserIds = {}; // Untuk melacak UID user yang sudah vote

    for (final userVoteDoc in votesSnapshot.docs) {
      final userId = userVoteDoc.id;
      try {
        // Ambil dokumen vote spesifik untuk polling ini dari subkoleksi
        final pollVoteDoc = await userVoteDoc.reference
            .collection('polls_voted')
            .doc(widget.pollId)
            .get();

        if (pollVoteDoc.exists && pollVoteDoc.data() != null) {
          final voteData = pollVoteDoc.data() as Map<String, dynamic>;
          final userName = _allUserNames[userId] ?? 'User Tidak Ditemukan'; // Ambil dari cache

          tempVotedUsers.add({
            'userId': userId,
            'userName': userName,
            'optionText': voteData['optionText'] ?? 'Opsi Tidak Tersedia',
            'votedAt': voteData['votedAt'],
          });
          votedUserIds.add(userId); // Tandai user ini sudah vote
        }
      } catch (e) {
        debugPrint('Error processing vote for user $userId: $e');
      }
    }

    // Urutkan user yang sudah vote berdasarkan waktu vote terbaru
    tempVotedUsers.sort((a, b) {
      final Timestamp timestampA = a['votedAt'] ?? Timestamp.now();
      final Timestamp timestampB = b['votedAt'] ?? Timestamp.now();
      return timestampB.compareTo(timestampA);
    });

    // Tentukan user yang belum polling
    List<String> tempNotVotedUserNames = [];
    _allUserNames.forEach((uid, name) {
      if (!votedUserIds.contains(uid)) {
        tempNotVotedUserNames.add(name);
      }
    });
    tempNotVotedUserNames.sort(); // Urutkan berdasarkan nama

    if (mounted) {
      setState(() {
        _votedUsers.clear();
        _votedUsers.addAll(tempVotedUsers);
        _notVotedUserNames.clear();
        _notVotedUserNames.addAll(tempNotVotedUserNames);
      });
    }
  }

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
            // Bagian User yang Sudah Memilih
            const Text(
              'Daftar User yang Sudah Memilih:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _votedUsers.isEmpty
                    ? const Text('Belum ada user yang memilih polling ini.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _votedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _votedUsers[index];
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
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 20),
            // Bagian User yang Belum Memilih
            const Text(
              'Daftar User yang Belum Memilih:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const SizedBox.shrink() // Sembunyikan saat loading
                : _notVotedUserNames.isEmpty
                    ? const Text('Semua user sudah memilih polling ini.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _notVotedUserNames.length,
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
                                '${index + 1}. ${_notVotedUserNames[index]}', // Urutan
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
