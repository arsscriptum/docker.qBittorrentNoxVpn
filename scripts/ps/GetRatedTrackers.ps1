#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   GetRatedTrackers.ps1                                                         ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $False)]
    [switch]$Update
)





$RatingScript = {
    param($Url,$DataDirectory)

    try{
        $TrackerExe = "D:\Dev\RateTorrentsTrackers\vs\bin\x64\Release\trackers-ratings.exe" 
        $Out = &"$TrackerExe" '-n' '-t' "$Url"
        $Data = $Out.Split('|') | % { $_.Trim() }
        $Url = $Data[0]
        $IsValid = ($Data[1] -eq 'valid')
        $NumPeers = $Data[2]
        $Latency = $Data[3].TrimEnd('seconds').Trim()
        $Description = $Data[4]
        Write-Verbose "$Url $NumPeers $Latency `"$Description`""
        [PsCustomObject]$Obj = [PsCustomObject]@{
            Url = $Url -as [string]
            IsValid = ($IsValid -as [bool])
            NumPeers = $NumPeers -as [int]
            Latency = $Latency -as [float]
            Description = $Description -as [string]
        }
        $str = ((New-Guid).Guid -as [string]).Substring(30)
        $FilePath = Join-Path "$DataDirectory" "$str"
        $FilePath += '.json'
        $JsonData = $Obj | ConvertTo-Json
        New-Item -Path "$FilePath" -ItemType file -Force | Out-Null
        Set-Content -Path "$FilePath" -Value "$JsonData" -Force
        Write-Output "Wrote $FilePath"
    }catch{
        Show-ExceptionDetails $_ -ShowStack
    }finally{
        Write-verbose "rated $Url"
}}.GetNewClosure()

[scriptblock]$RatingScriptBlock = [scriptblock]::create($RatingScript) 


function Wait-AllJobs {
    # Get all running jobs
    $jobs = Get-Job | Where-Object { $_.State -eq 'Running' }
    
    if ($jobs.Count -eq 0) {
        Write-Host "No running jobs to wait for." -ForegroundColor Green
        return
    }

    Write-Host "Waiting for jobs to complete..." -ForegroundColor Yellow -NoNewLine

    # Wait for jobs to finish
    foreach ($job in $jobs) {
        $jobres = Wait-Job -Id $job.Id
    }


    Write-Host "All jobs completed." -ForegroundColor Green
}

function Get-DateTimeDirectoryName {
    # Define the format for the directory name
    $format = "yyyy-MM-dd_HH-mm-ss"

    # Get the current date and time in the specified format
    $directoryName = Get-Date -Format $format

    # Return the formatted directory name
    return $directoryName
}

function Get-RatedTrackers{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $False)]
        [string]$Path,
        [Parameter(Mandatory = $False)]
        [switch]$Force,
        [Parameter(Mandatory = $False)]
        [switch]$Asynchronous
    )
    try{
        $RootPath = (Resolve-Path ".." -ErrorAction Stop).Path
        $BinPath = (Resolve-Path "$RootPath\vs\bin\x64\Release" -ErrorAction Stop).Path
        $ExePath = Join-Path $BinPath 'trackers-ratings.exe'
        $DataDirectory = (Resolve-Path "$RootPath\data" -ErrorAction Stop).Path

        if(Test-Path "$Path"){
            Write-Host "File `"$Path`" already exists." -NoNewLine -f DarkCyan
            if($Force){
                Write-Host "overwriting" -f DarkYellow
                New-Item -Path "$Path" -ItemType file -Force | Out-Null
            }else{
                Write-Host "exiting." -f DarkRed
            }
        }

        if($Asynchronous){
             Get-Job | Remove-Job -Force
             $DataDirectory = Join-Path $DataDirectory (Get-DateTimeDirectoryName)
             New-Item -Path "$DataDirectory" -ItemType "directory" -Force -ErrorAction Ignore | Out-Null
            Write-Host "DataDirectory $DataDirectory" -f DarkYellow
        }

        [System.Collections.ArrayList]$TrackersResults = [System.Collections.ArrayList]::new()
        $TmpFile = "$ENV:Temp\trackers.txt"
        $ProgressPreference ='SilentlyContinue'
        $Url = "https://raw.githubusercontent.com/ngosang/trackerslist/refs/heads/master/trackers_all_ip.txt"

        $Res = Invoke-WebRequest -Uri $Url -SkipCertificateCheck -OutFile $TmpFile -Passthru
        $StatusCode = $Res.StatusCode
        if($StatusCode -ne 200){ throw "Error $_" }
        [string[]]$Lines = Get-Content -Path "$TmpFile"
        $LinesCount = 0
        if(Test-Path "$ExePath"){
            $index=0
            ForEach($line in $Lines){
                if([string]::IsNullOrEmpty($line)) { continue; }
                $LinesCount++
            }
            Write-Host "Start rating trackers ($LinesCount total)" -f DarkCyan
            ForEach($line in $Lines){
                if([string]::IsNullOrEmpty($line)) { continue; }
                $index++
               
                if($Asynchronous){
                    $JobName = ((New-Guid).Guid -as [string]).Substring(30)
                    $jobby = Start-Job -Name $JobName -ScriptBlock $RatingScriptBlock -ArgumentList ($line,$DataDirectory)
                    $strlog = "[{0:d3}/{1:d3}] testing `"{2}`". job is {3}" -f $index,$LinesCount,$line,$JobName 
                    Write-Host $strlog -f DarkCyan
                }else{
                    Write-Verbose "testing `"$line`" "
                    $Out = &"$ExePath" '-n' '-t' "$line"
                    Write-Verbose "`"$ExePath`" '-n' '-t' `"$line`""
                    $Data = $Out.Split('|') | % { $_.Trim() }
                    $Url = $Data[0]
                    $IsValid = ($Data[1] -eq 'valid')
                    $NumPeers = $Data[2]
                    $Latency = $Data[3].TrimEnd('seconds').Trim()
                    $Description = $Data[4]
                    Write-Verbose "$Url $NumPeers $Latency `"$Description`""
                    [PsCustomObject]$Obj = [PsCustomObject]@{
                        Url = $Url -as [string]
                        IsValid = ($IsValid -as [bool])
                        NumPeers = $NumPeers -as [int]
                        Latency = $Latency -as [float]
                        Description = $Description -as [string]
                    }
                    [void]$TrackersResults.Add($Obj)
                }
            }
        }else{
            throw "missing trackers-ratings.exe binary"
        }
        if($Asynchronous){
            Wait-AllJobs
            Write-Host "parsing json files..."
            $AllJsonFiles = Get-ChildItem -Path "$DataDirectory" -Filter "*.json"
            ForEach($file in $AllJsonFiles.Fullname){
                $JsonItem = Get-Content $file | ConvertFrom-Json
                [void]$TrackersResults.Add($JsonItem)
            }
        }
        $AllData = $TrackersResults | ConvertTo-Json
        Write-Host "saving to `"$Path`""
        Set-Content -PAth "$Path" -Value "$AllData"
        $TrackersResults 
    }catch{
        Write-Error "$_"
    }
}



<#

### Key Recommendations**
- **If Peers are Most Important**:
  - Increase `Weight_Peers` (e.g., 0.8) and reduce `Weight_Latency` (e.g., 0.2).
- **If Latency is Most Important**:
  - Increase `Weight_Latency` (e.g., 0.7) and reduce `Weight_Peers` (e.g., 0.3).


  
### **1. Properties to Consider**
1. **Number of Peers (Availability)**:
   - **Why it matters**: A high number of peers usually indicates a healthy and popular tracker, which can improve torrent availability and download speed.
   - **Drawback**: Some trackers may list many peers, but they could be unreliable or slow.

2. **Latency (Responsiveness)**:
   - **Why it matters**: Low latency means faster communication with the tracker, which can speed up finding peers and starting downloads.
   - **Drawback**: A low-latency tracker might not provide many peers, limiting its usefulness.

---

### **2. Weighing the Factors**
The relative importance of peers vs. latency depends on your priorities:
- **For Download Speed**:
  - Prioritize **number of peers**, as more peers increase the chances of faster downloads.
- **For Real-Time Applications**:
  - Prioritize **latency**, as a responsive tracker quickly connects you to peers.

---

### **3. Quality Score Formula**
You can calculate a weighted score for each tracker to balance peers and latency:

#### **Formula**
```plaintext
Quality Score = (Weight_Peers * Normalized_Peers) - (Weight_Latency * Normalized_Latency)
```

#### **Steps to Compute**:
1. **Normalize Values**:
   - Convert peers and latency into a scale of 0 to 1.
     - Normalized Peers = `(Peers - Min_Peers) / (Max_Peers - Min_Peers)`
     - Normalized Latency = `(Latency - Min_Latency) / (Max_Latency - Min_Latency)`

2. **Set Weights**:
   - Assign weights based on importance:
     - Example: `Weight_Peers = 0.7`, `Weight_Latency = 0.3`.

3. **Calculate Score**:
   - Use the normalized values and weights in the formula.

#>

if($Update){
    $trackers = Get-RatedTrackers -Verbose -Path "d:\Tmp\trackers.json" -Force -Asynchronous
}

$trackers = Get-Content "d:\Tmp\trackers.json" | ConvertFrom-Json
# Define weights for peers and latency
$Weight_Peers = 0.7
$Weight_Latency = 0.3

# Find Min and Max values for normalization
$MinPeers = ($trackers | Measure-Object -Property NumPeers -Minimum).Minimum
$MaxPeers = ($trackers | Measure-Object -Property NumPeers -Maximum).Maximum
$MinLatency = ($trackers | Measure-Object -Property Latency -Minimum).Minimum
$MaxLatency = ($trackers | Measure-Object -Property Latency -Maximum).Maximum

# Function to normalize a value
function Normalize-Value {
    param (
        [float]$Value,
        [float]$Min,
        [float]$Max
    )
    if ($Max -eq $Min) {
        return 1.0 # Avoid division by zero, assume normalized value of 1
    }
    return ($Value - $Min) / ($Max - $Min)
}

$trackers = $trackers | where IsValid -eq $True

# Calculate quality score for each tracker
$trackers | ForEach-Object {
    $NormalizedPeers = Normalize-Value -Value $_.NumPeers -Min $MinPeers -Max $MaxPeers
    $NormalizedLatency = Normalize-Value -Value $_.Latency -Min $MinLatency -Max $MaxLatency

    # Calculate quality score
    $QualityScore = ($Weight_Peers * $NormalizedPeers) - ($Weight_Latency * $NormalizedLatency)

    # Add the quality score to the object
    $_ | Add-Member -MemberType NoteProperty -Name QualityScore -Value $QualityScore
}

# Display the results sorted by QualityScore
$trackers | Sort-Object -Property QualityScore -Descending | ForEach-Object {
    [PSCustomObject]@{
        Url          = $_.Url
        IsValid      = $_.IsValid
        NumPeers     = $_.NumPeers
        Latency      = $_.Latency
        Description  = $_.Description
        QualityScore = $_.QualityScore
    }
}



# Calculate the average Latency and NumPeers
$AverageLatency = ($trackers | Measure-Object -Property Latency -Average).Average
$AverageNumPeers = 8#($trackers | Measure-Object -Property NumPeers -Average).Average

# Filter the entries that are above the average NumPeers and below the average Latency
$aboveAverageTrackers = $trackers | Where-Object NumPeers -gt 8


# Display the results

# Output the calculated averages for reference
Write-Host "Average Latency: $AverageLatency ms"
Write-Host "Average NumPeers: $AverageNumPeers"

$aboveAverageTrackers | Sort-Object -Property QualityScore -Descending
