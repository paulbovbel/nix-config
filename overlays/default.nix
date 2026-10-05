final: prev: {
  # Locus L2TP VPNs require IKEv1, disabled by default in strongSwan 6.
  strongswan = prev.strongswan.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ ["--enable-ikev1"];
  });

  netbootxyz-efi = prev.netbootxyz-efi.overrideAttrs (_: {
    version = "3.0.2";
    src = final.fetchurl {
      url = "https://github.com/netbootxyz/netboot.xyz/releases/download/3.0.2/netboot.xyz.efi";
      hash = "sha256-4PbBxZPh2grQg/nXoOOjWAhR9gJqNgR53oriAUrv0i8=";
    };
  });

  netbootxyz-legacy = final.stdenvNoCC.mkDerivation {
    pname = "netboot.xyz-legacy";
    version = "3.0.2";
    src = final.fetchurl {
      url = "https://github.com/netbootxyz/netboot.xyz/releases/download/3.0.2/netboot.xyz-legacy.efi";
      hash = "sha256-TJNf+oy0lr2YOKJ+h2ooae+uIHD25J6T9AsPN01LiFM=";
    };
    dontUnpack = true;
    postInstall = ''
      cp $src $out
    '';
  };
}
