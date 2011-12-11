#!/bin/bash

echo -n "Enter the source file: "
read input
echo -n "Enter the output file: "
read output

ffmpeg -i $input -acodec libvorbis -ac 2 -ab 96k -ar 44100 -b 345k -s hd480 -r 29.97 $output 
