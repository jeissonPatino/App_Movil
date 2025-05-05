import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';
import 'dart:io' as io;

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

  Future<void> _takePictureAndSave() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    setState(() {
      _image = image;
    });

    await _getCurrentLocation();

    if (_image != null && _currentPosition != null) {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      await _dbHelper.insertPhoto({
        'filePath': _image!.path,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'timestamp': timestamp,
      });
      print('Foto guardada localmente con ubicación: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    }
  }

  Future<void> _loadPhotos() async {
    List<Map<String, dynamic>> photos = await _dbHelper.getPhotos();
    print('Fotos guardadas localmente: $photos');
    // Aquí puedes actualizar la UI para mostrar las fotos guardadas
  }

  @override
  void initState() {
    super.initState();
    _loadPhotos(); // Cargar las fotos al iniciar la pantalla
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
              onPressed: _takePictureAndSave,
              child: const Text('Tomar y Guardar Foto'),
            ),
            if (_currentPosition != null)
              Text(
                  'Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadPhotos,
              child: const Text('Cargar Fotos Guardadas'),
            ),
          ],
        ),
      ),
    );
  }
}