import os
import glob
import subprocess
import sys
import tempfile

# =====================================================
# CONFIGURATION
# =====================================================

input_dir = r"C:/Users/labadmin/Desktop/Toposheets/RAW"
output_dir = r"C:/Users/labadmin/Desktop/Toposheets/OUTPUT"

target_crs = "EPSG:4326"

# Batch controls
offset = 0
limit = None

# =====================================================
# CREATE OUTPUT DIRECTORY
# =====================================================

os.makedirs(output_dir, exist_ok=True)

# =====================================================
# FIND GDAL BINARIES
# =====================================================

qgis_bin_dir = os.path.dirname(sys.executable)

gdal_translate_exe = os.path.join(
    qgis_bin_dir,
    "gdal_translate.exe"
)

gdalwarp_exe = os.path.join(
    qgis_bin_dir,
    "gdalwarp.exe"
)

# -----------------------------------------------------
# OSGeo4W fallback
# -----------------------------------------------------

if not os.path.exists(gdal_translate_exe):

    possible_bin = os.path.join(
        os.path.dirname(qgis_bin_dir),
        "bin"
    )

    gdal_translate_exe = os.path.join(
        possible_bin,
        "gdal_translate.exe"
    )

    gdalwarp_exe = os.path.join(
        possible_bin,
        "gdalwarp.exe"
    )

# -----------------------------------------------------
# PATH fallback
# -----------------------------------------------------

if not os.path.exists(gdal_translate_exe):
    gdal_translate_exe = "gdal_translate"

if not os.path.exists(gdalwarp_exe):
    gdalwarp_exe = "gdalwarp"

# =====================================================
# FIND .POINTS FILES
# =====================================================

points_files = sorted(
    glob.glob(os.path.join(input_dir, "*.points"))
)

total_found = len(points_files)

if not points_files:

    print(
        "Execution halted: No .points files found "
        "in the target RAW directory."
    )

    queue_to_process = []

else:

    start_idx = min(offset, total_found)

    end_idx = (
        total_found
        if limit is None
        else min(start_idx + limit, total_found)
    )

    queue_to_process = points_files[start_idx:end_idx]

    print("=================================================")
    print(f"Total profiles found : {total_found}")
    print(f"Files to process     : {len(queue_to_process)}")
    print("=================================================\n")

# =====================================================
# MAIN LOOP
# =====================================================

