import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Places Routing with Distance & Time',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PlacesRoutingScreen(),
    );
  }
}

class PlacesRoutingScreen extends StatefulWidget {
  const PlacesRoutingScreen({super.key});
  @override
  State<PlacesRoutingScreen> createState() => _PlacesRoutingScreenState();
}

class _PlacesRoutingScreenState extends State<PlacesRoutingScreen> {
  final String googleApiKey = 'AIzaSyD35mPom8mU_08Skhpf0X25C46J3Lz5fV8';

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];

  bool _isLoadingStart = false;
  bool _isLoadingEnd = false;
  bool _isLoadingRoute = false;

  String? selectedStartPlaceId;
  String? selectedEndPlaceId;

  String? routesSummary;
  List<String> routeSteps = [];

  Future<void> fetchGooglePlaceSuggestions(String input, bool isStart) async {
    if (input.length < 3) {
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
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$googleApiKey&regionCode=in',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          List<dynamic> predictions = data['predictions'];
          if (predictions.length > 3) {
            predictions = predictions.sublist(0, 3);
          }
          setState(() {
            if (isStart) {
              _startSuggestions = predictions;
              _isLoadingStart = false;
            } else {
              _endSuggestions = predictions;
              _isLoadingEnd = false;
            }
          });
        } else {
          print('Autocomplete API returned status: ${data['status']}');
          setState(() {
            if (isStart) {
              _startSuggestions = [];
              _isLoadingStart = false;
            } else {
              _endSuggestions = [];
              _isLoadingEnd = false;
            }
          });
        }
      } else {
        print('Google Places API error: ${response.statusCode}');
        setState(() {
          if (isStart) {
            _startSuggestions = [];
            _isLoadingStart = false;
          } else {
            _endSuggestions = [];
            _isLoadingEnd = false;
          }
        });
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      setState(() {
        if (isStart) {
          _startSuggestions = [];
          _isLoadingStart = false;
        } else {
          _endSuggestions = [];
          _isLoadingEnd = false;
        }
      });
    }
  }

  Future<void> getDirectionsWithPlaceIds() async {
    if (selectedStartPlaceId == null || selectedEndPlaceId == null) {
      setState(() {
        routesSummary = null;
        routeSteps = ['Please select both start and end locations'];
      });
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      routeSteps.clear();
      routesSummary = null;
    });

    final Uri url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=place_id:$selectedStartPlaceId&destination=place_id:$selectedEndPlaceId&mode=driving&key=$googleApiKey',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final leg = data['routes'][0]['legs'][0];
          List<String> instructions = [];

          // Total distance in meters and km
          final totalDistanceMeters = leg['distance']['value'] ?? 0;
          final totalDistanceKm = (totalDistanceMeters / 1000).toStringAsFixed(2);

          // Estimated cycling time (assume 15 km/h)
          const averageCyclingSpeedKmh = 15.0;
          final estimatedTimeHours = totalDistanceMeters / 1000 / averageCyclingSpeedKmh;
          final estimatedTimeMinutes = (estimatedTimeHours * 60).round();

          for (var step in leg['steps']) {
            final instruction = step['html_instructions']
                .replaceAll(RegExp(r'<[^>]*>'), ''); // Strip HTML tags
            instructions.add(instruction);
          }

          setState(() {
            routeSteps = instructions;
            routesSummary = 'Distance: $totalDistanceKm km, Estimated time: $estimatedTimeMinutes min';
          });
        } else {
          setState(() {
            routeSteps = ['Directions API error: ${data['status']}'];
            routesSummary = null;
          });
        }
      } else {
        setState(() {
          routeSteps = ['Failed to fetch directions. Status code: ${response.statusCode}'];
          routesSummary = null;
        });
      }
    } catch (e) {
      setState(() {
        routeSteps = ['Error fetching directions: $e'];
        routesSummary = null;
      });
    } finally {
      setState(() {
        _isLoadingRoute = false;
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
        final description = suggestion['description'] ?? '';
        final placeId = suggestion['place_id'] ?? '';

        return ListTile(
          title: Text(description),
          onTap: () {
            controller.text = description;
            setState(() {
              if (isStart) {
                selectedStartPlaceId = placeId;
                _startSuggestions = [];
              } else {
                selectedEndPlaceId = placeId;
                _endSuggestions = [];
              }
            });
          },
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
        title: const Text('Google Places Routing'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _startController,
              decoration: InputDecoration(
                labelText: 'Start Location',
                prefixIcon: const Icon(Icons.my_location),
                suffixIcon:
                    _isLoadingStart ? const CircularProgressIndicator() : null,
              ),
              onChanged: (input) => fetchGooglePlaceSuggestions(input, true),
            ),
            _startSuggestions.isEmpty
                ? const SizedBox.shrink()
                : _buildSuggestionList(_startSuggestions, true, _startController),
            const SizedBox(height: 20),
            TextField(
              controller: _endController,
              decoration: InputDecoration(
                labelText: 'End Location',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon:
                    _isLoadingEnd ? const CircularProgressIndicator() : null,
              ),
              onChanged: (input) => fetchGooglePlaceSuggestions(input, false),
            ),
            _endSuggestions.isEmpty
                ? const SizedBox.shrink()
                : _buildSuggestionList(_endSuggestions, false, _endController),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoadingRoute ? null : getDirectionsWithPlaceIds,
              child: _isLoadingRoute
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Get Directions'),
            ),
            const SizedBox(height: 20),
            if (routesSummary != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  routesSummary!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
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
                  ),
          ],
        ),
      ),
    );
  }
}
