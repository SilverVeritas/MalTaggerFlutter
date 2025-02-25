# File: utils/data_utils.py

import os
from datetime import datetime
import json
import streamlit as st
from .state_utils import get_state_key

def get_updated_anime_list(anime_list):
    """Get the current state of the anime list with all edits.
    
    Args:
        anime_list (list): List of anime dictionaries to update
        
    Returns:
        list: Updated anime list with current edits from session state
    """
    updated_anime = []
    for idx, anime in enumerate(anime_list):
        original_title = anime['title']
        title_key = get_state_key(original_title, 'title', idx)  # Added index
        rss_key = get_state_key(original_title, 'rss', idx)      # Added index
        fansubber_key = get_state_key(original_title, 'fansubber', idx)  # Added index
        
        # Get values with fallbacks
        updated_title = st.session_state.edited_values.get(title_key, original_title)
        updated_rss = st.session_state.edited_values.get(rss_key, anime.get('rssUrl', ''))
        updated_fansubber = st.session_state.fansubber_values.get(fansubber_key, 'ember')
        
        updated_anime.append({
            **anime,  # Keep all original fields
            'title': updated_title,
            'rssUrl': updated_rss,
            'fansubber': updated_fansubber
        })
    return updated_anime