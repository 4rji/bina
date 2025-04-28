Import-Module GroupPolicy
Import-Module ActiveDirectory

# VARIABLES
$GPOName = "Default Domain Policy"
$User = "4RJI-MEX1\BRIAN"            # <-- MAYÚSCULAS EN DOMINIO Y USUARIO

# GET GPO ID
$GPO = Get-GPO -Name $GPOName
$GPOID = $GPO.Id

# BUILD GPO DN
$GPODN = "CN={$GPOID},CN=Policies,CN=System,DC=4RJI,DC=LOCAL"  # <-- DC EN MAYÚSCULAS

# GET CURRENT ACL
$ACL = Get-ADObject -Identity $GPODN -Properties ntSecurityDescriptor
$SecurityDescriptor = $ACL.ntSecurityDescriptor

# CREATE NEW ACE
$Identity = New-Object System.Security.Principal.NTAccount($User)
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $Identity,
    "WriteDacl",
    "Allow"
)

# APPLY ACE
$SecurityDescriptor.AddAccessRule($ACE)
Set-ADObject -Identity $GPODN -Replace @{ntSecurityDescriptor=$SecurityDescriptor}
