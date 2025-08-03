import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Realtime Database
import 'package:firebase_auth/firebase_auth.dart'; // Import untuk mendapatkan UID admin

class CreatePollPage extends StatefulWidget {
  const CreatePollPage({super.key});

  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final TextEditingController _pollTitleController = TextEditingController();
  final List<TextEditingController> _optionControllers = []; // Untuk opsi polling
  final _formKey = GlobalKey<FormState>(); // Key untuk validasi form
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Tambahkan 2 opsi default saat halaman dimuat
    _optionControllers.add(TextEditingController());
    _optionControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _pollTitleController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Fungsi untuk menambah opsi polling baru
  void _addOptionField() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  // Fungsi untuk menghapus opsi polling
  void _removeOptionField(int index) {
    setState(() {
      _optionControllers[index].dispose(); // Buang controller yang dihapus
      _optionControllers.removeAt(index);
    });
  }

  // Fungsi untuk membuat polling dan menyimpannya ke Realtime Database
  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Pastikan ada minimal 2 opsi
    if (_optionControllers.where((c) => c.text.trim().isNotEmpty).length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimal harus ada 2 opsi polling.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User tidak login. Tidak bisa membuat polling.');
      }

      final String pollTitle = _pollTitleController.text.trim();
      
      // Filter opsi yang kosong
      final List<String> options = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Referensi ke root database 'polls'
      DatabaseReference pollsRef = FirebaseDatabase.instance.ref('polls');

      // Push data polling baru ke database
      await pollsRef.push().set({
        'title': pollTitle,
        'createdBy': user.uid, // UID admin yang membuat polling
        'createdAt': ServerValue.timestamp, // Timestamp dari server Firebase
        'options': {
          for (int i = 0; i < options.length; i++)
            'option_${i + 1}': { // Contoh: option_1, option_2
              'text': options[i],
              'votes': 0, // Inisialisasi jumlah vote
            },
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Polling berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
        // Bersihkan form setelah sukses
        _pollTitleController.clear();
        for (var controller in _optionControllers) {
          controller.clear();
        }
        setState(() {
          _optionControllers.clear();
          _optionControllers.add(TextEditingController()); // Tambah 2 opsi awal lagi
          _optionControllers.add(TextEditingController());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat polling: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buat Polling Baru',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF673AB7),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Judul Polling',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF673AB7),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _pollTitleController,
                  decoration: InputDecoration(
                    labelText: 'Masukkan judul polling',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF673AB7)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Judul polling wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Opsi Polling',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF673AB7),
                  ),
                ),
                const SizedBox(height: 10),
                // List opsi polling yang bisa ditambah/dihapus
                ListView.builder(
                  shrinkWrap: true, // Penting agar ListView bisa di dalam SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // Nonaktifkan scroll ListView
                  itemCount: _optionControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _optionControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Opsi ${index + 1}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Color(0xFF673AB7)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Opsi tidak boleh kosong';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_optionControllers.length > 2) // Izinkan hapus jika lebih dari 2 opsi
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeOptionField(index),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Tombol untuk menambah opsi
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addOptionField,
                    icon: const Icon(Icons.add, color: Color(0xFF673AB7)),
                    label: const Text(
                      'Tambah Opsi',
                      style: TextStyle(color: Color(0xFF673AB7)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF673AB7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Tombol untuk membuat polling
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createPoll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF673AB7),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Buat Polling',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
