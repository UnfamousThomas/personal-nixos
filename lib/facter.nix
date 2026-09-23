{ lib }:
let
  # nixos-facter report schema (verified against pkg/hwinfo/*.go in
  # github:nix-community/nixos-facter -- it is an untyped cgo binding around
  # the openSUSE `hwinfo` C library, so this is genuinely the only source of
  # truth; there is no JSON Schema).
  #
  # report.hardware.memory[].resources[] holds one entry per device; the
  # entry with type == "phys_mem" has a `range` field: total RAM in bytes.
  physMemBytes =
    report:
    let
      allResources = lib.flatten (map (dev: dev.resources or [ ]) (report.hardware.memory or [ ]));
      physMem = lib.findFirst (r: (r.type or null) == "phys_mem") null allResources;
    in
    if physMem != null then physMem.range else null;

  # report.hardware.graphics_card[].vendor.hex is the PCI vendor ID.
  gpuVendorHexes = report: map (gpu: gpu.vendor.hex or null) (report.hardware.graphics_card or [ ]);

  hasVendor = hex: report: lib.elem hex (gpuVendorHexes report);
in
{
  inherit physMemBytes gpuVendorHexes;

  hasNvidia = hasVendor "10de";
  hasAmd = hasVendor "1002";
  hasIntelGpu = hasVendor "8086";

  # Round bytes down to whole GiB, for disko partition sizes ("<n>G").
  bytesToGiB = bytes: bytes / 1024 / 1024 / 1024;
}
