#!/bin/sh

./frontier-dev-latest-post-times.pl > frontier-dev-latest-post-times.html.tmp
if [ $? -eq 0 ];
then
	mv -f frontier-dev-latest-post-times.html.tmp frontier-dev-latest-post-times.html
	chmod 644 frontier-dev-latest-post-times.html
fi
rm -f frontier-dev-latest-post-times.html.tmp
