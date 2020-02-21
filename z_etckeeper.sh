# Place this in /usr/libexec/slackpkg/functions.d and make sure it's sourced AFTER slackpkg+'s files
#
# Override slackpkg(+)'s "makelist" and "cleanup" functions to
# add etckeeper. All changes contain "etckeeper" in their comments.
#
# "makelist" modifications for the pre-install hooks
#
# Function to make install/reinstall/upgrade lists
#
function makelist() {
        #echo "THIS IS MAKELIST FROM MODDED FOR ETCKEEPER"
        local ARGUMENT
        local i
        local VRFY

        INPUTLIST=$@

        grep -vE "(^#|^[[:blank:]]*$)" ${CONF}/blacklist > ${TMPDIR}/blacklist
        if echo $CMD | grep -q install ; then
                ls -1 $ROOT/var/log/packages/* | awk -f /usr/libexec/slackpkg/pkglist.awk > ${TMPDIR}/tmplist
        else
                ls -1 $ROOT/var/log/packages/* | awk -f /usr/libexec/slackpkg/pkglist.awk | applyblacklist > ${TMPDIR}/tmplist
        fi
        cat ${ROOT}/${WORKDIR}/pkglist | applyblacklist > ${TMPDIR}/pkglist

        # Create etckeeper's list
        if [ -x /usr/bin/etckeeper ]; then
                etckeeper pre-install
        fi
        if [ $? != 0 ]; then
                ( rm -f /var/lock/slackpkg.$$ && rm -rf $TMPDIR ) &>/dev/null
                exit
        fi

        touch ${TMPDIR}/waiting

        case "$CMD" in
                clean-system)
                        echo -n "Looking for packages to remove. Please wait... "
                ;;
                upgrade-all)
                        echo -n "Looking for packages to upgrade. Please wait... "
                ;;
                install-new)
                        echo -n "Looking for NEW packages to install. Please wait... "
                ;;
                *-template)
                        echo -n "Looking for packages in \"$ARG\" template to ${CMD/%-template/}. Please wait..."
                ;;
                *)
                        echo -n "Looking for $(echo $INPUTLIST | tr -d '\\') in package list. Please wait... "
                ;;
        esac

        [ "$SPINNING" = "off" ] || spinning ${TMPDIR}/waiting &

        case "$CMD" in
                download)
                        for ARGUMENT in $(echo $INPUTLIST); do
                                for i in $(grep -w -- "${ARGUMENT}" ${TMPDIR}/pkglist | cut -f2 -d\  | sort -u); do
                                        LIST="$LIST $(grep " ${i} " ${TMPDIR}/pkglist | cut -f6,8 -d\  --output-delimiter=.)"
                                done
                                LIST="$(echo -e $LIST | sort -u)"
                        done
                ;;
                blacklist)
                        for ARGUMENT in $(echo $INPUTLIST); do
                                for i in $(cat ${TMPDIR}/pkglist ${TMPDIR}/tmplist | \
                                                grep -w -- "${ARGUMENT}" | cut -f2 -d\  | sort -u); do
                                        grep -qx "${i}" ${CONF}/blacklist || LIST="$LIST $i"
                                done
                        done
                ;;
                install|upgrade|reinstall)
                        for ARGUMENT in $(echo $INPUTLIST); do
                                for i in $(grep -w -- "${ARGUMENT}" ${TMPDIR}/pkglist | cut -f2 -d\  | sort -u); do
                                        givepriority $i
                                        [ ! "$FULLNAME" ] && continue

                                        case $CMD in
                                                'upgrade')
                                                        VRFY=$(cut -f6 -d\  ${TMPDIR}/tmplist | \
                                                              grep -x "${NAME}-[^-]\+-\(noarch\|fw\|${ARCH}\)-[^-]\+")
                                                        [ "${FULLNAME/%.t[blxg]z/}" != "${VRFY}" ]  && \
                                                                                [ "${VRFY}" ] && \
                                                                LIST="$LIST ${FULLNAME}"
                                                ;;
                                                'install')
                                                        grep -q " ${NAME} " ${TMPDIR}/tmplist || \
                                                                LIST="$LIST ${FULLNAME}"
                                                ;;
                                                'reinstall')
                                                        grep -q " ${FULLNAME/%.t[blxg]z} " ${TMPDIR}/tmplist && \
                                                                LIST="$LIST ${FULLNAME}"
                                                ;;
                                        esac
                                done
                        done
                ;;
                remove)
                        for ARGUMENT in $(echo $INPUTLIST); do
                                for i in $(cat ${TMPDIR}/pkglist ${TMPDIR}/tmplist | \
                                                grep -w -- "${ARGUMENT}" | cut -f6 -d\  | sort -u); do
                                        PKGDATA=( $(grep -w -- "$i" ${TMPDIR}/tmplist) )
                                        [ ! "$PKGDATA" ] && continue
                                        LIST="$LIST ${PKGDATA[5]}"
                                        unset PKGDATA
                                done
                        done
                ;;
                clean-system)
                        listpkgname
                        for i in $(comm -2 -3 ${TMPDIR}/lpkg ${TMPDIR}/spkg) ; do
                                PKGDATA=( $(grep -- "^local $i " ${TMPDIR}/tmplist) )
                                [ ! "$PKGDATA" ] && continue
                                LIST="$LIST ${PKGDATA[5]}"
                                unset PKGDATA
                        done
                ;;
                upgrade-all)
                        listpkgname
                        for i in $(comm -1 -2 ${TMPDIR}/lpkg ${TMPDIR}/dpkg | \
                                   comm -1 -2 - ${TMPDIR}/spkg) ; do

                                givepriority ${i}
                                [ ! "$FULLNAME" ] && continue

                                VRFY=$(cut -f6 -d\  ${TMPDIR}/tmplist | grep -x "${NAME}-[^-]\+-\(noarch\|fw\|${ARCH}\)-[^-]\+")
                                [ "${FULLNAME/%.t[blxg]z}" != "${VRFY}" ]  && \
                                                        [ "${VRFY}" ] && \
                                        LIST="$LIST ${FULLNAME}"
                        done
                ;;
                install-new)
                        for i in $(awk -f /usr/libexec/slackpkg/install-new.awk ${ROOT}/${WORKDIR}/ChangeLog.txt |\
                                  sort -u ) dialog aaa_terminfo fontconfig \
                                ntfs-3g ghostscript wqy-zenhei-font-ttf \
                                xbacklight xf86-video-geode ; do

                                givepriority $i
                                [ ! "$FULLNAME" ] && continue

                                grep -q " ${NAME} " ${TMPDIR}/tmplist || \
                                        LIST="$LIST ${FULLNAME}"
                        done
                ;;
                install-template)
                        for i in $INPUTLIST ; do
                                givepriority $i
                                [ ! "$FULLNAME" ] && continue
                                grep -q " ${NAME} " ${TMPDIR}/tmplist || \
                                        LIST="$LIST ${FULLNAME}"
                        done
                ;;
                remove-template)
                        for i in $INPUTLIST ; do
                                givepriority $i
                                [ ! "$FULLNAME" ] && continue
                                grep -q " ${NAME} " ${TMPDIR}/tmplist && \
                                        LIST="$LIST ${FULLNAME}"
                        done
                ;;
                search|file-search)
                                # -- temporary file used to store the basename of selected
                                #    packages.

                        PKGNAMELIST=$(tempfile --directory=$TMPDIR)

                        if [ "$CMD" = "file-search" ]; then
                                # Search filelist.gz for possible matches
                                for i in ${PRIORITY[@]}; do
                                        if [ -e ${ROOT}/${WORKDIR}/${i}-filelist.gz ]; then
                                                PKGS="$(zegrep -w "${INPUTLIST}" ${ROOT}/${WORKDIR}/${i}-filelist.gz | \
                                                        cut -d\  -f 1 | awk -F'/' '{print $NF}')"
                                                for FULLNAME in $PKGS ; do
                                                        NAME=$(cutpkg ${FULLNAME})
                                                        grep -q "^${NAME}$" $PKGNAMELIST && continue
                                                        LIST="$LIST ${FULLNAME}"
                                                        echo "$NAME" >> $PKGNAMELIST
                                                done
                                        fi
                                done
                        else
                                for i in ${PRIORITY[@]}; do
                                        PKGS=$(grep "^${i}.*${PATTERN}" \
                                                ${TMPDIR}/pkglist | cut -f6 -d\ )
                                        for FULLNAME in $PKGS ; do
                                                NAME=$(cutpkg ${FULLNAME})

                                                grep -q "^${NAME}$" $PKGNAMELIST && continue
                                                LIST="$LIST ${FULLNAME}"
                                                echo "$NAME" >> $PKGNAMELIST
                                        done
                                done
                        fi
                        rm -f $PKGNAMELIST
                ;;
        esac
        LIST=$(echo -e $LIST | tr \  "\n" | uniq )

        rm ${TMPDIR}/waiting

        echo -e "DONE\n"
}

# "cleanup" modifications for etckeeper's post-install hooks
#
# Clean-up tmp and lock files
#
function cleanup() {
        # etckeeper:
        # Check if slackpkg+ exists and is enabled:
        if [ -e /etc/slackpkg/slackpkgplus.conf ]; then
                source /etc/slackpkg/slackpkgplus.conf
        else
                SLACKPKGPLUS="off"
        fi

        # List of commands that actually install or remove things
        INSTALLCMDS=(install reinstall upgrade remove clean-system upgrade-all install-new install-template remove-template)

        # etckeeper:
        # If not using slackpkgplus, use slackpkg's version
        if [ $SLACKPKGPLUS == "off" ]; then

                [ "$SPINNING" = "off" ] || tput cnorm
                if [ -e $TMPDIR/error.log ]; then
                        echo -e "
\n==============================================================================
WARNING!        WARNING!        WARNING!        WARNING!        WARNING!
==============================================================================
One or more errors occurred while slackpkg was running:
"
                        cat $TMPDIR/error.log
                        echo -e "
=============================================================================="
                fi
                echo
                if [ "$DELALL" = "on" ] && [ "$NAMEPKG" != "" ]; then
                        rm $CACHEPATH/$NAMEPKG &>/dev/null
                fi
                ( rm -f /var/lock/slackpkg.$$ && rm -rf $TMPDIR ) &>/dev/null
                # Add etckeeper's post hook
                if [ -x /usr/bin/etckeeper ] && [[ ${INSTALLCMDS[@]} =~ $CMD ]] ; then
                        etckeeper post-install
                fi
                exit

        else
                # If using slackpkgplus, use their version
                # Override cleanup() to improve log messages and debug functions

                # Get the current exit-code so that we can check if cleanup is
                # called in response of a CTRL+C (ie. $?=130) or not.
                local lEcode=$?

                if [ "$CMD" == "info" ];then
                        DETAILED_INFO=${DETAILED_INFO:-none}
                        [[ "$DETAILED_INFO" != "none" ]]&&more_info
                fi
                rm -f ${TMPDIR}/waiting
                if [ "$CMD" == "update" ];then
                        if [ "$ANSWER" != "Y" ] && [ "$ANSWER" != "y" ]; then
                                touch $WORKDIR/pkglist
                        fi

                        # When cleanup() has not been called in response of a CTRL+C, copy
                        # the files -downloaded and generated by getfile()- from
                        # TMPDIR/ChangeLogs into WORKDIR/ChangeLogs
                        #
                        if [ $lEcode -ne 130 ] && [ -e ${TMPDIR}/ChangeLogs ] ; then
                                if [ ! -e ${WORKDIR}/ChangeLogs ] ; then
                                        mkdir ${WORKDIR}/ChangeLogs
                                else
                                        rm -f ${WORKDIR}/ChangeLogs/*
                                fi
                                cp ${TMPDIR}/ChangeLogs/* ${WORKDIR}/ChangeLogs
                        fi
                fi
                [ "$TTYREDIRECTION" ] && exec 1>&3 2>&4
                [ "$SPINNING" = "off" ] || tput cnorm
                if [ "$DELALL" = "on" ] && [ "$NAMEPKG" != "" ]; then
                        rm $CACHEPATH/$NAMEPKG &>/dev/null
                fi
                if [ $VERBOSE -gt 2 ];then
                        echo "The temp directory $TMPDIR will NOT be removed!" >>$TMPDIR/info.log
                        echo
                fi
                if [ -s $TMPDIR/error.log -o -s $TMPDIR/info.log ];then
                        echo -e "\n\n=============================================================================="
                fi
                if [ -e $TMPDIR/error.log ]; then
                        echo "  WARNING! One or more errors occurred while slackpkg was running"
                        echo "------------------------------------------------------------------------------"
                        cat $TMPDIR/error.log
                        if [ -s $TMPDIR/info.log ];then
                                echo "------------------------------------------------------------------------------"
                        fi
                fi
                if [ -s $TMPDIR/info.log ]; then
                        echo "  INFO! Debug informations"
                        echo "------------------------------------------------------------------------------"
                        cat $TMPDIR/info.log
                        echo "=============================================================================="
                fi
                echo
                # Add etckeeper's post hook, but only when (un)-installing stuff
                echo "slackpkg+ + etckeeper: $CMD"
                if [ -x /usr/bin/etckeeper ] && [[ ${INSTALLCMDS[@]} =~ $CMD ]] ; then
                        etckeeper post-install
                fi
                rm -f /var/lock/slackpkg.$$
                if [ $VERBOSE -lt 3 ];then
                        rm -rf $TMPDIR
                fi
                exit
        fi
} # END function cleanup()
