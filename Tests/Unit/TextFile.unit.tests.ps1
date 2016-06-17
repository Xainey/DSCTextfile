using module "..\..\TextFile.psm1" 

describe "Textfile DSC Module - Unit Testing" {

    context "Check Path" {

        it 'return false for non-existing path' {
            [TextFileHelpers]::new().CheckPathExists('c:\bogus\path\example') | Should Be $false
        }

        it 'return true for existing path' {
            [TextFileHelpers]::new().CheckPathExists("$env:SystemDrive\Windows") | Should Be $true
        }
    }

    context "Check Content" {

        it 'return true for matching content' {
            $path = 'TestDrive:\file.txt'
            $content = 'Testing'
            Set-Content -Path $path -Value $content
            [TextFileHelpers]::new().CheckContent($path, $content) | Should Be $true
        }

        it 'return false for non-matching content' {
            $path = 'TestDrive:\file.txt'
            $content = 'Testing'
            Set-Content -Path $path -Value $content
            [TextFileHelpers]::new().CheckContent($path, 'Not Testing') | Should Be $false
        }
    }

}