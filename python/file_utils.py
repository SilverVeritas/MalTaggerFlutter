# File: utils/file_utils.py

import streamlit as st
import os
import json
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

def get_save_directory():
    """Get or create the directory for saved anime lists."""
    save_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'saved_lists')
    os.makedirs(save_dir, exist_ok=True)
    return save_dir

def format_filename(season, year):
    """Format filename with season, year, and timestamp."""
    current_time = datetime.now()
    timestamp = current_time.strftime("%Y%m%d_%H%M%S")
    return f"anime_list_{season.lower()}_{year}_{timestamp}.json"

def save_anime_list(anime_list, season, year):
    """Save anime list to a JSON file with formatted filename."""
    try:
        save_dir = get_save_directory()
        filename = format_filename(season, year)
        filepath = os.path.join(save_dir, filename)
        
        # Get updated state before saving
        from utils.data_utils import get_updated_anime_list
        
        # Ensure anime_list is not None and not empty
        if not anime_list:
            logger.error("No anime list to save")
            raise ValueError("No anime list to save")
            
        updated_list = get_updated_anime_list(anime_list)
        
        # Validate the updated list before saving
        if not updated_list:
            logger.error("Updated list is empty")
            raise ValueError("Updated list is empty")
            
        # Log some debugging info
        logger.info(f"Saving {len(updated_list)} anime entries")
        logger.info(f"First anime title: {updated_list[0].get('title', 'NO TITLE')}")
        
        # Ensure all required fields are present
        for anime in updated_list:
            if not anime.get('title'):
                logger.error(f"Missing title in anime entry: {anime}")
                continue
                
            # Ensure required fields with defaults
            if 'rssUrl' not in anime:
                anime['rssUrl'] = ''
            if 'fansubber' not in anime:
                anime['fansubber'] = 'ember'
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(updated_list, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Successfully saved anime list to {filename}")
        return filename
    
    except Exception as e:
        logger.error(f"Error saving anime list: {str(e)}")
        # Log additional debug information
        logger.error(f"Session state keys: {st.session_state.keys()}")
        if 'edited_values' in st.session_state:
            logger.error(f"Edited values keys: {st.session_state.edited_values.keys()}")
        raise

def load_anime_list(filename):
    """Load anime list from a JSON file."""
    try:
        filepath = os.path.join(get_save_directory(), filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Error loading anime list: {str(e)}")
        raise

def get_saved_files():
    """Get list of saved anime list files."""
    try:
        save_dir = get_save_directory()
        files = [f for f in os.listdir(save_dir) if f.endswith('.json')]
        return sorted(files, reverse=True)  # Most recent first
    except Exception as e:
        logger.error(f"Error getting saved files: {str(e)}")
        return []

def sort_anime_list(anime_list, sort_by):
    """Sort anime list based on specified criteria."""
    if sort_by == "date":
        return sorted(anime_list, key=lambda x: x.get('date', ''))
    elif sort_by == "date_reverse":
        return sorted(anime_list, key=lambda x: x.get('date', ''), reverse=True)
    elif sort_by == "alpha":
        return sorted(anime_list, key=lambda x: x.get('title', '').lower())
    elif sort_by == "alpha_reverse":
        return sorted(anime_list, key=lambda x: x.get('title', '').lower(), reverse=True)
    elif sort_by == "members_high":
        return sorted(anime_list, key=lambda x: x.get('members', 0), reverse=True)
    elif sort_by == "members_low":
        return sorted(anime_list, key=lambda x: x.get('members', 0))
    return anime_list