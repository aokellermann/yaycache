# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- checkupdates: Add option for downloading updates. (ab69666)
- docs: Add manpages for checkupdates, pacdiff, pacsort, updpkgsums. (d25a8b2, 35eef6b, ef63784, b258c31)
- paccache: Add --age-atime and --age-mtime arguments. (45c1916)
- vim: Add indent file. (020b533)
- vim: Add b2sums to PKGBUILD syntax file. (fc21909)

### Changed
- paclist: Allow listing packages from multiple repos at once. (58bfa06)
- paclist: Also list packages where the installed version differ from the repo version. (4849211)
- vim: Remove version check for Vim older than 6.0 from PKGBUILD syntax file. (b4ae0e5)
- checkupdates, paccache, pacdiff: Don't use colors on a dumb terminal. (c57d275)

### Fixed
- pacccache: Fix parsing of --move argument. (9ebae18)
- pacdiff: Don't assume the DBPath has a trailing slash. (0c260d3)
- pacsort: Support all compression formats supported by `makepkg`. (aa22e5c)
- vim: Add `unknown` license special case to PKGBUILD syntax file. (6193d12)


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
