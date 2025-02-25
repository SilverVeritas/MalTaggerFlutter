# File: utils/state_utils.py

import streamlit as st
from utils.season_utils import get_current_season
from utils.rss_utils import initialize_fansubber_from_rss

def initialize_session_state():
    """Initialize all session state variables."""
    # Season and year
    if 'season' not in st.session_state:
        current_season, current_year = get_current_season()
        st.session_state.season = current_season
        st.session_state.year = current_year

    # Anime list and JSON state
    if 'anime_list' not in st.session_state:
        st.session_state.anime_list = None
    if 'edited_json' not in st.session_state:
        st.session_state.edited_json = None

    # Editing state
    if 'edited_values' not in st.session_state:
        st.session_state.edited_values = {}
    if 'fansubber_values' not in st.session_state:
        st.session_state.fansubber_values = {}
    if 'rss_validation_results' not in st.session_state:
        st.session_state.rss_validation_results = {}

def reset_session_state():
    """Reset all session state values to current season."""
    current_season, current_year = get_current_season()
    st.session_state.season = current_season
    st.session_state.year = current_year
    st.session_state.anime_list = None
    st.session_state.edited_json = None
    st.session_state.edited_values = {}
    st.session_state.fansubber_values = {}
    st.session_state.rss_validation_results = {}

def get_state_key(anime_title, field_type, index=0):
    """Generate a consistent state key based on anime title and field type."""
    return f"{index}_{anime_title}_{field_type}"

def initialize_entry_state(original_title, anime, index=0):
    """
    Initialize session state for an anime entry, including title, rss, fansubber.
    Now properly generates initial RSS URLs.
    """
    # Ensure we have the relevant dictionaries
    if 'edited_values' not in st.session_state:
        st.session_state.edited_values = {}
    if 'fansubber_values' not in st.session_state:
        st.session_state.fansubber_values = {}
    if 'manual_rss_edit' not in st.session_state:
        st.session_state.manual_rss_edit = {}

    # Generate the keys with index
    title_key = get_state_key(original_title, 'title', index)
    rss_key = get_state_key(original_title, 'rss', index)
    fansubber_key = get_state_key(original_title, 'fansubber', index)

    # Initialize edited title if needed
    if title_key not in st.session_state.edited_values:
        st.session_state.edited_values[title_key] = anime.get('title', original_title)

    # Initialize fansubber first
    if fansubber_key not in st.session_state.fansubber_values:
        if anime.get('rssUrl'):
            fansubber = initialize_fansubber_from_rss(anime['rssUrl'], fansubber_key)
        else:
            fansubber = anime.get('fansubber', 'ember')
        st.session_state.fansubber_values[fansubber_key] = fansubber

    # Initialize RSS URL - preserve existing or generate new
    if rss_key not in st.session_state.edited_values:
        rss_url = anime.get('rssUrl', '')
        if rss_url:
            st.session_state.edited_values[rss_key] = rss_url
            st.session_state.manual_rss_edit[original_title] = True
        else:
            # Generate new RSS URL using the title and default fansubber
            from utils.rss_utils import format_rss_url
            new_rss_url = format_rss_url(
                st.session_state.edited_values[title_key],
                st.session_state.fansubber_values[fansubber_key]
            )
            st.session_state.edited_values[rss_key] = new_rss_url
            st.session_state.manual_rss_edit[original_title] = False
