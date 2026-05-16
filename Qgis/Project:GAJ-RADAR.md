# PROJECT PLAN: GAJARADAR
### *An Edge-AI & Crowd-Sourced Elephant Early Warning System*
## 1. THE "WHAT" (Product Definition)
**GajaRadar** is a free, lightweight mobile application designed for villagers and forest guards in Tamil Nadu. It turns community members into active sensors. Users can report elephant sightings securely, while a built-in "radar" automatically calculates danger zones and triggers loud local smartphone alarms for anyone entering an active elephant corridor—all while running on ₹0 of server or communication costs.
### Core App Features:
 * **One-Tap Reporting:** Simple UI for users to upload a sighting instantly.
 * **On-Device AI Filter:** A local AI model that verifies if the photo actually contains an elephant before wasting database space.
 * **Live Hazard Map:** An interactive, lightweight web map showing active herd tracks.
 * **Zero-Cost Native Alarms:** Push notifications and local siren alarms triggered by background geofencing, bypassing expensive SMS/WhatsApp APIs.
## 2. THE "WHY" (The Purpose & Value)
### The Problem:
Human-Elephant Conflict (HEC) causes tragic loss of life and crop damage. Existing warning systems rely on manual broadcasting or expensive enterprise communication APIs (like WhatsApp Business or SMS gateways) that a local student, NGO, or village community cannot afford long-term.
### The Solution Value:
 1. **Democratic Conservation (VGI):** It shifts the burden of tracking from a few understaffed forest guards to the entire community.
 2. **Financial Sustainability (₹0 Infrastructure):** By utilizing the user's phone hardware for AI processing and using Google’s free cloud tiers, the system can scale to thousands of users without generating a massive bill.
 3. **Proactive vs. Reactive Safety:** Instead of a user checking a text message too late, the phone itself watches the user's location and screams an alarm *before* they walk into a dark sugarcane field where an elephant is feeding.
## 3. THE "HOW" (Technical Architecture)
The system is split into three main components: **The App Front-End, The Edge-AI Engine, and The Cloud Database/GIS Hub.**
```
[User Takes Photo] 
       │
       ▼
[On-Device AI (YOLOv8)] ──(If Fake)──> [Reject Alert]
       │
   (If Valid Elephant)
       ▼
[Compress Image & Fetch GPS]
       │
       ▼
[Upload to Firebase (Free Tier)]
       │
       ▼
[QGIS Laptop Hub / Mapbox Web Map] ──> Calculates Corridor/Buffer Zones
       │
       ▼
[Background Geofence on App] ──> [LOCAL PHONE SIREN ALARM] (If user enters zone)

```
### Step-by-Step Technical Implementation:
### Phase A: The User Input & Edge-AI (The Front-End)
 * **How to Build It:** Use **FlutterFlow** (a low-code app builder) to design a clean, highly visual interface (supporting English and Tamil).
 * **How the Camera Works:** When a user takes a photo, the app invokes an embedded, lightweight **YOLOv8-nano** or **TensorFlow Lite** model saved locally inside the app bundle.
 * **How it Validates:** The model reads the image matrix pixels right on the phone. If "Elephant" confidence is >80\%, the app automatically downsizes the image to a highly compressed format (under 200 KB) to save the user's cellular data.
### Phase B: The Cloud Infrastructure (The Database)
 * **How to Store It:** Link FlutterFlow to a **Firebase Firestore** database.
 * **How the Data Flows:** When validated, the app pushes a tiny JSON payload to Firebase:
   ```json
   {
     "timestamp": "2026-05-16T13:15:00Z",
     "latitude": 11.1234,
     "longitude": 76.9876,
     "verified": true,
     "photo_url": "storage_link_to_compressed_image"
   }
   
   ```
 * **The Cost Optimization:** Because Firebase's free tier allows 20,000 writes/day, your community data storage remains completely free.
### Phase C: The Analytical Engine & Map Display
 * **How to Sync with QGIS:** On your laptop, you connect QGIS directly to your Firebase database using a live web service connection or simple python script.
 * **How to Calculate the Corridor:** You use your **LULC, Soil, and DEM layers** alongside these incoming points to run the **Least Cost Path** or **Buffer** tools. This creates your "Active Hazard Zone" boundaries.
 * **How to Publish the Map:** You export these danger zone polygons back into Firebase. A public **Mapbox GL JS** or **Leaflet** map embedded in your app pulls these shapes and shades them bright red.
### Phase D: The Native Alarm System (Bypassing APIs)
 * **How to Warn the User:** Instead of sending an external WhatsApp text, the mobile app uses the phone's native hardware background location services.
 * **The Logic:** The app downloads the coordinates of the "Active Hazard Zones" calculated by your QGIS engine.
 * **The Alarm:** If the phone's GPS intersects with the coordinates of that active hazard polygon, the app triggers a high-priority **Local Notification Alert** accompanied by an aggressive alarm sound—even if the app is closed.
## Summary of Your Stack (The Genius "Zero-Cost" Toolbox)
 * **App Build:** FlutterFlow (Free Tier)
 * **On-Device AI:** TensorFlow Lite / YOLOv8-nano (Open-source, Free)
 * **Database & Storage:** Google Firebase (Free Tier)
 * **Desktop GIS Analysis:** QGIS (Open-source, Free)
 * **Data Format:** GeoPackage for master analytical copies; JSON/KML for app syncing.
```

```

