# Release Process

## Automated Process

Every push to `main` triggers an automatic release via GitHub Actions:
- Reads the version from OneButtonMount.toc
- Creates a git tag if one doesn't exist for that version
- Tag push triggers the packager workflow
- BigWigsMods/packager builds the release zip and uploads to CurseForge

**Update the version in OneButtonMount.toc before pushing!**

## Manual Steps (For Major/Minor Releases)

### 1. Update Version

Update `## Version:` in `OneButtonMount.toc`.

### 2. Update CHANGELOG.md

```markdown
## [Unreleased]

### Added
- New feature description

### Fixed
- Bug fix description
```

### 3. Commit and Push

```bash
git add OneButtonMount.toc CHANGELOG.md
git commit -m "Release v1.0.X"
git push
```

The CI pipeline handles tagging and packaging automatically.

## Version Numbering

Following [Semantic Versioning](https://semver.org/):
- **MAJOR** (v2.0.0): Breaking changes
- **MINOR** (v1.1.0): New features, backwards-compatible
- **PATCH** (v1.0.1): Bug fixes, backwards-compatible
