# Photo Metadata Fixer (Google Photos & iCloud)

This repository contains **PowerShell scripts to restore EXIF metadata** (such as date taken and GPS location) to photos and videos exported from **Google Photos** or **iCloud Photos**.

Both services often export media files **without embedded metadata**, storing important information in **sidecar files** instead:

* **Google Photos:** `.json` metadata files
* **iCloud Photos:** `.csv` metadata files

These scripts automatically read those metadata files and use **ExifTool** to write the correct EXIF information back into the media files.

---

## ✨ Features

### Google Photos Fixer

* 📂 Recursively scans a Google Photos Takeout export
* 🔎 Automatically matches media files with their `.json` metadata
* 🕒 Restores metadata:

  * `DateTimeOriginal`
  * `CreateDate`
  * `XMP:CreateDate`
  * `FileModifyDate`
* 🌍 Restores GPS data:

  * Latitude / Longitude
  * Altitude
* 🔁 Handles duplicate filenames like `(1)`, `(2)`
* 🧾 Generates reusable `fix_exif_metadata.json`
* 🧹 Optional cleanup of `.json` sidecar files

### iCloud Photos Fixer

* 📂 Processes iCloud photo export folders
* 📊 Reads metadata from Apple `.csv` export files
* 🕒 Restores metadata:

  * `DateTimeOriginal`
  * `CreateDate`
  * `XMP:CreateDate`
  * `FileModifyDate`
* 🧾 Generates reusable `fix_exif_metadata.json`
* 🧹 Optional cleanup of `.csv` metadata files

---

## 📦 Requirements

* **Windows**
* **PowerShell 5.1+** or **PowerShell Core**
* **ExifTool** installed and available in `PATH`

Download ExifTool:
[https://exiftool.org/](https://exiftool.org/)

Verify installation:

```powershell
exiftool -ver
```

---

## 📁 Expected Folder Structures

### Google Photos (Google Takeout)

Media files and their `.json` metadata files are located in the same folders.

```
Google Photos/
├── 2019/
│   ├── IMG_1234.jpg
│   ├── IMG_1234.jpg.json
│   ├── VID_5678.mp4
│   └── VID_5678.mp4.json
└── 2020/
    └── ...
```

---

### iCloud Photos Export

Apple exports photos with metadata stored in `.csv` files.

```
iCloud Photos/
├── Photos/
│   ├── IMG_0001.JPG
│   ├── IMG_0002.MOV
│
├── Photo Details.csv
└── Photo Details 2.csv
```

The script reads the CSV metadata and applies it to the corresponding media files.

---

## 🚀 Usage

Clone or download the repository, then run the appropriate script.

---

### Fix Google Photos Metadata

```powershell
.\fix-google-photos-exif.ps1
```

Steps:

1. Enter the path to your **unzipped Google Photos export**
2. The script will:

   * Scan media files
   * Match `.json` metadata
   * Generate `fix_exif_metadata.json`
3. Confirm if you want to apply the metadata
4. Optionally delete the `.json` sidecar files

---

### Fix iCloud Photos Metadata

```powershell
.\fix-icloud-photos-exif.ps1
```

Steps:

1. Enter the path to your **unzipped iCloud export**
2. The script will:

   * Scan `.csv` metadata files
   * Generate `fix_exif_metadata.json`
3. Confirm if you want to apply the metadata
4. Optionally delete the `.csv` metadata files

---

## 🧾 Output

Both scripts generate a file named:

```
fix_exif_metadata.json
```

This file contains all metadata corrections and can be reused later with ExifTool:

```powershell
exiftool -r -m -j=fix_exif_metadata.json -overwrite_original <photos_folder>
```

This allows you to **reapply metadata without rescanning files**.

---

## ⚠️ Notes & Limitations

* Files without matching metadata will be reported
* If multiple metadata files match a single media file, the Google Photos script will warn and skip it
* GPS data restoration is only available for **Google Photos exports** (iCloud CSV files do not include GPS)
* Original files are modified **in place** (no backups are created)

---

## 🛡️ Safety Tips

* **Make a backup** of your photo export before running the scripts
* Test on a **small folder first**
* Review `fix_exif_metadata.json` if you want full control before applying changes

---

## 🙌 Credits

* Phil Harvey’s **ExifTool**

[https://exiftool.org/](https://exiftool.org/)

---

⭐ If this project helped you recover your photo metadata, consider starring the repository!