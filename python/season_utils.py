### File: utils/season_utils.py
from datetime import datetime

def get_current_season():
    """Get the current anime season based on the current date."""
    current_date = datetime.now()
    month = current_date.month
    year = current_date.year
    
    if month in [1, 2, 3]:
        return "winter", year
    elif month in [4, 5, 6]:
        return "spring", year
    elif month in [7, 8, 9]:
        return "summer", year
    else:  # month in [10, 11, 12]
        return "fall", year