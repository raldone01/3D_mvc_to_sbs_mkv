# Convert mvc to sbs mkv

This docker container can convert frame-packed (mvc) mkv files to side-by-side (sbs) mkv files.
All audio and subtitle tracks are copied to the output file.

Makemkv should output two streams one for the left and one for the right eye.
This script will take the multi view encoded streams and combine them back into a sbs video.

Based on [3DVideos2Stereo](https://github.com/lasinger/3DVideos2Stereo), [2016 Making a side-by-side 3D video out of blu-ray](http://www.fandecheng.com/personal/interests/2016_Making%20a%20side-by-side%203D%20video%20out%20of%20blu-ray.html)

```bash
docker buildx build . --tag mvc_to_sbs
docker run --rm -it -v ./input:/input -v ./output:/output mvc_to_sbs /input/input_file_left.mkv /input/input_file_right.mkv /output/output_file.mkv
```

```bash00
# debug command
docker run --rm -it --entrypoint /bin/bash -v ./input:/input -v ./output:/output mvc_to_sbs
/entrypoint.sh /input/input_file.mkv /output/output_file.mkv
```

```bash
# test with first 10 minutes
ffmpeg -i input/input_file_full_left.mkv -to 00:10:00 -c copy input/input_file_left.mkv
ffmpeg -i input/input_file_full_right.mkv -to 00:10:00 -c copy input/input_file_right.mkv
```
