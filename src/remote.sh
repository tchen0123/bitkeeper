#!/bin/bash

# The build script sets this so I'm not sure why we bother here.
# XXX - the build script should be merged into this.
PATH=/bin:/usr/bin:/usr/bsd:/usr/local/bin:/usr/gnu/bin:/usr/freeware/bin:/usr/ccs/bin

umask 0

test $OSTYPE = cygwin && {
	PATH=$PATH:/cygdrive/c/WINDOWS/system32::/cygdrive/c/PROGRA~1/BITKEE~1
	bk bkd -R >/dev/null 2>&1
}
BK_NOTTY=YES
export PATH BK_NOTTY

test X$LOG = X && LOG=LOG-$BK_USER
cd /build
chmod +w .$REPO.$BK_USER
BKDIR=${REPO}-${BK_USER}
CMD=$1
test X$CMD = X && CMD=build

failed() {
	echo '*****************'
	echo '!!!! Failed! !!!!'
	echo '*****************'
	exit 1
}

case $CMD in
    build|save)
	exec > /build/$LOG 2>&1
	set -e
	rm -rf /build/$BKDIR
	test -d .images && {
		find .images -type f -mtime +3 -print > .list$BK_USER
		test -s .list$BK_USER && xargs /bin/rm -f < .list$BK_USER
		rm -f .list$BK_USER
	}
	sleep 5		# give the other guys time to get rcp'ed and started

	BK_NOTTY=YES BK_LICENSE=ACCEPTED bk clone -z0 $URL $BKDIR || failed

	DOTBK=`bk dotbk`
	test "X$DOTBK" != X && rm -f "$DOTBK/lease/`bk gethost -r`"

	cd $BKDIR/src
	bk get Makefile build.sh
	make build || failed
	./build p image install test || failed

	MSG="Not your lucky day, the following tests failed:"
	test "X`grep "$MSG" /build/$LOG`" = "X$MSG" && exit 1

	test -d /build/.images || mkdir /build/.images
	cp utils/bk-* /build/.images

	# Leave the directory there only if they asked for a saved build
	test $CMD = save || {
		cd /build	# windows won't remove .
		rm -rf /build/$BKDIR
		# XXX - I'd like to remove /build/.bk-3.0.x.regcheck.lm but I
		# can't on windows, we have it open.
		test $OSTYPE = cygwin || rm -f /build/.${BKDIR}.$BK_USER
	}
	rm -rf /build/.tmp-$BK_USER
	;;

    clean)
	rm -rf /build/$BKDIR /build/$LOG
	;;

    status)
	MSG="Not your lucky day, the following tests failed:"
	test "X`grep "$MSG" $LOG`" = "X$MSG" && {
		echo regressions failed.
		exit 1
	}
	# grep -q is not portable so we use this
	test "X`grep '!!!! Failed! !!!!' $LOG`" = 'X!!!! Failed! !!!!' && {
		echo failed to build.
		exit 1
	}
	MSG="All requested tests passed, must be my lucky day"
	test "X`grep "$MSG" $LOG`" = "X$MSG" && {
		echo succeeded.
		exit 1
	}
	echo is not done yet.
	;;

    log)
	cat $LOG
	;;
esac