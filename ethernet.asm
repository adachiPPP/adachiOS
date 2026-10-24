%ifdef BIOS_BUILD
%include "ethernet_bios.inc"
%else
%include "ethernet_uefi.inc"
%endif
