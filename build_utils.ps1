# Build Powershell collection object from vagrant CLI
function Get-VagrantBoxes
{
    $matches = vagrant box list | Select-String -Pattern '(\S+)\s+\((\w+), ([\d.]+)\)' -AllMatches

    $boxes = @()
    foreach ($box in $matches)
    { 
        $boxes += [pscustomobject] @{
            "Vendor"   = $box.Matches.groups[1].value
            "Provider" = $box.Matches.groups[2].value
            "Version"  = $box.Matches.groups[3].value
        }
    }

    return $boxes
}

# Test of Vagrant Box is installed
function Test-VagrantBoxInstalled 
{
    [CmdletBinding()]
    Param
    (
        [string] $vendor,
        [string] $provider
    )

    return $null -ne (Get-VagrantBoxes | where {$_.Vendor -eq $vendor -and $_.Provider -eq $provider})
}

# Clone/Update Git repo
function Get-GitRepository
{
    [CmdletBinding()]
    Param
    (
        [string] $RepoPath,
        [string] $RepoURL
    )

    if ( (-not (Test-Path -Path $RepoPath)) )
    {
        & git @('clone',$RepoURL, $RepoPath)
    }
    else
    {
        & git @('-C',$RepoPath,'pull')
    }
}


# Run pester tests in a background job
function Invoke-PesterJob
{
    [CmdletBinding(DefaultParameterSetName = 'LegacyOutputXml')]
    param(
        [Parameter(Position=0,Mandatory=0)]
        [Alias('Path', 'relative_path')]
        [object[]]$Script = '.',

        [Parameter(Position=1,Mandatory=0)]
        [Alias("Name")]
        [string[]]$TestName,

        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit,

        [Parameter(Position=3,Mandatory=0, ParameterSetName = 'LegacyOutputXml')]
        [string]$OutputXml,

        [Parameter(Position=4,Mandatory=0)]
        [Alias('Tags')]
        [string[]]$Tag,

        [string[]]$ExcludeTag,

        [switch]$PassThru,

        [object[]] $CodeCoverage = @(),

        [Switch]$Strict,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [string] $OutputFile,

        [Parameter(ParameterSetName = 'NewOutputSet')]
        [ValidateSet('LegacyNUnitXml', 'NUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        [Switch]$Quiet,

        [object]$PesterOption
    )

    $params = $PSBoundParameters
    
    Start-Job -ScriptBlock { Set-Location $using:pwd; Invoke-Pester @using:params } |
    Receive-Job -Wait -AutoRemoveJob
}


# Pipe output back to current session
# Invoke-PesterJob -PassThru | ConvertFrom-PesterOutputObject
function ConvertFrom-PesterOutputObject {
  param (
    [parameter(ValueFromPipeline=$true)]
    [object]
    $InputObject
  )
  begin {
    $PesterModule = Import-Module Pester -Passthru
  }
  process {
    $DescribeGroup = $InputObject.testresult | Group-Object Describe
    foreach ($DescribeBlock in $DescribeGroup) {
      $PesterModule.Invoke({Write-Screen $args[0]}, "Describing $($DescribeBlock.Name)")
      $ContextGroup = $DescribeBlock.group | Group-Object Context
      foreach ($ContextBlock in $ContextGroup) {
        $PesterModule.Invoke({Write-Screen $args[0]}, "`tContext $($subheader.name)")
        foreach ($TestResult in $ContextBlock.group) {
          $PesterModule.Invoke({Write-PesterResult $args[0]}, $TestResult)
        }
      }
    }
    $PesterModule.Invoke({Write-PesterReport $args[0]}, $InputObject)
  }
}

<#
.Example
    Import-Module -Name BuildHelpers
    Set-BuildEnvironment
    
    $ModuleInfo = @{ 
        RepoName   = 'PoshRepo'
        RepoPath   = '\\server\PoshRepo'
        ModuleName = 'BuildHelpersTest'
        ModulePath = '.\BuildHelpersTest.psd1'
    }    

    Publish-SMBModule @ModuleInfo
#>
function Publish-SMBModule
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string] $RepoName,

        [Parameter(Mandatory=$true)]
        [string] $RepoPath,

        [Parameter(Mandatory=$true)]
        [string] $ModuleName,

        [Parameter(Mandatory=$true)]
        [string] $ModulePath     
    )

    # Resister SMB Share as Repository
    if(!(Get-PSRepository -Name $RepoName -ErrorAction SilentlyContinue))
    {
        Register-PSRepository -Name $RepoName -SourceLocation $RepoPath -InstallationPolicy Trusted
    }

    # Update Existing Manifest
    # - Source Manifest controls Major/Minor
    # - Jenkins Controls Build Number.
    if(Find-Module -Repository $RepoName -Name $ModuleName -ErrorAction SilentlyContinue)
    {
        $version = (Get-Module -FullyQualifiedName $ModulePath -ListAvailable).Version | Select Major, Minor
        $newVersion = New-Object Version -ArgumentList $version.major, $version.minor, $ENV:BHBuildNumber
        Update-ModuleManifest -Path $ModulePath -ModuleVersion $newVersion
    }

    # Publish ModuleInfo
    # - Fails if nuget install needs confirmation in NonInteractive Mode.
    try 
    {
        $env:PSModulePath += ";$PSScriptRoot"
        Publish-Module -Repository $RepoName -Name $ModuleName    
    }
    catch [System.Exception] 
    {
        Write-Error "Publish Failed"
        throw($_.Exception)
    }

}