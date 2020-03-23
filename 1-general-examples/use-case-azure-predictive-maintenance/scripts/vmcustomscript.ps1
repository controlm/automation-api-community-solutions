
New-Item -Path "C:\" -Name "Logfiles" -ItemType "directory"

$path = 'C:\Logfiles'
$file = 'ScriptFootprint.txt'

New-Item -Path $path -Name $file -ItemType "file" -Value "This is from a custom script."