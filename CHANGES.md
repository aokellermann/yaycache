# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added

### Changed

### Fixed


## [1.5.2]
### Added
- Vim: Add ISC and OFL as special licenses (!11)
- Add continuous testing (bbdf959f) (b05ed44f) (a0b1d8e1)

### Changed
- Switch to EditorConfig from Vim modelines (!9)

### Fixed
- paccache: Use more accurate --min-a/mtime description (!10)
- Remove PrivateUsers=yes from paccache.service (!13)


## [1.5.1] - 2022-05-04
### Fixed
- Fix version bump oversights (5350d1e4)


## [1.5.0] - 2022-05-03
### Added
- pacdiff: automatically delete pacfile after viewing if identical (3528b32c)
- pacdiff: Learn the (M)erge mode (94b2a194)
- pacdiff: Add option to use sudo/sudoedit to manage files (19ab4fac)
- paccache.service.in: Harden unit (59fd4efb)
- pacman-filesdb: systemd service and timer for `pacman -Fy` (dff74498) (871ffc94)
- checkupdates: Provide --nosync option (!2)

### Changed
- PKGBUILD.vim improvements (!5)

### Fixed
- updpkgsums: don't try to add nonexistent checksums (80275d21)


## [1.4.0] - 2020-07-28
### Added
- pactree: Add --debug (2d13a236)
- pactree: Add --gpgdir, set the gpg directory (a4e69cac)
- pactree: introduce the --optional flag (FS#61336) (b6d08b40)

### Changed
- doc: make timestamps in man pages reproducible (e2a5e43b)
- paccache.service.in: Reword description to more clearly specify what it does (269a2cdc)

### Fixed
- pactree: Improve command line validation (FS#64589) (e77e13b0)
- pactree: Fix redundant arrows in Graphviz output (c7be8631)
- doc: Fix pacdiff option descriptions (cf683ca0)
- vim: Add missing highlight links for b2sums (a1e7a764)
- paccache: Support cleaning many thousands of candidates (547a66d5)


## [1.3.0] - 2019-12-25
### Added
- Add document describing the release procedures. (21449e3)
- vim: Add Unlicense as valid license. (f835547)

### Changed
- checkupdates: Use $UID instead of $USER in the tempdir path. (a8b342e)
- checkupdates, paccache, and pacdiff were ported to libmakepkg. (431e564)

### Fixed
- checkupdates: Exit with 2 if there are no updates available. (3da550e)
- rankmirrors: Fix parsing of -m argument. (d026415)
- updpkgsums: Use makepkg's checksum algorithm type specification, fixing support for b2sums. (c8ef727)
- vim: Recognize validpgpkeys variable. (e6950d3)


## [1.2.0] - 2019-10-06
### Added
- checkupdates: Add option for downloading updates. (ab69666)
- docs: Add manpages for checkupdates, pacdiff, pacsort, updpkgsums. (d25a8b2, 35eef6b, ef63784, b258c31)
- paccache: Add --age-atime and --age-mtime arguments. (45c1916)
- vim: Add indent file. (020b533)
- vim: Add b2sums to PKGBUILD syntax file. (fc21909)
- Vim: Add Boost and MPL2 as valid licenses. (b5cb1ce)

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


[Unreleased]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.5.2...master
[1.5.2]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.5.1...v1.5.2
[1.5.1]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.5.0...v1.5.1
[1.5.0]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.4.0...v1.5.0
[1.4.0]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.3.0...v1.4.0
[1.3.0]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.2.0...v1.3.0
[1.2.0]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.1.0...v1.2.0
[1.1.0]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v1.0.0...v1.1.0
[1.0.0]: https://gitlab.archlinux.org/pacman/pacman-contrib/-/compare/v0.0.1...v1.0.0
