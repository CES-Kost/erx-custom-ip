from fastapi import FastAPI, HTTPException, Request, Header
import requests
import os

# Create FastAPI app
app = FastAPI()

# Environment variables for security
UISP_API_BASE_URL = os.getenv("UISP_API_URL", "https://uisp.yourdomain.com/nms/api/v2.1")
API_KEY = os.getenv("UISP_API_KEY", "your-api-key")
APP_API_KEY = os.getenv("APP_API_KEY", "your-secure-app-key")

# Headers for UISP API requests
HEADERS = {
    "accept": "application/json",
    "content-type": "application/json",
    "x-auth-token": API_KEY
}

@app.post("/update-ip")
async def update_device_ip(request: Request, authorization: str = Header(None)):
    """Update the public IP in the UISP custom IP settings."""
    
    # Validate API Key
    if authorization != f"Bearer {APP_API_KEY}":
        raise HTTPException(status_code=403, detail="Invalid API key")

    # Get request JSON
    body = await request.json()
    device_id = body.get("deviceId")
    public_ip = body.get("publicIp")

    if not device_id or not public_ip:
        raise HTTPException(status_code=400, detail="Missing required parameters (deviceId, publicIp)")

    # Get current device settings
    get_url = f"{UISP_API_BASE_URL}/devices/{device_id}/system/unms"
    response = requests.get(get_url, headers=HEADERS)

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail=f"Failed to fetch device settings: {response.text}")

    current_settings = response.json()

    # Prepare updated payload
    updated_payload = {
        "overrideGlobal": True,
        "devicePingAddress": current_settings.get("devicePingAddress", "1.1.1.1"),  # Default or keep existing
        "devicePingIntervalNormal": current_settings.get("devicePingIntervalNormal", 300000),
        "devicePingIntervalOutage": current_settings.get("devicePingIntervalOutage", 300000),
        "deviceTransmissionFrequency": current_settings.get("deviceTransmissionFrequency", "minimal"),
        "deviceGracePeriodOutage": current_settings.get("deviceGracePeriodOutage", 300000),
        "meta": {
            "alias": current_settings.get("meta", {}).get("alias", ""),
            "note": current_settings.get("meta", {}).get("note", ""),
            "maintenance": current_settings.get("meta", {}).get("maintenance", False),
            "customIpAddress": public_ip  # ✅ Set new public IP
        }
    }

    # Send update request
    put_url = f"{UISP_API_BASE_URL}/devices/{device_id}/system/unms"
    put_response = requests.put(put_url, headers=HEADERS, json=updated_payload)

    if put_response.status_code != 200:
        raise HTTPException(status_code=put_response.status_code, detail=f"Failed to update device: {put_response.text}")

    return {"message": "✅ Public IP updated successfully!", "deviceId": device_id, "publicIp": public_ip}
