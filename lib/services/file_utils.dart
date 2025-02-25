import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/anime.dart';

// For web platform
import 'package:universal_html/html.dart' if (dart.library.io) 'dart:io' as universal;

class FileUtils {
  static Future<Directory> getSaveDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${appDir.path}/saved_lists');
    
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    
    return saveDir;
  }
  
  static String formatFilename(String season, int year) {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
                     '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'anime_list_${season.toLowerCase()}_${year}_$timestamp.json';
  }
  
  static Future<String?> saveAnimeListWithSeason(List<Anime> animeList, String season, int year) async {
    try {
      final saveDir = await getSaveDirectory();
      final filename = formatFilename(season, year);
      final file = File('${saveDir.path}/$filename');
      
      // Convert anime list to JSON
      final jsonList = animeList.map((anime) => anime.toJson()).toList();
      
      // Write to file
      await file.writeAsString(jsonEncode(jsonList), flush: true);
      
      return filename;
    } catch (e) {
      print('Error saving anime list: $e');
      return null;
    }
  }
  
  static Future<List<Anime>> loadAnimeList(String filename) async {
    try {
      final saveDir = await getSaveDirectory();
      final file = File('${saveDir.path}/$filename');
      
      if (!await file.exists()) {
        return [];
      }
      
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      
      return jsonList.map((json) => Anime.fromJson(json)).toList();
    } catch (e) {
      print('Error loading anime list: $e');
      return [];
    }
  }
  
  static Future<List<String>> getSavedSeasonFiles() async {
    try {
      final saveDir = await getSaveDirectory();
      
      if (!await saveDir.exists()) {
        return [];
      }
      
      final files = await saveDir
          .list()
          .where((entity) => entity.path.endsWith('.json'))
          .map((entity) => entity.path.split('/').last)
          .toList();
      
      // Sort by most recent first
      files.sort((a, b) => b.compareTo(a));
      
      return files;
    } catch (e) {
      print('Error getting saved files: $e');
      return [];
    }
  }
  
  static List<Anime> sortAnimeList(List<Anime> animeList, String sortBy) {
    switch (sortBy) {
      case 'date':
        return List.from(animeList)..sort((a, b) => a.date.compareTo(b.date));
      case 'date_reverse':
        return List.from(animeList)..sort((a, b) => b.date.compareTo(a.date));
      case 'alpha':
        return List.from(animeList)..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'alpha_reverse':
        return List.from(animeList)..sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case 'members_high':
        return List.from(animeList)..sort((a, b) => b.members.compareTo(a.members));
      case 'members_low':
        return List.from(animeList)..sort((a, b) => a.members.compareTo(b.members));
      default:
        return animeList;
    }
  }

  static Future<List<Anime>> readAnimeList() async {
    try {
      if (kIsWeb) {
        // Web implementation
        final storage = universal.window.localStorage;
        final jsonString = storage['anime_list'];
        
        if (jsonString == null || jsonString.isEmpty) {
          return [];
        }
        
        final List<dynamic> jsonList = json.decode(jsonString);
        return jsonList.map((json) => Anime.fromJson(json)).toList();
      } else {
        // Native implementation
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/anime_list.json');
        
        if (!await file.exists()) {
          return [];
        }
        
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        
        return jsonList.map((json) => Anime.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error reading anime list: $e');
      return [];
    }
  }
  
  static Future<void> saveAnimeList(List<Anime> animeList) async {
    try {
      final jsonList = animeList.map((anime) => anime.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      if (kIsWeb) {
        // Web implementation
        final storage = universal.window.localStorage;
        storage['anime_list'] = jsonString;
      } else {
        // Native implementation
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/anime_list.json');
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving anime list: $e');
    }
  }
  
  static Future<List<String>> getSavedFiles() async {
    if (kIsWeb) {
      // For web, just return the main anime list if it exists
      return universal.window.localStorage.containsKey('anime_list') 
          ? ['anime_list.json'] 
          : [];
    } else {
      final path = await getApplicationDocumentsDirectory();
      final dir = Directory(path.path);
      
      final List<String> files = [];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          files.add(entity.path.split('/').last);
        }
      }
      
      return files;
    }
  }
} 