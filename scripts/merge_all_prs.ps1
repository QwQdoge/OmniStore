# PowerShell script to merge all open GitHub pull requests and delete their source branches
# Requires GitHub CLI (gh) installed and authenticated

# Retrieve open PRs with number and head branch name, output as "<number> <branch>"
$prLines = gh pr list --state open --json number,headRefName -q '.[] | "\(.number) \(.headRefName)"'

if (-not $prLines) {
    Write-Host "No open pull requests found. Exiting."
    exit 0
}

foreach ($line in $prLines) {
    $parts = $line -split "\s+", 2
    $number = $parts[0]
    $branch = $parts[1]
    Write-Host "Merging PR #$number from branch $branch..."
    # Attempt merge using admin mode to bypass review requirements
    gh pr merge $number --merge --admin
    if ($LASTEXITCODE -eq 0) {
        Write-Host "PR #$number merged successfully. Deleting remote branch $branch..."
        git push origin --delete $branch
    } else {
        Write-Host "Failed to merge PR #$number. Skipping delete."
    }
}

Write-Host "All open PRs processed."
