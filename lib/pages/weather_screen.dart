import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _cityController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  Map<String, dynamic>? _data;

  Future<void> fetchWeather(String city) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _data = null;
    });

    try {
      // Sanitiza entrada
      city = city.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚ, ]'), '');

      final apiKey = dotenv.env['API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        setState(() => _error = 'Falta API_KEY. Revisa el archivo .env y pubspec.yaml.');
        return;
      }

      final uri = Uri.https(
        'api.openweathermap.org',
        '/data/2.5/weather',
        <String, String>{
          'q': '$city,MX',
          'appid': apiKey,
          'units': 'metric',
          'lang': 'es',
        },
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        setState(() => _data = json.decode(resp.body) as Map<String, dynamic>);
      } else if (resp.statusCode == 401) {
        setState(() => _error = 'API key inválida o faltante (401).');
      } else if (resp.statusCode == 404) {
        setState(() => _error = 'Ciudad no encontrada.');
      } else if (resp.statusCode == 429) {
        setState(() => _error = 'Demasiadas solicitudes. Intenta más tarde.');
      } else {
        setState(() => _error = 'Error inesperado (${resp.statusCode}).');
      }
    } on TimeoutException {
      setState(() => _error = 'Tiempo de espera agotado.');
    } catch (_) {
      setState(() => _error = 'Error al conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clima actual')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (_cityController.text.trim().isEmpty) {
                  setState(() => _error = 'Por favor ingresa una ciudad.');
                } else {
                  fetchWeather(_cityController.text.trim());
                }
              },
              child: const Text('Buscar clima'),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_isLoading && _error == null && _data == null)
              const Text('Ingresa una ciudad para consultar el clima.'),
            if (_data != null) _buildWeatherCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    final main = _data!['main'] as Map<String, dynamic>;
    final weather0 = (_data!['weather'] as List).first as Map<String, dynamic>;

    final num temp = main['temp']; // puede ser int o double
    final String name = _data!['name'];
    final String desc = (weather0['description'] as String? ?? '');
    final String icon = (weather0['icon'] as String? ?? '01d');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Image.network(
              'https://openweathermap.org/img/wn/$icon@2x.png',
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, size: 64),
            ),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text('${temp.toStringAsFixed(1)} °C'),
            Text(desc.isEmpty ? '' : desc[0].toUpperCase() + desc.substring(1)),
          ],
        ),
      ),
    );
  }
}