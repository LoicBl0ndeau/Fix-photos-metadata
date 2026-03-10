$path = Read-Host "Enter the path of your unziped google photos export folder"

#Check if fix_exif_metadata.json exists in the path
if (Test-Path "$path\fix_exif_metadata.json") {
    $action = Read-Host "fix_exif_metadata.json already exists. Do you want to use it to fix metadata and skip scanning? (y/n)"
    if ($action -eq "y") {
        & exiftool -r -m -j="$path\fix_exif_metadata.json" -overwrite_original $path
        Write-Host "Metadata fixed using existing fix_exif_metadata.json"
        exit
    }
    else{
        Write-Host "Proceeding to scan files and create a new fix_exif_metadata.json"
    }
}

# Load ALL files one time
$allFiles = Get-ChildItem -Path $path -Recurse -File
$filenames = $allFiles | Where-Object { $_.Extension -ne ".json" } | Select-Object Name,FullName,Extension
$jsonFiles = $allFiles | Where-Object { $_.Extension -eq ".json" } | Select-Object Name,FullName
# Build lookup: directory -> json files
$jsonByFolder = @{}
foreach ($json in $jsonFiles) {
    $folder = Split-Path $json.FullName -Parent
    if (-not $jsonByFolder.ContainsKey($folder)) {
        $jsonByFolder[$folder] = New-Object System.Collections.Generic.List[Object]
    }
    $jsonByFolder[$folder].Add($json)
}
$total = $filenames.Count
$index = 0

Write-Host "Scanning $total files..."

# We find the .json file associated with each media file (we know that the format name of the json file is the same as the media filename + something + ".json") and we count the number of time we don't find it
$missingMetadataCount = 0
$updatedCount = 0
$metadataArray = @()
foreach ($file in $filenames) {
    $index++
    Write-Host "[$index/$total]" -NoNewline
    Write-Host "`r" -NoNewline

    $workingDir = Split-Path -Path $file.FullName -Parent

    # if the filename contains (X) where X is a number, we remove it for the search 
    if ($file.Name -match "^(.*?)(\(\d+\))(\..+)$") {
        $baseName = $matches[1]
        $pattern = $matches[2]
        $jsonFile = $jsonByFolder[$workingDir] | Where-Object { $_.Name -like ($baseName + "*" + $pattern + ".json") }
        if (-not $jsonFile) {
            if ($file.Extension -ieq ".mp4") {
                $jsonFile = $jsonByFolder[$workingDir] | Where-Object { $_.Name -like ($baseName + ".*.json") -and $_.Name -notlike "*).json" }
                if($jsonFile.Count -gt 1) {
                    # In case of iPhones, if there is multiple json files for a .mp4, we try to find the one with "HEIC" in the name
                    $jsonFile = $jsonByFolder[$workingDir] | Where-Object { $_.Name -like ($baseName + ".HEIC*.json") -and $_.Name -notlike "*).json" }
                }
            }
            else{
                $prefix = $file.Name.Substring(0, [Math]::Min(45, $file.Name.Length))
                $jsonFile = $jsonByFolder[$workingDir] | Where-Object { $_.Name -like ($prefix + "*.json") -and $_.Name -notlike "*).json" }
            }
        }
    }
    # Else we just search for the first 46 characters of the filename
    else{
        $prefix = $file.Name.Substring(0, [Math]::Min(46, $file.Name.Length))
        $jsonFile = $jsonByFolder[$workingDir] | Where-Object { $_.Name -like ($prefix + "*.json") -and $_.Name -notlike "*).json" }
        # Special cases
        if (-not $jsonFile -or $jsonFile.Count -gt 1) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $jsonFile = $jsonByFolder[$workingDir] | Where-Object { $_.Name -like ($baseName + ".*.json") -and $_.Name -notlike "*).json" }
            # In case of iPhones, if there is multiple json files for a .mp4, we try to find the one with "HEIC" in the name
            if($jsonFile.Count -gt 1 -and $file.Extension -ieq ".mp4") {
                $jsonFile = $jsonByFolder[$workingDir] | Where-Object { $_.Name -like ($baseName + ".HEIC*.json") -and $_.Name -notlike "*).json" }
            }
        }
    }
    if (-not $jsonFile) {
        $missingMetadataCount++
        Write-Host "Missing metadata for file: $($file.FullName)"
    }
    elseif ($jsonFile.Count -gt 1) {
        $missingMetadataCount++
        Write-Host "Multiple metadata files found for file: $($file.FullName)"
        # print all the found json files
        foreach ($jf in $jsonFile) {
            Write-Host " - $($jf.FullName)"
        }
    }
    else{
        $jsonPath = $jsonFile.FullName
        $mediaPath = $file.FullName
        $jsonContent = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $photoTakenTime = $jsonContent.photoTakenTime.timestamp
        $formattedPhotoTakenTime = [System.DateTimeOffset]::FromUnixTimeSeconds($photoTakenTime).ToLocalTime().ToString("yyyy:MM:dd HH:mm:ss")
        $latitude = $jsonContent.geoData.latitude
        $longitude = $jsonContent.geoData.longitude
        $altitude = $jsonContent.geoData.altitude
        $latitudeRef = if ($latitude -ge 0) { "N" } else { "S" }
        $longitudeRef = if ($longitude -ge 0) { "E" } else { "W" }
        $latitudeAbs = [math]::Abs($latitude)
        $longitudeAbs = [math]::Abs($longitude)
        
        $metadataArray += [PSCustomObject]@{
            SourceFile = $mediaPath

            # Canonical date
            "XMP:CreateDate"       = $formattedPhotoTakenTime

            # EXIF dates (JPG, TIFF, HEIC)
            DateTimeOriginal       = $formattedPhotoTakenTime
            CreateDate             = $formattedPhotoTakenTime

            # Format-specific
            "PNG:CreationTime"     = $formattedPhotoTakenTime
            "QuickTime:CreateDate" = $formattedPhotoTakenTime

            # Filesystem
            FileModifyDate         = $formattedPhotoTakenTime

            # GPS (EXIF)
            GPSLatitude            = $latitudeAbs
            GPSLatitudeRef         = $latitudeRef
            GPSLongitude           = $longitudeAbs
            GPSLongitudeRef        = $longitudeRef
            GPSAltitude            = $altitude

            # GPS (XMP – critical for PNG / WebP)
            "XMP:GPSLatitude"      = $latitudeAbs
            "XMP:GPSLongitude"     = $longitudeAbs
            "XMP:GPSAltitude"      = $altitude
        }

        $updatedCount++
    }
}
Write-Host "Total files missing metadata: $missingMetadataCount"

$exifJson = $metadataArray | ConvertTo-Json -Compress
$exifJson | Out-File -FilePath "$path\fix_exif_metadata.json" -Encoding UTF8
Write-Host "Metadata to fix saved to fix_exif_metadata.json"

$action = Read-Host "Do you want to fix the metadata? (y/n)"
if ($action -ne "y") {
    Write-Host "Exiting without making changes. Saving metadata to fix_exif_metadata.json"
    Write-Host "You can run the following command to apply the metadata fixes:"
    Write-Host "exiftool -json=fix_exif_metadata.json -overwrite_original"
    exit
}

& exiftool -r -m -j="$path\fix_exif_metadata.json" -overwrite_original $path

Write-Host "Total files updated: $updatedCount"

$action = Read-Host "Do you want to delete all .json files? (y/n)"
if ($action -eq "y") {
    foreach ($json in $jsonFiles) {
        Remove-Item $json.FullName
    }
    Write-Host "All .json files deleted."
} else {
    Write-Host "No .json files were deleted."
}