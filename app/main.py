from fastapi import FastAPI, HTTPException, Request
import requests
import os
import json
from datetime import datetime

# Create FastAPI app
app = FastAPI()

# Environment variables for security
UISP_API_BASE_URL = os.getenv("UISP_API_URL", "https://uisp.yourdomain.com/nms/api/v2.1")
API_KEY = os.getenv("UISP_API_KEY", "your-uisp-api-key")
APP_API_KEY = os.getenv("APP_API_KEY", "your-secure-app-key")

# Headers for UISP API requests
HEADERS = {
    "accept": "application/json",
    "content-type": "application/json",
    "x-auth-token": API_KEY
}

### 🔍 Helper Functions ###

def normalize_mac(mac):
    """Normalize MAC address by removing colons and converting to lowercase."""
    return mac.lower().replace(":", "")

def get_device_by_mac(mac_address):
    """Fetch the device details from UISP using the MAC address."""
    url = f"{UISP_API_BASE_URL}/devices"
    print(f"🔍 Fetching devices list from UISP API: {url}")

    try:
        response = requests.get(url, headers=HEADERS)
        if response.status_code != 200:
            print(f"❌ Failed to fetch devices: {response.status_code} - {response.text}")
            return None

        devices = response.json()
        normalized_mac = normalize_mac(mac_address)

        for device in devices:
            device_mac = device.get("identification", {}).get("mac", "")
            if normalize_mac(device_mac) == normalized_mac:
                device_id = device.get("identification", {}).get("id")
                device_name = device.get("identification", {}).get("name", "")
                device_hostname = device.get("identification", {}).get("hostname", "")

                # 🔥 Fix: Use hostname if name is missing
                if not device_name:
                    device_name = device_hostname if device_hostname else "Unknown"

                print(f"✅ Found device: ID {device_id}, Name {device_name}, MAC {device_mac}")
                return {"id": device_id, "name": device_name}

        print(f"❌ No device found with MAC: {mac_address}")
        return None

    except requests.RequestException as e:
        print(f"❌ Connection error when fetching devices: {e}")
        return None

def get_unms_settings(device_id):
    """Fetch the current UNMS system settings for a device."""
    get_url = f"{UISP_API_BASE_URL}/devices/{device_id}/system/unms"
    print(f"📡 Fetching current UNMS settings from: {get_url}")

    response = requests.get(get_url, headers=HEADERS)
    if response.status_code != 200:
        print(f"❌ Failed to fetch device settings: {response.status_code} - {response.text}")
        return None

    return response.json()

def update_unms_settings(device_id, updated_payload):
    """Send the updated UNMS system settings back to UISP."""
    put_url = f"{UISP_API_BASE_URL}/devices/{device_id}/system/unms"
    print(f"📦 Sending update request to: {put_url}")
    print(f"📦 Payload: {json.dumps(updated_payload, indent=2)}")

    put_response = requests.put(put_url, headers=HEADERS, json=updated_payload)

    print(f"📦 Response Status: {put_response.status_code}")
    print(f"📦 Response Body: {put_response.text}")

    if put_response.status_code != 200:
        print(f"❌ Failed to update device: {put_response.status_code} - {put_response.text}")
        return False

    return True


### 🌟 API Endpoints ###

@app.post("/init")
async def init_router(request: Request):
    """Initialize router by looking up MAC address and returning the APP_API_KEY."""
    body = await request.json()
    mac_address = body.get("macAddress")

    if not mac_address:
        raise HTTPException(status_code=400, detail="Missing required parameter: macAddress")

    device = get_device_by_mac(mac_address)

    if not device:
        raise HTTPException(status_code=404, detail=f"Device with MAC {mac_address} not found.")

    return {"message": "✅ Router initialized successfully!", "appApiKey": APP_API_KEY}

@app.post("/update-ip")
async def update_device_ip(request: Request):
    """Update the public IP in the UISP custom IP settings using MAC address."""
    body = await request.json()
    mac_address = body.get("macAddress")
    public_ip = body.get("publicIp")
    auth_key = request.headers.get("Authorization")

    # Validate API Key
    if not auth_key or auth_key != f"Bearer {APP_API_KEY}":
        print("❌ Invalid API Key provided")
        raise HTTPException(status_code=403, detail="Invalid API key")

    if not mac_address or not public_ip:
        print("❌ Missing required parameters in request")
        raise HTTPException(status_code=400, detail="Missing required parameters (macAddress, publicIp)")

    # Find the device details using MAC address
    device = get_device_by_mac(mac_address)
    if not device:
        print(f"❌ No device found for MAC {mac_address}")
        raise HTTPException(status_code=404, detail=f"Device with MAC {mac_address} not found.")

    device_id = device["id"]
    device_name = device["name"]  # Use this for the alias

    # Get current device settings
    current_settings = get_unms_settings(device_id)
    if not current_settings:
        raise HTTPException(status_code=500, detail="Failed to fetch current UNMS settings")

    print(f"📡 Current device settings: {json.dumps(current_settings, indent=2)}")

    # Generate the timestamp in UTC
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    last_updated_note = f"Public IP Last Updated: {timestamp}"

    # Ensure all required fields are present and replace `None` or `"null"` with default values
    def get_value(field, default):
        return default if field is None or field == "null" else field

    updated_payload = {
        "overrideGlobal": get_value(current_settings.get("overrideGlobal"), False),
        "devicePingAddress": get_value(current_settings.get("devicePingAddress"), "1.1.1.1"),
        "devicePingIntervalNormal": get_value(current_settings.get("devicePingIntervalNormal"), 300000),
        "devicePingIntervalOutage": get_value(current_settings.get("devicePingIntervalOutage"), 300000),
        "deviceTransmissionFrequency": get_value(current_settings.get("deviceTransmissionFrequency"), "minimal"),
        "deviceGracePeriodOutage": get_value(current_settings.get("deviceGracePeriodOutage"), 300000),
        "meta": {
            "alias": device_name,  # ✅ Fix: Now uses device name OR hostname
            "note": last_updated_note,  # ✅ Adds timestamp to the note field
            "maintenance": get_value(current_settings.get("meta", {}).get("maintenance"), False),
            "customIpAddress": public_ip  # ✅ Update only the IP
        }
    }

    # Send the update request
    if not update_unms_settings(device_id, updated_payload):
        raise HTTPException(status_code=500, detail="Failed to update UNMS settings")

    return {
        "message": "✅ Public IP updated successfully!",
        "deviceId": device_id,
        "macAddress": mac_address,
        "publicIp": public_ip,
        "lastUpdated": timestamp
    }