$path = Read-Host "Enter the path of your unziped icloud photos export folder"

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

#Search for .csv files in the path
$csvFiles = Get-ChildItem -Path $path -Recurse -Filter *.csv
if ($csvFiles.Count -eq 0) {
    Write-Host "No .csv files found in the specified path. Exiting."
    exit
}

# Process each .csv file
$metadataArray = @()
foreach ($csvFile in $csvFiles) {
    Write-Host "Processing $($csvFile.FullName)..."
    $csvData = Import-Csv -Path $csvFile.FullName

    foreach ($row in $csvData) {
        $imgName = $row.imgName
        # Delete the point if imgName starts with a dot
        if ($imgName.StartsWith(".")) {
            $imgName = $imgName.Substring(1)
        }

        # Determine the media file path and replace double backslashes with single slashes
        $mediaPath = Join-Path -Path (Split-Path -Path $csvFile.FullName -Parent) -ChildPath $imgName
        $mediaPath = $mediaPath -replace "\\+", "/"

        # Convert the date string as "Monday May 20,2019 8:56 AM GMT" to "yyyy:MM:dd HH:mm:ss"
        $formattedPhotoTakenTime = [DateTime]::ParseExact($row.originalCreationDate, "dddd MMMM d,yyyy h:mm tt 'GMT'", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToLocalTime().ToString("yyyy:MM:dd HH:mm:ss")
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
        }
    }
}

Write-Host "Total metadata entries prepared: $($metadataArray.Count)"
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
Write-Host "Metadata update process completed."

$action = Read-Host "Do you want to delete all .csv files? (y/n)"
if ($action -eq "y") {
    foreach ($csvFile in $csvFiles) {
        Remove-Item -Path $csvFile.FullName -Force
        Write-Host "Deleted $($csvFile.FullName)"
    }
    Write-Host "All .csv files deleted."
}
else {
    Write-Host "No files were deleted."
}