import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'services/firebase_service.dart';

class MapPage extends StatefulWidget {
  final double? lat;
  final double? lng;
  final String? name;
  final DateTime? date;

  const MapPage({super.key, this.lat, this.lng, this.name, this.date});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = (widget.lat != null && widget.lng != null)
        ? LatLng(widget.lat!, widget.lng!)
        : null;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('موقع التسجيل', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: location == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('الموقع غير متوفر', style: theme.textTheme.titleMedium),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: location, 
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.attendance_app',
                    ),
                    // Circles around all Branches (Geofences)
                    CircleLayer(
                      circles: [
                        ...FirebaseService.branches.map(
                          (branch) => CircleMarker(
                            point: LatLng(
                              (branch['lat'] as num).toDouble(),
                              (branch['lng'] as num).toDouble(),
                            ),
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            borderColor: theme.colorScheme.primary.withOpacity(0.5),
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: (branch['radius'] as num).toDouble(),
                          ),
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        ...FirebaseService.branches.map(
                          (branch) => Marker(
                            point: LatLng(
                              (branch['lat'] as num).toDouble(),
                              (branch['lng'] as num).toDouble(),
                            ),
                            width: 60,
                            height: 60,
                            child: const Icon(Icons.business, color: Colors.blue, size: 30),
                          ),
                        ),
                        Marker(
                          point: location,
                          width: 80,
                          height: 80,
                          child: Icon(
                            Icons.location_on,
                            color: theme.colorScheme.error,
                            size: 45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Info Card
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.name ?? 'اسم غير معروف',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.date != null
                                      ? DateFormat('yyyy-MM-dd — hh:mm a').format(widget.date!)
                                      : 'تاريخ غير متوفر',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Zoom Controls
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoomIn',
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoomOut',
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
