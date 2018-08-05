# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2018-08-05
### Added
- paccache: Add manpage.
- rankmirrors: Add --max-time flag to specify the timeout used.

### Changed
- pacscripts: Don't log to pacman.log when files are downloaded to the cache.
- pacscripts: Find package file path using pacman instead of doing it manually ourselves.
- pactree: Use full dependency string when finding dependencies, since if we don't use the version requirement part of the string, we will sometimes return the wrong results.
- vim/ftplugin/PKGBUILD:  Set vim 'commentstring' option
- vim/syntax/PKGBUILD: Add sha224sums support.

### Fixed
- pacsort: Fix short version option.


## [1.0.0] - 2018-05-28
### Added
- `--version` option to pactree.
- Import pacsort utility.
- systemd service and timer for paccache.

### Changed
- Make pacscripts use `-v` as the short flag for version output instead of `-V`, in accordance with its documentation.

### Fixed
- checkupdates now reports failures to update the databases.
- Add `-v` to pacsort help output.


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


[Unreleased]: https://git.archlinux.org/pacman-contrib.git/log/?qt=range&q=v1.0.0..master
[1.0.0]: https://git.archlinux.org/pacman-contrib.git/log/?qt=range&q=v0.0.1..v1.0.0
[1.1.0]: https://git.archlinux.org/pacman-contrib.git/log/?qt=range&q=v1.0.0..v1.1.0
