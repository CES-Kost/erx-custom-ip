UISP Public IP Updater API

🚀 A lightweight FastAPI service to securely update EdgeRouter Public IP settings in UISP without exposing API keys.

🛠 Features

Secure API authentication with APP_API_KEY

MAC address lookup to match UISP devices dynamically

Automatic public IP updates via API (no keys on routers)

Lightweight & Dockerized for easy deployment

⚡ Setup Instructions

1️⃣ Clone the Repository

git clone https://github.com/YOUR_GITHUB/uisp-ip-updater.git
cd uisp-ip-updater

2️⃣ Create a .env File

touch .env

Then add your UISP API key and secure app key:

UISP_API_URL=https://uisp.yourdomain.com/nms/api/v2.1
UISP_API_KEY=your-uisp-api-key
APP_API_KEY=your-secure-app-key

3️⃣ Build & Start the API

docker-compose up -d --build

🎯 The API will now be running at http://localhost:8000.

🌎 Usage

The EdgeRouter script will send a request to update the public IP based on the MAC address.

📡 Update Public IP

POST /update-ip

✅ Request Body

{
  "macAddress": "b4:fb:e4:24:b7:04",
  "publicIp": "203.0.113.45"
}

🔐 Required Headers

Authorization: Bearer your-secure-app-key

✅ Success Response

{
  "message": "✅ Public IP updated successfully!",
  "deviceId": "0165a0ad-adda-45e2-9116-36d41f777d3b",
  "macAddress": "b4:fb:e4:24:b7:04",
  "publicIp": "203.0.113.45"
}

🔧 EdgeRouter Setup

To configure EdgeRouters to send updates:

SSH into EdgeRouter

ssh admin@your-router-ip

Run the installer script

curl -sL https://raw.githubusercontent.com/YOUR_GITHUB/uisp-ip-updater/main/erx-set-custom-ip.sh | bash -s install

It will prompt for the API URL & Key.

Verify it’s working

sudo /config/scripts/update_custom_ip.sh update

✅ Now, the router will send updates every 3 hours via cron.

📦 Docker Management

Rebuild and restart API

docker-compose up -d --build

Stop API

docker-compose down

Check logs

docker-compose logs -f

🛠 Troubleshooting

1️⃣ Public IP not updating?

Check router logs:

tail -f /var/log/update_custom_ip.log

Check API logs:

docker-compose logs -f

2️⃣ Not finding device in UISP?

Verify the MAC address matches what's shown in UISP.

🤝 Contributing

Pull requests are welcome! If you'd like to suggest improvements, feel free to open an issue.

📜 License

MIT License © 2025 CuttingEdgeSys