#!/bin/bash
# Preparation script for waggle dance analysis with MTrackJ inside the FIJI package
# Depends on exiftool mediainfo avconv

# Will automatically concatenate and use all files in a directory specified in the csv file provided on the command line
# Make a csv file containing path to the folders containing the original MTS, MOV or MP4 files for a recording, followed by the site name
#
# CSV file example: test.csv
# Path,Site
#./Test2,Test2


INPUT=$1
OLDIFS=$IFS
IFS=,
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }

while read date timeperiod sequence beeid colmin colsec filepath
	do
	
	echo "Date : $date"
	echo "Time Period : $timeperiod"
	echo "Sequence : $sequence"
	echo "Bee ID : $beeid"
	echo "Collection time : $colmin:$colsec"
	echo "Path : $filepath"

	# Check to see if concatenated MTS file exists from previous loops.  If not, create it.
	in_file="$filepath/zTemp.MTS"
	if [ ! -f $in_file ]; then
		command_line="< /dev/null cat $filepath/*.MTS > $in_file"
		eval $command_line
	fi

	length=60 # length of clip to make (seconds)
	start_before_collection=50 # time to start before collection was recorded (seconds)
	timestart=$(((($colmin*60)+$colsec)-$start_before_collection)) 
	echo $timestart

	# Determine start time using EXIFTOOL and format it correctly
	startdatetime=`exiftool -datetimeoriginal $in_file`
	recordingdate=`echo $startdatetime | perl -pe 's/.*(\d{4}:\d{2}:\d{2}).*/$1/; s/:/\//g' | date -f - +%m%d%y`
	recordingstarthour=`echo $startdatetime | perl -pe 's/.*\s(\d{2}).*/$1/'`
	recordingstartminute=`echo $startdatetime | perl -pe 's/.*\s\d{2}:(\d{2}).*/$1/'`
	echo "Recording Date: $recordingdate"
	echo "Recording Start Hour: $recordingstarthour"
	echo "Recording Start Minute: $recordingstartminute"

	# Deterimine time in seconds since midnight
	totaltime=$(( ($(echo $recordingstarthour | sed 's/^0*//')* 3600) + ($(echo $recordingstartminute | sed 's/^0*//')*60) ))

	duration=`mediainfo --Inform="Video;%Duration/String1%" $in_file`
	if [[ $duration =~ [h] ]]; then
		hourend=`echo $duration | perl -pe 's/.*(\d+)h.*/$1/'`
	else
		hourend=0
	fi

	minend=`echo $duration | perl -pe 's/.*(\d+)mn.*/$1/'`
	secend=`echo $duration | perl -pe 's/.*(\d+)s.*/$1/'`

 	timeend=$((($hourend*60*60)+($minend*60)+$secend))
		#echo $timeend
	startpoint=$timestart
	startmin=$(($startpoint/60))
	startsec=$(($startpoint % 60))
	lengthmin=$(($length/60))
	lengthsec=$(($length % 60))

	totaltimehour=`printf %02d $((($totaltime + $startpoint)/3600))`		
	totaltimemin=`printf %02d $(((($totaltime + $startpoint) % 3600)/60))`
	totaltimesec=`printf $((($totaltime + $startpoint) % 60))`

	start_formatted="00:$startmin:$startsec"
	length_formatted="00:$lengthmin:$lengthsec"
	totaltime_formatted="$totaltimehour:$totaltimemin"
	echo "Total Time: " $totaltime_formatted
	echo "Timestart: " $(($totaltime+$startpoint))
	echo "Duration: " $length_formatted
				
	if [[ $minend =~ s ]]; then # Skips this file if it is shorter than 1 min.
		continue
	fi

	if [[ "$(($startpoint + $length))" -gt "$timeend" ]]; then #If the video file is shorter than segment length don't attempt 			
		continue
	fi	


#############################
### Process file
############################
	out_file="$beeid"_"$recordingdate"_"$totaltimehour"."$totaltimemin"_for_"$length"sec
	# mkdir $out_file
	## The command to convert video to 1600:900 video in mjpeg format
	# command_line_options="-vf "yadif=0:-1:0,scale=1600:900,setpts=1*PTS" -loglevel quiet -ss $start_formatted -t $length_formatted -s 1600x900 -f avi -vcodec mjpeg -q:v 2 -r 29.97 -an "$out_file".avi"
	# The command to convert video to 1600:900 video in tiff format
#	command_line_options="-compression_algo raw -vf "yadif=0:-1:0,scale=1600:900,setpts=1*PTS" -ss $start_formatted -t $length_formatted -s 1600x900 -vcodec tiff -pix_fmt rgb24 -an "$out_file/$out_file"%05d.tif"
	# Grayscale		
	# command_line_options="-compression_algo raw -vf "yadif=0:-1:0,scale=1600:900,setpts=1*PTS" -ss $start_formatted -t $length_formatted -s 1600x900 -vcodec tiff -pix_fmt gray16be -an "$out_file/$out_file"%05d.tif"
	
	# Simple copying of video to "temp_slice.MTS" file
	temp_slice="temp_slice.AVI"
	command_line_options="-ss $start_formatted -t $length_formatted -vcodec copy -an $temp_slice"
	command_line="< /dev/null avconv -y -i $in_file $command_line_options"
	echo "##########################"
	echo $command_line
	echo "##########################"
	eval $command_line		


	# Convert "temp_slice.MTS" to TIFs
	mkdir $out_file
	# Grayscale 8 bit		
	command_line_options="-compression_algo raw -r 29.970 -vcodec tiff -pix_fmt gray "$out_file/$out_file"%05d.tif"
	command_line="< /dev/null avconv -i $temp_slice $command_line_options"
	echo "##########################"
	echo $command_line
	echo "##########################"
	eval $command_line
	eval "</dev/null avconv -i $temp_slice -c:v libx264 $out_file.mp4"
	rm $temp_slice

done < $INPUT
IFS=$OLDIFS
exit
