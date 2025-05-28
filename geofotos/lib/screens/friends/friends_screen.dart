import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;
  String _searchStatusMessage = 'Busca usuarios por su nombre para mostrar.';

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchStatusMessage = 'Ingresa un nombre para buscar.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _searchStatusMessage = 'Buscando...';
    });
    try {
      // No queremos buscar al usuario actual
      final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserUid == null) { 
          setState(() {
            _isLoading = false;
            _searchStatusMessage = 'Error: Usuario no autenticado.';
          });
          return;
      }
      String searchQuery = query.toLowerCase(); 
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10) 
          .get();
      setState(() {
       
        _searchResults = querySnapshot.docs.where((doc) => doc.id != currentUserUid).toList();
        if (_searchResults.isEmpty) {
          _searchStatusMessage = 'No se encontraron usuarios.';
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error buscando usuarios: $e');
      setState(() {
        _isLoading = false;
        _searchStatusMessage = 'Error al buscar usuarios.';
      });
    }
  }

  
  Future<void> _sendFriendRequest(String toUid, String toDisplayName, String toEmail) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debes iniciar sesión para enviar solicitudes.'), backgroundColor: Colors.red),
    );
    return;
  }

  
  if (currentUser.uid == toUid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No puedes enviarte una solicitud a ti mismo.'), backgroundColor: Colors.orange),
    );
    return;
  }

  setState(() {
    _isLoading = true; 
  });

  try {
    
    String fromDisplayName = currentUser.email ?? 'Usuario Anónimo'; 
    String fromEmail = currentUser.email ?? '';

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final currentUserData = userDoc.data() as Map<String, dynamic>;
      if (currentUserData.containsKey('displayName') && (currentUserData['displayName'] as String).isNotEmpty) {
        fromDisplayName = currentUserData['displayName'];
      }
    }

    
    final existingRequestQuery = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUser.uid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingRequestQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya has enviado una solicitud pendiente a este usuario.'), backgroundColor: Colors.orange),
      );
      setState(() { _isLoading = false; });
      return;
    }
    
    
    await FirebaseFirestore.instance.collection('friend_requests').add({
      'fromUid': currentUser.uid,
      'fromDisplayName': fromDisplayName,
      'fromEmail': fromEmail, 
      'toUid': toUid,
      'toDisplayName': toDisplayName, 
      'status': 'pending', 
      'requestTimestamp': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Solicitud de amistad enviada a $toDisplayName.'), backgroundColor: Colors.green),
    );

  } catch (e) {
    print('Error al enviar solicitud de amistad: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al enviar la solicitud: $e'), backgroundColor: Colors.red),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}


