# Define parameters
$inputFile = "C:\path\to\your\video.mp4"  # Replace with your input video path
$outputFile = "C:\path\to\your\output.mp4"  # Replace with desired output path
$crf = 23  # CRF value (0-51): lower = higher quality, larger file; 23 is default, visually near-lossless
$preset = "slow"  # Encoding speed vs compression: 'slow' balances quality and size well

# Check if input file exists
if (-not (Test-Path $inputFile)) {
    Write-Error "Input file not found: $inputFile"
    exit
}

# Run FFmpeg command to encode video
$ffmpegCommand = "ffmpeg -i `"$inputFile`" -c:v libx264 -crf $crf -preset $preset -c:a aac -b:a 128k `"$outputFile`""
Invoke-Expression $ffmpegCommand

# Check if encoding was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Video encoded successfully! Output saved to: $outputFile"
    # Get file sizes for comparison
    $inputSize = (Get-Item $inputFile).Length / 1MB
    $outputSize = (Get-Item $outputFile).Length / 1MB
    Write-Host "Original size: $inputSize MB | Compressed size: $outputSize MB"
} else {
    Write-Error "Encoding failed. Check FFmpeg output for details."
}