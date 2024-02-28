#!/bin/bash

set -ex

# Setup headless X11
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX +render -noreset &
export DISPLAY=:0

# Converts the input mkv video stream to a side-by-side (sbs) mkv video stream and keeps audio, subtitles...
left_input_path=$1
right_input_path=$2
output_path=$2

output_basename=$(basename "$output_path")
mkdir -p $output_basename

tmp_dir=$(mktemp -d)

# Extract just the video stream from the input mkv
echo "Extracting LEFT video stream from $left_input_path"
left_extracted_video_bitstream_path="${tmp_dir}/left_extracted_video_bitstream.264"
mkvextract tracks "$left_input_path" 0:"$left_extracted_video_bitstream_path"
echo "Extracting RIGHT video stream from $right_input_path"
right_extracted_video_bitstream_path="${tmp_dir}/right_extracted_video_bitstream.264"
mkvextract tracks "$right_input_path" 0:"$right_extracted_video_bitstream_path"

sbs_mkv_video_path="${tmp_dir}/sbs_mkv_video.mkv"

# We convert the video stream to sbs mkv using FRIMDecode
# -r 24000/1001 framerate 23.976
# -s:v 3840x1080 resolution
WINEPREFIX=~/.wine64 WINEARCH=win64 wine /usr/local/bin/FRIMDecode/FRIMDecode64.exe -i:mvc "$left_extracted_video_bitstream_path" "$right_extracted_video_bitstream_path" -o - -sbs | ffmpeg -y -f rawvideo -i - -c:v libx264 "${sbs_mkv_video_path}.mkv"

# now that we have the sbs video, we can mux it back into the original mkv
# We will overwrite the original video track with the sbs video
ffmpeg -i "$sbs_mkv_video_path" -i "$left_input_path" -map 0:v:0 -map 1:a -map 1:s -c copy "$output_path"

# cleanup tmp dir
rm -rf $tmp_dir
