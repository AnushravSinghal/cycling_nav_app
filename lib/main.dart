import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapmyIndia + OSRM Directions',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const DirectionsScreen(),
    );
  }
}

class DirectionsScreen extends StatefulWidget {
  const DirectionsScreen({super.key});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  final String bearerToken = '881b6206-b44c-49ef-aa5b-fdd3d71ff36b';

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];

  bool _isLoadingStart = false;
  bool _isLoadingEnd = false;

  double? selectedStartLat;
  double? selectedStartLon;
  double? selectedEndLat;
  double? selectedEndLon;

  List<String> routeSteps = [];

  Future<void> fetchAutosuggest(String query, bool isStart) async {
    if (query.length < 3) {
      setState(() {
        if (isStart) {
          _startSuggestions = [];
        } else {
          _endSuggestions = [];
        }
      });
      return;
    }

    if (isStart) {
      setState(() => _isLoadingStart = true);
    } else {
      setState(() => _isLoadingEnd = true);
    }

    final Uri url = Uri.parse(
        'https://atlas.mapmyindia.com/api/places/search/json?query=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'bearer $bearerToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> locations = [];

        if (data.containsKey('suggestedLocations')) {
          locations = data['suggestedLocations'];
        } else if (data.containsKey('places')) {
          locations = data['places'];
        }

        if (locations.length > 3) {
  locations = locations.sublist(0, 3);
}

print('$locations' );

        setState(() {
          if (isStart) {
            _startSuggestions = locations;
            _isLoadingStart = false;
          } else {
            _endSuggestions = locations;
            _isLoadingEnd = false;
          }
        });
      } else {
        setState(() {
          if (isStart) {
            _startSuggestions = [];
            _isLoadingStart = false;
          } else {
            _endSuggestions = [];
            _isLoadingEnd = false;
          }
        });
        print('Error: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        if (isStart) {
          _startSuggestions = [];
          _isLoadingStart = false;
        } else {
          _endSuggestions = [];
          _isLoadingEnd = false;
        }
      });
      print('Exception: $e');
    }
  }

  Future<void> _getRoute() async {
    if (selectedStartLat == null ||
        selectedStartLon == null ||
        selectedEndLat == null ||
        selectedEndLon == null) {
      setState(() {
        routeSteps = ['Please select both start and end locations'];
      });
      return;
    }

    setState(() {
      routeSteps.clear();
    });

    final String coords =
        '${selectedStartLon},${selectedStartLat};${selectedEndLon},${selectedEndLat}';

    final Uri url = Uri.parse(
        'http://router.project-osrm.org/route/v1/bicycle/$coords?steps=true&geometries=geojson');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> steps = data['routes'][0]['legs'][0]['steps'];

        List<String> instructions = [];

        for (var step in steps) {
          var maneuver = step['maneuver'];
          String type = maneuver['type'] ?? '';
          String modifier = maneuver['modifier'] ?? '';
          String roadName = step['name'] ?? '';

          double distance = (step['distance'] ?? 0).toDouble();
          double duration = (step['duration'] ?? 0).toDouble();

          String distanceStr = distance > 1000
              ? '${(distance / 1000).toStringAsFixed(1)} km'
              : '${distance.toStringAsFixed(0)} m';

          String durationStr = duration >= 60
              ? '${(duration / 60).toStringAsFixed(0)} min'
              : '${duration.toStringAsFixed(0)} s';

          String instruction;

          switch (type) {
            case 'depart':
              instruction = 'START on $roadName';
              break;
            case 'turn':
              String modText = modifier.replaceAll('_', ' ').toUpperCase();
              instruction = 'TURN $modText onto $roadName';
              break;
            case 'roundabout':
              String exitNum = maneuver['exit'] != null ? maneuver['exit'].toString() : '';
              instruction = 'ROUNDABOUT, take exit $exitNum onto $roadName';
              break;
            case 'arrive':
              instruction = 'ARRIVE at your destination';
              break;
            default:
              instruction = '${type.toUpperCase()} on $roadName';
          }

          if (roadName.isEmpty) {
            instruction = instruction.replaceAll(' onto ', ' ');
          }

          instruction = '$instruction ($distanceStr, $durationStr)';

          instructions.add(instruction);
        }

        setState(() {
          routeSteps = instructions;
        });
      } else {
        setState(() {
          routeSteps = ['Failed to fetch route. Status code: ${response.statusCode}'];
        });
      }
    } catch (e) {
      setState(() {
        routeSteps = ['Error fetching route: $e'];
      });
    }
  }

  Widget _buildSuggestionList(
      List<dynamic> suggestions, bool isStart, TextEditingController controller) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final placeName = suggestion['placeName'] ?? '';
        final placeAddress = suggestion['placeAddress'] ?? '';

        return ListTile(
          title: Text(placeName),
          subtitle: Text(placeAddress),
          // ...existing code...
onTap: () {
  final latRaw = suggestion['latitude'];
  final lonRaw = suggestion['longitude'];

  // Safely parse latitude and longitude
  final double? lat = latRaw is double
      ? latRaw
      : latRaw is String
          ? double.tryParse(latRaw)
          : null;
  final double? lon = lonRaw is double
      ? lonRaw
      : lonRaw is String
          ? double.tryParse(lonRaw)
          : null;

  if (lat == null || lon == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid location data from API.')),
    );
    return;
  }

  setState(() {
    if (isStart) {
      selectedStartLat = lat;
      selectedStartLon = lon;
      _startSuggestions = [];
      _startController.text = placeName;
    } else {
      selectedEndLat = lat;
      selectedEndLon = lon;
      _endSuggestions = [];
      _endController.text = placeName;
    }
  });
},
// ...existing code...
        );
      },
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('MapmyIndia + OSRM Directions'),
        ),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                controller: _startController,
                decoration: InputDecoration(
                  labelText: 'Start Location',
                  prefixIcon: const Icon(Icons.my_location),
                  suffixIcon:
                      _isLoadingStart ? const CircularProgressIndicator(strokeWidth: 2) : null,
                ),
                onChanged: (input) => fetchAutosuggest(input, true),
              ),
              _startSuggestions.isEmpty
                  ? const SizedBox.shrink()
                  : Expanded(
                      flex: 0,
                      child: _buildSuggestionList(_startSuggestions, true, _startController)),
              const SizedBox(height: 10),
              TextField(
                controller: _endController,
                decoration: InputDecoration(
                  labelText: 'End Location',
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: _isLoadingEnd ? const CircularProgressIndicator(strokeWidth: 2) : null,
                ),
                onChanged: (input) => fetchAutosuggest(input, false),
              ),
              _endSuggestions.isEmpty
                  ? const SizedBox.shrink()
                  : Expanded(
                      flex: 0,
                      child: _buildSuggestionList(_endSuggestions, false, _endController)),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _getRoute,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                    child: Text('Get Directions', style: TextStyle(fontSize: 18)),
                  )),
              const SizedBox(height: 20),
              routeSteps.isEmpty
                  ? const Text('No route loaded')
                  : Expanded(
                      child: ListView.builder(
                        itemCount: routeSteps.length,
                        itemBuilder: (context, index) => ListTile(
                          leading: const Icon(Icons.directions_bike),
                          title: Text(routeSteps[index]),
                        ),
                      ),
                    )
            ])));
  }
}
