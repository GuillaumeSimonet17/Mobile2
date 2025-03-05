import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
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
  bool tabNameActived = true;

  String searchText = '';
  String geolocation = '';
  String _temperature = '';
  String _cityName = '';
  String _country = '';
  String _region = '';
  String _windSpeed = '';

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
    String region = '';
    String search = '';
    String temperature = '';

    if (coordinates != null && coordinates["country"] != null &&(coordinates['longitude'] ?? 0.0).isFinite) {
      country = coordinates["country"];
      region = coordinates["region"];
      search = coordinates['longitude'].toString() + ' ' +
          coordinates['latitude'].toString();
      temperature = await fetchWeather(coordinates['longitude'].toString(), coordinates['latitude'].toString());

    }


    setState(() {
      _cityName = value;
        _country = country;
        _region = region;
        searchText = search;
        _temperature = temperature;
        _searchController.clear();
    });
  }

  Future<String> getCityName(double longitude, double latitude) async {
    print(longitude);
    print(latitude);
    final url = Uri.parse(
        "https://api.open-meteo.com/v1/geocoding?latitude=4.835659&longitude=45.764043&language=fr");

    final response = await http.get(url);
    print(response.statusCode);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data);

      if (data['results'] != null && data['results'].isNotEmpty) {
        return data['results'][0]['name']; // Nom de la ville
      } else {
        return "Aucune ville trouvée";
      }
    } else {
      return "Erreur: ${response.statusCode}";
    }
  }

  Future<String> fetchWeather(longitude, latitude) async {
    final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current=temperature_2m,weathercode&timezone=Europe/Paris");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      String temperature = data['current']['temperature_2m'].toString() + data['current_units']['temperature_2m'];
      print('=============================$temperature');
      return temperature;
    } else {
      return "Erreur: ${response.statusCode}";
    }
  }

  Future<void> getSuggestionCityName(String cityName) async {
    final url = Uri.parse(
        "https://geocoding-api.open-meteo.com/v1/search?name=$cityName&count=10&language=fr");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['results'] != null) {
        List<String> cityNames = data['results'].map((city) => city["name"]
            .toString()).toList().cast<String>();
        List<String> countryNames = data['results'].map((city) => city["country"]
            .toString()).toList().cast<String>();
        List<String> regions = data['results'].map((city) => city["admin1"]
            .toString()).toList().cast<String>();

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

  Future<Map<String, dynamic>?> getCoordinates(String cityName) async {
    final url = Uri.parse(
        "https://geocoding-api.open-meteo.com/v1/search?name=$cityName&count=1&language=fr");

    final response = await http.get(url);
    // print('here = $response');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['results'] != null && data['results'].isNotEmpty) {
        double lat = data['results'][0]['latitude'];
        double lon = data['results'][0]['longitude'];
        String country = data['results'][0]['country'];
        String region = data['results'][0]['admin1'];

        return {'latitude': lat, 'longitude': lon, 'country': country, 'region': region};
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      final permissionStatus = await Permission.location.request();

      if (permissionStatus != PermissionStatus.granted) {
        print('Permissions de localisation refusées');
        return false;
      }
    }
    return true;
  }

  void _locationExe() async {
    if (!await _requestLocationPermission()) {
      setState(() {
        tabNameActived = false;
        searchText = 'Geoloation is not available, please enable it in your App settings';
      });
      return;
    }

    try {
      Position position = await _determinePosition();
      String temperature = await fetchWeather(position.longitude, position.latitude);
      String cityName = await getCityName(position.longitude, position.latitude);
      print(temperature);
      setState(() {
        _temperature = temperature;
        _cityName = cityName;
        searchText = '$position';
      });

    } catch (e) {
      print('Something went wrong');
    }
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
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }


  Widget _buildTabContent(String tabName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (tabNameActived)
            Text(
            tabName,
            style: TextStyle(fontSize: 24),
          ),
        Text(
          searchText,
          style: TextStyle(fontSize: 24),
        ),
        Text(
          _cityName,
          style: TextStyle(fontSize: 24),
        ),
        Text(
          _country,
          style: TextStyle(fontSize: 24),
        ),
        Text(
          _region,
          style: TextStyle(fontSize: 24),
        ),
        Text(
          _temperature,
          style: TextStyle(fontSize: 24),
        ),
      ]
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
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                ),
                onSubmitted: (value) {
                  _searchExe(value);
                },
                style: TextStyle(color: Colors.black),
              ),
            ),
            // Correction ici : Utilisation de Flexible
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
              _buildTabContent('Currently'),
              _buildTabContent('Today'),
              _buildTabContent('Weekly'),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0, // Juste sous l'AppBar
            child: Visibility(
              visible: suggestions.isNotEmpty,
              child: Container(
                color: Colors.grey[200],
                constraints: BoxConstraints(maxHeight: 520), // Limite la hauteur
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
        ]
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
