[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$TargetFolder,

    [Parameter(Position = 1)]
    [string]$DriverExtension,

    [Parameter(Position = 2)]
    [string]$packageName = "linq2db.LINQPad"
)

# ===== Global mutex to serialize execution =====
$mutexName = "Global\PackScriptMutex";
$createdNew = $false;
$mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$createdNew)
try {
    Write-Verbose "Waiting for mutex..."
    $mutex.WaitOne() | Out-Null;

    Write-Verbose "Mutex acquired"
    
    # ===== SCRIPT BODY STARTS HERE =====
    Write-Output "Packing [$DriverExtension]"
    Write-Verbose "Set path variables safely using Join-Path";
    $releaseFolder = Join-Path $TargetFolder "..\..\..\..\releases"
    $releaseFolder = [System.IO.Path]::GetFullPath($releaseFolder);
    
    $resourcesFolder = Join-Path $TargetFolder "..\..\..\..\..\Build"
    $resourcesFolder = [System.IO.Path]::GetFullPath($resourcesFolder);
    
    Write-Verbose "Release Folder: [$releaseFolder]";
    Write-Verbose "Resources Folder: [$resourcesFolder]";
    
    $packageFileExt = "$($packageName).$($DriverExtension)";
    $zipPath = Join-Path $releaseFolder "$($packageFileExt).zip";
    $finalPath = Join-Path $releaseFolder $packageFileExt;
    Write-Verbose "Zip Path: [$zipPath]";
    
    Write-Verbose "Delete existing target files if they exist";
    New-Item -Path $releaseFolder -ItemType Directory -Force | Out-Null;
    
    if (Test-Path $finalPath) { 
        Remove-Item -Path $finalPath -Force;
    }
    
    if (Test-Path $zipPath) { 
        Remove-Item -Path $zipPath -Force;
    }
    
    # LINQPad 5 driver archive generation
    if ($DriverExtension -eq "lpx") {
        Write-Output "[$DriverExtension]-----> Step 1: Remove resource satellite assemblies safely";
        $languages = @("cs", "de", "es", "fr", "it", "ja", "ko", "pl", "pt", "pt-BR", "ru", "tr", "zh-Hans", "zh-Hant")
        foreach ($currentLanguage in $languages) {
            $currentLanguageFolder = Join-Path $TargetFolder $currentLanguage
            if (Test-Path $currentLanguageFolder) { 
                Remove-Item -Path $currentLanguageFolder -Force -Recurse 
            }
        }
    
        Write-Output "[$DriverExtension]-----> Step 2: Remove not needed files safely";
        $files = @("linq2db.*.xml", "*.pdb");
        $fullPaths = $files.ForEach({ 
            Join-Path -Path $TargetFolder -ChildPath $_;
        });    
        Get-ChildItem -Path $fullPaths -ErrorAction SilentlyContinue | Remove-Item -Force;
       
        Write-Output "[$DriverExtension]-----> Step 3: Create zip with all contents of the target folder";
        Get-ChildItem -Path "$TargetFolder*" | Compress-Archive -DestinationPath $zipPath -Force;
        
        Write-Output "[$DriverExtension]-----> Step 4: Update zip with resource files";
        $files = @("Connection.png", "FailedConnection.png", "header.xml");
        $fullPaths = $files.ForEach({ 
            Join-Path -Path $resourcesFolder -ChildPath $_;
        });        
        Get-ChildItem -Path $fullPaths | Compress-Archive -Update -DestinationPath $zipPath;
    }
    
    # LINQPad 7-8 driver archive generation
    if ($DriverExtension -eq "lpx6") {
        Write-Output "[$DriverExtension]-----> Step 1: Create zip with specific driver files";
        $files = @( "$($packageName).dll", "$($packageName).deps.json" );
        $fullPaths = $files.ForEach({ 
            Join-Path -Path $TargetFolder -ChildPath $_;
        });    
        Get-ChildItem -Path $fullPaths | Compress-Archive -DestinationPath $zipPath -Force;
    
        Write-Output "[$DriverExtension]-----> Step 2: Update zip with resource files";
        $files = @("Connection.png", "FailedConnection.png");
        $fullPaths = $files.ForEach({ 
            Join-Path -Path $resourcesFolder -ChildPath $_;
        });    
        Get-ChildItem -Path $fullPaths | Compress-Archive -Update -DestinationPath $zipPath;
    }
    
    # Rename the final file (removes the .zip extension)
    if (Test-Path $zipPath) {
        if (Test-Path $packageFileExt) {
            Remove-Item -Path $packageFileExt -Force;
        }
        Rename-Item -Path $zipPath -NewName $packageFileExt;
    }
} finally {
    if ($mutex) {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
        Write-Verbose "Mutex released"
    }
}
