# Releasing to CurseForge

## TBC Anniversary Support

OneButtonMount targets TBC Anniversary Classic. The TOC file specifies:

```
## Interface: 20504
```

## Release Process

### Automated (GitHub Actions)

1. Update version in `OneButtonMount.toc`
2. Update `CHANGELOG.md` with release notes
3. Commit and push to `main`
4. CI automatically creates a tag from the TOC version and triggers the packager

### Manual Upload to CurseForge

1. Create a zip file:
   ```bash
   cd /home/vocoder/Code
   zip -r OneButtonMount-v1.0.X.zip OneButtonMount -x "*.git*" -x "*README.md"
   ```
2. Upload at [CurseForge Project Page](https://www.curseforge.com/wow/addons/onebuttonmount/files)

## What Gets Released

The `.pkgmeta` file controls what gets included:
- OneButtonMount.lua
- OneButtonMount.toc
- CHANGELOG.md
- README.md (excluded)
- .git files (excluded)
