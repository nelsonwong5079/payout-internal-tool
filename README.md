# 🌐 Payout Internal Tool (Web Version)

A **web-based automation tool** that streamlines **payout sandbox integration testing**.
It automates **transaction status updates** and **webhook notifications**, reducing the process from **\~2 hours to just 2 minutes**.

---

## 🚀 Key Feature: Sandbox Update

### ⏳ Before (Manual Process)

* 10+ manual steps across Excel, SQL, and email.
* Required Development and Support involvement.
* Time: **\~2 hours**.

### ⚡ Now (Web Automation)

* User performs **1 simple step** (fill in required info).
* The tool automatically:

  1. Updates transaction status.
  2. Sends webhook notifications.
  3. Generates payout report.
  4. Encrypts files (if needed).
  5. Sends report via email.

⏱️ Time: **\~2 minutes**

✅ Benefits:

* **Internal** → Saves Engineering, Support, and Compliance hours.
* **External** → Faster partner onboarding & testing.

---

## 🌐 Why Web Version?

* 🚫 **No setup required** — just open in browser.
* 🎨 **Clean UI/UX** — guided flow for ease of use.
* ⚡ **Faster execution** — optimized backend.
* 🧹 **Refactored codebase** — modular and maintainable.

---

## 🧑‍💻 Tech Stack

* **Frontend**: HTML / CSS / JavaScript
* **Backend**: Python (Flask/FastAPI)
* **Automation**: Webhook send, Report generation, Email dispatch
* **Security**: JWT & HMAC signing for API calls

---

## 📸 Screenshots

 <img width="1917" height="958" alt="image" src="https://github.com/user-attachments/assets/751eaa24-54ba-4d3b-a3f5-1e7724db614a" />
<img width="358" height="575" alt="image" src="https://github.com/user-attachments/assets/0239dcf5-03d9-45be-9568-3a0bf8407efb" />


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
```

Fill in the required input → the tool automates the rest.

---

## 🔗 Repository

👉 [payout-internal-tool (Web Version)](https://github.com/nelsonwong5079/payout-internal-tool)

---

Do you also want me to **add a “Future Enhancements” section** (e.g., dashboard for logs, multi-user support, cloud deploy), so the repo looks more like a growing project?
