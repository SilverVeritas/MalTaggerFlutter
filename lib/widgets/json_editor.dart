import 'package:flutter/material.dart';
import '../models/anime.dart';

class JsonEditor extends StatelessWidget {
  final List<Anime> animeList;

  const JsonEditor({
    super.key,
    required this.animeList,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(animeList.map((a) => a.toJson()).toList().toString()),
      ),
    );
  }
} 