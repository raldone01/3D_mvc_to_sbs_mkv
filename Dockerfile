FROM debian:bookworm

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  sed -i -e's/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources && \
  dpkg --add-architecture i386 && \
  mkdir -pm755 /etc/apt/keyrings && \
  apt-get update && \
  apt-get install -y gnupg2 wget curl ca-certificates && \
  wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
  wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
  apt-get update && \
  apt-get install -y mkvtoolnix ffmpeg unzip && \
  apt-get install -y winehq-stable xorg xserver-xorg-video-dummy xvfb libvulkan1 libvulkan1:i386 vulkan-tools mesa-utils mesa-utils-extra mesa-vulkan-drivers mesa-vulkan-drivers:i386 mesa-vdpau-drivers mesa-vdpau-drivers:i386 mesa-va-drivers mesa-va-drivers:i386 && \
  debug_packages="nano strace less" && \
  apt-get install -y $debug_packages && \
  apt-get clean

# Download FRIMDecode 64
RUN \
  mkdir -p /tmp/frimdecode && \
  cd /tmp/frimdecode && \
  curl -L 'https://www.videohelp.com/download/FRIM_x64_version_1.29.zip' -H 'Referer: https://www.videohelp.com/software/FRIM/old-versions' -o FRIM_x64.zip && \
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

# Install d3d11-triangle.exe
RUN \
  mkdir -p /tmp/d3d11-triangle && \
  cd /tmp/d3d11-triangle && \
  curl -L 'https://gitlab.melroy.org/melroy/winegui/uploads/c4db93700d13dfb71997f28c2965aeb7/dxvk-test.tar.gz' -o triangle.tar.gz && \
  tar -xzf triangle.tar.gz && \
  mv dxvk-test /usr/local/bin/d3d11-triangle && \
  rm -rf /tmp/d3d11-triangle

COPY --chown=root:root --chmod=755 entrypoint.sh /entrypoint.sh
COPY xorg.conf /etc/X11/xorg.conf.d/20-virt.conf
ENTRYPOINT ["/entrypoint.sh"]
