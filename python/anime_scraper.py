# File: anime_scraper.py

import requests
import json
from datetime import datetime
import time
import logging
from typing import Dict, List, Optional, Set, Callable

logger = logging.getLogger(__name__)

class JikanAnimeScraper:
    """Scraper for fetching seasonal anime data from Jikan API with advanced filtering."""
    
    def __init__(self, min_members: int = 5000):
        self.min_members = min_members
        self.stats = {
            'total_fetched': 0,
            'filtered_out': 0,
            'chinese_filtered': 0,
            'low_members_filtered': 0
        }
    
    def _is_chinese_animation(self, anime: Dict) -> bool:
        """Check if anime is Chinese animation based on type and producers."""
        anime_type = anime.get('type', '').upper()
        
        # Direct type matches
        if anime_type in ['ONA-CN', 'DONGHUA']:
            return True
            
        # Check ONA types for Chinese producers
        if anime_type == 'ONA':
            producers = anime.get('producers', [])
            producer_names = [p.get('name', '').lower() for p in producers]
            chinese_keywords = {'bilibili', 'tencent', 'iqiyi', 'youku'}
            if any(name for name in producer_names if any(keyword in name for keyword in chinese_keywords)):
                return True
        
        return False

    def _filter_anime(self, anime: Dict) -> bool:
        """Apply filtering rules to anime entry."""
        # Check member count
        if anime.get('members', 0) < self.min_members:
            self.stats['low_members_filtered'] += 1
            return False
            
        # Check if Chinese animation
        if self._is_chinese_animation(anime):
            self.stats['chinese_filtered'] += 1
            return False
            
        return True

    def _extract_anime_data(self, anime: Dict) -> Dict:
        """Extract relevant fields from anime data."""
        title = anime.get('title', '')
        
        # Generate initial RSS URL with default fansubber
        from utils.rss_utils import format_rss_url
        initial_rss = format_rss_url(title, "ember")
        
        # Format the date to be human readable
        aired_from = anime.get('aired', {}).get('from', 'TBA')
        if aired_from and aired_from != 'TBA':
            try:
                from datetime import datetime
                aired_date = datetime.fromisoformat(aired_from.replace('Z', '+00:00'))
                aired_from = aired_date.strftime('%Y-%m-%d')  # Format as YYYY-MM-DD
            except:
                pass  # Keep original format if parsing fails
            
        return {
            'title': title,
            'date': aired_from,
            'synopsis': anime.get('synopsis', 'No synopsis available.'),
            'genres': [genre.get('name', '') for genre in anime.get('genres', [])],
            'score': anime.get('score', 0),
            'members': anime.get('members', 0),
            'episodes': anime.get('episodes', '?'),
            'status': anime.get('status', 'Unknown'),
            'image_url': anime.get('images', {}).get('jpg', {}).get('image_url', ''),
            'type': anime.get('type', 'Unknown'),
            'source': anime.get('source', 'Unknown'),
            'mal_id': anime.get('mal_id', None),
            'rssUrl': initial_rss,
            'fansubber': 'ember'
        }
    
    def _remove_duplicates(self, anime_list: List[Dict]) -> List[Dict]:
        """Remove duplicate anime entries based on MAL ID and title."""
        seen_ids = set()
        seen_titles = set()
        unique_list = []
        original_count = len(anime_list)

        for anime in anime_list:
            mal_id = anime.get('mal_id')
            title = anime.get('title')

            # Skip if we've seen this ID or title before
            if mal_id in seen_ids or title in seen_titles:
                continue

            unique_list.append(anime)
            if mal_id:
                seen_ids.add(mal_id)
            if title:
                seen_titles.add(title)

        self.stats['duplicates_removed'] = original_count - len(unique_list)
        return unique_list

    def fetch_seasonal_anime(self, season: str = None, year: int = None, 
                        progress_callback: Callable[[int, int], None] = None) -> List[Dict]:
        """
        Fetch and filter seasonal anime.
        
        Args:
            season: Anime season (winter, spring, summer, fall)
            year: Year to fetch
            progress_callback: Callback function receiving current_page and total_pages
            
        Returns:
            List of filtered and processed anime entries
        """
        # Use current season/year if not provided
        if not season or not year:
            current_month = datetime.now().month
            year = datetime.now().year
            
            if current_month == 12:  # December is part of next year's winter
                year += 1
                season = "winter"
            elif current_month in [1, 2]:
                season = "winter"
            elif current_month in [3, 4, 5]:
                season = "spring"
            elif current_month in [6, 7, 8]:
                season = "summer"
            else:
                season = "fall"

        filtered_anime = []
        current_page = 1
        total_pages = 1  # Will be updated after first request
        
        while True:
            url = f"https://api.jikan.moe/v4/seasons/{year}/{season}?page={current_page}"
            logger.info(f"Fetching page {current_page} from: {url}")
            
            try:
                response = requests.get(url)
                response.raise_for_status()
                data = response.json()
                
                if 'data' not in data:
                    break
                
                # Update total pages from pagination data
                pagination = data.get('pagination', {})
                total_pages = pagination.get('last_visible_page', 1)
                
                # Call progress callback if provided
                if progress_callback:
                    progress_callback(current_page, total_pages)
                
                # Process each anime entry
                anime_list = data['data']
                self.stats['total_fetched'] += len(anime_list)
                
                for anime in anime_list:
                    if self._filter_anime(anime):
                        processed_anime = self._extract_anime_data(anime)
                        filtered_anime.append(processed_anime)
                    else:
                        self.stats['filtered_out'] += 1
                
                # Check for more pages
                if not pagination.get('has_next_page', False):
                    break
                    
                current_page += 1
                time.sleep(1)  # Respect API rate limit
                
            except requests.RequestException as e:
                logger.error(f"Error fetching anime data: {str(e)}")
                break

        # Remove duplicates before returning
        unique_anime = self._remove_duplicates(filtered_anime)
                
        logger.info(f"""
        Scraping Statistics:
        - Season: {season.capitalize()} {year}
        - Total fetched: {self.stats['total_fetched']}
        - Passed filters: {len(filtered_anime)}
        - Duplicates removed: {self.stats['duplicates_removed']}
        - Final unique entries: {len(unique_anime)}
        - Filtered out: {self.stats['filtered_out']}
        * Low members: {self.stats['low_members_filtered']}
        * Chinese animation: {self.stats['chinese_filtered']}
        """)
        
        return unique_anime

if __name__ == "__main__":
    # Example usage
    logging.basicConfig(level=logging.INFO)
    scraper = JikanAnimeScraper(min_members=5000)
    anime_list = scraper.fetch_seasonal_anime()
    print(f"Found {len(anime_list)} anime after filtering")