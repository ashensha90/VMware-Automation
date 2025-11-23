function Get-VMInventoryLicense
{
<#
.SYNOPSIS
    Retrieves vSphere license information from multiple vCenter servers
.DESCRIPTION
    Connects to vCenter servers listed in a CSV file and exports license information
.PARAMETER ConfigFile
    Path to CSV file containing vCenter connection details
.PARAMETER OutputFile
    Path to output CSV file for license information
.EXAMPLE
    Get-VMInventoryLicense -ConfigFile .\custviservers.csv
.NOTES
    CSV Format Required (custviservers.csv):
    viserver,username,password
    vcenter01.local,admin@vsphere.local,YourPassword
    vcenter02.local,admin@vsphere.local,YourPassword
    
    SECURITY NOTE: Consider using encrypted credentials instead of plain text passwords
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigFile = ".\custviservers.csv",
        
        [Parameter(Mandatory=$false)]
        [string]$OutputFile = ".\LicenseInformation.csv"
    )
    
    # Check if config file exists
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        Write-Host "`nPlease create a CSV file with the following format:" -ForegroundColor Yellow
        Write-Host "viserver,username,password" -ForegroundColor Cyan
        Write-Host "vcenter01.local,admin@vsphere.local,YourPassword" -ForegroundColor Cyan
        Write-Host "`nFor better security, consider using credential objects or encrypted files." -ForegroundColor Yellow
        return
    }
    
    $vSphereLicInfo = @()
    $viCntinfo = Import-Csv $ConfigFile
    
    foreach ($vi in $viCntInfo)
    {
        Write-Host "`nConnecting to: $($vi.viserver)" -ForegroundColor Cyan
        
        try {
            $convi = Connect-VIServer -Server $vi.viserver -Username $vi.username -Password $vi.password -ErrorAction Stop
            Write-Host "Successfully connected to $($vi.viserver)" -ForegroundColor Green
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Warning "Failed to connect to $($vi.viserver): $ErrorMessage"
            
            $details = @{
                Vcenter = $vi.viserver
                Connection = "Failed"
                Notes = $ErrorMessage
            }
     
            $vSphereLicInfo += New-Object PSObject -Property $details
            continue
        }

        # Get license information
        try {
            $ServiceInstance = Get-View ServiceInstance
            $LicenseMan = Get-View $ServiceInstance.Content.LicenseManager
            
            Write-Host "Retrieving license information..." -ForegroundColor Yellow
            
            Foreach ($License in $LicenseMan.Licenses) {
                $Details = "" | Select-Object vCenter, Name, Key, Total, Used, Information
                $Details.vCenter = $vi.viserver
                $Details.Name = $License.Name
                $Details.Key = $License.LicenseKey
                $Details.Total = $License.Total
                $Details.Used = $License.Used
                $Details.Information = $License.Labels | Select-Object -ExpandProperty Value
                $vSphereLicInfo += $Details
            }
            
            Write-Host "Retrieved $($LicenseMan.Licenses.Count) licenses from $($vi.viserver)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to retrieve license information from $($vi.viserver): $_"
        }
        
        # Disconnect from vCenter
        Disconnect-VIServer -Server * -Force -Confirm:$false
    }

    # Export to CSV
    if ($vSphereLicInfo.Count -gt 0) {
        $vSphereLicInfo | Select-Object vCenter, Name, Key, Total, Used, Information | 
            Export-Csv -NoTypeInformation $OutputFile
        
        Write-Host "`n=== License Report Complete ===" -ForegroundColor Green
        Write-Host "Total licenses retrieved: $($vSphereLicInfo.Count)" -ForegroundColor Yellow
        Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
        
        # Display summary
        $vSphereLicInfo | Format-Table vCenter, Name, Total, Used -AutoSize
    }
    else {
        Write-Warning "No license information was retrieved."
    }
}

# Main execution
Get-VMInventoryLicense
