import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'map_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _styleLoaded = false;
  bool _styleTimedOut = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 12), () {
      if (mounted && !_styleLoaded) {
        setState(() => _styleTimedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: MapConfig.styleUrl,
            initialCameraPosition: MapConfig.initialCameraPosition,
            onStyleLoadedCallback: () {
              if (mounted) setState(() => _styleLoaded = true);
            },
          ),
          if (!_styleLoaded)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _styleTimedOut
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off, size: 42),
                                SizedBox(height: 12),
                                Text(
                                  'Map could not be loaded.',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Check your internet connection and try again.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
