FROM debian:bookworm

# Install WINE, mkvtoolnix, and ffmpeg
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list.d/debian.sources && \
  dpkg --add-architecture i386 && \
  mkdir -pm755 /etc/apt/keyrings && \
  apt-get update && \
  apt-get install -y --install-recommends gnupg2 wget ca-certificates && \
  wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
  wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
  apt-get update && \
  apt-get install -y --install-recommends winehq-stable mkvtoolnix ffmpeg curl xvfb intel-media-va-driver-non-free libvulkan1 libvulkan1:i386 intel-media-va-driver-non-free:i386 unzip vulkan-tools mesa-utils mesa-vulkan-drivers mesa-vulkan-drivers:i386 mesa-vdpau-drivers mesa-vdpau-drivers:i386 mesa-va-drivers mesa-va-drivers:i386 && \
  debug_packages="nano strace mesa-utils less" && \
  apt-get install -y --install-recommends $debug_packages && \
  apt-get clean

# Download FRIMDecode 64
RUN \
  mkdir -p /tmp/frimdecode && \
  cd /tmp/frimdecode && \
  curl -L 'https://www.videohelp.com/download/FRIM_x64_version_1.29.zip' -H 'Referer: https://www.videohelp.com/software/FRIM/old-versions' -o FRIM_x64.zip && \
  #expected_sha512=f59592a72996a3663906f7e80edee7d58f7479a692a97471b90fe56b7ac91c9afff36fce37bd115d651172a265346fd7f23d6043a932eff9224acd43de256e43 && \
  #actual_sha512=$(sha512sum FRIM_x64.zip | cut -d' ' -f1) && \
  #if [ "$expected_sha512" != "$actual_sha512" ]; then echo "SHA512 mismatch" && exit 1; fi && \
  #echo "SHA512 match" && \
  # unpack FRIMDecode and install to /usr/local/bin
  unzip FRIM_x64.zip && \
  mv x64/ /usr/local/bin/FRIMDecode64 && \
  chmod +x /usr/local/bin/FRIMDecode64/*.exe && \
  rm -rf /tmp/frimdecode

# Download FRIMDecode 32
RUN \
  mkdir -p /tmp/frimdecode && \
  cd /tmp/frimdecode && \
  curl -L 'https://www.videohelp.com/download/FRIM_x86_version_1.29.zip' -H 'Referer: https://www.videohelp.com/software/FRIM/old-versions' -o FRIM_x86.zip && \
  #expected_sha512=150564abdce63e64857334d03d2ac6d8b0a1f8c727dd2b8fd4ed6a5926d3473d2bd10dfdacfa968eb38a54075605121e0ed403daea706938f7a6abcdc57c1729 && \
  #actual_sha512=$(sha512sum FRIM_x86.zip | cut -d' ' -f1) && \
  #if [ "$expected_sha512" != "$actual_sha512" ]; then echo "SHA512 mismatch" && exit 1; fi && \
  #echo "SHA512 match" && \
  # unpack FRIMDecode and install to /usr/local/bin
  unzip FRIM_x86.zip && \
  mv x86/ /usr/local/bin/FRIMDecode32 && \
  chmod +x /usr/local/bin/FRIMDecode32/*.exe && \
  rm -rf /tmp/frimdecode

# Download and install dxvk
RUN \
  mkdir -p /tmp/dxvk && \
  cd /tmp/dxvk && \
  curl -L 'https://github.com/doitsujin/dxvk/releases/download/v2.3/dxvk-2.3.tar.gz' -o dxvk-2.3.tar.gz && \
  # unpack and install dxvk
  tar -xzf dxvk-2.3.tar.gz && \
  cd dxvk-2.3 && \
  # copy the x32 and x64 folders to /usr/local/bin/dxvk
  mkdir -p /usr/local/bin/dxvk && \
  cp -r x32 x64 /usr/local/bin/dxvk && \
  rm -rf /tmp/dxvk

ENV WINEPREFIX=/root/.wine64
ENV WINEARCH=win64

# Setup wine prefix
RUN \
  wineboot -u && \
  cp /usr/local/bin/dxvk/x64/*.dll $WINEPREFIX/drive_c/windows/system32 && \
  cp /usr/local/bin/dxvk/x32/*.dll $WINEPREFIX/drive_c/windows/syswow64 && \
  #do this for every dll in x64 and x32 wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v path_to_dll /d native /f && \
  before=$(stat -c '%Y' $WINEPREFIX/user.reg) \
  dlls_paths=$(find /usr/local/bin/dxvk -name '*.dll') && \
  for dll in $dlls_paths; do \
  wine reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "$(basename "${dll%.*}")" /d native /f; \
  # get the reg keys
  # wine reg query "HKEY_CURRENT_USER\Software\Wine\DllOverrides" | grep -i $(basename "${dll%.*}"); \
  done \
  && while [ $(stat -c '%Y' $WINEPREFIX/user.reg) = $before ]; do sleep 1; done

COPY --chown=root:root --chmod=755 entrypoint.sh /entrypoint.sh
COPY d3d11-triangle.exe /d3d11-triangle.exe
ENTRYPOINT ["/entrypoint.sh"]
