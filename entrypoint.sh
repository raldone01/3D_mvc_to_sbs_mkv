#!/bin/bash

set -ex

# Setup headless X11
# mkdir -p /tmp/.X11-unix
# chmod 1777 /tmp/.X11-unix
# Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX +extension RANDR +extension RENDER +render -noreset &
# export DISPLAY=:0

# use xorg
Xorg -noreset +extension GLX +extension RANDR +extension RENDER -logfile ./10.log -config /etc/X11/xorg.conf :10 &
export DISPLAY=:10

# Converts the input mkv video stream to a side-by-side (sbs) mkv video stream and keeps audio, subtitles...
left_input_path=$1
right_input_path=$2
output_path=$3

output_basename=$(basename "$output_path")
mkdir -p $output_basename

tmp_dir=$(mktemp -d)

# Extract framerate from the input mkv
framerate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$left_input_path")
echo "Detected framerate: $framerate"
# Extract the resolution from the input mkv
resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$left_input_path")
# remove last letter
resolution=${resolution::-1}
echo "Detected resolution: $resolution"

# Double the resolution
double_resolution=$(echo $resolution | awk -F'x' '{print $1*2 "x" $2}')
echo "Double resolution: $double_resolution"

# Extract just the video stream from the input mkv
echo "Extracting LEFT video stream from $left_input_path"
left_extracted_video_bitstream_path="${tmp_dir}/left_extracted_video_bitstream.264"
mkvextract tracks "$left_input_path" 0:"$left_extracted_video_bitstream_path"

if [[ -f "$right_input_path" ]]; then
  echo "Extracting RIGHT video stream from $right_input_path"
  right_extracted_video_bitstream_path="${tmp_dir}/right_extracted_video_bitstream.264"
  mkvextract tracks "$right_input_path" 0:"$right_extracted_video_bitstream_path"
fi

sbs_mkv_video_path="${tmp_dir}/sbs_mkv_video.mkv"

# We convert the video stream to sbs mkv using FRIMDecode
# -r 24000/1001 framerate 23.976
# -s:v 3840x1080 resolution
# -async 1
plugin1="/usr/local/bin/FRIMDecode/2fca99749fdb49aeb121a5b63ef568f7/mfxplugin64_hevce_sw.dll"
plugin2="/usr/local/bin/FRIMDecode/15dd936825ad475ea34e35f3f54217a6/mfxplugin64_hevcd_sw.dll"
plugin1=$(winepath -w $plugin1)
plugin2=$(winepath -w $plugin2)
echo "Using plugins: $plugin1 $plugin2"
# -path $plugin1 -path $plugin2
# -sw or -hw or -d3d -d3d11

frim_bits=64

frimdir="/usr/local/bin/FRIMDecode${frim_bits}"
frimdir_win=$(winepath -w $frimdir)
export WINEPATH=$frimdir_win
frimpath=$frimdir/FRIMDecode${frim_bits}.exe

wine $frimpath -d3d11 -async 1 -i:mvc "$left_extracted_video_bitstream_path" $right_extracted_video_bitstream_path -o - -sbs | ffmpeg -y -f rawvideo -s:v $double_resolution -r $framerate -i - -c:v libx264 "${sbs_mkv_video_path}.mkv"

# now that we have the sbs video, we can mux it back into the original mkv
# We will overwrite the original video track with the sbs video
ffmpeg -i "$sbs_mkv_video_path" -i "$left_input_path" -map 0:v:0 -map 1:a -map 1:s -c copy "$output_path"

# cleanup tmp dir
rm -rf $tmp_dir
