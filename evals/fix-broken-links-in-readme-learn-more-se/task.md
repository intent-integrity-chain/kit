# Fix broken links in README "Learn More" section

## Problem/Feature Description

The README has a "Learn More" section with links to additional resources. Two of those links are broken or don't work well in all contexts:

1. The link to the dashboard documentation (`DASHBOARD.md`) uses a relative path. This works fine when viewing the README on GitHub, but breaks when the README is rendered elsewhere (e.g., npm registry, documentation sites, or other contexts where relative links don't resolve correctly). It should point to the actual GitHub URL for that file instead.

2. There's a link to a conference talk ("Back to the Future of Software") that returns a 404 error — the page no longer exists. It shouldn't be listed as a resource since it doesn't work.

## Expected Behavior

- The dashboard documentation link in the "Learn More" section should work when the README is viewed from any context, not just within GitHub.
- Broken links that return 404 should not appear in the README.

## Acceptance Criteria

- The `DASHBOARD.md` link resolves correctly when accessed from outside the repository context (e.g., as an absolute URL)
- The broken conference talk link is no longer present in the README
- All other links in the "Learn More" section remain unchanged
