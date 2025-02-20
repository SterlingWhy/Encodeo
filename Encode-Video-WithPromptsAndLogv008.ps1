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

# Function to get video duration in seconds (optional, for progress bar)
function Get-VideoDuration {
    param ($FilePath)
    try {
        $ffprobeCommand = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 `"$FilePath`""
        $duration = Invoke-Expression $ffprobeCommand
        if ($duration) {
            return [float]$duration
        } else {
            throw "No duration returned"
        }
    } catch {
        Write-Host "Warning: Could not determine video duration (ffprobe missing or failed). Using simulated progress."
        return $null
    }
}

# Function to prompt for quality/size trade-off
function Get-QualityChoice {
    Write-Host "Choose a quality/size trade-off:"
    Write-Host "1. High Quality (Larger file, CRF 18, slow preset)"
    Write-Host "2. Balanced (Medium file size, CRF 23, slow preset)"
    Write-Host "3. Small Size (Smaller file, CRF 28, fast preset)"
    $choice = Read-Host "Enter your choice (1-3)"
    switch ($choice) {
        "1" { return @{ CRF = 18; Preset = "slow" } }
        "2" { return @{ CRF = 23; Preset = "slow" } }
        "3" { return @{ CRF = 28; Preset = "fast" } }
        default {
            Write-Host "Invalid choice. Defaulting to Balanced (CRF 23, slow preset)."
            return @{ CRF = 23; Preset = "slow" }
        }
    }
}

# Get file paths from user via dialogs
$inputFile = Get-InputFile
$outputFile = Get-OutputFile

# Get quality/size preference
$qualitySettings = Get-QualityChoice
$crf = $qualitySettings.CRF
$preset = $qualitySettings.Preset

# Define error log file path
$outputDir = Split-Path -Path $outputFile -Parent
$errorLog = Join-Path -Path $outputDir -ChildPath "VideoEncodingErrorLog.txt"

# Check if input file exists
if (-not (Test-Path $inputFile)) {
    $errorMessage = "$(Get-Date) - ERROR: Input file not found: $inputFile"
    Write-Error $errorMessage
    $errorMessage | Out-File -FilePath $errorLog -Append
    exit
}

# Get video duration for progress bar (if possible)
$duration = Get-VideoDuration -FilePath $inputFile
$useRealProgress = $duration -ne $null

# Run FFmpeg command with progress tracking
if ($useRealProgress) {
    $ffmpegCommand = "ffmpeg -i `"$inputFile`" -c:v libx264 -crf $crf -preset $preset -c:a aac -b:a 128k `"$outputFile`" -progress pipe:1 2>&1"
    $process = Start-Process -FilePath "ffmpeg" -ArgumentList "-i `"$inputFile`" -c:v libx264 -crf $crf -preset $preset -c:a aac -b:a 128k `"$outputFile`" -progress pipe:1" -NoNewWindow -PassThru -RedirectStandardOutput "progress.txt" -RedirectStandardError "error.txt"
    
    # Monitor real progress
    $progressFile = "progress.txt"
    while (-not $process.HasExited) {
        if (Test-Path $progressFile) {
            $progressData = Get-Content $progressFile -Raw
            if ($progressData -match "out_time_ms=(\d+)") {
                $currentTime = [float]$matches[1] / 1000000  # Convert microseconds to seconds
                $percentComplete = [math]::Min([int](($currentTime / $duration) * 100), 100)
                Write-Progress -Activity "Encoding Video" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
            }
        }
        Start-Sleep -Milliseconds 500
    }
    if (Test-Path $progressFile) { Remove-Item $progressFile }
} else {
    $ffmpegCommand = "ffmpeg -i `"$inputFile`" -c:v libx264 -crf $crf -preset $preset -c:a aac -b:a 128k `"$outputFile`" 2>&1"
    $process = Start-Process -FilePath "ffmpeg" -ArgumentList "-i `"$inputFile`" -c:v libx264 -crf $crf -preset $preset -c:a aac -b:a 128k `"$outputFile`"" -NoNewWindow -PassThru -RedirectStandardError "error.txt"
    
    # Simulated progress (no duration)
    $percent = 0
    while (-not $process.HasExited) {
        $percent = [math]::Min($percent + 2, 100)  # Increment by 2% every second
        Write-Progress -Activity "Encoding Video" -Status "$percent% Complete (Estimated)" -PercentComplete $percent
        Start-Sleep -Seconds 1
    }
}

# Check encoding result
if ($process.ExitCode -eq 0) {
    Write-Progress -Activity "Encoding Video" -Status "100% Complete" -Completed
    Write-Host "Video encoded successfully! Output saved to: $outputFile"
    $inputSize = (Get-Item $inputFile).Length / 1MB
    $outputSize = (Get-Item $outputFile).Length / 1MB
    Write-Host "Original size: $inputSize MB | Compressed size: $outputSize MB"
} else {
    $errorOutput = Get-Content "error.txt" -Raw
    $errorMessage = "$(Get-Date) - ERROR: Encoding failed for $inputFile. FFmpeg output:`n$errorOutput"
    Write-Error "Encoding failed. Details logged to: $errorLog"
    $errorMessage | Out-File -FilePath $errorLog -Append
    if (Test-Path "error.txt") { Remove-Item "error.txt" }
}