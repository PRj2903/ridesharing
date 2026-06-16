import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_details.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isSearching = false;
  Map<String, dynamic>? _assignedDriver;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ),
    );
  }

  Future<void> _requestRide() async {
    if (_currentPosition == null) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Create request in Firestore
      await FirebaseFirestore.instance.collection('ride_requests').add({
        'userId': 'user_demo_123',
        'pickup': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'status': 'searching',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Simulate driver assignment for prototype
      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        setState(() {
          _isSearching = false;
          _assignedDriver = {
            'name': 'Alex Johnson',
            'vehicle': 'White Toyota Camry (XYZ-789)',
            'rating': '4.8',
          };
          
          // Add driver marker
          _markers.add(
            Marker(
              markerId: const MarkerId('driver'),
              position: LatLng(
                _currentPosition!.latitude + 0.005,
                _currentPosition!.longitude + 0.005,
              ),
              infoWindow: const InfoWindow(title: 'Driver is arriving'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                ),
          
          // Header
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blue),
                    const SizedBox(width: 10),
                    const Text('Where to?', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _assignedDriver != null
                ? DriverDetails(
                    name: _assignedDriver!['name'],
                    vehicle: _assignedDriver!['vehicle'],
                    rating: _assignedDriver!['rating'],
                  )
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSearching) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 10),
                          const Text('Finding nearby drivers...'),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSearching ? null : _requestRide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              _isSearching ? 'SEARCHING...' : 'REQUEST RIDE',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
