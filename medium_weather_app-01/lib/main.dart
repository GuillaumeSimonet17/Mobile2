import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeatherApp',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  @override
  _WeatherHomePageState createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  TextEditingController _searchController = TextEditingController();

  String errorText = '';
  String geolocation = '';
  String _currentTemperature = '';
  String _cityName = '';
  String _country = '';
  String _region = '';
  String _currentWindSpeed = '';

  List<Map<String, String>> suggestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);

    _searchController.addListener(() {
      if (_searchController.text.isNotEmpty) {
        getSuggestionCityName(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    // libérer les ressources et éviter les leaks lorsqu'un widget est supprimé
    // car des objects peuvent encore écouter des événements en arrière-plan
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _searchExe(value) async {
    Map<String, dynamic>? coordinates = await getCoordinates(value);

    String country = '';
    String city = '';
    String region = '';

    try {
      if (coordinates == null) {
        setState(() {
          errorText = 'Location not found';
          _searchController.clear();
          suggestions.clear();
        });
        return;
      } else {
        setState(() {
          errorText = '';
        });
      }

      if (coordinates["country"] != null &&
          (coordinates['longitude'] ?? 0.0).isFinite) {
        country = coordinates["country"];
        city = coordinates["city"];
        region = coordinates["region"];

        await fetchWeather(coordinates['longitude'].toString(),
            coordinates['latitude'].toString());
      }
    } catch (e) {
      setState(() {
        _searchController.clear();
        suggestions.clear();
      });
      return ;
    }

    setState(() {
      _cityName = city;
      _country = country;
      _region = region;

      errorText = '';

      _searchController.clear();
      suggestions.clear();
    });
  }

  void _locationExe() async {
    if (!await _requestLocationPermission()) {
      setState(() {
        errorText =
        'Geoloation is not available, please enable it in your App settings';
      });
      return;
    }

    try {
      Position position = await _determinePosition();
      List<String> cityAndState = await getCityAndState(
        position.longitude,
        position.latitude,
      );
      setState(() {
        errorText = '';

        _cityName = cityAndState[0];
        _country = cityAndState[2];
        _region = cityAndState[1];
      });

      await fetchWeather(position.longitude, position.latitude);

    } catch (e) {
      print('Something went wrong');
    }
  }

  Future<Map<String, dynamic>?> getCoordinates(String cityName) async {
    final url = Uri.parse(
      "https://geocoding-api.open-meteo.com/v1/search?name=$cityName&count=1&language=fr",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['results'] != null && data['results'].isNotEmpty) {
        double lat = data['results'][0]['latitude'];
        double lon = data['results'][0]['longitude'];
        String country = data['results'][0]['country'];
        String city = data['results'][0]['name'];
        String region = data['results'][0]['admin1'];

        return {
          'latitude': lat,
          'longitude': lon,
          'country': country,
          'region': region,
          'city': city,
        };
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;

    if (status.isGranted) {
      return true; // Déjà autorisé
    }

    if (status.isPermanentlyDenied) {
      print("Permission refusée définitivement. Ouvrir les paramètres.");
      openAppSettings(); // Ouvre les paramètres de l'application
      return false;
    }

    // Demander la permission si elle est "denied"
    final permissionStatus = await Permission.location.request();
    if (permissionStatus.isGranted) {
      return true;
    }

    print("Permission refusée");
    return false;
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<List<String>> getCityAndState(double longitude, double latitude) async {
    String api = "69194e403214af6ed44902500147d7da";

    final url = Uri.parse(
      "http://api.openweathermap.org/geo/1.0/reverse?lat=$latitude&lon=$longitude&limit=1&appid=$api",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return [data[0]['name'], data[0]['state'], data[0]['country']];
    } else {
      return ["Erreur: ${response.statusCode}"];
    }
  }

  Future<void> getSuggestionCityName(String cityName) async {
    final url = Uri.parse(
      "https://geocoding-api.open-meteo.com/v1/search?name=$cityName&count=10&language=fr",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['results'] != null) {
        List<String> cityNames =
        data['results']
            .map((city) => city["name"].toString())
            .toList()
            .cast<String>();
        List<String> countryNames =
        data['results']
            .map((city) => city["country"].toString())
            .toList()
            .cast<String>();
        List<String> regions =
        data['results']
            .map((city) => city["admin1"].toString())
            .toList()
            .cast<String>();

        setState(() {
          suggestions = List.generate(
            cityNames.length,
                (index) => {
              "city": cityNames[index],
              "country": countryNames[index],
              "region": regions[index],
            },
          );
        });
      }
    } else {
      return null;
    }
  }

  Future<void>  fetchWeather(longitude, latitude) async {
    final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?"
            "latitude=$latitude&longitude=$longitude"
            "&current=temperature_2m,wind_speed_10m"
        );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      String temperature =
          data['current']['temperature_2m'].toString() +
          data['current_units']['temperature_2m'];
      String windSpeed = data['current']['wind_speed_10m'].toString() + ' k/h';

      setState(() {
        _currentWindSpeed = windSpeed;
        _currentTemperature = temperature;
      });
      return ;
    } else {
      return ;
    }
  }

  Widget _buildTabToday() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (errorText.isNotEmpty)
          Text(errorText, style: TextStyle(fontSize: 24, color: Colors.red))
        else ...[
          Text(_cityName, style: TextStyle(fontSize: 24)),
          Text(_region, style: TextStyle(fontSize: 24)),
          Text(_country, style: TextStyle(fontSize: 24)),
        ],
      ],
    );
  }

  Widget _buildTabWeekly() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (errorText.isNotEmpty)
          Text(errorText, style: TextStyle(fontSize: 24, color: Colors.red))
        else ...[
          Text(_cityName, style: TextStyle(fontSize: 24)),
          Text(_region, style: TextStyle(fontSize: 24)),
          Text(_country, style: TextStyle(fontSize: 24)),
        ],
      ],
    );
  }

  Widget _buildTabCurrently() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (errorText.isNotEmpty)
          Text(errorText, style: TextStyle(fontSize: 24, color: Colors.red))
        else ...[
          Text(_cityName, style: TextStyle(fontSize: 24)),
          Text(_region, style: TextStyle(fontSize: 24)),
          Text(_country, style: TextStyle(fontSize: 24)),
          Text(_currentTemperature, style: TextStyle(fontSize: 24)),
          Text(_currentWindSpeed, style: TextStyle(fontSize: 24)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(hintText: 'Rechercher...'),
                onSubmitted: (value) {
                  _searchExe(value);
                },
                style: TextStyle(color: Colors.black),
              ),
            ),
            IconButton(
              icon: Icon(Icons.location_on),
              onPressed: () {
                _locationExe();
              },
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildTabCurrently(),
              _buildTabToday(),
              _buildTabWeekly(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Visibility(
              visible: suggestions.isNotEmpty,
              child: Container(
                color: Colors.grey[200],
                constraints: BoxConstraints(maxHeight: 520),
                // Limite la hauteur
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(suggestions[index]['city'] ?? ''),
                      subtitle: Text(
                        '${suggestions[index]['region'] ?? ''}, ${suggestions[index]['country'] ?? ''}',
                      ),
                      onTap: () {
                        _searchExe(suggestions[index]['city']!);
                        setState(() {
                          suggestions.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.cloud_outlined), text: 'Currently'),
            Tab(icon: Icon(Icons.today), text: 'Today'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Weekly'),
          ],
        ),
      ),
    );
  }
}
