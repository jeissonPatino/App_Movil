import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  XFile? _image;
  Position? _currentPosition;
  final ImagePicker _picker = ImagePicker();

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // El usuario denegó los permisos de ubicación
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Los permisos de ubicación están denegados para siempre
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

  Future<void> _takePicture() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    setState(() {
      _image = image;
    });

    // Obtener la ubicación después de tomar la foto
    await _getCurrentLocation();
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
              Image.network(_image!.path) // Mostrar la imagen si se ha tomado una
            else
              const Text('No se ha tomado ninguna foto.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _takePicture,
              child: const Text('Tomar Foto'),
            ),
            if (_currentPosition != null)
              Text(
                  'Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}'),
          ],
        ),
      ),
    );
  }
}