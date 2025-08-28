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
      title: 'MapmyIndia Routing with eLocs',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const RoutingScreen(),
    );
  }
}

class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key});
  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  final String apiKey = '7dd87200f91b7bbe0f3ffba12d4262d3'; // Your static API key
  final String bearerToken = '0406ebc3-893c-4d1b-9705-1462d0452372'; // Your OAuth Bearer token

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];

  bool _isLoadingStart = false;
  bool _isLoadingEnd = false;

  String? selectedStartELoc;
  String? selectedEndELoc;

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

        // Limit suggestions to first 3 only
        if (locations.length > 3) {
          locations = locations.sublist(0, 3);
        }

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

  // Parse routing response steps into readable instructions
  List<String> parseRouteSteps(Map<String, dynamic> data) {
    List<String> instructions = [];
    try {
      final steps = data['routes'][0]['legs'][0]['steps'];

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
            : '${duration.toStringAsFixed(0)} sec';

        String instruction;
        switch (type) {
          case 'depart':
            instruction = 'Start on $roadName';
            break;
          case 'turn':
            String modText = modifier.replaceAll('_', ' ').toLowerCase();
            instruction =
                'Turn $modText${roadName.isNotEmpty ? ' onto $roadName' : ''}';
            break;
          case 'arrive':
            instruction = 'You have arrived at your destination';
            break;
          case 'roundabout':
            String exitNum = maneuver['exit']?.toString() ?? '';
            instruction =
                'At roundabout, take exit $exitNum${roadName.isNotEmpty ? ' onto $roadName' : ''}';
            break;
          default:
            instruction = '$type on $roadName';
            break;
        }

        instructions.add('$instruction ($distanceStr, $durationStr)');
      }
    } catch (e) {
      instructions.add('Failed to parse route steps: $e');
    }

    return instructions;
  }

  Future<void> _getRouteWithELoc() async {
    if (selectedStartELoc == null || selectedEndELoc == null) {
      setState(() {
        routeSteps = ['Please select start and end locations from suggestions (must have eLocs).'];
      });
      return;
    }

    setState(() {
      routeSteps.clear();
    });

    final String urlStr =
        'https://apis.mapmyindia.com/advancedmaps/v1/$apiKey/route_adv/biking/$selectedStartELoc;$selectedEndELoc?steps=true';

    final Uri url = Uri.parse(urlStr);

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<String> instructions = parseRouteSteps(data);
        setState(() {
          routeSteps = instructions;
        });
      } else {
        setState(() {
          routeSteps = ['Routing API failed: ${response.statusCode}'];
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
        final eLoc = suggestion['eLoc'] ?? '';

        return ListTile(
          title: Text(placeName),
          subtitle: Text(placeAddress),
          trailing: Text(eLoc),
          onTap: () {
            setState(() {
              if (isStart) {
                selectedStartELoc = eLoc;
                _startSuggestions = [];
                _startController.text = placeName;
              } else {
                selectedEndELoc = eLoc;
                _endSuggestions = [];
                _endController.text = placeName;
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
        title: const Text('MapmyIndia Routing with eLocs'),
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
                suffixIcon:
                    _isLoadingEnd ? const CircularProgressIndicator(strokeWidth: 2) : null,
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
              onPressed: _getRouteWithELoc,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                child: Text('Get Directions', style: TextStyle(fontSize: 18)),
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}
