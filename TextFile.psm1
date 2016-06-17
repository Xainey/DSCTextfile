enum Ensure
{
    Absent
    Present
}

class TextFileHelpers
{
    [bool] CheckPathExists ([string]$Path)
    {
        if (Test-Path -Path $Path)
        {
            Write-Verbose "Directory $($Path) exists."
            return $true
        }

        Write-Verbose "Directory $($Path) exists."
        return $false
    }

    [bool] CheckContent ([string]$Path, [string]$Content)
    {
        if ((Get-Content -Path $Path)-eq $Content)
        {
            Write-Verbose "Content Matches."
            return $true
        }

        Write-Verbose "Content Doesnt Match."
        return $false
    }
}

[DscResource()]
class TextFile
{
    [DscProperty(Key)]
    [string] $FilePath

    [DscProperty(Mandatory)]
    [string] $FileContent

    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    
    # Gets the resource's current state.
    [TextFile] Get()
    {
        return @{
            FilePath = $this.FilePath
            FileContent = $this.FileContent
            Ensure = $this.Ensure
        }
    }
    
    # Sets the desired state of the resource.
    [void] Set()
    {
        if ($this.Ensure -eq [Ensure]::Present)
        {
            # Create File and Set content if non-existing
            if (![TextFileHelpers]::new().CheckPathExists($this.FilePath))
            {
                New-Item -Path $this.FilePath -type file -force -value $this.FileContent
            }

            # Update Content if existing
            else
            {
                Set-Content -Path $this.FilePath -Value $this.FileContent
            }
        }
        else
        {
            Remove-Item -Path $this.FilePath
        }
    }
    
    # Tests if the resource is in the desired state.
    [bool] Test()
    {
        $pathExists = [TextFileHelpers]::new().CheckPathExists($this.FilePath)

        # present case
        if ($this.Ensure -eq [Ensure]::Present)
        {
            $isContent = [TextFileHelpers]::new().CheckContent($this.FilePath, $this.FileContent)

            return ( $pathExists -and $isContent)
        }
        # absent case
        else
        {
            return (![TextFileHelpers]::new().CheckPathExists($this.FilePath))
        }
    }
}
