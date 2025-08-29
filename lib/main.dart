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
      title: 'Google Places Two Inputs',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PlacesAutocompleteTwoInputsScreen(),
    );
  }
}

class PlacesAutocompleteTwoInputsScreen extends StatefulWidget {
  const PlacesAutocompleteTwoInputsScreen({super.key});
  @override
  State<PlacesAutocompleteTwoInputsScreen> createState() =>
      _PlacesAutocompleteTwoInputsScreenState();
}

class _PlacesAutocompleteTwoInputsScreenState
    extends State<PlacesAutocompleteTwoInputsScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  final String googleApiKey = 'AIzaSyD35mPom8mU_08Skhpf0X25C46J3Lz5fV8';

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];

  bool _isLoadingStart = false;
  bool _isLoadingEnd = false;

  void fetchGooglePlaceSuggestions(String input, bool isStart) async {
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
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$googleApiKey&types=geocode&components=country:in');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            if (isStart) {
              _startSuggestions = data['predictions'];
              _isLoadingStart = false;
            } else {
              _endSuggestions = data['predictions'];
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
        print('Error from Google Places API: ${response.statusCode}');
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

  Widget _buildSuggestionList(
      List<dynamic> suggestions, bool isStart, TextEditingController controller) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final description = suggestion['description'] ?? '';

        return ListTile(
          title: Text(description),
          onTap: () {
            controller.text = description;
            setState(() {
              if (isStart) {
                _startSuggestions = [];
              } else {
                _endSuggestions = [];
              }
            });
            print('Selected place_id: ${suggestion['place_id']}');
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
        title: const Text('Google Places Autocomplete Two Inputs'),
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
          ],
        ),
      ),
    );
  }
}
