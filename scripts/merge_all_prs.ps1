# PowerShell script to merge all open GitHub pull requests and delete their source branches
# Requires GitHub CLI (gh) installed and authenticated

# Retrieve open PRs with number and head branch name.
$prsJson = gh pr list --state open --json number,headRefName --limit 100
$prs = @(($prsJson | ConvertFrom-Json).ForEach({ $_ }))

if (-not $prs -or $prs.Count -eq 0) {
    Write-Host "No open pull requests found. Exiting."
    exit 0
}

# Retrieve user info from GitHub to construct noreply email address
$gitConfigOverride = @()
try {
    $gitUserJson = gh api user -q '.' | ConvertFrom-Json
    $gitUserEmail = "$($gitUserJson.id)+$($gitUserJson.login)@users.noreply.github.com"
    $gitUserName = $gitUserJson.name
    if (-not $gitUserName) { $gitUserName = $gitUserJson.login }
    if ($gitUserEmail -and $gitUserName) {
        $gitConfigOverride = @("-c", "user.name=$gitUserName", "-c", "user.email=$gitUserEmail")
    }
} catch {
    Write-Host "Warning: Failed to fetch GitHub user info for noreply email. Falling back to default git config."
}

foreach ($pr in $prs) {
    $number = $pr.number
    $branch = $pr.headRefName
    if (-not $number -or -not $branch) { continue }
    Write-Host "Merging PR #$number from branch $branch..."
    # Attempt merge using admin mode to bypass review requirements
    gh pr merge $number --merge --admin
    if ($LASTEXITCODE -eq 0) {
        Write-Host "PR #$number merged successfully. Deleting remote branch $branch..."
        git push origin --delete $branch
        } else {
            Write-Host "Failed to merge PR #$number. Resolving conflicts locally and creating a new PR..."
            # Determine the base branch of the PR
            $baseBranch = (gh pr view $number --json baseRefName -q .baseRefName)
            
            # Save current branch and state
            $currentBranch = (git branch --show-current)
            git stash
            
            # Prepare a new temporary branch from base branch
            $tempBranch = "temp-resolve-pr-$number"
            git checkout $baseBranch
            git pull origin $baseBranch
            
            # Delete local temp branch if it already exists
            git branch -D $tempBranch 2>$null
            git checkout -b $tempBranch
            
            # Fetch and merge the source branch preferring theirs (new branch changes)
            git fetch origin $branch
            git @gitConfigOverride merge origin/$branch -X theirs -m "Merge branch '$branch' into $tempBranch preferring theirs"
            
            if ($LASTEXITCODE -eq 0) {
                # Push the resolved temp branch to origin
                git push origin $tempBranch --force
                
                # Close the original PR (without deleting branch)
                gh pr close $number
                
                # Create a new PR from the temp branch
                $newPRUrl = gh pr create --head $tempBranch --base $baseBranch --title "Force merge $branch" --body "Auto-created PR to force merge source branch content with conflict resolution preferring theirs"
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "New PR created: $newPRUrl. Attempting to merge..."
                    gh pr merge $tempBranch --merge --admin
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Force merge via new PR succeeded. Deleting branches..."
                        git push origin --delete $tempBranch
                        git push origin --delete $branch
                        git branch -D $tempBranch 2>$null
                    } else {
                        Write-Host "Failed to merge new PR automatically. Manual resolution required on: $newPRUrl"
                    }
                } else {
                    Write-Host "Failed to create new PR. Manual resolution required."
                }
            } else {
                Write-Host "Failed to resolve conflicts locally using '-X theirs'."
                git merge --abort 2>$null
            }
            
            # Restore original state
            git checkout $currentBranch
            git stash pop 2>$null
        }
}

Write-Host "All open PRs processed."
