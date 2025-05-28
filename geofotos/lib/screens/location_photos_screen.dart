import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para el tipo Timestamp

class LocationPhotosScreen extends StatelessWidget {
  final List<DocumentSnapshot> photosAtLocation; // Lista de fotos para esta ubicación
  final String locationKey; // Clave de la ubicación (ej. "lat,lon" o un nombre)

  const LocationPhotosScreen({
    super.key,
    required this.photosAtLocation,
    required this.locationKey,
  });

  @override
  Widget build(BuildContext context) {
    // Puedes usar la locationKey para mostrar un título más descriptivo si quieres
    // o extraer lat/lon de la primera foto para el título.
    String appBarTitle = 'Fotos en: ${locationKey.replaceAll(",", ", ")}';
    if (photosAtLocation.isNotEmpty) {
        final firstPhotoData = photosAtLocation.first.data() as Map<String, dynamic>;
        final double lat = firstPhotoData['latitude'];
        final double lon = firstPhotoData['longitude'];
        appBarTitle = 'Fotos en Lat: ${lat.toStringAsFixed(3)}, Lon: ${lon.toStringAsFixed(3)}';
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: photosAtLocation.isEmpty
          ? const Center(
              child: Text('No hay fotos para mostrar en esta ubicación.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0), // Padding para la lista
              itemCount: photosAtLocation.length,
              itemBuilder: (context, index) {
                final photoData = photosAtLocation[index].data() as Map<String, dynamic>;
                final String imageUrl = photoData['imageUrl'] ?? '';
                final String uploaderName = photoData['uploaderDisplayName'] ?? photoData['uploaderEmail'] ?? 'Usuario desconocido';
                final Timestamp? uploadedAt = photoData['uploadedAt'] as Timestamp?;
                final String caption = photoData['caption'] ?? '';

                // Reutilizamos la misma estructura de Card que en HomeScreen para mostrar la foto
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uploaderName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (uploadedAt != null)
                          Text(
                            'Subida: ${uploadedAt.toDate().day}/${uploadedAt.toDate().month}/${uploadedAt.toDate().year}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        const SizedBox(height: 8),
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              imageUrl,
                              height: 250, // Puedes ajustar esta altura
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 250,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                                return const SizedBox(
                                  height: 250,
                                  child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                                );
                              },
                            ),
                          )
                        else
                          const SizedBox(
                            height: 250,
                            child: Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                          ),
                        if (caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(caption),
                          ),
                        // Aquí podrías mostrar más detalles de la foto si quisieras
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}