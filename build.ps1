param([Parameter(Mandatory = $true)][string]$ZombieBuddyJar)
$ErrorActionPreference = 'Stop'
$classes = Join-Path $PSScriptRoot ('build\classes-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $classes | Out-Null
$sources = Get-ChildItem (Join-Path $PSScriptRoot 'src') -Recurse -Filter '*.java'
& javac --release 17 -cp $ZombieBuddyJar -d $classes $sources.FullName
if ($LASTEXITCODE -ne 0) { throw 'Preview helper compilation failed' }
$jar = Join-Path $PSScriptRoot '42\media\java\client\ExtractionModePDA.jar'
New-Item -ItemType Directory -Force -Path (Split-Path $jar) | Out-Null
& jar --create --file $jar -C $classes maeiro
if ($LASTEXITCODE -ne 0) { throw 'Preview helper packaging failed' }
