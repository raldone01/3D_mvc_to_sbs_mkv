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
  apt-get install -y --install-recommends winehq-stable mkvtoolnix ffmpeg curl unrar xvfb && \
  apt-get clean

# Download FRIMDecode
RUN \
  mkdir -p /tmp/frimdecode && \
  cd /tmp/frimdecode && \
  curl -L 'https://drive.google.com/uc?export=download&id=1lumXLd74U-E2k195bzfETbHgFcHcT4sH' -o FRIM_x64_version_1.31.rar && \
  expected_sha512=2d4e5d987cdc84d6cff8f2f88c955dfce8d5cf006d0580abe5e15b6aeceb87eddc0df4790d6e207d4b6d18badc2cec6ee5cf556d00eeb7a1402d492aaf194b5c && \
  actual_sha512=$(sha512sum FRIM_x64_version_1.31.rar | cut -d' ' -f1) && \
  if [ "$expected_sha512" != "$actual_sha512" ]; then echo "SHA512 mismatch" && exit 1; fi && \
  echo "SHA512 match" && \
  # unpack FRIMDecode and install to /usr/local/bin
  unrar x FRIM_x64_version_1.31.rar && \
  mv x64/ /usr/local/bin/FRIMDecode && \
  chmod +x /usr/local/bin/FRIMDecode/*.exe && \
  rm -rf /tmp/frimdecode

# Setup wine prefix
RUN \
  WINEPREFIX=~/.wine64 WINEARCH=win64 winecfg

COPY --chown=root:root --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
