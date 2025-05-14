import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';
import 'dart:io' as io;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  XFile? _image;
  Position? _currentPosition;
  final ImagePicker _picker = ImagePicker();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isConnected = false;

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Error al obtener la ubicación: $e");
    }
  }

  Future<void> _checkInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    setState(() {
      _isConnected = (connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi);
    });
  }

  Future<void> _takePicture() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    setState(() {
      _image = image;
    });
    await _getCurrentLocation();
    await _checkInternetConnection();
  }

  Future<void> _uploadImageToFirebase() async {
    if (_image != null && _currentPosition != null && _isConnected) {
      try {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        firebase_storage.Reference ref = _storage.ref().child('images/$fileName');
        await ref.putFile(io.File(_image!.path));
        String downloadURL = await ref.getDownloadURL();

        GeoPoint location = GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude);

        await _firestore.collection('photos').add({
          'userId': 'user_id_temporal',
          'imageUrl': downloadURL,
          'location': location,
          'timestamp': FieldValue.serverTimestamp(),
        });

        print('Imagen subida a Firebase Storage y metadatos guardados en Firestore.');
        // Opcional: Limpiar la imagen local después de subir
        setState(() {
          _image = null;
          _currentPosition = null;
        });
      } catch (e) {
        print('Error al subir la imagen o guardar metadatos: $e');
      }
    } else if (_image == null) {
      print('No se ha tomado ninguna foto.');
    } else if (_currentPosition == null) {
      print('Ubicación no disponible.');
    } else {
      print('No hay conexión a internet para subir la foto.');
    }
  }

  Future<void> _loadPhotos() async {
    List<Map<String, dynamic>> photos = await _dbHelper.getPhotos();
    print('Fotos guardadas localmente: $photos');
  }

  Future<void> _initializeFirestoreStructure() async {
    final collection = FirebaseFirestore.instance.collection('photos');
    final snapshot = await collection.limit(1).get();

    if (snapshot.docs.isEmpty) {
      await collection.doc('__structure__').set({
        'filePath': 'TEXT',
        'location': 'GeoPoint',
        'timestamp': 'INTEGER',
        'userId': 'TEXT',
        'imageUrl': 'TEXT',
      });
      print('Estructura de la colección "photos" inicializada en Firestore.');
    } else {
      print('La colección "photos" ya existe en Firestore.');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _initializeFirestoreStructure();
    _checkInternetConnection(); // Verificar la conexión inicial
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty) {
        _checkInternetConnection(); 
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoFotos Sociales'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_image != null)
              Image.file(io.File(_image!.path))
            else
              const Text('No se ha tomado ninguna foto.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _takePicture,
              child: const Text('Tomar Foto'),
            ),
            const SizedBox(height: 20),
            if (_image != null)
              ElevatedButton(
                onPressed: _uploadImageToFirebase,
                child: const Text('Subir a Firebase'),
              ),
            if (_currentPosition != null)
              Text(
                  'Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadPhotos,
              child: const Text('Cargar Fotos Guardadas Localmente'),
            ),
          ],
        ),
      ),
    );
  }
}