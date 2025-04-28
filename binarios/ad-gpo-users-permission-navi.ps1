#for the user brian



Import-Module GroupPolicy
Import-Module ActiveDirectory

# Variables
$GPOName = "Default Domain Policy"
$User = "4RJI-Mex1\Brian"

# Get GPO ID
$GPO = Get-GPO -Name $GPOName
$GPOID = $GPO.Id

# Build GPO DN
$GpoDN = "CN={$GPOID},CN=Policies,CN=System,DC=4rji,DC=local"

# Get current ACL
$Acl = Get-ADObject -Identity $GpoDN -Properties ntSecurityDescriptor
$SecurityDescriptor = $Acl.ntSecurityDescriptor

# Create new ACE
$Identity = New-Object System.Security.Principal.NTAccount($User)
$Ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $Identity,
    "WriteDacl",
    "Allow"
)

# Apply ACE
$SecurityDescriptor.AddAccessRule($Ace)
Set-ADObject -Identity $GpoDN -Replace @{ntSecurityDescriptor=$SecurityDescriptor}