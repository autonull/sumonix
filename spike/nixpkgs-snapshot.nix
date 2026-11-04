{ pkgs ? import <nixpkgs> {} }:

let
  targets = [
    "openssl" "curl" "nginx" "git" "python3" "nodejs" "postgresql" "redis"
    "libssh2" "wget" "zlib" "libxml2" "libxslt" "sqlite" "readline" "ncurses"
    "gcc" "glibc" "coreutils" "bash" "grep" "sed" "awk" "findutils" "diffutils"
    "make" "cmake" "pkg-config" "autoconf" "automake" "libtool" "m4"
    "openssh" "gnutls" "libgcrypt" "libgpg-error" "pcre2" "icu" "libffi"
    "gettext" "expat" "bzip2" "xz" "zstd" "lz4" "libarchive" "gdbm" "dbus"
    "systemd" "util-linux" "e2fsprogs" "kbd" "less" "vim"
  ];

  toKIF = name: pkg:
    let
      deps = pkg.propagatedBuildInputs ++ pkg.buildInputs;
      depNames = lib.map (d: d.pname) deps;
    in ''
      (instance ${name} NIXPackage)
      ${lib.concatStringsSep "\n" (lib.map (d: "(dependsOn ${name} ${d})") depNames)}
      (hasLicense ${name} ${pkg.meta.license.spdxId or "unknown"})
    '';

  kifFacts = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: toKIF n) (lib.filterAttrs (n: v: lib.elem n targets) pkgs));
in
kifFacts