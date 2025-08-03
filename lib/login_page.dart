import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'admin/admin_page.dart';
import 'home_page.dart'; // Pastikan ini ada dan mengarah ke file HomePage kamu

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String? errorMessage;

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      // Melakukan otentikasi user dengan Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Pastikan user berhasil login dan UID tersedia
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;

        // Mengambil dokumen user dari Firestore berdasarkan UID
        // Pastikan nama koleksi 'users' sesuai dengan yang ada di Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        // Memeriksa apakah dokumen user ada dan memiliki field 'role'
        if (userDoc.exists && userDoc.data() != null && (userDoc.data() as Map<String, dynamic>).containsKey('role')) {
          String userRole = userDoc.get('role');

          // Navigasi berdasarkan role
          if (mounted) {
            if (userRole == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminPage()),
              );
            } else {
              // Jika role bukan admin, arahkan ke HomePage (untuk user biasa)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          }
        } else {
          // Jika dokumen user atau role tidak ditemukan di Firestore
          setState(() {
            errorMessage = 'Data peran user tidak ditemukan. Hubungi administrator.';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage!),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan saat login';
      
      if (e.code == 'user-not-found') {
        message = 'Email tidak terdaftar';
      } else if (e.code == 'wrong-password') {
        message = 'Password salah';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid';
      } else if (e.code == 'too-many-requests') {
        message = 'Terlalu banyak percobaan. Coba lagi nanti';
      } else if (e.code == 'user-disabled') {
        message = 'Akun ini dinonaktifkan';
      } else {
        // Tangani error umum Firebase Auth lainnya
        message = 'Kesalahan otentikasi: ${e.message}';
      }

      setState(() {
        errorMessage = message;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Tangani error umum lainnya
      setState(() {
        errorMessage = 'Terjadi kesalahan. Coba lagi nanti: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo dan judul
                    Column(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 100,
                          width: 100,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Poling',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF673AB7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Error message
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red[800],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (errorMessage != null) const SizedBox(height: 20),

                    // Input email
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email, color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email wajib diisi';
                        }
                        if (!value.contains('@')) {
                          return 'Masukkan email yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Input password
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi',
                        prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password wajib diisi';
                        }
                        if (value.length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Tombol login
                    ElevatedButton(
                      onPressed: isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673AB7),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Masuk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
