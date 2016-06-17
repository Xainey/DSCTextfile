node('windows') {
    // May not need this stage if using Jenkins SCM to checkout Jenkinsfile
    stage 'Stage 1: Build'
    git url: 'https://github.com/Xainey/DSCTextfile.git'

    stage 'Stage 2: Analyze'
    posh './build.ps1 -Task JenkinsAnalyze'

    stage 'Stage 3: Test'
    posh './build.ps1 -Task JenkinsTest'

    stage 'Stage 4: Approve Publish Module'
    input 'Deploy to Module Respository?'

    stage 'Stage 5: Publish Module'
    posh './build.ps1 -Task JenkinsDeploy'
}
def posh(cmd) {
  bat 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& ' + cmd + '"'
}