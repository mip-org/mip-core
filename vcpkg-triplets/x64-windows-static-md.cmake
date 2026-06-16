# Channel-shared vcpkg overlay triplet. Shadows vcpkg's builtin
# x64-windows-static-md (same NAME, so a package's `pkg:x64-windows-static-md`
# qualifier and compile.m's VCPKG_TARGET_TRIPLET are unchanged) and adds
# VCPKG_BUILD_TYPE=release.
#
# Why channel-level (not per-package): vcpkg keys cached binary packages by an
# ABI hash that includes the triplet's content. Pointing every Windows+vcpkg
# package's `vcpkg install ... --overlay-triplets=vcpkg-triplets` at THIS one
# file gives them identical ABIs, so they share the persisted binary cache
# (build-package.yml caches the vcpkg archives dir across runs). A per-package
# copy would risk ABI drift and defeat that reuse.
#
# Release-only: vcpkg builds BOTH debug and release of every port by default,
# but the MEX link only the release libs (built -DCMAKE_BUILD_TYPE=Release), so
# the debug half roughly doubles a cold build for nothing. This only affects
# `vcpkg install`; at consume time CMake's vcpkg toolchain just reads
# installed/<triplet>/lib.
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_BUILD_TYPE release)
