# 🌐 Payout Internal Tool (Web Version)

A **web-based automation tool** that streamlines **payout sandbox integration testing** and **sandbox environment monitoring**.  
It automates **transaction status updates**, **webhook notifications**, and **sandbox health checks** — reducing manual effort by **95%+**.

Hosted at: 👉 [https://payout-tool.web.app/](https://payout-tool.web.app/)

---

## 🌐 Deploy Web Changes (Firebase Hosting)
When you change the Flutter web UI (for example, adding/updating internal HTML tools embedded in the app), deploy the updated static site to the existing Firebase Hosting target `payout-tool`.

### Prerequisites
- You have the Flutter SDK installed.
- You have Firebase CLI installed and are logged in: `firebase login`

### Steps
From the repo root:
```bash
cd /Users/nelson/Development/payout-internal-tool

# Build latest Flutter web assets
cd payout_internal_tool
flutter build web --release

# Deploy ONLY hosting (no backend/functions changes)
cd ..
firebase deploy --only hosting:payout-tool
```

### Notes
- Firebase Hosting is configured to serve from `payout_internal_tool/build/web`.
- If you add standalone HTML/JS assets under `payout_internal_tool/web/`, the Flutter web build will copy them into `build/web/` (so they become available to the app via iframe/import).

## 🚀 Key Features

### 1️⃣ Sandbox Update

#### ⏳ Before (Manual Process)
- 10+ manual steps across Excel, SQL, and email.  
- Required Development and Support involvement.  
- Time: **~2 hours**.  

#### ⚡ Now (Web Automation)
- User performs **1 simple step** (fill in required info).  
- The tool automatically:  
  1. Updates transaction status.  
  2. Sends webhook notifications.  
  3. Generates payout report.  
  4. Encrypts files (if needed).  
  5. Sends report via email.  

⏱️ Time: **~2 minutes**  

✅ Benefits:  
- **Internal** → Saves Engineering, Support, and Compliance hours.  
- **External** → Faster partner onboarding & testing.  

---

### 2️⃣ Sandbox Monitoring

#### 📖 Background
Previously, to monitor if **Payin Sandbox** was up or down:  
- Manually triggered Postman requests to check if endpoints returned errors.  
- If successful, copied the transaction ID and tested if the **payment page** would load.  
- This process was repeated for every channel and was highly inefficient.  

#### ⚡ Now (Web Dashboard + Auto Monitoring)
- Once the page is opened, the system **automatically triggers all sandbox requests**.  
- Results are displayed as a **metric dashboard view** (success/fail per channel).  
- The sandbox **payment page is auto-loaded in an iframe**, linked to the returned transaction ID.  
- **Automated Scheduled Checks** → The system checks sandbox environments **2 times a day (09:00 & 13:00 SGT)**.  
- **Email Alerts** → If errors are detected, an **alert email** is sent to recipients immediately.  

⏱️ Effort reduced by **~95%**  

✅ Benefits:  
- **Internal** → Instant visibility into sandbox health, proactive alerts without Postman.  
- **External** → Ensures smoother testing and faster troubleshooting.  

---

## 🌐 Why Web Version?
- 🚫 **No setup required** — just open in browser.  
- 🎨 **Clean UI/UX** — guided flow and real-time dashboard.  
- ⚡ **Faster execution** — optimized backend.  
- 🧹 **Refactored codebase** — modular and maintainable.  

---

## 🧑‍💻 Tech Stack
- **Frontend:** HTML / CSS / JavaScript  
- **Backend:** Python (Flask/FastAPI)  
- **Automation:** Webhook send, Report generation, Sandbox monitoring, Email dispatch  
- **Security:** JWT & HMAC signing for API calls  
- **Hosting:** Firebase  

---

## 📸 Screenshots

<div align="center">
  <img width="45%" alt="Sandbox Update" src="https://github.com/user-attachments/assets/751eaa24-54ba-4d3b-a3f5-1e7724db614a" />
  <img width="45%" alt="Sandbox Monitoring" src="https://github.com/user-attachments/assets/0239dcf5-03d9-45be-9568-3a0bf8407efb" />
  <img width="1915" height="959" alt="image" src="https://github.com/user-attachments/assets/c7978b38-22a4-4e6c-b3dc-fb531c90d485" />

</div>

---

## ⚡ Setup & Usage

```bash
# Clone repo
git clone https://github.com/nelsonwong5079/payout-internal-tool.git
cd payout-internal-tool

# Install dependencies
pip install -r requirements.txt

# Run server
python app.py

# Open in browser
http://localhost:5000
````

Fill in the required input → the tool automates the rest.
Or directly access the hosted version: [https://payout-tool.web.app/](https://payout-tool.web.app/)

---


## 📊 Impact

* Reduced payout sandbox handling from **2 hours → 2 minutes**.
* Reduced sandbox monitoring effort by **95%**.
* Eliminated dependency on manual Postman requests.
* Improved speed, visibility, and reliability of integration testing.
* Proactive **alerting system** ensures issues are detected early before partners are affected.

---

## 👤 Author

Developed end-to-end by **Nelson Wong** as a one-man initiative to improve internal efficiency and scalability.
