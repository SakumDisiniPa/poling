import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Realtime Database

class EditPollPage extends StatefulWidget {
  final String pollId;
  final Map<dynamic, dynamic> pollData; // Menerima data polling yang akan diedit

  const EditPollPage({super.key, required this.pollId, required this.pollData});

  @override
  State<EditPollPage> createState() => _EditPollPageState();
}

class _EditPollPageState extends State<EditPollPage> {
  final TextEditingController _pollTitleController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Isi form dengan data polling yang diterima
    _pollTitleController.text = widget.pollData['title'] ?? '';

    // Isi opsi yang ada
    Map<dynamic, dynamic> optionsMap = widget.pollData['options'] ?? {};
    optionsMap.forEach((key, value) {
      _optionControllers.add(TextEditingController(text: value['text'] ?? ''));
    });

    // Pastikan ada minimal 2 opsi jika data awal kurang dari 2
    while (_optionControllers.length < 2) {
      _optionControllers.add(TextEditingController());
    }
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
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  // Fungsi untuk mengupdate polling di Realtime Database
  Future<void> _updatePoll() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      final String pollTitle = _pollTitleController.text.trim();
      final List<String> options = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Referensi ke dokumen polling spesifik di Realtime Database
      DatabaseReference pollRef = FirebaseDatabase.instance.ref('polls/${widget.pollId}');

      // Update data polling
      await pollRef.update({
        'title': pollTitle,
        'options': {
          for (int i = 0; i < options.length; i++)
            'option_${i + 1}': {
              'text': options[i],
              'votes': (widget.pollData['options']?['option_${i + 1}']?['votes'] ?? 0), // Pertahankan jumlah vote yang sudah ada
            },
        },
        // createdBy dan createdAt tidak diubah saat update
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Polling berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke halaman daftar polling
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui polling: $e'),
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
          'Edit Polling',
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                          if (_optionControllers.length > 2)
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePoll, // Panggil fungsi update
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
                            'Perbarui Polling',
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
