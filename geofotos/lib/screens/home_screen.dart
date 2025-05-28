import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofotos/screens/auth/login_screen.dart';
import 'package:geofotos/screens/location_photos_screen.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class HomeScreen extends StatefulWidget { 
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedImage;
  bool _isUploading = false;
  String? _uploadedImageUrl;
  Position? _currentPosition;
  String _locationMessage = "No se ha obtenido la ubicación todavía.";
  final ImagePicker _picker = ImagePicker();
  


  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una imagen primero.')),
      );
      return;
    }
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación. Intenta seleccionar la imagen de nuevo.')),
      );
      return; 
    }
    setState(() {
      _isUploading = true;
      _uploadedImageUrl = null;
    });
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado.');
      }
      String fileName = 'photos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance.ref().child(fileName);
      firebase_storage.UploadTask uploadTask = ref.putFile(_selectedImage!);
      firebase_storage.TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();
      print('Imagen subida a Storage. URL: $downloadURL');
      String uploaderDisplayName = user.email ?? 'Usuario desconocido'; 
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('displayName') && userData['displayName'] != null && (userData['displayName'] as String).isNotEmpty) {
              uploaderDisplayName = userData['displayName'];
          }
        }
      } catch (e) {
        print("Error al obtener displayName del usuario: $e");
        
      }
      Map<String, dynamic> photoData = {
        'uploaderUid': user.uid,
        'uploaderEmail': user.email,
        'uploaderDisplayName': uploaderDisplayName,
        'imageUrl': downloadURL,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'caption': '', 
        'uploadedAt': Timestamp.now(),
        'locationName': '', 
        'visibility': 'friends_only',
      };

      await FirebaseFirestore.instance.collection('photos').add(photoData);

      print('Metadatos de la foto guardados en Firestore.');

      setState(() {
        _uploadedImageUrl = downloadURL; 
        _selectedImage = null; 
        _currentPosition = null; 
        _locationMessage = "No se ha obtenido la ubicación todavía.";
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto subida y guardada con éxito!'), backgroundColor: Colors.green),
        );
      });

    } catch (e) {
      print('Error durante el proceso de subida y guardado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en la subida/guardado: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
          setState(() {
            _isUploading = false;
          });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Los servicios de ubicación están deshabilitados.';
      });
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = 'Permiso de ubicación denegado.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage = 'Permiso de ubicación denegado permanentemente. Ve a configuraciones para habilitarlo.';
      });
      return;
    } 
    
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      try {
        setState(() {
          _locationMessage = "Obteniendo ubicación...";
        });
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high 
        );
        setState(() {
          _currentPosition = position;
          _locationMessage = 'Lat: ${position.latitude}, Lon: ${position.longitude}';
          print('Ubicación obtenida: $position');
        });
      } catch (e) {
        print("Error al obtener la ubicación: $e");
        setState(() {
          _locationMessage = 'Error al obtener la ubicación: $e';
        });
      }
    }
  }

  Future<void> _requestPermission(Permission permission) async {
  final status = await permission.request();
  if (status.isGranted) {
    print('${permission.toString()} permission granted');
  } else if (status.isDenied) {
    print('${permission.toString()} permission denied');
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso denegado para acceder a los archivos.')));
  } else if (status.isPermanentlyDenied) {
    print('${permission.toString()} permission permanently denied');
    await openAppSettings();
  }
}

  
  Future<void> _pickImageFromGallery() async {
    PermissionStatus status;
    if (Platform.isAndroid) { 
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.photos.status;
        if (!status.isGranted) await _requestPermission(Permission.photos);
      } else {
        status = await Permission.storage.status;
        if (!status.isGranted) await _requestPermission(Permission.storage);
      }
    } else { // Para iOS, es photos
      status = await Permission.photos.status;
      if (!status.isGranted) await _requestPermission(Permission.photos);
    }
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.photos.status;
      } else {
        status = await Permission.storage.status;
      }
    } else {
      status = await Permission.photos.status;
    }
    if (status.isGranted) {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _currentPosition = null;
          _locationMessage = "Ubicación no obtenida para esta imagen.";
        });
        await _getCurrentLocation(); 
      } else {
        print('No se seleccionó ninguna imagen.');
      }
    } else {
      print('Permiso de galería no concedido.');
    }
  }

 
  Future<void> _pickImageFromCamera() async {
    final cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      await _requestPermission(Permission.camera);
    }
    if (await Permission.camera.isGranted) {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _currentPosition = null;
          _locationMessage = "Ubicación no obtenida para esta imagen.";
        });
        await _getCurrentLocation(); 
      } else {
        print('No se tomó ninguna foto.');
      }
    } else {
      print('Permiso de cámara no concedido.');
    }
  }


  Future<void> _signOut(BuildContext context) async {
    
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error al cerrar sesión: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red),
      );
    }
  }
 

 @override
  Widget build(BuildContext context) {
      final User? currentUser = FirebaseAuth.instance.currentUser;
        return Scaffold( 
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¡Has iniciado sesión con éxito!',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                if (currentUser != null)
                  Text(
                    'Bienvenido, ${currentUser.email}',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 30),
                _selectedImage != null
                ? SizedBox( 
                    height: 250,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.file(_selectedImage!, fit: BoxFit.contain),
                    ),
                  )
                : Padding( 
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: const Text(
                      'No has seleccionado ninguna imagen.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Seleccionar de Galería'),
                    onPressed: _pickImageFromGallery, 
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tomar Foto'),
                    onPressed: _pickImageFromCamera, 
                  ), 
                  const SizedBox(height: 20), 
                  if (_selectedImage != null && !_isUploading) 
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Subir Imagen'),
                      onPressed: _uploadImage,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),          
                  if (_isUploading) 
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_uploadedImageUrl != null && !_isUploading) 
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SelectableText(
                        "Última URL: $_uploadedImageUrl",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    _locationMessage,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30), 
                  const Text(
                    'GeoFotos Recientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<DocumentSnapshot>(
              stream: currentUser!= null
                  ? FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots()
                  : null,
              builder: (context, userDocSnapshot) {
                if (currentUser== null) {
                  return const Center(child: Text("Inicia sesión para ver fotos."));
                }
                if (userDocSnapshot.connectionState == ConnectionState.waiting && !userDocSnapshot.hasData) {
                  // Mostrar cargador solo si es la carga inicial del perfil
                  return const Center(child: CircularProgressIndicator());
                }
                if (userDocSnapshot.hasError) {
                  return Center(child: Text('Error al cargar datos del perfil: ${userDocSnapshot.error}'));
                }
                if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
                  return const Center(child: Text('No se encontró tu perfil.'));
                }

                final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
                final List<String> friendUids = List<String>.from(userData['friends'] ?? []);
                List<String> uidsToQuery = [currentUser!.uid];
                if (friendUids.isNotEmpty) {
                  uidsToQuery.addAll(friendUids);
                }
                if (uidsToQuery.isEmpty) {
                    return const Center(child: Text('No hay usuarios para mostrar fotos.'));
                }
               return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('photos')
                      .where('uploaderUid', whereIn: uidsToQuery.take(30).toList())
                      .orderBy('uploadedAt', descending: true)
                      .snapshots(),
                  builder: (context, photoSnapshot) {
                    // ... (tus logs y manejo de connectionState, hasError se mantienen)
                    print('Photo StreamBuilder connection state: ${photoSnapshot.connectionState}');
                    // ... etc ...

                    if (photoSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (photoSnapshot.hasError) {
                      return Center(child: Text('Error al cargar GeoFotos: ${photoSnapshot.error}'));
                    }
                    // CAMBIO IMPORTANTE: Incluso si no hay datos, no mostramos el mensaje aquí,
                    // sino después de procesar las ubicaciones.
                    // if (!photoSnapshot.hasData || photoSnapshot.data!.docs.isEmpty) {
                    //   return const Center(child: Text('Aún no hay GeoFotos para mostrar (antes del filtro). ¡Sube la primera!'));
                    // }

                    // Procesar las fotos para extraer y agrupar por ubicaciones únicas
                    List<Map<String, dynamic>> uniqueLocations = [];
                    if (photoSnapshot.hasData && photoSnapshot.data!.docs.isNotEmpty) {
                      final List<DocumentSnapshot> allRelevantPhotos = photoSnapshot.data!.docs;
                      final List<DocumentSnapshot> filteredPhotos = allRelevantPhotos.where((doc) {
                        final photoData = doc.data() as Map<String, dynamic>;
                        final String uploaderUidInPhoto = photoData['uploaderUid'];
                        final String visibility = photoData['visibility'] ?? 'private';

                        if (uploaderUidInPhoto == currentUser!.uid) {
                          return true;
                        } else if (friendUids.contains(uploaderUidInPhoto) && visibility == 'friends_only') {
                          return true;
                        }
                        return false;
                      }).toList();

                      print('Docs AFTER filter for location grouping: ${filteredPhotos.length}');

                      // Agrupar fotos por ubicación (lat,lon como clave)
                      final Map<String, List<DocumentSnapshot>> photosByLocation = {};
                      for (var photoDoc in filteredPhotos) {
                        final photoData = photoDoc.data() as Map<String, dynamic>;
                        final double lat = photoData['latitude'];
                        final double lon = photoData['longitude'];
                        // Redondear un poco para agrupar puntos muy cercanos (opcional, ajusta decimales)
                        // final String locKey = "${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}";
                        final String locKey = "${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}"; // Clave exacta por ahora

                        if (photosByLocation.containsKey(locKey)) {
                          photosByLocation[locKey]!.add(photoDoc);
                        } else {
                          photosByLocation[locKey] = [photoDoc];
                        }
                      }
                      
                      
                      uniqueLocations = photosByLocation.entries.map((entry) {
                        final firstPhotoData = entry.value.first.data() as Map<String, dynamic>;
                        return {
                          'key': entry.key, // "lat,lon"
                          'latitude': firstPhotoData['latitude'],
                          'longitude': firstPhotoData['longitude'],
                          'representativeImageUrl': firstPhotoData['imageUrl'],
                          'photoCount': entry.value.length,
                          'allPhotosAtLocation': entry.value 
                        };
                      }).toList();
                      
                      
                      print('Ubicaciones únicas encontradas: ${uniqueLocations.length}');

                    } 

                    if (uniqueLocations.isEmpty) {
                      return const Center(child: Text('No hay GeoFotos para mostrar agrupadas por ubicación.'));
                    }

                    // ListView.builder para mostrar las UBICACIONES ÚNICAS
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: uniqueLocations.length,
                      itemBuilder: (context, index) {
                        final locationData = uniqueLocations[index];
                        final String representativeImageUrl = locationData['representativeImageUrl'] ?? '';
                        final int photoCount = locationData['photoCount'] ?? 0;
                        final double lat = locationData['latitude'];
                        final double lon = locationData['longitude'];

                        final List<DocumentSnapshot> photosForThisLocation = locationData['allPhotosAtLocation'] as List<DocumentSnapshot>;
                        final String locKey = "${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}";

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          elevation: 3,
                          child: ListTile(
                            leading: representativeImageUrl.isNotEmpty
                                ? SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4.0),
                                      child: Image.network(
                                        representativeImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, size: 40),
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: 80, height: 80, child: Icon(Icons.location_on, size: 40)),
                            title: Text('Ubicación (${photoCount} foto${photoCount > 1 ? "s" : ""})'),
                            subtitle: Text('Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}'),
                            onTap: () {
                              print('Tocado en ubicación: $lat, $lon');
                              print('Fotos en esta ubicación: ${photoCount}');
                             Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationPhotosScreen(
                                    
                                    photosAtLocation: photosForThisLocation,
                                    locationKey: locKey,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  }, // Fin del builder del StreamBuilder de photos
                ); // Fin del StreamBuilder de photos
              }, // Fin del builder del StreamBuilder de userDocSnapshot
            ),
          ],
        ),
      ),
    );
  } 
}