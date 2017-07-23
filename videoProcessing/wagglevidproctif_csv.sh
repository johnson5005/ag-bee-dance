#!/bin/bash
# Preparation script for waggle dance analysis with MTrackJ inside the FIJI package
# Depends on exiftool mediainfo avconv

# Will automatically concatenate and use all files in a directory specified in the csv file provided on the command line

INPUT=$1
OLDIFS=$IFS
IFS=,
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read filepath sitename
	do
	echo "Path : $filepath"
	echo "Site : $sitename"

#	echo -n "Site Name: "
#	echo -n ""
#	read sitename
#	echo "$sitename"

	length=60 # length of clip to make (seconds)
	timestart=210 # time to start the first clip (seconds) Use "60" for initial run and "210" if fewer than 10 dances are found that day
#	timestart=60 #	
	timestep=300 # time step between beginings of clips (seconds)

	## Remove processed video from previous runs
	#if [[ -n $(find ./ -iname "*avi") ]]; then
	#	rm *avi
	#fi
	# Find movie files in directory and sort them
	if [[ -n $( find $filepath \( -iname "*MP4" -o -iname "*MOV" -o -iname "*MTS" \) ) ]]; then
		array=() # Initialize the array
		while IFS=  read -r -d $'\0'; do
			array+=("$REPLY")
		done < <(find $filepath \( -iname "*MP4" -o -iname "*MOV" -o -iname "*MTS" \) -print0)
		readarray -t in_files < <(printf '%s\0' "${array[@]}" | sort -z | xargs -0n1) # Sort the array
	#	in_files=$(find ./ \( -iname "*MP4" -o -iname "*MOV" -o -iname "*MTS" \) | sort) # get list of video files and store in "$in_files"
	else
		echo "No video files in this directory"
		continue
	fi

	echo $in_files

	# Determine start time using EXIFTOOL and format it correctly
	startdatetime=`exiftool -datetimeoriginal ${in_files[0]}`
	recordingdate=`echo $startdatetime | perl -pe 's/.*(\d{4}:\d{2}:\d{2}).*/$1/; s/:/\//g' | date -f - +%m%d%y`
	recordingstarthour=`echo $startdatetime | perl -pe 's/.*\s(\d{2}).*/$1/'`
	recordingstartminute=`echo $startdatetime | perl -pe 's/.*\s\d{2}:(\d{2}).*/$1/'`
	echo "Recording Date: $recordingdate"
	echo "Recording Start Hour: $recordingstarthour"
	echo "Recording Start Minute: $recordingstartminute"

	# Deterimine time in seconds since midnight
	totaltime=$(( ($(echo $recordingstarthour | sed 's/^0*//')* 3600) + ($(echo $recordingstartminute | sed 's/^0*//')*60) ))
	# Set startpoint for this group of video files

	#for ((i=0 ; i<1 ; i++)); do ## Testing
	for ((i=0 ; i<${#in_files[@]} ; i++)); do
	#for in_file in $in_files; do
		in_file=${in_files[$i]}
		duration=`mediainfo --Inform="Video;%Duration/String1%" $in_file`
		minend=`echo $duration | perl -pe 's/^(\d+)mn.*/$1/'`
		secend=`echo $duration | perl -pe 's/^\d+mn (\d+)s.*/$1/'`
		#echo $minend
		#echo $secend
		if [[ $minend =~ s ]]; then # Skips this file if it is shorter than 1 min.
			continue
		fi
			
		timeend=$((($minend*60)+$secend))

		#echo $timeend
		# Loop through video at increments indicated by "$timestep"
		startpoint=$timestart
		while [[ $startpoint -le $timeend ]]	
		do
#		for start in $(eval echo "{$timestart..$timeend..$timestep}"); do 				
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
			#echo "Start Time: " $start
			echo "Duration: " $length_formatted
				
			out_file="$sitename"_"$recordingdate"_"$totaltimehour"."$totaltimemin"_for_"$length"sec
			# mkdir $out_file
			## The command to convert video to 1600:900 video in mjpeg format
			# command_line_options="-vf "yadif=0:-1:0,scale=1600:900,setpts=1*PTS" -loglevel quiet -ss $start_formatted -t $length_formatted -s 1600x900 -f avi -vcodec mjpeg -q:v 2 -r 29.97 -an "$out_file".avi"
			# The command to convert video to 1600:900 video in tiff format
	#		command_line_options="-compression_algo raw -vf "yadif=0:-1:0,scale=1600:900,setpts=1*PTS" -ss $start_formatted -t $length_formatted -s 1600x900 -vcodec tiff -pix_fmt rgb24 -an "$out_file/$out_file"%05d.tif"
			# Grayscale		
			# command_line_options="-compression_algo raw -vf "yadif=0:-1:0,scale=1600:900,setpts=1*PTS" -ss $start_formatted -t $length_formatted -s 1600x900 -vcodec tiff -pix_fmt gray16be -an "$out_file/$out_file"%05d.tif"
			
			# Simple copying of video to "temp_slice.MTS" file
			temp_slice="temp_slice.AVI"
			command_line_options="-ss $start_formatted -t $length_formatted -vcodec copy -an $temp_slice"

			if [[ "$(($startpoint + $length))" -gt "$timeend" ]]; then #If the video file is shorter than segment length, concatenate two files			
				echo "Concatenating!"
				cat ${in_files[$i]} ${in_files[$(($i+1))]} > zTemp.MTS
				command_line="avconv -y -i zTemp.MTS $command_line_options"
				#echo $command_line
				eval $command_line
				rm zTemp.MTS
#				continue
			
			else
				command_line="avconv -y -i $in_file $command_line_options"
				eval $command_line
			fi		

			#echo $command_line

			# Convert "temp_slice.MTS" to TIFs
			mkdir $out_file
			# Grayscale 8 bit		
			command_line_options="-compression_algo raw -r 29.970 -vcodec tiff -pix_fmt gray "$out_file/$out_file"%05d.tif"
			command_line="avconv -i $temp_slice $command_line_options"
			#echo $command_line
			eval $command_line

			startpoint=$(($startpoint + $timestep)) # Advance the start time by "$timestep" 
		done
		timestart=$(($timestep-($timeend-($startpoint-$timestep)))) #Adjust timestart so that subsequent files pick up where previous left off
		totaltime=$(($totaltime + $timeend)) #Adjust total time since beginning of recording
		echo $timestart
	done

	 rm $temp_slice
done < $INPUT
IFS=$OLDIFS
exit