for pts_path in queue_to_process:

    pts_filename = os.path.basename(pts_path)

    # -------------------------------------------------
    # NORMALIZE STEM
    # Handles:
    # abc.points
    # abc.pdf.points
    # abc.PDF.points
    # -------------------------------------------------

    clean_stem = (
        pts_filename
        .replace(".points", "")
        .replace(".pdf", "")
        .replace(".PDF", "")
    )

    # -------------------------------------------------
    # FIND MATCHING PDF
    # -------------------------------------------------

    lower_pdf = os.path.join(
        input_dir,
        f"{clean_stem}.pdf"
    )

    upper_pdf = os.path.join(
        input_dir,
        f"{clean_stem}.PDF"
    )

    if os.path.exists(lower_pdf):

        img_path = lower_pdf
        base_name = os.path.basename(lower_pdf)

    elif os.path.exists(upper_pdf):

        img_path = upper_pdf
        base_name = os.path.basename(upper_pdf)

    else:

        print(
            f"Skipping missing PDF for: {pts_filename}"
        )

        continue

    print("\n=================================================")
    print(f"Processing Layer : {base_name}")
    print("=================================================")

    # -------------------------------------------------
    # OUTPUT FILES
    # -------------------------------------------------

    clean_name = os.path.splitext(base_name)[0]

    temp_translated = os.path.join(
        tempfile.gettempdir(),
        f"{clean_name}.tif"
    )

    final_geotiff = os.path.join(
        output_dir,
        f"{clean_name}_modified.tif"
    )

    # -------------------------------------------------
    # READ GCPs
    # -------------------------------------------------

    gcp_flags = []

    try:

        with open(
            pts_path,
            "r",
            encoding="utf-8-sig"
        ) as f:

            lines = f.readlines()

    except Exception as e:

        print(
            f"Failed reading points file: {pts_filename}"
        )

        print(e)

        continue

    for line in lines:

        clean_line = line.strip()

        if (
            not clean_line
            or clean_line.startswith("#")
            or clean_line.startswith("mapX")
        ):
            continue

        parts = clean_line.split(",")

        if len(parts) < 5:

            print(
                f"Skipped malformed row: {clean_line}"
            )

            continue

        enabled = parts[4].strip()

        if enabled != "1":
            continue

        # -------------------------------------------------
        # VERIFIED FORMAT:
        # mapX,mapY,sourceX,sourceY,enable
        # -------------------------------------------------

        map_x = parts[0].strip()
        map_y = parts[1].strip()

        pixel_x = parts[2].strip()
        pixel_y = parts[3].strip()

        # -------------------------------------------------
        # VALIDATE NUMERIC VALUES
        # -------------------------------------------------

        try:

            float(map_x)
            float(map_y)
            float(pixel_x)
            float(pixel_y)

        except ValueError:

            print(
                f"Skipped invalid numeric row: "
                f"{clean_line}"
            )

            continue

        gcp_flags.extend([
            "-gcp",
            pixel_x,
            pixel_y,
            map_x,
            map_y
        ])

    if not gcp_flags:

        print("No valid GCPs found.")
        continue

    print(f"Loaded {len(gcp_flags) // 5} GCPs")

    # =================================================
    # GDAL_TRANSLATE COMMAND
    # =================================================

    translate_cmd = [
        gdal_translate_exe,
        "-progress",
        "-of", "GTiff"
    ]

    translate_cmd.extend(gcp_flags)

    translate_cmd.extend([
        img_path,
        temp_translated
    ])

    # =================================================
    # GDALWARP COMMAND
    # =================================================

    warp_cmd = [
        gdalwarp_exe,
        "-progress",
        "-r", "near",
        "-order", "2",
        "-co", "COMPRESS=LZW",
        "-co", "PREDICTOR=2",
        "-co", "BIGTIFF=IF_NEEDED",
        "-t_srs", target_crs,
        temp_translated,
        final_geotiff
    ]

    try:

        # =================================================
        # RUN GDAL_TRANSLATE
        # =================================================

        print("\nRunning gdal_translate...\n")

        translate_output = []

        translate_process = subprocess.Popen(
            translate_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        for line_out in translate_process.stdout:

            clean_output = line_out.strip()

            translate_output.append(clean_output)

            print(clean_output, flush=True)

        translate_process.wait()

        if translate_process.returncode != 0:

            print("\nGDAL_TRANSLATE ERROR LOG:\n")

            for msg in translate_output[-30:]:
                print(msg)

            raise subprocess.CalledProcessError(
                translate_process.returncode,
                translate_cmd
            )

        # =================================================
        # RUN GDALWARP
        # =================================================

        print("\nRunning gdalwarp...\n")

        warp_output = []

        warp_process = subprocess.Popen(
            warp_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        for line_out in warp_process.stdout:

            clean_output = line_out.strip()

            warp_output.append(clean_output)

            print(clean_output, flush=True)

        warp_process.wait()

        if warp_process.returncode != 0:

            print("\nGDALWARP ERROR LOG:\n")

            for msg in warp_output[-30:]:
                print(msg)

            raise subprocess.CalledProcessError(
                warp_process.returncode,
                warp_cmd
            )

        print("\nSUCCESS")
        print(f"Generated: {final_geotiff}")

    except subprocess.CalledProcessError as e:

        print("\nERROR DURING GDAL EXECUTION")
        print(f"Return Code : {e.returncode}")

        try:
            print(
                "Command      :",
                " ".join(e.cmd)
            )
        except Exception:
            pass

    except Exception as e:

        print("\nUNEXPECTED ERROR")
        print(str(e))

    finally:

        # -------------------------------------------------
        # CLEAN TEMP FILE
        # -------------------------------------------------

        if os.path.exists(temp_translated):

            try:
                os.remove(temp_translated)
            except Exception:
                pass

# =====================================================
# FINISHED
# =====================================================

if points_files:

    print("\n=================================================")
    print("BATCH PROCESSING COMPLETED")
    print("=================================================")
