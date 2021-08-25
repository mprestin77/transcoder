#!/bin/bash
set -e #Exit if any of commands fails
set -x
INPUT_FILE=$1
INPUT_BUCKET=$TC_SRC_BUCKET
OUTPUT_BUCKET=$TC_DST_BUCKET
OS_NAMESPACE=$TC_OS_NAMESPACE
OUTPUT_DIR="/tmp/ffmpeg"
DB_HOST=$TC_DB_HOST
DB_NAME=$TC_DB_NAME
DB_USER=$TC_DB_USER
DB_PWD=$TC_DB_PASSWORD
CDN_URL=$TC_FFMPEG_HLS_BASE_URL

#Download the input file from OCI object storage
echo "Downloading file $INPUT_FILE from $INPUT_BUCKET OS bucket"
ifile="/tmp/$(basename $INPUT_FILE)"
oci os object get --namespace $OS_NAMESPACE --bucket-name $INPUT_BUCKET --name $INPUT_FILE --file $ifile --auth instance_principal

#Check resolution of the video file
#res=`./ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 ../../images/big_buck_bunny_1080p_h264.mov`

#Create output directories
mkdir -p $OUTPUT_DIR
cd $OUTPUT_DIR

#Run ffmpeg transcoding
echo "Transcoding file $INPUT_FILE"
ffmpeg -i $ifile $TC_FFMPEG_CONFIG -hls_base_url "${TC_FFMPEG_HLS_BASE_URL}/${INPUT_FILE}/" -var_stream_map "${TC_FFMPEG_STREAM_MAP}" stream_%v.m3u8

  
#Upload the transcoded files to OCI object storage bucket
echo "Uploading transcoded files to $TC_DST_BUCKET OS bicket"
#Firt check if the folder with this name already exists. If found - delete it including all objects inside the folder.
oci os object bulk-delete --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --prefix $INPUT_FILE/ --force --auth instance_principal
for dir in *
do
  if [ -d $dir ]; then
    for file in $dir/*
    do
      oci os object put --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --file $file --name $INPUT_FILE/$file --force --auth instance_principal
    done
  fi
done

#Upload manifest files to OCI object storage bucket
for file in *.m3u8
do
#  fname=$(echo $file | cut -d'.' -f1)
#  if [[ "$fname" == "stream_"* ]]; then
#    stream_dir="$fname/" #stream manifest file
#  else
#    stream_dir=""        #master manifest file
#  fi

  #If CDN_URL variable is set update manifest files adding CDN_URL prefix to the file path 
#  if [ ! -z $CDN_URL ]; then
#    URL=$(echo $CDN_URL/$INPUT_FILE/$stream_dir | sed -e 's/\//\\\//g')
#    echo $URL
#    sed -i -e "/^[a-z]/ s/^/$URL/" $file
#  fi

  oci os object put --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --file $file --name $INPUT_FILE/$file --force --auth instance_principal
done

#Update DB
echo "Updating $DB_NAME DB"

if [ ! -z $CDN_URL ]; then
  URL="$CDN_URL/$INPUT_FILE/master.m3u8"
else
  URL=""
fi

mysql -h $DB_HOST -u $DB_USER -p"$DB_PWD" -D $DB_NAME -e "delete from transcoded_files where name='$INPUT_FILE'; insert into transcoded_files (name, bucket, object, url, create_date) values ('$INPUT_FILE', '$OUTPUT_BUCKET', '$INPUT_FILE/master.m3u8', '$URL', now())"

