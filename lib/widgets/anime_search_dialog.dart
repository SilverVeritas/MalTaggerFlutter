// lib/widgets/anime_search_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class AnimeSearchDialog extends StatefulWidget {
  final Function(int) onAnimeSelected;

  const AnimeSearchDialog({super.key, required this.onAnimeSelected});

  @override
  AnimeSearchDialogState createState() => AnimeSearchDialogState();
}

class AnimeSearchDialogState extends State<AnimeSearchDialog> {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool isSubmitting = false;
  bool isSearchMode = false;
  List<dynamic> searchResults = [];
  bool isSearching = false;

  @override
  void dispose() {
    urlController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAnime(String query) async {
    if (query.isEmpty) return;

    setState(() {
      isSearching = true;
    });

    try {
      // Use Jikan API to search for anime
      final url =
          '$kJikanApiBaseUrl/anime?q=${Uri.encodeComponent(query)}&limit=5';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          searchResults = data['data'] as List;
          isSearching = false;
        });
      } else {
        throw Exception('Failed to search anime: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isSearching = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _processUrl() async {
    if (formKey.currentState!.validate()) {
      setState(() {
        isSubmitting = true;
      });

      // Extract MAL ID from URL
      final url = urlController.text;
      final RegExp regExp = RegExp(r'myanimelist\.net/anime/(\d+)');
      final match = regExp.firstMatch(url);

      if (match != null && match.groupCount >= 1) {
        final malId = int.parse(match.group(1)!);
        widget.onAnimeSelected(malId);
      } else {
        setState(() {
          isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not extract MAL ID from URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog title
              Text(
                isSearchMode ? 'Search Anime' : 'Add Anime from MAL URL',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Mode toggle
              Row(
                children: [
                  ToggleButtons(
                    isSelected: [!isSearchMode, isSearchMode],
                    onPressed: (index) {
                      setState(() {
                        isSearchMode = index == 1;
                        searchResults = [];
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('URL'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Search'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main content area
              Expanded(
                child:
                    isSearchMode ? _buildSearchContent() : _buildUrlContent(),
              ),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  if (!isSearchMode)
                    ElevatedButton(
                      onPressed: isSubmitting ? null : _processUrl,
                      child: const Text('Add'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search box
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            labelText: 'Search anime',
            hintText: 'Enter anime title',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                searchController.clear();
                setState(() {
                  searchResults = [];
                });
              },
            ),
          ),
          enabled: !isSearching && !isSubmitting,
          onSubmitted: _searchAnime,
        ),

        const SizedBox(height: 16),

        // Search results or loading indicator
        Expanded(
          child:
              isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : searchResults.isEmpty
                  ? Center(
                    child:
                        searchController.text.isNotEmpty
                            ? const Text('No results found')
                            : const Text('Enter a search term to find anime'),
                  )
                  : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final anime = searchResults[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            anime['images']?['jpg']?['image_url'] ?? '',
                            width: 40,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Icon(Icons.broken_image),
                          ),
                        ),
                        title: Text(
                          anime['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${anime['type'] ?? 'Unknown'} • ${anime['aired']?['string'] ?? 'Unknown'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap:
                            isSubmitting
                                ? null
                                : () {
                                  setState(() {
                                    isSubmitting = true;
                                  });
                                  widget.onAnimeSelected(anime['mal_id']);
                                },
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildUrlContent() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'MyAnimeList URL',
              hintText: 'https://myanimelist.net/anime/...',
              prefixIcon: Icon(Icons.link),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a URL';
              }
              if (!value.contains('myanimelist.net/anime/')) {
                return 'Please enter a valid MyAnimeList anime URL';
              }
              return null;
            },
            enabled: !isSubmitting,
          ),

          if (isSubmitting)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching anime data...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
