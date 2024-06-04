if (-not (Test-Path C:\Logs)) {
        New-Item -ItemType Directory -Path C:\Logs | Out-Null
    }

$logFile = "C:\Logs\Update_log.txt"

$StoppedComputer = $env:COMPUTERNAME

if ($StoppedComputer -eq "MSP2C060" -or $StoppedComputer -eq "") {
    exit
}

if (Test-Path $logFile) {
    $fileSize = (Get-Item $logFile).length
    $sizeLimit = 5 * 1MB

    if ($fileSize -gt $sizeLimit) {
        Remove-Item $logFile -Force
    }
}

"psUpdate.ps1 Script Started    - $(Get-Date)" | Out-File -Append $logFile

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$xcopyArgs1 = @("/c", "/q", "/s", "/e", "/k", "/h", "/y", "/d", "/v")
if (-not (Test-Path C:\temp\icon.ico)) {
        xcopy "\\fscloud.io\dfsroot\data\fileshare\Airport_Deployment\psScripts\Icon.ico" C:\temp $xcopyArgs1
    }

# Create hashtable to share data between runspaces
$syncHash = [hashtable]::Synchronized(@{})
$syncHash.Halt = $false

# Define progress bar GUI window
$form = New-Object Windows.Forms.Form
$form.Text = "File Update"
$form.Width = 500
$form.Height = 150
$form.StartPosition = 'Manual'
$form.Location = New-Object System.Drawing.Point(712,800)

$iconPath = "C:\Temp\Icon.ico"
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)

$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Width = 450
$progressBar.Height = 30
$progressBar.Top = 50
$progressBar.Left = 10
$form.Controls.Add($progressBar)

# $cancelButton = New-Object Windows.Forms.Button
# $cancelButton.Text = "Cancel"
# $cancelButton.Top = 90
# $cancelButton.Left = 10
# $cancelButton.Add_Click({
#     $syncHash.Halt = $true
#     $runspace.Close()
#     $form.Close()
# })
# $form.Controls.Add($cancelButton)
$form.Add_FormClosing({
    $syncHash.Halt = $true
    $runspace.Close()
})

$label = New-Object Windows.Forms.Label
$label.Text = "Starting..."
$label.Width = 450
$label.Height = 30
$label.Top = 10
$label.Left = 10
$form.Controls.Add($label)

