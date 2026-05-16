### **PROJECT OVERVIEW**
This is the official product blueprint for a crowd-sourced, AI-driven Human-Wildlife Conflict (HWC) safety application engineered by **Pankaj**. We call this project **"GajaRadar MP"** (adapted to protect local tribal communities, farmers, and forest beats from migrating elephant herds and territorial apex predators).
Here is the complete **What, Why, and How** of the system, laid out so clearly that you can hand this blueprint to a mobile app developer or pitch it directly to the Madhya Pradesh Forest Department for a zero-cost community pilot.
# PROJECT PLAN: GAJARADAR MP
### **Author & Architect:** Pankaj
### **Core Purpose:** To reduce Human-Wildlife Conflict (HWC) in Madhya Pradesh at the lowest possible cost.
### **Target Area:** Conflict-prone corridors surrounding Bandhavgarh Tiger Reserve, Sanjay-Dhubri Tiger Reserve, Kanha Tiger Reserve, and adjacent forest divisions.
## 1. THE "WHAT" (Product Definition)
**GajaRadar MP** is a free, open-source, lightweight mobile application designed for rural communities, local Primary Response Teams (PRTs), and forest beat guards across Madhya Pradesh. It crowdsources real-time wildlife movement data. Users safely upload animal sightings, while an automated, on-laptop GIS radar calculates immediate threat zones. It triggers native, high-decibel smartphone alarms for anyone entering active conflict corridors—operating on **₹0 of server or bulk communication costs**.
### Core App Features:
 * **One-Tap Reporting:** Simple, multilingual UI (Hindi/English) allowing a farmer or guard to report an animal spotting in two clicks.
 * **On-Device AI Filter:** A local computer vision model running entirely on the user's phone hardware to verify the photo actually contains a conflict animal (Elephant/Tiger/Leopard/Sloth Bear) before allowing submission.
 * **Dynamic Geofence Alarms:** Local siren alarms triggered by background device GPS, bypassing the need for paid enterprise WhatsApp APIs or SMS gateways.
 * **Lightweight Web Interface:** A free, interactive vector map showing current danger zones that villagers can access on basic mobile browsers.
## 2. THE "WHY" (The Purpose & Value)
### The Problem:
With wild elephant herds migrating permanently from Chhattisgarh into eastern MP (Umaria, Anuppur, Shahdol) and rising territorial tiger/leopard movements near buffer zones, HWC in Madhya Pradesh has reached critical levels. Traditional mitigation tools like solar fencing are prohibitively expensive (\approx ₹2 Lakhs/km), and official emergency communication relies on expensive bulk text alerts that community-driven initiatives or local groups cannot afford to sustain out of pocket.
### The Solution Value by Pankaj:
 1. **Lowest Cost Blueprint:** It completely replaces paid messaging APIs with a user-side, background geofencing script. The software runs completely free.
 2. **Edge-AI Computing:** By handling the AI validation on the sender's smartphone processor, it eliminates the need for expensive cloud servers or paid image-processing tokens.
 3. **Proactive Tribal Safety:** Mahua collectors, woodgatherers, and marginal farmers receive location-aware sirens *before* walking blindly into dense forest patches or nocturnal crop-raiding zones.
## 3. THE "HOW" (Technical Architecture)
The system split designed by **Pankaj** utilizes three free-tier components: **The App Front-End, The On-Device AI Engine, and the QGIS/Cloud Database Hub.**
```
[User Spots Wildlife & Takes Photo] 
                  │
                  ▼
   [On-Device AI (YOLOv8-Nano)] ──────(If Spam/Fake)──────> [Auto-Reject Report]
                  │
         (If Verified Animal)
                  ▼
     [Auto-Compress GPS Photo]
                  │
                  ▼
    [Upload to Firebase Free Tier]
                  │
                  ▼
[Pankaj's Laptop: QGIS Hub / Leaflet Map] ───> Computes 2-Hour Hazard Corridors
                  │
                  ▼
   [App syncs Hazard Polygons] ───────> [LOCAL PHONE SIREN ALARM] (If user enters zone)

```
### Step-by-Step Technical Implementation:
### Phase A: User Input & Edge-AI (The Front-End)
 * **The Framework:** Built on **FlutterFlow** (free tier) for ultra-fast UI rendering in Hindi.
 * **The Camera Integration:** When a user captures a photo of an encroaching animal, the app invokes an embedded, lightweight **YOLOv8-nano** or **TensorFlow Lite** model compiled directly inside the app bundle.
 * **The Validation Layer:** The smartphone's local processor reads the image. If the model confirms the animal with >80\% confidence, the app crops, downsamples, and highly compresses the image (under 150 KB) to ensure it transmits over weak 2G/3G rural networks.
### Phase B: Cloud Infrastructure (The Database)
 * **The Backend:** Linked directly to **Google Firebase Firestore**.
 * **The Free-Tier Logic:** Firebase's standard free tier provides up to 20,000 database writes and 50,000 reads per day. For a cluster of 50-60 vulnerable villages in an MP buffer zone, this threshold will never be crossed, keeping data storage **100% free**.
 * **Data Payload Structure:**
   ```json
   {
     "reporter_id": "PRT_Umaria_04",
     "timestamp": "2026-05-16T13:20:00Z",
     "latitude": 23.5384,
     "longitude": 81.0125,
     "species": "Elephant",
     "verified": true
   }
   
   ```
### Phase C: Analytical Engine & Corridor Calculations
 * **The GIS Core:** On your laptop, you connect **QGIS** directly to the Firebase database stream using a basic web service connection or standard script.
 * **The Grid Analysis:** You run your **LULC** (mapping sugarcane/kodo millet patches), **DEM** (identifying flat valley corridors), and **Forest Boundaries** against the live coordinates.
 * **The Hazard Output:** Instead of complex server nodes, your QGIS laptop creates a simple vector **Buffer Map** (e.g., 5km warning radii around active movement vector headings).
### Phase D: Native Alarm System (Bypassing Meta/SMS Costs)
 * **The Zero-Cost Warning:** The computed warning polygon boundaries are uploaded back to Firebase as raw coordinates.
 * **The Background Geofence:** The GajaRadar MP app running on the villager’s phone routinely downloads this small text array of active hazard coordinates.
 * **The Trigger:** The phone uses its built-in Android background location service. If the user's coordinates intersect with Pankaj's calculated hazard zone, the app generates a high-priority push notification and plays a continuous, high-volume siren—even without active internet connectivity at that moment.
## SUMMARY OF THE PANKAJ "ZERO-COST" TOOLBOX
 * **App UI/UX:** FlutterFlow (Free Tier)
 * **Computer Vision:** YOLOv8-nano / TensorFlow Lite (Open-Source, Free)
 * **Cloud Ledger:** Google Firebase (Free Tier)
 * **Analytical Engine:** QGIS Desktop Software (Open-Source, Free)
 * **Spatial Storage:** Modern GeoPackage (.gpkg) files for local archival storage on your laptop.
This blueprint is official, highly practical, and tailored to save lives in Central India. You have the vision down, Pankaj—this is exactly how you turn tech into a shield for rural India!
```

```

