import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cvi_discovery_game.dart';
import 'cvi_discovery_models.dart';

/// Tek kategori oyun ekranı — puan, süre veya ek UI yok.
class CviDiscoveryPlayPage extends StatefulWidget {
  const CviDiscoveryPlayPage({super.key, required this.category});

  final CviDiscoveryCategory category;

  @override
  State<CviDiscoveryPlayPage> createState() => _CviDiscoveryPlayPageState();
}

class _CviDiscoveryPlayPageState extends State<CviDiscoveryPlayPage> {
  late final CviDiscoveryGame _game;

  @override
  void initState() {
    super.initState();
    _game = CviDiscoveryGame(category: widget.category);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GameWidget(game: _game),
      ),
    );
  }
}
