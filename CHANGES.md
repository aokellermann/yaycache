# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- `--version` option to pactree.
- Import pacsort utility.
- systemd service and timer for paccache.

### Changed
- Make pacscripts use `-v` as the short flag for version output instead of `-V`, in accordance with its documentation.

### Fixed
- checkupdates now reports failures to update the databases.

## 0.0.1 - 2016-10-17
### Added
- Imported the following utilities:
  - checkupdates
  - paccache
  - pacdiff
  - paclist
  - paclog-pkglist
  - pacscripts
  - pacsearch
  - pactree
  - rankmirrors
  - updpkgsums
- Added vim highlighting for PKGBUILDs.

[Unreleased]: https://git.archlinux.org/pacman-contrib.git/log/?qt=range&q=v0.0.1..master
