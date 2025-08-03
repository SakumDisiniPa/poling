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

  TimeOfDay? _startTime; // Waktu mulai polling
  TimeOfDay? _endTime;   // Waktu berakhir polling

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

    // --- INISIALISASI WAKTU DARI pollData ---
    String? storedStartTime = widget.pollData['startTime'];
    String? storedEndTime = widget.pollData['endTime'];

    if (storedStartTime != null && storedStartTime.contains(':')) {
      List<String> parts = storedStartTime.split(':');
      _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (storedEndTime != null && storedEndTime.contains(':')) {
      List<String> parts = storedEndTime.split(':');
      _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    // --- AKHIR INISIALISASI WAKTU ---
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

  // Fungsi untuk memilih waktu mulai
  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  // Fungsi untuk memilih waktu berakhir
  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
    }
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

    // Validasi waktu
    if (_startTime == null || _endTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waktu mulai dan berakhir polling wajib diisi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Konversi TimeOfDay ke format yang bisa disimpan (misal: "19:00")
    String startTimeString = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
    String endTimeString = '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';

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

      // Siapkan opsi baru dengan mempertahankan vote yang sudah ada
      Map<String, dynamic> newOptionsData = {};
      for (int i = 0; i < options.length; i++) {
        String optionKey = 'option_${i + 1}';
        // Ambil vote yang sudah ada untuk opsi ini (jika ada)
        int existingVotes = (widget.pollData['options']?[optionKey]?['votes'] ?? 0);
        newOptionsData[optionKey] = {
          'text': options[i],
          'votes': existingVotes,
        };
      }

      // Update data polling
      await pollRef.update({
        'title': pollTitle,
        'startTime': startTimeString, // Update waktu mulai
        'endTime': endTimeString,     // Update waktu berakhir
        'options': newOptionsData,
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
                // --- PENGATURAN WAKTU POLLING ---
                const Text(
                  'Waktu Polling Aktif',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF673AB7),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartTime(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Waktu Mulai',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF673AB7)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.access_time),
                          ),
                          child: Text(
                            _startTime == null
                                ? 'Pilih Waktu'
                                : _startTime!.format(context),
                            style: TextStyle(
                              fontSize: 16,
                              color: _startTime == null ? Colors.grey[600] : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectEndTime(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Waktu Berakhir',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF673AB7)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.access_time),
                          ),
                          child: Text(
                            _endTime == null
                                ? 'Pilih Waktu'
                                : _endTime!.format(context),
                            style: TextStyle(
                              fontSize: 16,
                              color: _endTime == null ? Colors.grey[600] : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // --- AKHIR PENGATURAN WAKTU POLLING ---
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
