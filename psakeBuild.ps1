properties {
    $script = "$PSScriptRoot\TextFile.psd1"
    $server = $Server
    $repo = $Repo
}

Include ".\build_utils.ps1"

# Manual Tasks run from build.ps1
task default -depends JenkinsAnalyze, JenkinsTest
task Analyze -depends JenkinsAnalyze
task Test    -depends JenkinsAnalyze, JenkinsTest
task Deploy  -depends JenkinsAnalyze, JenkinsTest, JenkinsDeploy

task BuildEnvironment {
    exec {
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))  
        choco feature enable -n allowGlobalConfirmation
        choco install ruby --version 2.2.4 
        choco install ruby2.devkit virtualbox vagrant 
    }
    
    # Fails since path isnt reloaded after choco install
    # $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    exec { vagrant plugin install vagrant-winrm }

    exec { gem install test-kitchen kitchen-vagrant kitchen-dsc kitchen-pester winrm winrm-fs }

    # Install vagrant box if not installed
    $vendor = 'Windows2012R2WMF5'
    $provider = 'virtualbox'

    if(-not (Test-VagrantBoxInstalled -vendor $vendor -provider $provider))
    {
        exec { vagrant box add $vendor --provider $provider }
    }
    else
    {
        Write-Host "Box already installed"
    }
}

task UnitTest {
    Invoke-PesterJob ./Tests/Unit*
    
    # Optionally return results to session
    # Invoke-PesterJob ./Tests/Unit* -PassThru | ConvertFrom-PesterOutputObject
}

task JenkinsAnalyze {
        
    # Add current location to temp PSModulePath
    $env:psmodulepath += ";$PSScriptRoot\Modules"

    $saResults = Invoke-ScriptAnalyzer -Path $script -Severity @('Error', 'Warning') -Recurse -Verbose:$false
    if ($saResults) {
        $saResults | Format-Table  
        Write-Error -Message 'One or more Script Analyzer errors/warnings where found. Build cannot continue!'
    }
}

task JenkinsTest {
    # Run test-kitchen to build VM for integration tests
    exec { kitchen test --destroy always }
}

task JenkinsDeploy {

    $ModuleInfo = @{ 
        RepoName   = 'DSCGallery'
        RepoPath   = '\\testserver\DSCRepo\Gallery'
        ModuleName = 'TextFile'
        ModulePath = '.\TextFile.psd1'
    }    

    Publish-SMBModule @ModuleInfo
}