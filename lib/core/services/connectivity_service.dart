import 'dart:async';
import 'dart:io';
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
    // Açılışı BEKLETMEDEN: radyo durumu hemen alınır, gerçek internet
    // doğrulaması (en fazla 4 sn'lik DNS sorgusu) arka planda yapılır.
    // Önceden bu sorgu main() içinde runApp'ten ÖNCE bekleniyordu —
    // internetsiz bir Wi-Fi'deyken açılış 4 sn uzuyordu.
    _isConnected = _checkConnected(result);
    if (_isConnected) {
      _hasRealInternet().then((ok) {
        if (ok != _isConnected) {
          _isConnected = ok;
          _controller.add(ok);
        }
      });
    }

    _connectivity.onConnectivityChanged.listen((result) async {
      // DÜZELTME: connectivity_plus yalnızca bir ağ ARAYÜZÜNÜN (Wi-Fi/mobil
      // veri radyosu) bağlı olduğunu söyler — gerçek internet erişimini
      // GARANTİ ETMEZ (ör. internetsiz bir Wi-Fi'ye veya "captive portal"lı
      // bir ağa bağlıyken bile "connected" döner). Radyo bağlıysa ek olarak
      // kısa zaman aşımlı gerçek bir DNS sorgusuyla (_hasRealInternet)
      // gerçekten erişilebilir olup olmadığı doğrulanıyor.
      final connected = _checkConnected(result) && await _hasRealInternet();
      if (connected != _isConnected) {
        _isConnected = connected;
        _controller.add(connected);
      }
    });
  }

  /// Radyo seviyesinde "bağlı" görünse bile gerçekten internete
  /// erişilebiliyor mu diye kısa bir DNS sorgusuyla doğrular. Başarısız
  /// olursa (zaman aşımı, DNS hatası vb.) internet YOK kabul edilir.
  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('firebase.google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
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
