### File: pages/2_Add_to_qBittorrent.py

import streamlit as st
import os
from dotenv import load_dotenv
import requests
from datetime import datetime
import json
import re
from utils.file_utils import get_saved_files, load_anime_list
from utils.season_utils import get_current_season
from utils.state_utils import initialize_session_state


# Load environment variables
load_dotenv()

# Default connection settings from .env
QB_BASE_URL = os.getenv('QB_BASE_URL', 'http://localhost:8080')
QB_USER = os.getenv('QB_USER', '')
QB_PASSWORD = os.getenv('QB_PASSWORD', '')

class QBittorrentAPI:
    def __init__(self, host, username, password):
        self.host = host
        self.username = username
        self.password = password
        self.session = requests.Session()
        self.sid = None
    
    def login(self):
        """Login to qBittorrent and get SID cookie"""
        try:
            url = f"{self.host}/api/v2/auth/login"
            data = {
                'username': self.username,
                'password': self.password
            }
            response = self.session.post(url, data=data)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            st.error(f"Login failed: {str(e)}")
            return False
    
    def add_rss_feed(self, url, feed_path):
        """Add RSS feed to qBittorrent"""
        try:
            api_url = f"{self.host}/api/v2/rss/addFeed"
            data = {
                'url': url,
                'path': feed_path
            }
            response = self.session.post(api_url, data=data)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            st.error(f"Failed to add RSS feed: {str(e)}")
            return False
    
    def add_rss_rule(self, rule_name, rule_def):
        """Add RSS auto-downloading rule"""
        try:
            api_url = f"{self.host}/api/v2/rss/setRule"
            data = {
                'ruleName': rule_name,
                'ruleDef': rule_def
            }
            response = self.session.post(api_url, data=data)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            st.error(f"Failed to add rule: {str(e)}")
            return False
        
def initialize_qb_session_state():
    """Initialize all necessary session state variables"""
    # Initialize base session state
    initialize_session_state()
    
    # Initialize qBittorrent specific state
    if 'qb_connected' not in st.session_state:
        st.session_state.qb_connected = False
    if 'qb_client' not in st.session_state:
        st.session_state.qb_client = None
    if 'processing_results' not in st.session_state:
        st.session_state.processing_results = {
            'successful': [],
            'failed': [],
            'unavailable': []
        }
    
    # Ensure season and year are set
    if 'season' not in st.session_state or 'year' not in st.session_state:
        current_season, current_year = get_current_season()
        st.session_state.season = current_season
        st.session_state.year = current_year

def initialize_connection_state():
    """Initialize qBittorrent connection state"""
    if 'qb_connected' not in st.session_state:
        st.session_state.qb_connected = False
    if 'qb_client' not in st.session_state:
        st.session_state.qb_client = None
    if 'processing_results' not in st.session_state:
        st.session_state.processing_results = {
            'successful': [],
            'failed': [],
            'unavailable': []
        }

def render_connection_settings():
    """Render qBittorrent connection settings"""
    st.sidebar.header("Connection Settings")
    
    # Connection inputs with default values from .env
    host = st.sidebar.text_input("Host URL", value=QB_BASE_URL)
    username = st.sidebar.text_input("Username", value=QB_USER)
    password = st.sidebar.text_input("Password", value=QB_PASSWORD, type="password")
    
    if st.sidebar.button("Connect"):
        client = QBittorrentAPI(host, username, password)
        if client.login():
            st.session_state.qb_connected = True
            st.session_state.qb_client = client
            st.sidebar.success("Connected to qBittorrent")
        else:
            st.sidebar.error("Connection failed")

def sanitize_filename(filename):
    """
    Sanitize filename to be valid across Windows, Linux, and macOS
    - Remove invalid characters
    - Preserve spaces
    - Handle reserved names in Windows
    - Limit length for compatibility
    """
    # Remove invalid characters but keep spaces
    # Replace invalid characters with a space
    sanitized = re.sub(r'[<>:"/\\|?*]', ' ', filename)
    
    # Replace multiple spaces with a single space
    sanitized = re.sub(r'\s+', ' ', sanitized)
    
    # Remove leading/trailing spaces and periods (problematic in Windows)
    sanitized = sanitized.strip(' .')
    
    # Handle Windows reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9)
    reserved_names = {'con', 'prn', 'aux', 'nul'} | {f'com{i}' for i in range(1, 10)} | {f'lpt{i}' for i in range(1, 10)}
    name_without_ext = os.path.splitext(sanitized)[0].lower()
    if name_without_ext in reserved_names:
        sanitized = f"_{sanitized}"
    
    # Limit length to 255 characters (common filesystem limit)
    if len(sanitized) > 255:
        base, ext = os.path.splitext(sanitized)
        sanitized = base[:255 - len(ext)] + ext
    
    return sanitized

