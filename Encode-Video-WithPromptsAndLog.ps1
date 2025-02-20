# Load Windows Forms for GUI file picker
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Function to prompt for input file
function Get-InputFile {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $openFileDialog.Filter = "Video files (*.mp4;*.avi;*.mkv;*.mov)|*.mp4;*.avi;*.mkv;*.mov|All files (*.*)|*.*"
    $openFileDialog.Title = "Select a video file to encode"
    $result = $openFileDialog.ShowDialog()
    if ($result -eq "OK") {
        return $openFileDialog.FileName
    } else {
        Write-Host "No input file selected. Exiting."
        exit
    }
}

# Function to prompt for output file
function Get-OutputFile {
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $saveFileDialog.Filter = "MP4 files (*.mp4)|*.mp4|All files (*.*)|*.*"
    $saveFileDialog.Title = "Choose where to save the encoded video"
    $saveFileDialog.DefaultExt = "mp4"
    $saveFileDialog.FileName = "encoded_video.mp4"
    $result = $saveFileDialog.ShowDialog()
    if ($result -eq "OK") {
        return $saveFileDialog.FileName
    } else {
        Write-Host "No output file selected. Exiting."
        exit
    }
}

# Get file paths from user via dialogs
$inputFile = Get-InputFile
$outputFile = Get-OutputFile

# Define encoding parameters
$crf = 23  # CRF value (0-51): lower = higher quality, larger file; 23 is default, visually near-lossless
$preset = "slow"  # Encoding speed vs compression: 'slow' balances quality and size well

# Define error log file path (same directory as output file)
$outputDir = Split-Path -Path $outputFile -Parent
$errorLog = Join-Path -Path $outputDir -ChildPath "VideoEncodingErrorLog.txt"

# Check if input file exists
if (-not (Test-Path $inputFile)) {
    $errorMessage = "$(Get-Date) - ERROR: Input file not found: $inputFile"
    Write-Error $errorMessage
    $errorMessage | Out-File -FilePath $errorLog -Append
    exit
}

# Run FFmpeg command to encode video and capture output
$ffmpegCommand = "ffmpeg -i `"$inputFile`" -c:v libx264 -crf $crf -preset $preset -c:a aac -b:a 128k `"$outputFile`" 2>&1"
$ffmpegOutput = Invoke-Expression $ffmpegCommand

# Check if encoding was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Video encoded successfully! Output saved to: $outputFile"
    # Get file sizes for comparison
    $inputSize = (Get-Item $inputFile).Length / 1MB
    $outputSize = (Get-Item $outputFile).Length / 1MB
    Write-Host "Original size: $inputSize MB | Compressed size: $outputSize MB"
} else {
    $errorMessage = "$(Get-Date) - ERROR: Encoding failed for $inputFile. FFmpeg output:`n$ffmpegOutput"
    Write-Error "Encoding failed. Details logged to: $errorLog"
    $errorMessage | Out-File -FilePath $errorLog -Append
}