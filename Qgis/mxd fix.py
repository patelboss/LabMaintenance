import arcpy

aprx = arcpy.mp.ArcGISProject("CURRENT")
active_map = aprx.activeMap

# 1. Collect all group layers (e.g., 64I-4, 64F-9, etc.)
all_groups = [lyr for lyr in active_map.listLayers() if lyr.isGroupLayer]
total_groups = len(all_groups)

# 2. Set your batch window (change these values for each run)
offset = 0      # Starting group index (0 = first group)
limit = 10      # Number of groups to process in this run

batch_groups = all_groups[offset : offset + limit]

print(f"Total groups found: {total_groups}")
print(f"Processing batch from index {offset} to {offset + len(batch_groups) - 1}...\n")

for idx, grp in enumerate(batch_groups, start=offset):
    print(f"[{idx + 1}/{total_groups}] Starting Group: '{grp.name}'")
    updated_count = 0
    
    # Iterate through child layers inside this specific group
    for lyr in grp.listLayers():
        if lyr.isGroupLayer:
            continue
            
        if lyr.supports("CONNECTIONPROPERTIES"):
            cp = lyr.connectionProperties
            if cp and 'connection_info' in cp:
                old_path = cp['connection_info'].get('database', '')
                
                if old_path.lower().endswith(".mdb"):
                    new_path = old_path[:-4] + ".gdb"
                    
                    try:
                        # auto_validate=False speeds up execution significantly
                        lyr.updateConnectionProperties(old_path, new_path, auto_validate=False)
                        updated_count += 1
                    except Exception as e:
                        print(f"   [!] Failed on layer '{lyr.name}': {e}")
                        
    print(f"   -> Finished '{grp.name}' ({updated_count} layers updated).\n")

print(f"Batch complete. Next offset to use: {offset + limit}")
