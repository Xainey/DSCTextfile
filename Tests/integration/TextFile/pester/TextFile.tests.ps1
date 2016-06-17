describe "TextFile" {
    it 'creates a text file' {
        'c:\Temp\hello.txt' | Should Exist
    }
    it 'has the correct content' {
        'c:\Temp\hello.txt' | Should Contain 'Hello World!'
    }    
}