configuration TextFile
{
    #Import-DscResource -ModuleName PSDesiredStateConfiguration
    #Import-DscResource -Name MSFT_xRemoteFile -ModuleName xPSDesiredStateConfiguration

    Import-DscResource -ModuleName TextFile

    node $AllNodes.Where{$_.Role -eq "TextFile"}.NodeName
    {
        TextFile addTextFile
        {
            Ensure      = 'Present'
            FilePath    = 'c:\Temp\hello.txt'
            FileContent = 'Hello World!'
        }
    }
}

$configData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Role = 'TextFile'
        }
    )
}

