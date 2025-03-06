import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class RssUtils {
  static Future<(bool, int?)> validateRssFeed(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 ||
          !response.headers['content-type']!.contains('xml')) {
        return (false, null);
      }

      // Parse XML content
      final document = xml.XmlDocument.parse(response.body);

      // Find channel and then items
      final channelElements = document.findAllElements('channel');
      if (channelElements.isEmpty) {
        return (false, null);
      }

      final channel = channelElements.first;

      // Look for item elements
      final items = channel.findAllElements('item').toList();
      final episodeCount = items.length;

      // Return true and episode count only if there are items with valid links
      if (episodeCount > 0 &&
          items.any((item) => item.findElements('link').isNotEmpty)) {
        return (true, episodeCount);
      }

      return (false, null);
    } catch (e) {
      return (false, null);
    }
  }

  static (String?, String?) extractFromRssUrl(String rssUrl) {
    try {
      // Get the query part after q= and before &
      final qParamStart = rssUrl.indexOf('q=');
      if (qParamStart == -1) return (null, null);

      final qParamEnd = rssUrl.indexOf('&', qParamStart);
      final qParam = Uri.decodeComponent(
        qParamEnd == -1
            ? rssUrl.substring(qParamStart + 2)
            : rssUrl.substring(qParamStart + 2, qParamEnd),
      );

      // Split on spaces
      final parts = qParam.split('+');

      // Find the index after -batch
      final batchIndex = parts.indexOf('-batch');
      if (batchIndex == -1 || batchIndex + 1 >= parts.length) {
        return (null, null);
      }

      // Get fansubber (first term after -batch)
      final fansubber = parts[batchIndex + 1];

      // Get search terms (everything after fansubber)
      final searchTerms = parts.sublist(batchIndex + 2).join('+');

      return (fansubber, searchTerms);
    } catch (e) {
      return (null, null);
    }
  }

  static String initializeFansubberFromRss(String rssUrl) {
    final (fansubber, _) = extractFromRssUrl(rssUrl);
    return fansubber ?? 'ember';
  }

  static String formatRssUrl(String title, [String fansubber = 'ember']) {
    // For RSS URLs we need to properly encode everything including spaces
    final safeFansubber = Uri.encodeComponent(fansubber);
    // Replace quotes first, then encode the whole title
    final safeTitle = Uri.encodeComponent(title.replaceAll('"', "'"));

    return 'https://nyaa.si/?page=rss&q=-batch+$safeFansubber+$safeTitle&c=0_0&f=0';
  }

  static String formatSearchUrl(String title, [String fansubber = 'ember']) {
    // Encode the fansubber
    final safeFansubber = Uri.encodeComponent(fansubber);
    // For the title, we want to keep spaces for the search interface
    final safeTitle = title.replaceAll('"', "'");

    // Construct the URL with properly encoded components
    return 'https://nyaa.si/?f=0&c=0_0&q=-batch+$safeFansubber+$safeTitle';
  }

  static String formatSearchUrlFromTerms(String searchTerms, String fansubber) {
    // URL encode fansubber
    final safeFansubber = Uri.encodeComponent(fansubber);
    // For search terms, replace quotes but keep spaces
    final safeTerms = searchTerms.replaceAll('"', "'");

    return 'https://nyaa.si/?f=0&c=0_0&q=-batch+$safeFansubber+$safeTerms';
  }

  static bool validateRssUrl(String url) {
    return url.toLowerCase().contains('rss') &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  static String convertRssToSearchUrl(String rssUrl) {
    try {
      // Parse the RSS URL
      final uri = Uri.parse(rssUrl);

      // Get the query parameters
      final queryParams = uri.queryParameters;

      // We need the search query from the q parameter
      final searchQuery = queryParams['q'] ?? '';
      final category = queryParams['c'] ?? '0_0';
      final filter = queryParams['f'] ?? '0';

      // Construct the search URL (remove the page=rss part)
      return 'https://nyaa.si/?f=$filter&c=$category&q=$searchQuery';
    } catch (e) {
      print('Error converting RSS to search URL: $e');
      return rssUrl.replaceFirst('page=rss&', ''); // Fallback conversion
    }
  }
}
