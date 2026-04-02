import 'package:flutter/material.dart';

import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../lieux_map_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  late Future<List<LieuModel>> _lieuxFuture;

  @override
  void initState() {
    super.initState();
    _lieuxFuture = LieuService.getLieux();
  }

  @override
  void reassemble() {
    super.reassemble();
    _lieuxFuture = LieuService.getLieux();
  }

  Future<void> _refresh() async {
    setState(() {
      _lieuxFuture = LieuService.getLieux();
    });
    await _lieuxFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LieuModel>>(
      future: _lieuxFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final lieux = snapshot.data ?? const <LieuModel>[];
        return LieuxMapScreen(lieux: lieux);
      },
    );
  }
}
