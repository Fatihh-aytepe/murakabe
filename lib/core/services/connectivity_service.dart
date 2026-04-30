import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  late StreamController<bool> _controller;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  Future<void> init() async {
    _controller = StreamController<bool>.broadcast();

    final result = await _connectivity.checkConnectivity();
    _isConnected = _checkConnected(result);

    _connectivity.onConnectivityChanged.listen((result) {
      final connected = _checkConnected(result);
      if (connected != _isConnected) {
        _isConnected = connected;
        _controller.add(connected);
      }
    });
  }

  bool _checkConnected(dynamic result) {
    if (result is List) {
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } else {
      return result != ConnectivityResult.none;
    }
  }

  void dispose() {
    _controller.close();
  }
}

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _showBanner = false;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = ConnectivityService().onConnectivityChanged.listen((connected) {
      if (mounted) setState(() => _showBanner = !connected);
      if (connected) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showBanner = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.red.shade700,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'İnternet bağlantısı yok — Çevrimdışı mod',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
