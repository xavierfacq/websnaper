#!/bin/sh

# check PID
PID_FILE='/tmp/websnap.pid'

# check since when the pid is created
if [ -e $PID_FILE ] 
then
	NOW_IN_MILLIS=`date --utc +%s`
	FILE_IN_MILLIS=`date --utc --reference=$PID_FILE +%s`
	ELAPSED_IN_MILLIS=$(($NOW_IN_MILLIS - $FILE_IN_MILLIS))

	if [ $ELAPSED_IN_MILLIS -gt 120 ] 
	then
		#echo 'this pid is too old, I remove it'
		killall chrome
		rm -rf $PID_FILE
	fi
fi

if [ -e $PID_FILE ] 
then
	echo "Content-type: text/html"
	echo ""
	echo "busy..."
else
	touch $PID_FILE

	URL=`echo "$QUERY_STRING" | grep -oE "(^|[?&])url=[^&]+" | cut -f 2 -d "="`
	SIZE=`echo "$QUERY_STRING" | grep -oE "(^|[?&])size=[^&]+" | cut -f 2 -d "="`

	if [ $SIZE != 'XXL' -a $SIZE != 'XL' -a $SIZE != 'L' -a $SIZE != 'M' -a $SIZE != 'S' ]
	then
	      echo "Status: 400 Bad Request"
	      echo "Content-type: text/html"
	      echo ""
	      echo "Missing or wrong parameter 'size'. Values are : (L)arge,(M)edium,(S)mall"
	else
	      # check HTTP HEADER response
	      HTTP_CODE=`curl --user-agent "Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/532.0 (KHTML, like Gecko) Chrome/4.0.202.0 Safari/532.0" --connect-timeout 10 -s -w "%{http_code}\n" -o /dev/null $URL`
	      HTTP_CODE=`expr substr $HTTP_CODE 1 1`

	      if [ $HTTP_CODE != 0 -a $HTTP_CODE != 4 -a $HTTP_CODE != 5 ]
	      then
		    CROPPED_SIZE='1265x1024+0+0'
		    case $SIZE in
		      'XXL')
			  FINISHED_SIZE='1280x1024'
			  ;;
		      'XL')
			  FINISHED_SIZE='1024x768'
			  ;;
		      'L')
			  FINISHED_SIZE='640x480'
			  ;;
		      'M')
			  FINISHED_SIZE='320x240'
			  ;;
		      'S')
			  FINISHED_SIZE='80x60'
			  ;;
		      *)
			  ;;
		    esac

		      # start Xvfb if necessary
		      XVFB_PID=`pidof Xvfb`
		      if [ -z $XVFB_PID ]
		      then
			      Xvfb :2 -screen 0 1280x1024x24 -ac -fbdir /tmp/ &
		      fi

		      # default settings
		      export DISPLAY=:2.0
		      xsetroot -solid White

		      OUPUT_FILE=`echo $URL | tr ':/\.' '-'`
		      OUPUT_FILE=`echo '/tmp/'$OUPUT_FILE'.png'`

		      google-chrome --start-maximized --kiosk --disable-java --disable-logging --disable-metrics-reporting --disable-dev-tools $URL &
		      sleep 7

		      import -window root -silent -quiet $OUPUT_FILE

		      convert $OUPUT_FILE -crop $CROPPED_SIZE -resize $FINISHED_SIZE\! PNG8:$OUPUT_FILE
		      # compression with optipng
		      #optipng -quiet -o5 $OUPUT_FILE -out $OUPUT_FILE

		      # compression with pngquant
		      pngquant -ext .png -force 256 $OUPUT_FILE

		      sleep 2
		      killall -q -u www-data chrome

		      COLOR_COUNT=`identify -format "%k" $OUPUT_FILE`
		      if [ -s $OUPUT_FILE -a $COLOR_COUNT -gt 20 ] 
		      then
			      # as websnaper for wikio 
			      echo "x-image-status: 1"
			      echo "Content-type: image/png"
			      echo ""
			      cat $OUPUT_FILE
		      else
			      # as websnaper for wikio 
			      echo "x-image-status: 2"
			      echo "Content-type: text/html"
			      echo ""
			      echo "not content"
		      fi
		      rm -rf $OUPUT_FILE
	      else
		      echo "Content-type: text/html"
		      echo ""
		      echo "Content not available. Missing or wrong parameter 'url'."
		      echo $URL" returns an HTTP error: "$HTTP_CODE
	      fi
	 fi

	rm -rf $PID_FILE
fi
