# QGIS Master Map Layout Execution Plan

## PHASE 1: Data Preparation & Contour Labeling
Before opening the Layout Manager, the main map canvas must be perfectly styled.

### 1. Labeling Contours Professionally
* **Action:** Right-click Contour Layer > Properties > Labels.
* **Type:** Single Labels (Column: `Elevation`).
* **Placement:** Select **Curved** and **On Line**.
* **Readability (The Mask):** Go to Buffer tab > Check **Draw text buffer** (Match color to the background elevation map).
* **Pro-Tip (Index Contours):** Use the Expression button (`ε`) to only label every 100m: 
    `IF("ELEV" % 100 = 0, "ELEV" || ' m', '')`

### 2. Lock Your Map Themes
* **Action:** Organize layers for your 3 map types (Geological, Lat-Lng, Treatment).
* **Execution:** Turn on the specific layers for one type, click the **Eye Icon** at the top of the Layers Panel > **Add Theme** > Name it (e.g., `Treatment_Map`). Repeat for the other two.

---

## PHASE 2: Layout Structure (The Blueprint)
Press `Ctrl + P` to create a new Print Layout. Name it `Master_Division_Layout`.

### 1. The Header Section (Top of Page)
Use the **Add Label** (Text) tool for these static/dynamic elements:
* **Top Center:** `[% @layout_name %]` or hardcode "TREATMENT MAP" (Font: Bold, Large).
* **Below Heading:** "Division Detail: [Your Division Name]" (Font: Regular, Medium).
* **Top Left:** `Range: [% "Range_Column" %] | Beat: [% "Beat_Column" %]` (Use Atlas dynamic text).
* **Top Right:** `CRS: WGS 84 (EPSG:4326)` (Static text).

### 2. The Main Rectangle (The Suspect)
* **Action:** Use **Add Map** and draw a large rectangle filling the center of the page.
* **Theme Lock:** In Item Properties, check **Follow Layer Theme** and select your desired theme (e.g., `Treatment_Map`).

### 3. The Coordinate Grid (DMS Edges)
* **Action:** Select the Main Map > Item Properties > Grids > Add Grid (`+`).
* **CRS:** Set to EPSG:4326.
* **Interval:** Set X and Y to appropriate Map Units (e.g., `0.05` degrees).
* **Frame:** Set Frame Style to **Zebra**.
* **Draw Coordinates:** Check the box. Set format to **Degree Minute Second (DMS)**. 
* **Placement:** Left/Right (Vertical), Top/Bottom (Horizontal).

---

## PHASE 3: Inside the Main Rectangle

### 1. The Small Map (Top Left Inset)
* **Action:** Add a second, smaller map inside the top-left of the main map frame.
* **Scale:** Set the scale to show the *entire* Division/Range. 
* **The Rectangular Mark (Overview):** In Item Properties > Overviews > Add (`+`) > Set Map Frame to **Map 1** (Main Map). Give it a red frame color.
* **Styling:** Add a background color (White) and a Frame (0.5mm) so it "hangs" cleanly over the main map.

### 2. Map Elements (Top Right & Bottom Left)
* **North Arrow (Top Right):** Add Picture > Search Directories > Choose a clean, official North Arrow. Link it to **Map 1** so it syncs with map rotation.
* **Scale Bar (Bottom Left):** Add Scale Bar > Link to **Map 1**. Set Style to **Line Ticks Up** or **Double Box**. Set units to Meters or Kilometers. Add a solid background if it sits over satellite imagery.

### 3. The Index / Legend (Bottom Right)
* **Action:** Add Legend in the bottom right corner.
* **Cleanup:** Uncheck **Auto-update**. Remove layers that don't need explaining (like Google Satellite).
* **Dynamic Filtering:** Check **Only show items inside linked map**. (This ensures if a compartment only has teak, only teak shows in the legend).

---

## PHASE 4: The Footer & Atlas Automation

### 1. The Footer (Bottom Outside Rectangle)
* **Action:** Add Text labels for authorities.
* **Format:** `Prepared By: Pankaj (Lab Admin)` [Left Side]
    `Approved By: DFO / Conservator` [Right Side]

### 2. Atlas Configuration (The Loop)
* **Action:** Go to the **Atlas Tab** (Right panel) > Check **Generate an atlas**.
* **Coverage Layer:** Select your **Division KML** (Compartments) layer.
* **Page Name:** Select the Compartment Name column.
* **Link the Main Map:** Click the Main Map > Item Properties > Check **Controlled by Atlas**. Set **Margin around feature** to `10%`. 
* *Note: Do NOT check "Controlled by Atlas" for the small inset map.*

---

## ⚠️ CAREFUL ABOUT: (Crucial Developer Checks)

1.  **CRS Mismatches:** Ensure your Points layer, KML layer, and the Project CRS are all strictly EPSG:4326 before exporting. If they aren't, the Red Overview box will fly off into the ocean.
2.  **Z-Order (Layer Hierarchy):** Your Main Map must be at the *bottom* of the layout items list. If it is on top, you won't be able to click on your North Arrow, Legend, or Inset Map. Use the "Items" panel to drag the Main Map to the bottom.
3.  **Label Overlap:** Before exporting the whole batch, preview a large compartment and a small compartment. Ensure your dynamic title texts (`[% "Comp_Name" %]`) have enough physical space in the layout so they don't get cut off when the names are long.
4.  **Null Values:** If the Atlas driver layer has empty cells in the Range or Beat columns, your header will just say "Range: | Beat: ". Check the Attribute table first!
5.  
