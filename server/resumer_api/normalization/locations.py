from __future__ import annotations

import re

# Complete official list of Indian States and Union Territories (all 36)
INDIAN_STATES_AND_UTS: tuple[str, ...] = (
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
    # Union Territories
    "Delhi",
    "Jammu & Kashmir",
    "Ladakh",
    "Puducherry",
    "Chandigarh",
    "Andaman & Nicobar Islands",
    "Dadra and Nagar Haveli and Daman and Diu",
    "Lakshadweep",
)

# Major cities mapped to their respective state
MAJOR_INDIAN_CITIES: dict[str, str] = {
    # Karnataka
    "bengaluru": "Karnataka",
    "bangalore": "Karnataka",
    "mysuru": "Karnataka",
    "mysore": "Karnataka",
    "hubballi": "Karnataka",
    "mangalore": "Karnataka",

    # Telangana
    "hyderabad": "Telangana",
    "secunderabad": "Telangana",
    "warangal": "Telangana",

    # Maharashtra
    "mumbai": "Maharashtra",
    "pune": "Maharashtra",
    "nagpur": "Maharashtra",
    "navi mumbai": "Maharashtra",
    "thane": "Maharashtra",
    "nashik": "Maharashtra",

    # Delhi NCR
    "delhi": "Delhi",
    "new delhi": "Delhi",
    "noida": "Uttar Pradesh",
    "greater noida": "Uttar Pradesh",
    "gurugram": "Haryana",
    "gurgaon": "Haryana",
    "faridabad": "Haryana",
    "ghaziabad": "Uttar Pradesh",

    # Tamil Nadu
    "chennai": "Tamil Nadu",
    "coimbatore": "Tamil Nadu",
    "madurai": "Tamil Nadu",
    "tiruchirappalli": "Tamil Nadu",

    # West Bengal
    "kolkata": "West Bengal",
    "howrah": "West Bengal",
    "siliguri": "West Bengal",

    # Gujarat
    "ahmedabad": "Gujarat",
    "gandhinagar": "Gujarat",
    "surat": "Gujarat",
    "vadodara": "Gujarat",
    "rajkot": "Gujarat",

    # Kerala
    "kochi": "Kerala",
    "cochin": "Kerala",
    "thiruvananthapuram": "Kerala",
    "trivandrum": "Kerala",
    "kozhikode": "Kerala",

    # Andhra Pradesh
    "visakhapatnam": "Andhra Pradesh",
    "vizag": "Andhra Pradesh",
    "vijayawada": "Andhra Pradesh",
    "guntur": "Andhra Pradesh",
    "tirupati": "Andhra Pradesh",

    # Rajasthan
    "jaipur": "Rajasthan",
    "jodhpur": "Rajasthan",
    "udaipur": "Rajasthan",

    # Madhya Pradesh
    "indore": "Madhya Pradesh",
    "bhopal": "Madhya Pradesh",
    "gwalior": "Madhya Pradesh",

    # Punjab / Chandigarh
    "chandigarh": "Chandigarh",
    "mohali": "Punjab",
    "ludhiana": "Punjab",
    "amritsar": "Punjab",

    # Odisha
    "bhubaneswar": "Odisha",
    "cuttack": "Odisha",

    # Bihar & Jharkhand
    "patna": "Bihar",
    "ranchi": "Jharkhand",
    "jamshedpur": "Jharkhand",

    # Uttar Pradesh
    "lucknow": "Uttar Pradesh",
    "kanpur": "Uttar Pradesh",
    "varanasi": "Uttar Pradesh",
    "agra": "Uttar Pradesh",
}


def detect_state_and_city(location_str: str | None) -> tuple[str | None, str | None, str]:
    """Parses a location string into (state, city, work_mode)."""
    if not location_str or not location_str.strip():
        return None, None, "On-site"

    loc_lower = location_str.lower().strip()

    # Detect work mode
    if "remote" in loc_lower or "anywhere" in loc_lower:
        work_mode = "Remote"
    elif "hybrid" in loc_lower:
        work_mode = "Hybrid"
    else:
        work_mode = "On-site"

    detected_city: str | None = None
    detected_state: str | None = None

    # Check known cities
    for city_key, state_val in MAJOR_INDIAN_CITIES.items():
        if re.search(r"\b" + re.escape(city_key) + r"\b", loc_lower):
            detected_city = city_key.title()
            detected_state = state_val
            break

    # Check known states directly if state not yet found
    if not detected_state:
        for state in INDIAN_STATES_AND_UTS:
            if state.lower() in loc_lower:
                detected_state = state
                break

    return detected_state, detected_city, work_mode
