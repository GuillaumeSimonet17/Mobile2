import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';


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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search_exe(value) {
    setState(() {
      searchText = value;
      _searchController.clear();
    });
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

    String city;

    try {
      Position position = await _determinePosition();
      setState(() {
        searchText = '$position';
      });

      // city = await getCityFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      city = 'Something went wrong';
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
                  _search_exe(value);
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

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent('Currently'),
          _buildTabContent('Today'),
          _buildTabContent('Weekly'),
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
