import 'dart:convert';

import 'package:d_write/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static final WeatherService _instance = WeatherService._();
  factory WeatherService() => _instance;
  WeatherService._();

  /// 현재 날씨 조건 문자열 반환.
  /// 실패 시 'All' 반환 (폴백 보장)
  Future<String> getCurrentWeather() async {
    try {
      final position = await _getPosition();
      if (position == null) return 'All';
      return await _fetchWeather(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('WeatherService error: $e');
      return 'All';
    }
  }

  Future<Position?> _getPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('WeatherService._getPosition error: $e');
      return null;
    }
  }

  Future<String> _fetchWeather(double lat, double lon) async {
    if (AppConfig.weatherApiKey == 'YOUR_OPENWEATHERMAP_API_KEY') {
      return 'All';
    }

    final uri = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
      '?lat=$lat&lon=$lon&appid=${AppConfig.weatherApiKey}',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return 'All';

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final weatherList = json['weather'] as List?;
    if (weatherList == null || weatherList.isEmpty) return 'All';

    final main = (weatherList.first as Map<String, dynamic>)['main'] as String?;
    return _normalize(main ?? 'All');
  }

  /// OpenWeatherMap 날씨 조건을 앱 태그로 매핑
  String _normalize(String main) {
    switch (main) {
      case 'Clear':
        return 'Clear';
      case 'Clouds':
        return 'Clouds';
      case 'Rain':
      case 'Drizzle':
      case 'Thunderstorm':
        return 'Rain';
      case 'Snow':
        return 'Snow';
      default:
        return 'All';
    }
  }
}
