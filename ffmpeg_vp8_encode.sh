#!/bin/bash

echo -n "Enter the source file: "
read input
echo -n "Enter the output file: "
read output

ffmpeg -i $input  -vcodec libvpx -acodec libvorbis -s hd480 -r 29.97 $output 
