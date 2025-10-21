# GitHub Pages Setup for SwiftXDAV Documentation

This guide explains how to set up automatic DocC documentation hosting on GitHub Pages.

## Overview

SwiftXDAV uses GitHub Actions to automatically build and deploy DocC documentation to GitHub Pages whenever changes are pushed to the `main` branch.

## Prerequisites

- Repository hosted on GitHub
- Admin access to the repository (to enable GitHub Pages)

## One-Time Setup

### 1. Enable GitHub Pages

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Pages**
3. Under **Build and deployment**:
   - **Source**: Select "GitHub Actions"
   - This allows the workflow to deploy to Pages

![GitHub Pages Settings](https://docs.github.com/assets/cb-49864/mw-1440/images/help/pages/publishing-source-drop-down.webp)

### 2. Commit and Push

The workflow file is already included at `.github/workflows/documentation.yml`. Simply push your changes:

```bash
git add .
git commit -m "Add GitHub Pages documentation workflow"
git push origin main
```

### 3. Monitor the Workflow

1. Go to the **Actions** tab in your GitHub repository
2. You should see a workflow run called "Documentation"
3. Click on it to monitor progress
4. The workflow consists of two jobs:
   - **build**: Builds the DocC documentation
   - **deploy**: Deploys to GitHub Pages

### 4. Access Your Documentation

Once the workflow completes successfully:

1. Go to **Settings** → **Pages**
2. You'll see "Your site is live at `https://yourusername.github.io/swiftxdav/`"
3. The documentation will be available at:
   - Main page: `https://yourusername.github.io/swiftxdav/`
   - SwiftXDAV docs: `https://yourusername.github.io/swiftxdav/documentation/swiftxdav/`

## How It Works

### Workflow Configuration

The workflow (`.github/workflows/documentation.yml`) does the following:

1. **Triggers**: Runs on push to `main` branch or manual trigger
2. **Builds**: Uses `swift package generate-documentation` to create static HTML
3. **Deploys**: Uploads the documentation to GitHub Pages
4. **Hosting**: Makes it available at your GitHub Pages URL

### Documentation Structure

```
.docc-build/                    # Generated (not committed)
├── index.html                  # Landing page
├── documentation/
│   └── swiftxdav/             # Main documentation
├── css/                        # Styles
├── js/                         # JavaScript
└── data/                       # Symbol data
```

The `.docc-build/` directory is git-ignored since it's generated during CI/CD.

## Local Preview

To preview documentation locally:

```bash
# Generate documentation
swift package --allow-writing-to-directory ./.docc-build \
  generate-documentation \
  --target SwiftXDAV \
  --output-path ./.docc-build \
  --transform-for-static-hosting \
  --hosting-base-path swiftxdav

# Serve locally (requires Python)
cd .docc-build
python3 -m http.server 8000

# Open in browser
open http://localhost:8000
```

## Customization

### Change Hosting Base Path

If your repository name is different, update `.github/workflows/documentation.yml`:

```yaml
--hosting-base-path your-repo-name
```

### Build Multiple Targets

To generate documentation for specific modules:

```yaml
# Build SwiftXDAVCore documentation
swift package generate-documentation --target SwiftXDAVCore

# Build SwiftXDAVCalendar documentation
swift package generate-documentation --target SwiftXDAVCalendar
```

You can create multiple workflows or combine targets in one workflow.

### Custom Domain

To use a custom domain:

1. Add a `CNAME` file to the repository root:
   ```
   docs.yourdomain.com
   ```

2. Configure DNS with your domain provider:
   ```
   CNAME  docs  yourusername.github.io
   ```

3. In GitHub Settings → Pages, enter your custom domain

## Troubleshooting

### Workflow Fails with "Permission denied"

**Solution**: Ensure GitHub Pages source is set to "GitHub Actions" (not "Deploy from a branch").

### Documentation not showing up

**Solution**:
1. Check the Actions tab for errors
2. Verify the workflow completed successfully
3. Wait a few minutes for GitHub Pages to refresh
4. Clear your browser cache

### 404 Not Found

**Solution**: Verify the `--hosting-base-path` matches your repository name.

```yaml
# For repository named "swiftxdav"
--hosting-base-path swiftxdav

# For repository named "my-caldav-lib"
--hosting-base-path my-caldav-lib
```

### Build fails with "Cannot find target SwiftXDAV"

**Solution**: Ensure `swift-docc-plugin` is in your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
]
```

## Updating Documentation

Documentation is automatically rebuilt and deployed on every push to `main`. No manual action needed!

To manually trigger a rebuild:
1. Go to **Actions** tab
2. Click **Documentation** workflow
3. Click **Run workflow** → **Run workflow**

## Best Practices

### 1. Write Good DocC Comments

```swift
/// A client for interacting with CalDAV servers.
///
/// `CalDAVClient` provides high-level methods for calendar operations.
///
/// ## Usage
///
/// ```swift
/// let client = CalDAVClient.iCloud(
///     username: "user@icloud.com",
///     appSpecificPassword: "xxxx-xxxx-xxxx-xxxx"
/// )
/// let calendars = try await client.listCalendars()
/// ```
///
/// ## Topics
///
/// ### Creating a Client
/// - ``init(httpClient:baseURL:)``
/// - ``iCloud(username:appSpecificPassword:)``
///
/// ### Calendar Operations
/// - ``listCalendars()``
/// - ``fetchEvents(from:start:end:)``
public actor CalDAVClient { ... }
```

### 2. Organize with Topics

Use `## Topics` sections to group related APIs:

```swift
/// ## Topics
///
/// ### Creating Events
/// - ``createEvent(_:in:)``
/// - ``updateEvent(_:at:)``
///
/// ### Fetching Events
/// - ``fetchEvent(at:)``
/// - ``fetchEvents(from:start:end:)``
```

### 3. Link to Related APIs

Use double backticks to link to other symbols:

```swift
/// See also ``CalDAVClient`` for calendar operations.
```

### 4. Include Code Examples

Show real usage examples in your documentation:

```swift
/// ## Example
///
/// ```swift
/// let event = VEvent(
///     uid: UUID().uuidString,
///     dtstart: Date(),
///     dtend: Date().addingTimeInterval(3600),
///     summary: "Team Meeting"
/// )
/// ```
```

## Resources

- [DocC Documentation](https://www.swift.org/documentation/docc/)
- [Swift-DocC Plugin](https://github.com/apple/swift-docc-plugin)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Maintenance

### Monitoring

- Check the **Actions** tab regularly for build failures
- Subscribe to workflow notifications in repository settings

### Updates

The workflow uses:
- `maxim-lobanov/setup-xcode@v1` - Updates automatically
- `actions/upload-pages-artifact@v3` - Pin version for stability
- `actions/deploy-pages@v4` - Pin version for stability

Update dependencies annually or when new features are needed.

---

**Last Updated:** 2025-10-21
