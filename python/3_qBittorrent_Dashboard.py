### File: pages/3_qBittorrent_Dashboard.py

import streamlit as st
import requests
import json
from datetime import datetime
import os
from dotenv import load_dotenv

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
    
    def get_app_version(self):
        """Get qBittorrent version"""
        url = f"{self.host}/api/v2/app/version"
        response = self.session.get(url)
        return response.text if response.ok else None

    def get_rss_feeds(self):
        """Get RSS feeds"""
        url = f"{self.host}/api/v2/rss/items"
        response = self.session.get(url)
        return response.json() if response.ok else {}
        
    def get_rss_rules(self):
        """Get RSS rules"""
        url = f"{self.host}/api/v2/rss/rules"
        response = self.session.get(url)
        return response.json() if response.ok else {}

def initialize_connection_state():
    """Initialize qBittorrent connection state"""
    if 'qb_connected' not in st.session_state:
        st.session_state.qb_connected = False
    if 'qb_client' not in st.session_state:
        st.session_state.qb_client = None
    if 'last_refresh' not in st.session_state:
        st.session_state.last_refresh = None

def render_connection_settings():
    """Render qBittorrent connection settings"""
    st.sidebar.header("Connection Settings")
    
    # Connection inputs with default values from .env
    host = st.sidebar.text_input("Host URL", value=QB_BASE_URL)
    username = st.sidebar.text_input("Username", value=QB_USER)
    password = st.sidebar.text_input("Password", value=QB_PASSWORD, type="password")
    
    # Create connect button
    if st.sidebar.button("Connect"):
        client = QBittorrentAPI(host, username, password)
        if client.login():
            version = client.get_app_version()
            if version:
                st.session_state.qb_connected = True
                st.session_state.qb_client = client
                st.sidebar.success(f"Connected to qBittorrent {version}")
            else:
                st.sidebar.error("Failed to get qBittorrent version")
        else:
            st.sidebar.error("Connection failed")

def render_rss_feeds(feeds):
    """Render RSS feeds table"""
    st.header("RSS Feeds")
    
    if not feeds:
        st.info("No RSS feeds found")
        return

    # Create a formatted table for feeds
    feed_data = []
    for url, feed in feeds.items():
        feed_data.append({
            "Feed Name": url.split('/')[-1],
            "URL": url,
            "Total Articles": len(feed.get('articles', [])),
            "Last Update": datetime.fromtimestamp(feed.get('lastBuildDate', 0)).strftime('%Y-%m-%d %H:%M:%S')
        })
    
    if feed_data:
        st.dataframe(feed_data)

def render_rss_rules(rules):
    """Render RSS rules table"""
    st.header("Download Rules")
    
    if not rules:
        st.info("No download rules found")
        return
    
    # Create a formatted table for rules
    rule_data = []
    for name, rule in rules.items():
        rule_data.append({
            "Rule Name": name,
            "Enabled": "✅" if rule.get('enabled', False) else "❌",
            "Must Contain": rule.get('mustContain', ''),
            "Save Path": rule.get('savePath', 'Default'),
            "Category": rule.get('assignedCategory', 'None')
        })
    
    if rule_data:
        st.dataframe(rule_data)

def main():
    st.title("qBittorrent Dashboard")
    initialize_connection_state()
    
    # Render connection settings in sidebar
    render_connection_settings()
    
    # Main dashboard area
    if st.session_state.qb_connected and st.session_state.qb_client:
        col1, col2, col3 = st.columns(3)
        
        # Add refresh button
        with col1:
            refresh = st.button("🔄 Refresh Data")
        
        # Show last refresh time
        with col2:
            if st.session_state.last_refresh:
                st.write(f"Last refreshed: {st.session_state.last_refresh.strftime('%H:%M:%S')}")
        
        # Fetch and display data
        if refresh or st.session_state.last_refresh is None:
            with st.spinner("Fetching data..."):
                client = st.session_state.qb_client
                feeds = client.get_rss_feeds()
                rules = client.get_rss_rules()
                
                if feeds is not None and rules is not None:
                    st.session_state.last_refresh = datetime.now()
                    render_rss_feeds(feeds)
                    st.markdown("---")
                    render_rss_rules(rules)
                else:
                    st.error("Failed to fetch data. Please check connection.")
    else:
        st.info("Please connect to qBittorrent using the sidebar settings")

if __name__ == "__main__":
    main()