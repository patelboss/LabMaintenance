import arcpy

# Targets the currently open soi_12500 - Copy.mxd
mxd = arcpy.mapping.MapDocument("CURRENT")

# Loop through all 1000+ layers in the Table of Contents
for lyr in arcpy.mapping.ListLayers(mxd):
    if lyr.supports("WORKSPACEPATH"):
        old_path = lyr.workspacePath
        
        # Identify layers that were pointing to Personal Geodatabases
        if old_path.lower().endswith(".mdb"):
            
            # Construct the new path by swapping .mdb for .gdb
            # NOTE: If your GDBs are in a different folder now, add: 
            # new_path = new_path.replace(r"C:\OldFolder", r"D:\NewFolder")
            new_path = old_path[:-4] + ".gdb"
            
            # Force the layer to look only at its specific new GDB
            try:
                lyr.replaceDataSource(new_path, "FILEGDB_WORKSPACE", lyr.datasetName)
            except Exception:
                print("Failed to repath: " + lyr.name)

arcpy.RefreshActiveView()
arcpy.RefreshTOC()
print("Batch repathing complete.")