def process_anime_list(client, anime_list):
    """Process anime list and add to qBittorrent"""
    results = {
        'successful': [],
        'failed': [],
        'unavailable': []
    }
    
    progress_bar = st.progress(0)
    status_text = st.empty()
    
    total_items = len(anime_list)
    for idx, anime in enumerate(anime_list, 1):
        progress = idx / total_items
        progress_bar.progress(progress)
        status_text.text(f"Processing: {anime['title']}")
        
        # Format feed path with season and year
        season = st.session_state.season.capitalize()
        year = st.session_state.year
        feed_path = f"{season}{year}/{anime['title']}"
        
        # Create sanitized download path
        sanitized_title = sanitize_filename(anime['title'])
        download_path = f"/dl/{sanitized_title}"
        
        # Create rule name with season and year prefix
        rule_name = f"{season}{year} {anime['title']}"
        
        # Add RSS feed
        if client.add_rss_feed(anime['rssUrl'], feed_path):
            # Create rule definition as a dictionary
            rule_def = {
                'enabled': True,
                'mustContain': '',  # Empty string for no content filtering
                'mustNotContain': '',
                'useRegex': False,
                'episodeFilter': '',
                'smartFilter': False,
                'previouslyMatchedEpisodes': [],
                'affectedFeeds': [anime['rssUrl']],
                'ignoreDays': 0,
                'lastMatch': '',
                'addPaused': False,
                'assignedCategory': 'anime',
                'savePath': download_path,
                'saveDifferentPath': True
            }
            
            # Convert rule definition to string properly
            rule_str = json.dumps(rule_def)
            
            # Add download rule with the new rule name format
            if client.add_rss_rule(rule_name, rule_str):
                results['successful'].append(anime)
            else:
                results['failed'].append(anime)
        else:
            results['unavailable'].append(anime)
    
    progress_bar.empty()
    status_text.empty()
    return results

def render_results(results):
    """Render processing results"""
    if results['successful']:
        st.success(f"Successfully added {len(results['successful'])} anime")
        with st.expander("Show successful"):
            for anime in results['successful']:
                st.write(f"✅ {anime['title']}")
    
    if results['failed']:
        st.error(f"Failed to add {len(results['failed'])} anime")
        with st.expander("Show failed"):
            for anime in results['failed']:
                st.write(f"❌ {anime['title']}")
    
    if results['unavailable']:
        st.warning(f"{len(results['unavailable'])} anime had unavailable RSS feeds")
        with st.expander("Show unavailable"):
            for anime in results['unavailable']:
                st.write(f"⚠️ {anime['title']}")

def main():
    st.title("Add Anime to qBittorrent")
    
    # Initialize session state first
    initialize_qb_session_state()
    
    # Render connection settings in sidebar
    render_connection_settings()
    
    # Main content area
    saved_files = get_saved_files()
    
    if not saved_files:
        st.info("No saved anime lists found. Please create one in the Anime Scraper page first.")
        return
    
    # List selection
    selected_file = st.selectbox(
        "Select saved list",
        saved_files,
        format_func=lambda x: x.replace("anime_list_", "").replace(".json", "").replace("_", " ")
    )
    
    if st.session_state.qb_connected and st.session_state.qb_client:
        if st.button("Process Selected List"):
            # Load anime list
            anime_list = load_anime_list(selected_file)
            
            if anime_list:
                with st.spinner("Processing anime list..."):
                    # Process the list
                    results = process_anime_list(st.session_state.qb_client, anime_list)
                    st.session_state.processing_results = results
                    
                # Show results
                render_results(results)
            else:
                st.error("Failed to load anime list")
    else:
        st.info("Please connect to qBittorrent using the sidebar settings")

if __name__ == "__main__":
    main()