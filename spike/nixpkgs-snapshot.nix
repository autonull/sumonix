{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  targets = [
    "openssl" "curl" "nginx" "git" "python3" "nodejs" "postgresql" "redis"
    "libssh2" "wget" "zlib" "libxml2" "libxslt" "sqlite" "readline" "ncurses"
    "gcc" "glibc" "coreutils" "bash" "grep" "sed" "awk" "findutils" "diffutils"
    "make" "cmake" "pkg-config" "autoconf" "automake" "libtool" "m4"
    "openssh" "gnutls" "libgcrypt" "libgpg-error" "pcre2" "icu" "libffi"
    "gettext" "expat" "bzip2" "xz" "zstd" "lz4" "libarchive" "gdbm" "dbus"
    "systemd" "util-linux" "e2fsprogs" "kbd" "less" "vim"
  ];

  # Map packages to capabilities they provide
  capabilities = {
    openssl = [ "TLS" "Crypto" "X509" ];
    curl = [ "HTTPClient" "FileTransfer" ];
    nginx = [ "HTTPServer" "ReverseProxy" "LoadBalancer" ];
    git = [ "VersionControl" "DistributedSync" ];
    python3 = [ "Scripting" "DataScience" "WebFramework" "ML" ];
    nodejs = [ "JavaScriptRuntime" "WebServer" "PackageManager" ];
    postgresql = [ "RelationalDB" "ACID" "SQL" ];
    redis = [ "KeyValueStore" "PubSub" "Cache" ];
    libssh2 = [ "SSHClient" "SFTP" ];
    wget = [ "HTTPClient" "RecursiveDownload" ];
    zlib = [ "Compression" ];
    libxml2 = [ "XMLParsing" "XPath" ];
    libxslt = [ "XSLT" ];
    sqlite = [ "EmbeddedDB" "SQL" ];
    readline = [ "InteractiveCLI" ];
    ncurses = [ "TUI" ];
    gcc = [ "Compilation" "C" "CPlusPlus" ];
    glibc = [ "SystemCalls" "POSIX" ];
    coreutils = [ "FileOps" "TextProcessing" ];
    bash = [ "ShellScripting" ];
    grep = [ "PatternMatching" ];
    sed = [ "StreamEditing" ];
    awk = [ "TextProcessing" "DataExtraction" ];
    findutils = [ "FileDiscovery" ];
    diffutils = [ "Diffing" ];
    make = [ "BuildAutomation" ];
    cmake = [ "BuildConfiguration" ];
    "pkg-config" = [ "DependencyDiscovery" ];
    autoconf = [ "BuildConfiguration" ];
    automake = [ "BuildAutomation" ];
    libtool = [ "LibraryBuilding" ];
    m4 = [ "MacroProcessing" ];
    openssh = [ "SSHServer" "RemoteAccess" ];
    gnutls = [ "TLS" "Crypto" ];
    libgcrypt = [ "Crypto" ];
    libgpg-error = [ "Crypto" ];
    pcre2 = [ "Regex" ];
    icu = [ "Unicode" "I18n" ];
    libffi = [ "FFI" ];
    gettext = [ "I18n" ];
    expat = [ "XMLParsing" ];
    bzip2 = [ "Compression" ];
    xz = [ "Compression" ];
    zstd = [ "Compression" ];
    lz4 = [ "Compression" ];
    libarchive = [ "ArchiveHandling" ];
    gdbm = [ "KeyValueStore" ];
    dbus = [ "IPC" "ServiceDiscovery" ];
    systemd = [ "ServiceManagement" "InitSystem" ];
    "util-linux" = [ "SystemUtils" ];
    e2fsprogs = [ "FilesystemTools" ];
    kbd = [ "ConsoleTools" ];
    less = [ "Paging" ];
    vim = [ "TextEditing" ];
  };

  # nixpkgs renames some packages; map dep pnames to our instance names
  alias = {
    "zlib-ng" = "zlib";
    "util-linux-minimal" = "util-linux";
    "gnum4" = "m4";
    "gmake" = "make";
  };
  normalize = pname:
    if alias ? ${pname} then alias.${pname}
    else if builtins.match "glibc-iconv-[0-9.]+" pname != null then "glibc"
    else pname;

  toKIF = name: pkg:
    let
      deps = pkg.propagatedBuildInputs ++ pkg.buildInputs;
      depNames = lib.map (d: normalize (d.pname or d.name or "unknown")) deps;
      caps = capabilities.${name} or [];
      capFacts = lib.concatStringsSep "\n" (lib.map (c: "(providesCapability ${name} ${c})") caps);
    in ''
      (instance ${name} NIXPackage)
      ${lib.concatStringsSep "\n" (lib.map (d: "(dependsOn ${name} ${d})") depNames)}
      (hasLicense ${name} ${pkg.meta.license.spdxId or "unknown"})
      ${capFacts}
    '';

  kifFacts = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: toKIF n) (lib.filterAttrs (n: v: lib.elem n targets) pkgs));
in
kifFacts