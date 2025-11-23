# VMware PowerShell Automation Scripts

A collection of PowerShell scripts for VMware vSphere infrastructure automation, maintenance, and management. These scripts leverage VMware PowerCLI to automate common administrative tasks.

## 📋 Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Scripts Overview](#scripts-overview)
- [Usage Examples](#usage-examples)
- [Contributing](#contributing)
- [Disclaimer](#disclaimer)

## ✨ Features

- **Automated ESXi Patching** - Complete workflow for patching ESXi hosts with baseline compliance
- **Storage Management** - Identify orphaned VMDK files and free up datastore space
- **Monitoring & Reporting** - IOPS monitoring, license tracking, and inventory reports
- **Network Configuration** - VMKernel port group management and configuration
- **VM Operations** - Snapshot management, permission assignment, migration checks

## 🔧 Prerequisites

- **PowerShell**: Version 5.1 or higher (PowerShell 7+ recommended)
- **VMware PowerCLI**: Version 12.0 or higher
- **vSphere Access**: Appropriate permissions for the operations you intend to perform
- **Network Access**: Connectivity to vCenter Server and ESXi hosts

### Installing PowerCLI

```powershell
# Install VMware PowerCLI module
Install-Module -Name VMware.PowerCLI -Scope CurrentUser

# Allow execution of scripts (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Set PowerCLI configuration (optional)
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false
```

## 📂 Scripts Overview

### Patching & Maintenance

#### `Automate-ESXi-Patching.ps1`
Comprehensive ESXi host patching automation with baseline compliance checks.

**Features:**
- Creates and validates patch baselines
- Cluster-wide patching with sequential host processing
- Automatic maintenance mode management
- HA Admission Control handling
- SLP service verification
- Retry logic for failed hosts
- Exclude list for problematic hosts

**Usage:**
```powershell
.\Automate-ESXi-Patching.ps1
# Follow interactive prompts for:
# - Patch baseline date (YYYY/MM/DD)
# - Baseline name
# - Cluster name
# - ESXi host credentials
```

#### `test-maintenanceMode.ps1`
Checks ESXi host maintenance mode status and manages transitions.

---

### Storage Management

#### `findOrphanedVMDK.ps1`
Scans datastores to identify orphaned VMDK files not attached to any VM.

**Features:**
- Recursive datastore scanning
- Excludes snapshot and flat VMDK files
- Generates CSV report with file sizes and modification dates
- Helps identify reclaimable storage

**Configuration Required:**
Create a configuration file or modify the script with your environment details.

#### `removeOrphanedData.ps1`
Identifies and optionally removes orphaned folders and VMDK files.

**Features:**
- Safe discovery mode (default)
- Optional deletion with `-Delete` switch
- Supports pipeline input
- Author credit: Luc Dekens

**Usage:**
```powershell
# Discovery mode
Get-Datastore ds* | .\removeOrphanedData.ps1

# Delete mode (use with caution!)
.\removeOrphanedData.ps1 -Datastore "DatastoreName" -Delete
```

#### `get-SharedDisk.ps1`
Identifies VMs using shared disks (useful for clustering scenarios).

#### `getHardDiskSize.ps1`
Reports on VM hard disk sizes and provisioning types.

---

### Performance Monitoring

#### `get-IOPS-NFS.ps1`
Monitors IOPS for NFS datastores.

**Features:**
- Real-time IOPS monitoring
- Per-datastore metrics
- Useful for capacity planning

#### `get-IOPS-VMFS.ps1`
Monitors IOPS for VMFS datastores.

---

### Network Configuration

#### `VMKernalPortGroups.ps1`
Automates VMKernel port group creation and configuration from CSV input.

**Features:**
- Supports multiple VMKernel types (VMotion, Management, NFS, FT)
- VLAN configuration
- IP address assignment
- Bulk configuration from CSV

**CSV Format:**
```csv
Hostname,PortGroupName,VSwitch,New_IP,Subnet,New_VLAN,Label
esxi01.local,vMotion-PG,vSwitch0,192.168.1.10,255.255.255.0,100,VMotion
```

---

### VM Operations

#### `Create-snapshot.ps1`
Creates VM snapshots with customizable parameters.

#### `Get-PoweredOnOff.ps1`
Reports VM power state across the environment.

#### `giveVMPermission.ps1`
Assigns permissions to VMs for specific users or groups.

#### `CheckMigrationforVMs.ps1`
Validates VM migration readiness and compatibility.

---

### Reporting & Inventory

#### `get-AllLicenseInfo.ps1`
Generates comprehensive vSphere license information report.

**Features:**
- Multi-vCenter support
- License usage tracking
- Exports to CSV

**Configuration Required:**
Create `custviservers.csv` with your vCenter details:
```csv
viserver,username,password
vcenter01.local,administrator@vsphere.local,YourPasswordHere
```

**Security Note:** Store credentials securely. Consider using credential objects or encrypted files.

---

## 🚀 Usage Examples

### Example 1: Automated Patching Workflow
```powershell
# Run the patching script
.\Automate-ESXi-Patching.ps1

# When prompted:
# Date: 2024/12/01
# Baseline: December-2024-Patches
# Cluster: Production-Cluster
# Credentials: <ESXi root credentials>

# The script will:
# 1. Create baseline
# 2. Validate cluster
# 3. Process each host sequentially
# 4. Generate ExcludeHosts.txt for any failures
```

### Example 2: Finding Orphaned Storage
```powershell
# Connect to vCenter
Connect-VIServer -Server vcenter.local

# Scan for orphaned VMDKs
.\findOrphanedVMDK.ps1

# Review the generated report
Import-Csv .\OrphanedVMDK_new.csv | Format-Table
```

### Example 3: Bulk VMKernel Configuration
```powershell
# Prepare CSV file with network details
# Run the configuration script
.\VMKernalPortGroups.ps1

# The script reads from BO3VMKernal.csv and applies configurations
```

---

## 🔐 Security Best Practices

1. **Never commit credentials to Git**
   - Use external configuration files
   - Leverage credential managers (e.g., Azure Key Vault, CyberArk)
   - Use PowerShell credential objects with encrypted files

2. **Use credential encryption**
   ```powershell
   # Export encrypted credential
   Get-Credential | Export-Clixml -Path .\creds.xml
   
   # Import in script
   $cred = Import-Clixml -Path .\creds.xml
   ```

3. **Apply least privilege principle**
   - Use service accounts with minimal required permissions
   - Regularly audit script actions

4. **Test in non-production first**
   - Always validate scripts in lab environments
   - Use `-WhatIf` parameter where supported

---

## 📝 Configuration Files

Some scripts require external configuration files. **These files are NOT included in this repository** for security reasons.

### Required Files (create these yourself):

1. **custviservers.csv** - For `get-AllLicenseInfo.ps1`
   ```csv
   viserver,username,password
   vcenter.example.com,admin@vsphere.local,password123
   ```

2. **BO3VMKernal.csv** - For `VMKernalPortGroups.ps1`
   ```csv
   Hostname,PortGroupName,VSwitch,New_IP,Subnet,New_VLAN,Label
   esxi01,vMotion-PG,vSwitch0,10.0.0.10,255.255.255.0,100,VMotion
   ```

3. **ExcludeHosts.txt** - Created automatically by patching script
   - Lists hosts that failed patching
   - Allows script to skip problematic hosts on re-runs

---

## 🛠️ Troubleshooting

### Common Issues

**PowerCLI Module Not Found**
```powershell
Install-Module VMware.PowerCLI -Scope CurrentUser -Force
```

**Certificate Errors**
```powershell
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
```

**Timeout Errors During Patching**
- The patching script increases timeout to 1800 seconds automatically
- Check network connectivity to ESXi hosts
- Verify SSH is enabled on hosts

**Permission Denied Errors**
- Verify your account has appropriate vSphere permissions
- Some operations require administrator-level access

---

## 🤝 Contributing

Contributions are welcome! Please feel free to:
- Report bugs
- Suggest enhancements
- Submit pull requests

---

## ⚠️ Disclaimer

These scripts are provided "as-is" without warranty of any kind. Always:
- Test in non-production environments first
- Review and understand scripts before execution
- Maintain proper backups
- Follow your organization's change management procedures

**Use at your own risk.** The author is not responsible for any damage or data loss caused by the use of these scripts.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Ashen Perera**
- GitHub: [@ashensha90](https://github.com/ashensha90)
- LinkedIn: [Ashen Perera](https://www.linkedin.com/in/ashenshanaka/)

---

## 🙏 Acknowledgments

- VMware PowerCLI team for the excellent automation framework
- Script authors credited within individual files
- VMware community for sharing knowledge and best practices