# Main Update.bat script in PS form
$taskScript = {
    param($syncHash)

    $logFile = "C:\Logs\Update_log.txt"

    function Update-Progress {
        param (
            [Parameter(Mandatory = $true)]
            [int]$increment,

            [Parameter(Mandatory = $false)]
            [string]$status
        )

        $global:currentProgress += $increment
        $syncHash.ProgressBarValue = [Math]::Min(100, $global:currentProgress)
        $syncHash.Status = $status
    }

    Update-Progress -increment 7 -status "Checking username..."

    if (-not $env:USERNAME) {
        Start-Process -FilePath "\\fscloud.io\dfsroot\data\fileshare\Airport_Deployment\Scripts\refresh_environment.bat" -NoNewWindow -Wait
        if (-not $env:USERNAME) { return }
    }

    $UNAME = $env:USERNAME.Substring(3,3)
    Update-Progress -increment 7 -status "Checking user type..."

    if ($UNAME -ieq "vdi") { 
        # VDI code goes here
    }

    $dirs = @(
        "c:\Apps",
        "c:\Apps\eDesktop",
        "c:\Apps\eDesktop\Taskbar",
        "C:\Apps\CLA",
        "C:\Apps\ps",
        "C:\Apps\eDesktop\AppLaunch",
        "C:\Apps\eDesktop\Images",
        "C:\Apps\eDesktop\Apps",
        "C:\Apps\eDesktop\Apps\eBrowser",
        "C:\Apps\eDesktop\Apps\Amadeus",
        "C:\Apps\eDesktop\Apps\Amadeus\Updates",
        "C:\Apps\eDesktop\Tools",
        "C:\Apps\CUPPSFS",
        "C:\Apps\SERIALDEV"
    )

    Update-Progress -increment 7 -status "Checking directories..."

    $dirs | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ | Out-Null
        }
    }

    $airport = $env:COMPUTERNAME.Substring(0,3)
    if ($airport -eq "GRR") { $airport = "XXX" }
    if ($airport -eq "SRQ") { $airport = "ZZZ" }

    $batchFiles = @(
        #"\\fscloud.io\dfsroot\data\fileshare\Apps\TaskbarFS\update_TaskbarFS.bat",
        "\\fscloud.io\dfsroot\data\fileshare\Apps\CLA\update_CLA.bat",
        "\\fscloud.io\dfsroot\data\fileshare\Apps\CUPPSFS\update_CUPPS.bat",
        "\\fscloud.io\dfsroot\data\fileshare\Apps\SERIALDEV\update_SERIALDEV.bat"
    )

    foreach ($batch in $batchFiles) {
        $status = "Running $(Split-Path -Leaf $batch) check..."
        Update-Progress -increment 7 -status $status

        $logFilePath = "C:\Logs\$(Split-Path -Leaf $batch).log"
        Start-Process -FilePath $batch -NoNewWindow -Wait # -RedirectStandardOutput $logFile
    }

    $xcopyArgs = @("/c", "/q", "/s", "/e", "/k", "/h", "/y", "/d", "/v")
    $sources = @(
        "\\fscloud.io\dfsroot\data\fileshare\Sites\$airport\CLA\*.*",
        "\\fscloud.io\dfsroot\data\Fileshare\Airport_Deployment\psScripts\Copied\*.*",
        "\\fscloud.io\dfsroot\data\fileshare\Airport_Deployment\Tools\*.*",
        "\\fscloud.io\dfsroot\data\Fileshare\Apps\eBrowser\*.*"
    )

    $destinations = @(
        "C:\Apps\CLA\",
        "C:\Apps\ps\",
        "C:\Apps\eDesktop\Tools\",
        "C:\Apps\eDesktop\Tools\eBrowser\"
    )

    for ($i = 0; $i -lt $sources.Length; $i++) {
        $status = "Checking files from $($sources[$i])..."
        Update-Progress -increment 7 -status $status
        xcopy $sources[$i] $destinations[$i] @xcopyArgs
    }

    Update-Progress -increment 7 -status "Checking launch files..."
    "Starting launch file download  - $(Get-Date)" | Out-File -Append $logFile
    Start-Process -FilePath "cmd.exe" -ArgumentList "/C powershell.exe -ExecutionPolicy Bypass -File \\fscloud.io\dfsroot\data\fileshare\Apps\Download\Download_Launch_Files.ps1 > C:\Apps\eDesktop\DownloadLaunchFiles_output.txt" -NoNewWindow -Wait
    "Finishing launch file download - $(Get-Date)" | Out-File -Append $logFile

    "Starting app file download     - $(Get-Date)" | Out-File -Append $logFile
    Update-Progress -increment 7 -status "Checking airline applications..."
    Start-Process -FilePath "cmd.exe" -ArgumentList "/C powershell.exe -ExecutionPolicy Bypass -File \\fscloud.io\dfsroot\data\fileshare\Apps\Download\Download_AirlineApp.ps1 > C:\Apps\eDesktop\DownloadApps_output.txt" -NoNewWindow -Wait
    "Finishing app file download    - $(Get-Date)" | Out-File -Append $logFile

    if ($airport -eq "MSP") {
        xcopy \\MSP2C034\c$\Apps\eDesktop\Apps\LH C:\Apps\eDesktop\Apps\LH\ /c /q /s /e /k /h /y /v /d >> $logFile
    }

    $SYS=[string]"/M"
    $alteaSwipe="fullTrackData"

    $destinationPath = "C:\Apps\eDesktop\Apps\FI"

    if (Test-Path $destinationPath) {
        SETX FIMS1 $alteaSwipe $SYS >$NULL
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\WN"

    if (Test-Path $destinationPath) {
        SETX WNMS1 $alteaSwipe $SYS >$NULL
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\AC"

    if (Test-Path $destinationPath) {
        SETX ACMS1 $alteaSwipe $SYS >$NULL
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\B6"

    if (Test-Path $destinationPath) {
        "Copying B6 taconfig file       - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\B6\*.* $destinationPath\Interact\v12.1\app\ /c /q /s /e /k /h /y /v >> $logFile
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\G4"

    if (Test-Path $destinationPath) {
        "Copying G4 GoNow config file   - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\G4\*.* $destinationPath\GoNow\CUPPS\4.7.3.1\ /c /q /s /e /k /h /y /v >> $logFile
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\F9"

    if (Test-Path $destinationPath) {
        "Copying F9 GoNow config files  - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\F9\Prodr4x\*.* $destinationPath\GoNow\4.7.3.1\Prodr4x\ /c /q /s /e /k /h /y /v >> $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\F9\Prodr4y\*.* $destinationPath\GoNow\4.7.3.1\Prodr4y\ /c /q /s /e /k /h /y /v >> $logFile
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\SY"

    if (Test-Path $destinationPath) {
        "Copying SY GoNow config file   - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\SY\*.* $destinationPath\GoNow\4.4.4.3\prod4x\ /c /q /s /e /k /h /y /v >> $logFile
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\NK"

    if (Test-Path $destinationPath) {
        "Copying NK GoNow config file   - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\NK\*.* $destinationPath\GoNow\4.2.1.6\prodr4x\ /c /q /s /e /k /h /y /v >> $logFile
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\EI"

    if (Test-Path $destinationPath) {
        "Copying EI EI-RN config file   - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\EI\*.* $destinationPath\20.0\Address\ /c /q /s /e /k /h /y /v >> $logFile
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\UA"

    if (Test-Path $destinationPath) {
        "Copying UA config files        - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\UA\*.* $destinationPath\UA-SUITE\1.0\InfoConnect\9.1b\ /c /q /s /e /k /h /y /v >> $logFile
    }

    $destinationPath = "C:\Apps\eDesktop\Apps\LH"

    if (Test-Path $destinationPath) {
        "Copying LH installation file   - $(Get-Date)" | Out-File -Append $logFile
        xcopy \\fscloud.io\dfsroot\data\Fileshare\Sites\$airport\Apps\LH\*.* $destinationPath /c /q /s /e /k /h /y /v >> $logFile
    }

    $global:currentProgress = 100
    Update-Progress -increment 0 -status "Completed!"
    "psUpdate.ps1 Script Finished   - $(Get-Date)" | Out-File -Append $logFile
    "****************************************************" | Out-File -Append $logFile
}

# Create and start runspace for download tasks
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = "STA"
$runspace.Open()
$psCmd = [powershell]::Create().AddScript($taskScript).AddArgument($syncHash)
$psCmd.Runspace = $runspace
$asyncResult = $psCmd.BeginInvoke()

# Define code for GUI updates
$updateGuiScript = {
    param($syncHash, $progressBar, $label)
    do {
        Start-Sleep -Milliseconds 100
        $progressBar.Value = $syncHash.ProgressBarValue
        $label.Text = $syncHash.Status
    } while ($true)
}

# Create and start the runspace for GUI updates
$updateGuiRunspace = [runspacefactory]::CreateRunspace()
$updateGuiRunspace.ApartmentState = "STA"
$updateGuiRunspace.Open()
$updateGuiPsCmd = [powershell]::Create().AddScript($updateGuiScript).AddArgument($syncHash).AddArgument($progressBar).AddArgument($label)
$updateGuiPsCmd.Runspace = $updateGuiRunspace
$updateGuiAsyncResult = $updateGuiPsCmd.BeginInvoke()

$form.ShowDialog()

$psCmd.EndInvoke($asyncResult)
$runspace.Close()

$updateGuiPsCmd.Stop()
$updateGuiPsCmd.EndInvoke($updateGuiAsyncResult)
$updateGuiRunspace.Close()
