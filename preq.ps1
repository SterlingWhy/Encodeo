Set-ExecutionPolicy Bypass -Scope CurrentUser; iwr https://chocolatey.org/install.ps1 | iex
choco install ffmpeg
ffmpeg -version
winget install "FFmpeg (Essentials Build)"