import arcpy

aprx = arcpy.mp.ArcGISProject("CURRENT")
active_map = aprx.activeMap

all_groups = [lyr for lyr in active_map.listLayers() if lyr.isGroupLayer]
total_groups = len(all_groups)

# Adjust offset and limit as needed
offset = 0
limit = 5
batch_groups = all_groups[offset : offset + limit]

print(f"Processing groups {offset + 1} to {offset + len(batch_groups)} of {total_groups}...\n")

for idx, grp in enumerate(batch_groups, start=offset):
    print(f"[{idx + 1}/{total_groups}] Starting Group: '{grp.name}'")
    updated_count = 0
    
    for lyr in grp.listLayers():
        if lyr.isGroupLayer:
            continue
            
        if lyr.supports("CONNECTIONPROPERTIES"):
            cp = lyr.connectionProperties
            if cp and 'connection_info' in cp:
                old_db = cp['connection_info'].get('database', '')
                
                if old_db.lower().endswith('.mdb'):
                    new_db = old_db[:-4] + '.gdb'
                    
                    # Create a copy and update both path and workspace factory
                    new_cp = dict(cp)
                    new_cp['connection_info']['database'] = new_db
                    
                    # Change workspace type to FileGDB
                    if 'workspace_factory' in new_cp:
                        new_cp['workspace_factory'] = 'FileGDB'
                    
                    try:
                        lyr.updateConnectionProperties(cp, new_cp, validate=False)
                        updated_count += 1
                    except Exception as e:
                        print(f"   [!] Error on '{lyr.name}': {e}")
                        
    print(f"   -> Finished '{grp.name}' ({updated_count} layers modified).\n")

print("Batch complete. Check the layer source properties now.")
