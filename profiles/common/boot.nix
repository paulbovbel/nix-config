{
  boot = {
    # Performance-biased defaults: trades hardening for lower overhead.
    kernelParams = [
      # Disable most CPU vulnerability mitigations globally (kernel 5.2+).
      "mitigations=off"
      # Disable KPTI (Meltdown mitigation).
      "nopti"
      # Disable IBRS (Spectre v2 mitigation).
      "noibrs"
      # Disable IBPB (Spectre v2 mitigation).
      "noibpb"
      # Disable Spectre v2 mitigation paths.
      "nospectre_v2"
      # Disable Speculative Store Bypass mitigation.
      "spec_store_bypass_disable=off"
      # Disable L1TF mitigations.
      "l1tf=off"
      # Disable MDS mitigations.
      "mds=off"
    ];
  };
}
