import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofotos/screens/auth/login_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _displayNameController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false; 
  bool _isProfileLoading = true; 

  String _originalDisplayName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isProfileLoading = true;
    });
    if (_currentUser != null) {
      _userEmail = _currentUser!.email ?? 'No disponible';
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          _originalDisplayName = userData['displayName'] ?? '';
          _displayNameController.text = _originalDisplayName;
        } else {
          _originalDisplayName = _userEmail.split('@')[0]; 
          _displayNameController.text = _originalDisplayName;
        }
      } catch (e) {
        print("Error cargando perfil de usuario: $e");
        _displayNameController.text = 'Error al cargar nombre';
        _originalDisplayName = 'Error al cargar nombre';
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar perfil: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    if (mounted) {
      setState(() {
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;
    if (_displayNameController.text.isEmpty || _displayNameController.text.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre para mostrar debe tener al menos 3 caracteres.'), backgroundColor: Colors.orange),
      );
      return;
    }


    setState(() {
      _isLoading = true;
    });

    try {
      final newDisplayName = _displayNameController.text.trim();
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'displayName': newDisplayName});
      setState(() {
        _isEditing = false;
        _originalDisplayName = newDisplayName; 
      });
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado con éxito.'), backgroundColor: Colors.green),
        );
       }
    } catch (e) {
      print("Error guardando perfil: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar perfil: $e'), backgroundColor: Colors.red),
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

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error al cerrar sesión: $e");
     
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isProfileLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Mi Perfil',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text('Correo Electrónico:', style: Theme.of(context).textTheme.titleMedium),
                  Text(_userEmail, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 20),

                  Text('Nombre para Mostrar:', style: Theme.of(context).textTheme.titleMedium),
                  _isEditing
                      ? TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            hintText: 'Tu nombre o apodo',
                            border: OutlineInputBorder(),
                          ),
                           validator: (value) { 
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa un nombre';
                            }
                            if (value.length < 3) {
                              return 'El nombre debe tener al menos 3 caracteres';
                            }
                            return null;
                          },
                        )
                      : Text(_displayNameController.text, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _saveProfile,
                          child: const Text('Guardar'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _displayNameController.text = _originalDisplayName; 
                            });
                          },
                          child: const Text('Cancelar'),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Nombre'),
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}