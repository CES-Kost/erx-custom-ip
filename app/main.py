from fastapi import FastAPI, HTTPException, Request, Header
import requests
import os
import json

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

def normalize_mac(mac):
    """Normalize MAC address by removing colons and converting to lowercase."""
    return mac.lower().replace(":", "")

def get_device_id_by_mac(mac_address):
    """Fetch the device ID from UISP using the MAC address."""
    url = f"{UISP_API_BASE_URL}/devices"
    print(f"🔍 Fetching devices list from UISP API: {url}")

    try:
        response = requests.get(url, headers=HEADERS)

        if response.status_code != 200:
            print(f"❌ Failed to fetch devices: {response.status_code} - {response.text}")
            raise HTTPException(status_code=response.status_code, detail=f"Failed to fetch devices: {response.text}")

        try:
            devices = response.json()
        except json.decoder.JSONDecodeError:
            print("❌ UISP API returned an invalid JSON response!")
            raise HTTPException(status_code=500, detail="UISP API returned an invalid JSON response.")

        normalized_mac = normalize_mac(mac_address)  # Normalize the MAC address
        print(f"🔍 Looking for MAC: {normalized_mac} in device list...")

        # Match MAC address ignoring case and colons
        for device in devices:
            device_mac = device.get("identification", {}).get("mac", "")
            if normalize_mac(device_mac) == normalized_mac:
                print(f"✅ Found device with MAC {mac_address}: Device ID {device.get('identification', {}).get('id')}")
                return device.get("identification", {}).get("id")

        print(f"❌ No device found with MAC: {mac_address}")
        return None  # Return None if no match is found

    except requests.RequestException as e:
        print(f"❌ Connection error when fetching devices: {e}")
        raise HTTPException(status_code=500, detail="UISP API connection error.")

@app.post("/update-ip")
async def update_device_ip(request: Request, authorization: str = Header(None)):
    """Update the public IP in the UISP custom IP settings using MAC address."""
    
    # Validate API Key
    if authorization != f"Bearer {APP_API_KEY}":
        raise HTTPException(status_code=403, detail="Invalid API key")

    # Get request JSON
    body = await request.json()
    mac_address = body.get("macAddress")
    public_ip = body.get("publicIp")

    if not mac_address or not public_ip:
        raise HTTPException(status_code=400, detail="Missing required parameters (macAddress, publicIp)")

    # Find the device ID using MAC address
    device_id = get_device_id_by_mac(mac_address)
    if not device_id:
        raise HTTPException(status_code=404, detail=f"Device with MAC {mac_address} not found.")

    # Get current device settings
    get_url = f"{UISP_API_BASE_URL}/devices/{device_id}/system/unms"
    response = requests.get(get_url, headers=HEADERS)

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail=f"Failed to fetch device settings: {response.text}")

    current_settings = response.json()

    # Helper function to replace None or "null" with a default value
    def get_value(field, default):
        return default if field is None or field == "null" else field

    # Ensure all required fields are present and replace `None` or `"null"` with default values
    updated_payload = {
        "overrideGlobal": get_value(current_settings.get("overrideGlobal"), False),
        "devicePingAddress": get_value(current_settings.get("devicePingAddress"), "1.1.1.1"),
        "devicePingIntervalNormal": get_value(current_settings.get("devicePingIntervalNormal"), 300000),
        "devicePingIntervalOutage": get_value(current_settings.get("devicePingIntervalOutage"), 300000),
        "deviceTransmissionFrequency": get_value(current_settings.get("deviceTransmissionFrequency"), "minimal"),
        "deviceGracePeriodOutage": get_value(current_settings.get("deviceGracePeriodOutage"), 300000),
        "meta": {
            "alias": get_value(current_settings.get("meta", {}).get("alias"), ""),
            "note": get_value(current_settings.get("meta", {}).get("note"), ""),
            "maintenance": get_value(current_settings.get("meta", {}).get("maintenance"), False),
            "customIpAddress": public_ip  # ✅ Update only the IP
        }
    }

    print(f"📦 Sending update request to: {put_url}")
    print(f"📦 Payload: {json.dumps(updated_payload, indent=2)}")

    # Send update request
    put_url = f"{UISP_API_BASE_URL}/devices/{device_id}/system/unms"
    put_response = requests.put(put_url, headers=HEADERS, json=updated_payload)

    print(f"📦 Response Status: {put_response.status_code}")
    print(f"📦 Response Body: {put_response.text}")

    if put_response.status_code != 200:
        raise HTTPException(status_code=put_response.status_code, detail=f"Failed to update device: {put_response.text}")

    return {
        "message": "✅ Public IP updated successfully!",
        "deviceId": device_id,
        "macAddress": mac_address,
        "publicIp": public_ip
    }