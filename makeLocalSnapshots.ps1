# This application creates UMDH memory snapshots in a loop at specified intervals.

param(
    [Parameter(Mandatory = $true)]
	[string]$DumpPath, # Path where dumps will be stored
	[string]$SubfolderName = "local", # Subfolder name for the dumps
	[string]$FilePathUmdh = ".\x64\umdh.exe", # Path to UMDH executable
    [Parameter(Mandatory = $true)]
    [double]$IntervalMinutes, # Interval in minutes between snapshots
    [Parameter(Mandatory = $true)]
	[int]$Iterations, # Number of snapshots to create
	[switch]$CreateDiffs # Whether to create diffs between snapshots
)
$WorkingDir = (Get-Location).Path

# Set symbol path for all child scripts
$Env:_NT_SYMBOL_PATH = 'srv*\\build\symbols*;srv*C:\mssymcache*https://msdl.microsoft.com/download/symbols'
Write-Host "Symbol-Pfad (_NT_SYMBOL_PATH): $Env:_NT_SYMBOL_PATH"
""
"This application will create UMDH memory snapshots in a loop every $IntervalMinutes minute(s) $Iterations times."
""
"--- Parameters:"
"Current working directory: $WorkingDir"
"Dump path: $DumpPath"
"Subfolder name: $SubfolderName"
"Path to UMDH: $FilePathUmdh"
"Interval (minutes): $IntervalMinutes"
"Iterations: $Iterations"
"Create diffs: $CreateDiffs"
"_NT_SYMBOL_PATH: $Env:_NT_SYMBOL_PATH"
""
"--- Performing validations ..."

# Validates if symbols paths are reachable
'\\build\symbols','\\builddrv.estos.de\build' |
	ForEach-Object {
		if (Test-Path $_) {
			Write-Host "OK: $_" -ForegroundColor Green
		} else {
			Write-Host "FAIL: $_" -ForegroundColor Red
		}
	}

# Check if IntervalMinutes was provided
if (-not $PSBoundParameters.ContainsKey('IntervalMinutes')) {
    Write-Warning "Please provide the interval in minutes as a parameter! Example: .\\snapshotloop.ps1 -IntervalMinutes 5"
    exit 1
}

# Check for administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run with administrative privileges!"
    exit 1
}

# Create subfolder with timestamp name
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$DumpPath = "$(Join-Path $DumpPath $SubfolderName)-$timestamp"
if (-not (Test-Path $DumpPath)) {
	New-Item -ItemType Directory -Path $DumpPath | Out-Null
	Write-Host "Created dump folder: $DumpPath"
} else {
	Write-Host "Dump folder already exists: $DumpPath"
}


"Validations passed."
""
"--- Starting snapshot loop ..."
""

$dumpCreateCounter = 1

$currentDumpFile = ""
$lastDumpFile = ""

# Diff creation jobs which run in the background
$diffJobs = @()

while ($Iterations -ge $dumpCreateCounter) {
	$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
	$DumpFilePath = Join-Path $DumpPath "dump_$($dumpCreateCounter.ToString('0000'))-$SubfolderName-$timestamp.dmp"
	
	# Create dump filename and dump
	$currentDumpFile = $DumpFilePath
	"Create dump to with: $FilePathUmdh -pn:EUCSrv.exe -f:$DumpFilePath"
	& $FilePathUmdh -pn:EUCSrv.exe -f:$DumpFilePath

	"Create process info"
	$processInfoCommand = "Get-Process EUCSrv | Select-Object ProcessName, Id, WorkingSet64, HandleCount | ConvertTo-Json"
	Write-Host $processInfoCommand -ForegroundColor Cyan
	$processInfo = Get-Process EUCSrv | Select-Object ProcessName, Id, WorkingSet64, HandleCount | ConvertTo-Json
	$processInfoFilePath = Join-Path $DumpPath "processinfo_$($dumpCreateCounter.ToString('0000'))-$SubfolderName-$timestamp.json"
	$processInfo | Out-File -FilePath $processInfoFilePath -Encoding utf8
	"Process info saved to $processInfoFilePath"
	""

	# In case more then 2 diffs are to be created, start a background job to create the diff
    if ($dumpCreateCounter -gt 1) {
		$DiffFilePath = Join-Path $DumpPath "diff_$($dumpCreateCounter - 1).diff"
		$diffJob = Start-Job -ScriptBlock { 
			param ($ParamFilePathUmdh, $ParamLastDumpFile, $ParamCurrentDumpFile, $ParamDiffFilePath, $ParamWorkingDir)
			Set-Location $ParamWorkingDir
			"Create diff in background job: $ParamFilePathUmdh $ParamLastDumpFile $ParamCurrentDumpFile -f:$ParamDiffFilePath"
			& $ParamFilePathUmdh $ParamLastDumpFile $ParamCurrentDumpFile "-f:$ParamDiffFilePath"
		} -ArgumentList $FilePathUmdh, $LastDumpFile, $CurrentDumpFile, $DiffFilePath, $WorkingDir

		# Store the job so we can wait for it later
		$diffJobs += $diffJob
	}

	$lastDumpFile = $currentDumpFile
    $dumpCreateCounter++
	if ($Iterations -ge $dumpCreateCounter) {
		Write-Host "Waiting $IntervalMinutes minutes until the next iteration ..."
		""
		Start-Sleep -Seconds ($IntervalMinutes * 60)
	}
}

"All dumps created. Waiting for diff jobs to complete ..."
# Wait for all diff jobs to complete
if ($diffJobs.Count -eq 0) {
	Write-Host "No diff jobs were created."
} else {
	Wait-Job $diffJobs | Receive-Job | Out-Default
}
"All diff jobs completed."
