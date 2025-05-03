# GeoFotos Sociales

Una aplicación creada con Flutter para compartir fotos con ubicación.

## Descripción

Esta aplicación permite a los usuarios registrarse, iniciar sesión, tomar fotos (simulado en la web), y guardar la ubicación de las fotos. El objetivo final es permitir a los usuarios compartir fotos con amigos y ver fotos agrupadas por ubicación.

## Estado Actual

Actualmente, las siguientes funcionalidades han sido implementadas:

* **Login:** Permite a los usuarios iniciar sesión con un nombre de usuario único.
* **Registro de Usuario:** Permite a nuevos usuarios crear una cuenta con un nombre de usuario único y contraseña. Se realiza una validación básica para asegurar que el nombre de usuario no exista y que las contraseñas coincidan.
* **Tomar Fotos:** En la versión web, esta funcionalidad simula la toma de fotos permitiendo al usuario seleccionar un archivo de imagen desde su sistema.
* **Geolocalización:** La aplicación solicita permiso para acceder a la ubicación del usuario y puede obtener las coordenadas de latitud y longitud.

## Próximos Pasos

Los siguientes pasos planeados para el desarrollo incluyen:

* Guardar las fotos con la información de ubicación.
* Mostrar las fotos tomadas agrupadas por ubicación.
* Implementar la funcionalidad de solicitudes de amistad.
* Permitir compartir fotos con amigos.
* Crear un chat básico para el envío de fotos con ubicación.
* Implementar carpetas compartidas para amigos que han tomado fotos en el mismo lugar.

## Cómo Ejecutar la Aplicación

1.  Asegúrate de tener Flutter instalado en tu entorno de desarrollo. Puedes seguir la guía de instalación en la [documentación oficial de Flutter](https://flutter.dev/docs/get-started/install).
2.  Clona este repositorio.
3.  Navega al directorio del proyecto en tu terminal:
    ```bash
    cd App_Movil/flutter_application_1
    ```
4.  Obtén las dependencias del proyecto:
    ```bash
    flutter pub get
    ```
5.  Ejecuta la aplicación en un dispositivo conectado o en un emulador/simulador:
    ```bash
    flutter run
    ```
    Para ejecutar en un navegador web:
    ```bash
    flutter run -d chrome
    ```

## Tecnologías Utilizadas

* Flutter
* Dart
* Paquete `image_picker`
* Paquete `geolocator`

## Integrantes del Equipo

* Jeisson Andrés Patiño Ramírez - ja.patino@urepublicana.edu.co

¡Espero que esta configuración inicial para tu `README.md` sea útil! Puedes seguir actualizándolo a medida que avances con el desarrollo de tu aplicación. ¿Hay alguna sección específica que te gustaría detallar más o agregar algo más?
