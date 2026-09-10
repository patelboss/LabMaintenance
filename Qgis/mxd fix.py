import arcpy

# Target the current ArcGIS Pro project and active map
aprx = arcpy.mp.ArcGISProject("CURRENT")
active_map = aprx.activeMap

# Loop through the 1000+ layers
for lyr in active_map.listLayers():
    if lyr.supports("CONNECTIONPROPERTIES"):
        # Read the current connection data
        cp = lyr.connectionProperties
        
        if cp and 'connection_info' in cp:
            old_path = cp['connection_info'].get('database', '')
            
            # Find layers pointing to Personal Geodatabases
            if old_path.lower().endswith(".mdb"):
                # Construct the new GDB path
                new_path = old_path[:-4] + ".gdb"
                
                try:
                    # Isolate the update to this specific layer's database
                    lyr.updateConnectionProperties(old_path, new_path)
                except Exception:
                    print(f"Failed to repath: {lyr.name}")

print("Batch repathing complete.")
