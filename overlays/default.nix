final: prev: {
  headsetcontrol = prev.headsetcontrol.overrideAttrs (_: {
    # Last released version doesn't include fixes for Audeze Maxwell.
    # https://github.com/Sapd/HeadsetControl/pull/412
    version = "4d57d17af8b49d436b01822a23a3871aa7646f11";
    src = final.fetchFromGitHub {
      owner = "Sapd";
      repo = "HeadsetControl";
      rev = "4d57d17af8b49d436b01822a23a3871aa7646f11";
      hash = "sha256-N59GYF5XEIdm2zeIbsHwFA6dkXaCCyi3oxIWuUVL1fk=";
    };
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
