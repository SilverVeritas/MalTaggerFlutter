# File: utils/rss_utils.py

import requests
import time
import xml.etree.ElementTree as ET
from urllib.parse import quote_plus, unquote

def validate_rss_feed(url):
    """
    Validate RSS feed by checking both accessibility and content.
    Returns True only if the feed is accessible and contains torrent items.
    """
    try:
        response = requests.get(url, timeout=5)
        if response.status_code != 200 or 'xml' not in response.headers.get('content-type', ''):
            return False, None

        # Parse XML content
        root = ET.fromstring(response.content)
        
        # Find channel and then items
        channel = root.find('channel')
        if channel is None:
            return False, None
            
        # Look for item elements
        items = channel.findall('item')
        episode_count = len(items)
        
        # Return True and episode count only if there are items with valid links
        if episode_count > 0 and any(item.find('link') is not None for item in items):
            return True, episode_count
        return False, None

    except (requests.RequestException, ET.ParseError):
        return False, None
    
def extract_from_rss_url(rss_url):
    """Extract search terms and fansubber from RSS URL."""
    try:
        # Get the query part after q= and before &
        q_param = rss_url.split('q=')[1].split('&')[0]
        # URL decode the parameter
        q_param = unquote(q_param)
        # Split on spaces
        parts = q_param.split('+')
        
        # Find the index after -batch
        batch_index = parts.index('-batch')
        if batch_index + 1 >= len(parts):
            return None, None
            
        # Get fansubber (first term after -batch)
        fansubber = parts[batch_index + 1]
        
        # Get search terms (everything after fansubber)
        search_terms = '+'.join(parts[batch_index + 2:])
        
        return fansubber, search_terms
    except:
        return None, None
    
def initialize_fansubber_from_rss(rss_url, fansubber_key):
    """Extract and initialize fansubber value from RSS URL."""
    fansubber, _ = extract_from_rss_url(rss_url)
    if fansubber:
        return fansubber
    return "ember"  # Default fallback

def validate_rss_feeds_with_delay(rss_urls, delay=0.5):
    """Validate RSS feeds with a delay between each request."""
    results = {}
    episode_counts = {}
    total = len(rss_urls)
    
    for i, url in enumerate(rss_urls, 1):
        is_valid, count = validate_rss_feed(url)
        results[url] = is_valid
        episode_counts[url] = count
        time.sleep(delay)
        yield results, episode_counts, (i / total) * 100

def format_rss_url(title, fansubber="ember"):
    """Format the RSS URL for a given anime title and fansubber."""
    # For RSS URLs we need to properly encode everything including spaces
    safe_fansubber = quote_plus(fansubber)
    # Replace quotes first, then encode the whole title
    safe_title = title.replace('"', "'")
    safe_title = quote_plus(safe_title)

    return f"https://nyaa.si/?page=rss&q=-batch+{safe_fansubber}+{safe_title}&c=0_0&f=0"

def format_search_url(title, fansubber="ember"):
    """Format the search URL for a given anime title and fansubber."""
    # Encode the fansubber and title separately
    safe_fansubber = quote_plus(fansubber)
    # For the title, we want to keep spaces for the search interface
    safe_title = title.replace('"', "'")  # Replace quotes but keep spaces
    
    # Construct the URL keeping spaces between terms
    return f"https://nyaa.si/?f=0&c=0_0&q=-batch+{safe_fansubber}+{safe_title}"

def format_search_url_from_terms(search_terms, fansubber):
    """Format search URL from extracted search terms and fansubber."""
    # URL encode fansubber but keep spaces in search terms
    safe_fansubber = quote_plus(fansubber)
    # For search terms, replace quotes but keep spaces
    safe_terms = search_terms.replace('"', "'")
    
    return f"https://nyaa.si/?f=0&c=0_0&q=-batch+{safe_fansubber}+{safe_terms}"

def validate_rss_url(url):
    """Validate if the URL contains 'rss' and basic URL structure."""
    return 'rss' in url.lower() and (url.startswith('http://') or url.startswith('https://'))