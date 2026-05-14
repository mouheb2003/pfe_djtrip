$files = @(
    "lib/screens/tourist/place_detail_screen.dart",
    "lib/screens/tourist/my_activities_screen.dart"
)

foreach ($file in $files) {
    Write-Host "Cleaning conflicts in $file..."
    $content = Get-Content -Raw $file
    
    # Remove all conflict markers by keeping the HEAD version
    $pattern = '<<<<<<< HEAD\r?\n([\s\S]*?)\r?\n=======\r?\n(?:[\s\S]*?)\r?\n>>>>>>> [^\r\n]+\r?\n'
    $content = [System.Text.RegularExpressions.Regex]::Replace($content, $pattern, '$1')
    
    # Write back
    $content | Out-File $file -Encoding UTF8 -NoNewline
    Write-Host "✓ Cleaned $file"
}

Write-Host "Done!"
