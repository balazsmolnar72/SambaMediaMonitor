#!/bin/bash
. /home/balazs/bin/mediawatch/mediamon.conf

status=$( sudo /usr/bin/smbstatus )
#status=$( cat teststatus1 )
#status=$( cat teststatus )
#status=$( cat teststatus2 )

# this is the status discovery part of the code

mv $MEDIAMON_HOME/media.status $MEDIAMON_HOME/media.old
echo "$status" | grep "No locked files" >/dev/null
if [ "$?" == "0" ]
then
	echo -n >$MEDIAMON_HOME/media.status
else
	locked="$( /bin/sed  "1,/Locked files:/d" < <(echo "$status" | grep -Fvf $MEDIAMON_HOME/mediaexception) )"
 	numfiles=$(($(/bin/sed  "1,/Locked files:/d" < <(echo "$status" | grep -Fvf $MEDIAMON_HOME/mediaexception) | wc -l)-2))
	if [ "$numfiles" == "0" ]
	then
		echo -n >$MEDIAMON_HOME/media.status
		locked=""
	else
		locked="$(echo "$locked" | /usr/bin/tail -$((numfiles)) | /usr/bin/head -$numfiles)"
		/usr/bin/touch $MEDIAMON_HOME/media.status
		while read file
		do
			filename="$( echo "$file" | /usr/bin/tr -s ' ' | /usr/bin/awk '{ print $7"/"$8}')"
			echo -n "Filename:$filename " >> $MEDIAMON_HOME/media.status
			since=$( echo "$file" | /usr/bin/tr -s ' ' | /usr/bin/cut -d' ' -f9- )
			echo -n "since:" >> $MEDIAMON_HOME/media.status
			/bin/date -d "$since" "+%x %X">> $MEDIAMON_HOME/media.status
		done <<<"$locked"
	fi
fi

if diff $MEDIAMON_HOME/media.status $MEDIAMON_HOME/media.old >/dev/null
then
	echo >/dev/null
elif [ "$( cat $MEDIAMON_HOME/media.status | wc -l )" -lt "$( cat $MEDIAMON_HOME/media.old | wc -l )" ]
then
	while read file
	do
		{
		echo -n "$(date "+%x %X") " 
		echo -n "Watched:" 
		echo -n $(echo $file | /usr/bin/cut -d' ' -f1 | /usr/bin/cut -d':' -f2)
		echo -n " Duration:"
		duration=$(( $(/bin/date "+%s") - $(/bin/date -d "$(echo $file | /usr/bin/cut -d':' -f3)" '+%s') ))
		/usr/bin/printf "%02d:%02d:%02d\n" $(( $duration/3600 )) $(( $duration%3600/60 )) $(( $duration%3600%60 )) 
		} >> $MEDIAMON_LOG/mediamon.log
		filename="$(echo $file | /usr/bin/cut -d' ' -f1 | /usr/bin/cut -d':' -f2 | /usr/bin/awk -F'/' '{ print $NF }')"
		if [ -e $MEDIAMON_HOME/active ] && ! grep "$filename" $MEDIAMON_HOME/media.status
                then
			echo "$(/bin/date "+%x %X") stopped:$filename" | /home/balazs/bin/notifyBalazs
                fi
	done < "$MEDIAMON_HOME/media.old"
else
        while read file
        do
                filename="$(echo $file | /usr/bin/cut -d' ' -f1 | /usr/bin/cut -d':' -f2 | /usr/bin/awk -F'/' '{ print $NF }')"
 		if [ -e $MEDIAMON_HOME/active ] && ! grep "$filename" $MEDIAMON_HOME/media.old
		then
                        echo "$(/bin/date "+%x %X") started:$filename" | /home/balazs/bin/notifyBalazs
 
		fi
        done < "$MEDIAMON_HOME/media.status"
fi
