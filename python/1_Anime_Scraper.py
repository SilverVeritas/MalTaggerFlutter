# File: pages/1_Anime_Scraper.py


import streamlit as st
from anime_scraper import JikanAnimeScraper
import time
import logging
import sys
from datetime import datetime

# Logging setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)
stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setLevel(logging.INFO)
formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
stream_handler.setFormatter(formatter)
logger.addHandler(stream_handler)

# Import the relevant components
from components.anime_list.list_components import render_rss_validation_controls
from components.anime_list.anime_item import render_anime_item
from components.anime_list.json_editor import render_json_editor
from utils.state_utils import initialize_session_state, reset_session_state
from utils.data_utils import get_updated_anime_list
from utils.file_utils import (
    sort_anime_list, 
    get_saved_files, 
    load_anime_list,
    save_anime_list
)

def render_sidebar():
    """Render the sidebar components (season/year/member threshold)."""
    st.sidebar.header("Options")

    min_members = st.sidebar.number_input(
        "Minimum MAL Members",
        min_value=0,
        max_value=100000,
        value=5000,
        step=1000,
        help="Filter anime by minimum number of MyAnimeList members"
    )

    season = st.sidebar.selectbox(
        "Select Season",
        ["winter", "spring", "summer", "fall"],
        index=["winter", "spring", "summer", "fall"].index(st.session_state.season),
        key='season_select'
    )
    
    year = st.sidebar.number_input(
        "Select Year",
        min_value=1950,
        max_value=2050,
        value=st.session_state.year,
        key='year_input'
    )

    if st.sidebar.button("Reset to Current Date"):
        reset_session_state()
        st.sidebar.success(f"Reset to: {st.session_state.season.capitalize()} {st.session_state.year}")
        st.rerun()

    return season, year, min_members

def render_load_controls():
    """Render load controls with dynamic file list."""
    saved_files = get_saved_files()
    
    if not saved_files:
        st.info("No saved lists found")
        return
    
    col1, col2 = st.columns([3, 1])
    with col1:
        selected_file = st.selectbox(
            "Select saved list",
            saved_files,
            format_func=lambda x: x.replace("anime_list_", "").replace(".json", "").replace("_", " "),
            key="load_select"
        )
    
    with col2:
        if st.button("Load List", use_container_width=True, key="load_btn"):
            try:
                loaded_list = load_anime_list(selected_file)
                st.session_state.anime_list = loaded_list
                st.session_state.edited_values = {}
                st.session_state.fansubber_values = {}
                st.session_state.manual_rss_edit = {}
                st.success(f"Successfully loaded {selected_file}")
                st.rerun()
            except Exception as e:
                st.error(f"Error loading file: {str(e)}")

def render_sort_controls():
    """Render sorting controls for the anime list."""
    st.markdown("##### Sort Options")
    sort_by = st.selectbox(
        "Sort by",
        ["original", "date", "date_reverse", "alpha", "alpha_reverse", "members_high", "members_low"],
        format_func=lambda x: {
            "original": "Original Order",
            "date": "Date ↑",
            "date_reverse": "Date ↓",
            "alpha": "Alphabetical ↑",
            "alpha_reverse": "Alphabetical ↓",
            "members_high": "Members ↓",
            "members_low": "Members ↑"
        }[x]
    )
    return sort_by

def render_anime_list(anime_list):
    """Render the complete anime list."""
    # Detect duplicate titles
    titles = [anime['title'] for anime in anime_list]
    duplicates = [title for title in set(titles) if titles.count(title) > 1]
    if duplicates:
        st.warning(f"Duplicate titles detected: {', '.join(duplicates)}")

    sort_by = render_sort_controls()
    if sort_by != "original":
        anime_list = sort_anime_list(anime_list, sort_by)

    # Add a save button at the top
    if st.button("Save List to File", key="save_top", use_container_width=True):
        try:
            updated_anime = get_updated_anime_list(anime_list)
            filename = save_anime_list(updated_anime, st.session_state.season, st.session_state.year)
            if filename:
                st.success(f"Successfully saved to {filename}")
            else:
                st.error("Failed to save file")
        except Exception as e:
            st.error(f"Error saving file: {str(e)}")

    # Render anime items
    for idx, anime in enumerate(anime_list):
        render_anime_item(anime, index=idx)

    # Bottom save button
    if st.button("Save List to File", key="save_bottom", use_container_width=True):
        try:
            updated_anime = get_updated_anime_list(anime_list)
            filename = save_anime_list(updated_anime, st.session_state.season, st.session_state.year)
            if filename:
                st.success(f"Successfully saved to {filename}")
            else:
                st.error("Failed to save file")
        except Exception as e:
            st.error(f"Error saving file: {str(e)}")

def main():
    st.title("Anime Scraper")
    st.write("Fetch seasonal anime details with advanced features for editing and validation.")

    # Initialize session state
    initialize_session_state()

    # Sidebar for season/year/threshold
    season, year, min_members = render_sidebar()

    col1, col2 = st.columns(2)
    
    with col1:
        # Fetch section
        fetch_clicked = st.button("🔄 Fetch Anime List", key="fetch_button", use_container_width=True, type="primary")
    
    with col2:
        # Load section
        render_load_controls()

    # Toggle to show JSON editor
    show_json = st.checkbox("Show JSON Editor", key="json_toggle")
    
    st.markdown("---")

    if fetch_clicked:
        logger.info(f"Fetching anime for Season: {season} | Year: {year} | Min Members: {min_members}")
        
        # Create progress elements
        progress_bar = st.progress(0)
        status_text = st.empty()
        
        def update_progress(current_page, total_pages):
            progress = (current_page - 1) / total_pages
            progress_bar.progress(progress)
            status_text.write(f"Fetching page {current_page} of {total_pages}")
        
        # Initialize scraper with progress
        scraper = JikanAnimeScraper(min_members=min_members)
        st.session_state.anime_list = scraper.fetch_seasonal_anime(
            season, year, progress_callback=update_progress
        )
        
        # Clean up progress elements
        progress_bar.empty()
        status_text.empty()
        
        # Reset state
        st.session_state.edited_json = None
        st.session_state.edited_values = {}
        st.session_state.rss_validation_results = {}
        
        # Log count only when fetching new data
        if st.session_state.anime_list:
            logger.info(f"Found {len(st.session_state.anime_list)} anime entries.")

    if st.session_state.anime_list:
        anime_list = st.session_state.anime_list
        
        # Only show these messages, don't log them
        st.success(f"### {season.capitalize()} {year} Anime")
        st.write(f"Found {len(anime_list)} anime.")

        # RSS Validation Controls
        render_rss_validation_controls(anime_list)

        # Show either JSON editor or anime list
        if show_json:
            if not st.session_state.get('last_view') == 'json':
                st.session_state.edited_json = None
            st.session_state.last_view = 'json'
            updated_list = render_json_editor(anime_list)
            if updated_list:
                st.session_state.anime_list = updated_list
        else:
            st.session_state.last_view = 'list'
            render_anime_list(anime_list)
    else:
        if fetch_clicked:
            st.warning("No anime found for the selected season.")
            logger.warning(f"No anime found for {season} {year}")

if __name__ == "__main__":
    main()