#
# Purpose : List all orphaned vmdk on all datastores in vCenter
# Version: 1.1 (Sanitized for public release)
# Original Author: HJA van Bokhoven
# Modified: Parameterized credentials and vCenter connection

param(
    [Parameter(Mandatory=$true)]
    [string]$VCenterServer,
    
    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = ".\OrphanedVMDK_new.csv"
)

# Prompt for credentials if not provided
if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter vCenter credentials"
}

# Connect to vCenter
try {
    Write-Host "Connecting to vCenter: $VCenterServer" -ForegroundColor Yellow
    Connect-VIServer $VCenterServer -Credential $Credential -ErrorAction Stop
    Write-Host "Connected successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to vCenter: $_"
    exit 1
}

# Get all VMs and their disks
$arrUsedDisks = Get-VM | Get-HardDisk | %{$_.filename}
$arrDS = Get-Datastore
$OutArray = @()

Write-Host "Scanning datastores for orphaned VMDKs..." -ForegroundColor Yellow

Foreach ($strDatastore in $arrDS)
{
    $strDatastoreName = $strDatastore.name
    Write-Host "Processing datastore: $strDatastoreName" -ForegroundColor Cyan
    
    $ds = Get-Datastore -Name $strDatastoreName | %{Get-View $_.Id}
    $fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
    $fileQueryFlags.FileSize = $true
    $fileQueryFlags.FileType = $true
    $fileQueryFlags.Modification = $true
    
    $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $searchSpec.details = $fileQueryFlags
    $searchSpec.sortFoldersFirst = $true
    
    $dsBrowser = Get-View $ds.browser
    $rootPath = "["+$ds.summary.Name+"]"
    $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)
    
    $myCol = @()
    foreach ($folder in $searchResult)
    {
        foreach ($fileResult in $folder.File)
        {
            $file = "" | select Name, FullPath			
            $file.Name = $fileResult.Path
            $strFilename = $file.Name
            
            IF ($strFilename)
            {
                # Check if it's a VMDK file
                IF ($strFilename.Contains(".vmdk")) 
                {
                    # Exclude flat and delta VMDKs
                    IF (!$strFilename.Contains("-flat.vmdk"))
                    {
                        IF (!$strFilename.Contains("delta.vmdk"))		  
                        {
                            $strCheckfile = "*"+$file.Name+"*"
                            
                            # Check if VMDK is attached to any VM
                            IF ($arrUsedDisks -Like $strCheckfile)
                            {
                                # VMDK is in use, skip
                            }
                            ELSE 
                            {			 
                                # Orphaned VMDK found
                                $details = @{
                                    orphaned_VMDK = $strFilename
                                    Datastore = $strDatastoreName
                                    length = $fileresult.filesize
                                    Disk_Size_GB = [math]::Round($fileresult.filesize/1GB, 2)
                                    Last_Write_Time = $fileresult.modification
                                }
                                
                                $OutArray += New-Object PSObject -Property $details
                            }	         
                        }
                    }		  
                }
            }
        }
    }       
}

# Export results
Write-Host "`nExporting results to: $OutputFile" -ForegroundColor Yellow
$outarray | Export-Csv $OutputFile -NoTypeInformation

# Display summary
$totalOrphaned = $outarray.Count
$totalSizeGB = ($outarray | Measure-Object -Property Disk_Size_GB -Sum).Sum

Write-Host "`n=== Scan Complete ===" -ForegroundColor Green
Write-Host "Orphaned VMDKs found: $totalOrphaned" -ForegroundColor Yellow
Write-Host "Total size: $([math]::Round($totalSizeGB, 2)) GB" -ForegroundColor Yellow
Write-Host "Report saved to: $OutputFile" -ForegroundColor Green

# Disconnect from vCenter
Disconnect-VIServer -Server * -Force -Confirm:$false
