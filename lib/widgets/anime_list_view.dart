import 'package:flutter/material.dart';
import '../models/anime.dart';
import './anime_item.dart';
import './json_editor.dart';

class AnimeListView extends StatelessWidget {
  final List<Anime> animeList;
  final bool showJsonEditor;
  
  const AnimeListView({
    super.key,
    required this.animeList,
    required this.showJsonEditor,
  });

  @override
  Widget build(BuildContext context) {
    if (animeList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.blue[200],
            ),
            const SizedBox(height: 16),
            const Text(
              'No anime in the list',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fetch a season or load a saved list',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    if (showJsonEditor) {
      return JsonEditor(animeList: animeList);
    }
    
    return ListView.builder(
      itemCount: animeList.length,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemBuilder: (context, index) {
        return AnimeItem(
          anime: animeList[index],
          index: index,
        );
      },
    );
  }
} 