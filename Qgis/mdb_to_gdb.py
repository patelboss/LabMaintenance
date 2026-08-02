import os
import subprocess
from pathlib import Path
from osgeo import gdal

# Enable GDAL exceptions for cleaner error handling
gdal.UseExceptions()

# -------------------------------------------------------------------
# CONFIGURATION
# Set the folder containing your .mdb files
# Note: Use forward slashes '/' in your folder paths
SOURCE_DIR = "C:/Users/Pankaj/Desktop/SOI_MDB_Files"
# -------------------------------------------------------------------

source_path = Path(SOURCE_DIR)
# Output folder will be created inside the same directory as 'converted_gdbs'
output_dir = source_path / "converted_gdbs"
output_dir.mkdir(exist_ok=True)

# Find all .mdb files in the source directory
mdb_files = list(source_path.glob("*.mdb"))

if not mdb_files:
    print(f"❌ No .mdb files found in: {source_path}")
else:
    print(f"🚀 Found {len(mdb_files)} .mdb file(s). Starting conversion...\n")

    for mdb_file in mdb_files:
        # Create output .gdb path with the same name as the .mdb file
        gdb_name = f"{mdb_file.stem}.gdb"
        output_gdb = output_dir / gdb_name

        print(f"Processing: '{mdb_file.name}'  ➔  '{gdb_name}'...")

        try:
            # Use gdal.VectorTranslate (equivalent to ogr2ogr)
            # Format 'OpenFileGDB' writes native Esri File Geodatabase folders
            options = gdal.VectorTranslateOptions(
                format="OpenFileGDB",
                accessMode="overwrite"
            )
            
            gdal.VectorTranslate(
                destNameOrDestDS=str(output_gdb),
                srcDS=str(mdb_file),
                options=options
            )
            print(f"  ✅ Successfully converted: {output_gdb.name}\n")

        except Exception as e:
             print(f"  ❌ Error converting {mdb_file.name}: {e}\n")

    print(f"🎉 Batch conversion complete! All .gdb folders are saved in:\n{output_dir}")