Future<void> _acceptFriendRequest(String requestId, String fromUid) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado.')));
    return;
  }

  final String currentUid = currentUser.uid;

  setState(() {
    // Podrías tener un indicador de carga específico si quieres
    // _isProcessingRequest[requestId] = true; // Necesitarías un Map para esto
  });

  try {
    
    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference requestRef = FirebaseFirestore.instance.collection('friend_requests').doc(requestId);
    batch.update(requestRef, {'status': 'accepted'});
    DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
    batch.update(currentUserRef, {
      'friends': FieldValue.arrayUnion([fromUid]) 
    });

    
    DocumentReference friendUserRef = FirebaseFirestore.instance.collection('users').doc(fromUid);
    batch.update(friendUserRef, {
      'friends': FieldValue.arrayUnion([currentUid]) 
    });

    
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Solicitud de amistad aceptada!'), backgroundColor: Colors.green),
    );
    print('Amistad aceptada entre $currentUid y $fromUid');

  } catch (e) {
    print('Error al aceptar la solicitud de amistad: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al aceptar la solicitud: $e'), backgroundColor: Colors.red),
    );
  } finally {
    // setState(() {
    //   _isProcessingRequest[requestId] = false;
    // });
  }
}

  Future<void> _declineFriendRequest(String requestId) async {
  print('Intentando rechazar solicitud ID: $requestId');
  // setState(() { _isProcessingRequest[requestId] = true; });
  try {
    
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .update({'status': 'declined'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud de amistad rechazada con éxito.'), backgroundColor: Colors.orange),
    );
    print('Solicitud de amistad $requestId marcada como declined en Firestore.');

  } catch (e) {
    print('Error al rechazar la solicitud de amistad: $e');
    if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar la solicitud: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    // setState(() { _isProcessingRequest[requestId] = false; });
  }
}

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  final currentUser = FirebaseAuth.instance.currentUser;

  return Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar usuarios por nombre',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _searchUsers(_searchController.text),
              ),
            ),
            onSubmitted: (value) => _searchUsers(value),
          ),
          const SizedBox(height: 10.0),
          if (_isLoading && _searchResults.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty)
            SizedBox(
              height: _searchResults.isEmpty ? 0 : 150,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final userData = _searchResults[index].data() as Map<String, dynamic>;
                  final String userId = _searchResults[index].id;
                  final String displayName = userData['displayName'] ?? 'Nombre no disponible';
                  final String email = userData['email'] ?? 'Email no disponible';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text(displayName),
                      subtitle: Text(email),
                      trailing: ElevatedButton(
                        onPressed: () => _sendFriendRequest(userId, displayName, email),
                        child: const Text('Añadir'),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(_searchStatusMessage, textAlign: TextAlign.center),
            ),
          
          const SizedBox(height: 10.0),
          const Divider(),
          const Text(
            'Solicitudes de Amistad Recibidas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10.0),
          Expanded( 
            child: StreamBuilder<QuerySnapshot>(
              stream: currentUser != null
                  ? FirebaseFirestore.instance
                      .collection('friend_requests')
                      .where('toUid', isEqualTo: currentUser.uid)
                      .where('status', isEqualTo: 'pending')
                      .orderBy('requestTimestamp', descending: true)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) { /* ... */ }
                if (snapshot.hasError) { /* ... */ }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No tienes solicitudes de amistad pendientes.'));
                }
                final requestDocs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: requestDocs.length,
                  itemBuilder: (context, index) {
                    final requestData = requestDocs[index].data() as Map<String, dynamic>;
                    final String requestId = requestDocs[index].id;
                    final String fromDisplayName = requestData['fromDisplayName'] ?? 'Usuario desconocido';
                    final String fromUid = requestData['fromUid'];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text(fromDisplayName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _acceptFriendRequest(requestId, fromUid),
                              child: const Text('Aceptar', style: TextStyle(color: Colors.green)),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _declineFriendRequest(requestId),
                              child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 10.0),
          const Divider(), // Otro separador

          // --- NUEVA SECCIÓN: LISTA DE AMIGOS ---
          const Text(
            'Mis Amigos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10.0),
          Expanded( 
            child: StreamBuilder<DocumentSnapshot>(
              stream: currentUser != null
                  ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots()
                  : null,
              builder: (context, userSnapshot) {
                if (currentUser == null) {
                  return const Center(child: Text('Inicia sesión para ver tus amigos.'));
                }
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (userSnapshot.hasError) {
                  return Center(child: Text('Error: ${userSnapshot.error}'));
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: Text('No se encontró tu perfil de usuario.'));
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final List<String> friendUids = List<String>.from(userData['friends'] ?? []);

                if (friendUids.isEmpty) {
                  return const Center(child: Text('Aún no tienes amigos. ¡Busca y añade algunos!'));
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: friendUids.isNotEmpty ? friendUids : [' ']) 
                      .snapshots(),
                  builder: (context, friendsDetailsSnapshot) {
                    if (friendsDetailsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (friendsDetailsSnapshot.hasError) {
                      return Center(child: Text('Error al cargar amigos: ${friendsDetailsSnapshot.error}'));
                    }
                    if (!friendsDetailsSnapshot.hasData || friendsDetailsSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No se encontraron detalles de tus amigos.'));
                    }
                    final friendsDocs = friendsDetailsSnapshot.data!.docs;
                    return ListView.builder(
                      itemCount: friendsDocs.length,
                      itemBuilder: (context, index) {
                        final friendData = friendsDocs[index].data() as Map<String, dynamic>;
                        final String friendName = friendData['displayName'] ?? 'Amigo';
                        final String friendEmail = friendData['email'] ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            title: Text(friendName),
                            subtitle: Text(friendEmail),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}}