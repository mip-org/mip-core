# Channel-shared vcpkg overlay triplet shadowing the builtin host triplet
# x64-windows. Identical to the builtin (dynamic CRT + dynamic library) but adds
# VCPKG_BUILD_TYPE=release.
#
# Why this exists: gmp's vcpkg port declares a {"name":"gmp","host":true}
# self-dependency, so installing gmp for any target also builds gmp for the HOST
# triplet (x64-windows on a 64-bit Windows runner). The target-only overlay
# (x64-windows-static-md.cmake) doesn't cover that, so the host gmp otherwise
# builds debug+release. This keeps host-tool builds release-only too. Selected
# automatically — --overlay-triplets points at this whole dir.
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_BUILD_TYPE release)
