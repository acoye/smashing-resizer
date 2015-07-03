#!/bin/bash
# Originally written by Vlad Gerasimov from http://www.vladstudio.com
# Quick and dirty edits - weavee.net

## sanity chk
if [ -z "$1" ]
then
printf '\e[0;31m [err] \e[0m please feed a file path containing the image sizes in px as a parameter\n'
exit
fi

## helpers
# uncomment to echo generated commands
function varDump(){
#local verbose="true"
if [[ $verbose == "true" ]]
then
echo $1
fi
}

# test existence of file
function testLocalFile(){
if [ ! -f "$1" ]
then
printf '\e[0;31m [err] \e[0m the necessary file \e[92m"%s"\e[0m does not exist in the current folder\n' $1
exit
fi
}

# We'll create a simple function that handles math for us in python
# Example: $(math 2 * 2)
function math(){
echo $(python -c "from __future__ import division; print $@")
}


# trasform on read
export IFS=,

pathToSizes=$1
echo "using .sizes source file :${pathToSizes}"

# read file
rawOutput=$(<$pathToSizes)

# to arr
output=($rawOutput)
echo "using sizes : ${output[@]}"
#echo "0: ${output[0]}, 1: ${output[1]}, all: ${output[@]}"


# path of image to be resized
default_src="icon.png";

# test if default file exists
testLocalFile $default_src

# output format - I feed iOS with PNGs
default_dst="%.png";

# Gravity is for cropping left/right edges for different proportions (center, east, west)
default_gravity="center"

# Output JPG quality - Optionnal for PNGs
quality=100



# main func
function save(){

	# images allways squared
	local dst_w=${1}
	local dst_h=${1}

	# calculate ratio 
	local ratio=$(math $dst_w/$dst_h);
    varDump "ratio '${ratio}'"

	# calculate "intermediate" width and height
	local inter_w=$(math "int(round($src_h*$ratio))")
	local inter_h=${src_h}

	# which size we're saving now
	local size="${dst_w}x${dst_h}"
    local tempPsdFileName="${size}.psd"
	echo "Saving '${size}' ..."

	#crop intermediate image (with target ratio)
	local cmd="convert ${src} -gravity ${gravity} -crop ${inter_w}x${inter_h}+0+0 +repage ${tempPsdFileName}"
    eval $cmd
    varDump "command '${cmd}'"

    # test generation of file
    testLocalFile $tempPsdFileName

    ## For best quality, I resize image 80%, sharpen 3 times, then repeat.
	# setup resize filter and unsharp parameters (calculated through trial and error)
	local arguments="-interpolate bicubic -filter Lagrange"
	local unsharp="-unsharp 0.4x0.4+0.4+0.008"

	# scale 80%, sharpen, repeat until less than 150% of target size
#local current_w=${dst_w}


#	while [ $(math "${current_w}/${dst_w} > 1.5") = "True" ]; do
#		current_w=$(math ${current_w}\*0\.80)
#		current_w=$(math "int(round(${current_w}))")
#		arguments="${arguments} -resize 80% +repage ${unsharp} ${unsharp} ${unsharp} "
#	done

	# final resize
	arguments="${arguments} -resize ${dst_w}x${dst_h}! +repage ${unsharp} ${unsharp} ${unsharp} -density 72x72 +repage"

	# final convert! resize, sharpen, save
    arguments="convert ${tempPsdFileName} ${arguments} -quality ${quality} ${dst/\%/${size}}"
    varDump "last command :${arguments}"
    eval $arguments

    # Delete temporary file
    rm $tempPsdFileName
}

# Ask for source image, or use default value
#echo "Enter path to source image, or hit Enter to keep default value (${default_src}): "
#read src
#src=${src:-${default_src}}
printf "using source image \e[92m"%s"\e[0m \n" "${default_src}"
src=$default_src

# ask for destination path, or use default value
#echo "Enter destination path, or hit Enter to keep default value (${default_dst})."
#echo "must include % symbol, it will be replaced by output size, f.e. '800x600'"
#read dst
#dst=${dst:-${default_dst}}
dst=$default_dst

# ask for gravity, or use default value
#echo "Enter gravity for cropping left/right edges (center, east, west), or hit Enter to keep default value (${default_gravity}): "
#read gravity
#gravity=${gravity:-${default_gravity}}
gravity=$default_gravity

#echo "press [entrer] to proceed or [ctrl]-[c] to exit"
printf 'press \e[1m[entrer]\e[0m to proceed or \e[1m[ctrl]-[c]\e[0m to exit \n'
read temp


# detect source image width and height
src_w=$(identify -format "%w" "${src}")
src_h=$(identify -format "%h" "${src}")


# loop throught output sizes and save each size
for i in "${output[@]}"
do
    # each resize operation in a fork. ||ize all the things
    save $i &
done

# wait for all forks to finish
wait

# Done!
echo "Done!"

