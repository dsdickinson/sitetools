#!/usr/bin/env bash
#############################################################################
# PROGRAM
#     sitepet.sh
#
# SYNOPSIS
#     Used to append idea snippets to a log file for later addition to a website
#
# USAGE
#     sitepet [-h] [-i ip address] [-r] [-p password] [-s 'snippet'] [-u user name]
#             [-v] [-w]
#
# OPTIONS
#    -h      		Usage information
#    -i [ip address]    FTP ip address
#    -r      		Empty the log file on website
#    -p [password]	FTP site root password
#    -s '[snippet]'	Snippet to append to log file
#    -u [user name] 	FTP site user name
#    -v      		Be verbose
#    -w      		Be extra verbose
#
# MODULES/FILES REQUIRED
#     None
#
# PROGRAMS REQUIRED
#     None
#
# AUTHOR
#     Steve Dickinson
#
# DEVELOPMENT DATES
#     04.27.09
#
# RELEASE DATE
#     04.29.09
#
# COMMENTS
#     None
#
# REVISIONS
#     None
#############################################################################
# GLOBAL VARIABLES / SETTINGS
#############################################################################
# SET THE FOLLOWING VARIABLES TO CORRECT VALUES FOR THE FTP SITE
# NO OTHER SECTIONS NEED TO BE MODIFIED BY THE USER
#############################################################################
FTP_IP='IP';
FTP_LOGIN='LOGIN';
FTP_PASSWORD='PASSWORD';

# REMOTE SERVER'S ROOT DIRECTORY FOR SITE
# Keep this blank if the ftp account dumps the user into site's root directory
# and this is where the file to append to will go. Otherwise make it the full
# path to the directory on the remote server where the fill should go.
REMOTE_DIR_ROOT=''; 

# LOCAL SYSTEM'S TMP DIRECTORY
# Temporary directory on the local system where this command will run.
TMP_DIR='/tmp';

# APPEND FILE
# File name to append the snippets to on the website
FILE='sitepet.log';

#############################################################################
# MORE GLOBAL VARIABLES / SETTINGS
#############################################################################
VERSION="0.2";

CP="$(which cp)";
GREP="$(which grep)";
FTP="$(which ftp)";
RM="$(which rm)";

# BACKUP APPEND FILE
# File name to use as a backup before changes are made
FILE_BACKUP=${FILE}.bak;

# REMOTE FILE PATH
# Full file path on the remote system
FILE_PATH=${REMOTE_DIR_ROOT}${FILE};
FILE_BACKUP_PATH=${REMOTE_DIR_ROOT}${FILE_BACKUP};

# LOCAL TMP APPEND FILE PATH
# Temporary file path on the local system
FILE_PATH_TMP=${TMP_DIR}/${FILE}$$;
FILE_BACKUP_PATH_TMP=${TMP_DIR}/${FILE_BACKUP}$$;

# LOCAL TMP FTP LOG FILE NAMES
# File names on the local system to log first/second ftp transfers
LOGFILE1='sitepet_tmp1.log';
LOGFILE2='sitepet_tmp2.log';

# LOCAL TMP FTP LOG FILE PATHS
# Temporary log file paths on local system for first/second ftp transfers
LOGFILE1_PATH_TMP=${TMP_DIR}/${LOGFILE1}$$;
LOGFILE2_PATH_TMP=${TMP_DIR}/${LOGFILE2}$$;

#############################################################################
# USAGE
#############################################################################
usage()
{
PROGRAM=`basename $0`;

cat << EOF
usage: $PROGRAM options

Used to append idea snippets to a log file for later addition to a website.

OPTIONS:
   -h      		Usage information
   -i [ip address]     	FTP ip address
   -r      		Empty the log file on website
   -p [password]	FTP site root password
   -s '[snippet]'	Snippet to append to log file
   -u [user name] 	FTP site user name
   -v      		Be verbose
   -w      		Be extra verbose

EXAMPLES:
> sitepet.sh -v -s 'My idea snippet!' 
Add the entry "My idea snippet!" to the file. Be verbose about it.

> sitepet.sh -w -s 'Another great idea!' -i www.mysite.com -u myuser -p mypass 
Add the entry "Another great idea!" to the file. Be extra verbose about it.
Use the ftp site credentials passed via the command line (Will override any
hardcoded credentials in the script.

EOF
}

#############################################################################
# PROCESS ARGUMENTS
#############################################################################
DEBUG=0;
REMOVE=0;
VERBOSE=0;
SNIPPET='';

while getopts "dhi:rp:s:u:vw" OPTION
do
     case $OPTION in
         d)
             DEBUG=1
             ;;
         h)
             usage
             exit 1
             ;;
         i)
             FTP_IP=$OPTARG
             ;;
         r)
             REMOVE=1
             ;;
         p)
             FTP_PASSWORD=$OPTARG
             ;;
         s)
             SNIPPET=$OPTARG
             ;;
         u)
             FTP_LOGIN=$OPTARG
             ;;
         v)
             VERBOSE=1
             ;;
         w)
             VERBOSE=2
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $FTP_IP ]] || [[ -z $FTP_LOGIN ]] || [[ -z $FTP_PASSWORD ]] || [[ -z $SNIPPET ]]
then
     usage
     exit 1
fi

#############################################################################
# MAIN
#############################################################################
echo "===========";
echo "sitepet $VERSION";
echo "===========";
if [ $DEBUG -eq 1 ]; then
    printf "DEBUG mode on\n";
    echo "";
    echo "      ip = $FTP_IP";
    echo "   login = $FTP_LOGIN";
    echo "password = $FTP_PASSWORD";
    echo " snippet = $SNIPPET";
    echo "";
    echo "Nothing done.";
fi

if [ $DEBUG -eq 0 ]; then

    if [ $VERBOSE -gt 0 ]; then
	echo -n "o Attempting to download $FILE from $FTP_IP ... ";
    fi

if [ $VERBOSE -eq 2 ]; then
echo "";
$FTP -inv $FTP_IP <<EOF | tee $LOGFILE1_PATH_TMP 2>&1
user $FTP_LOGIN $FTP_PASSWORD
ascii
get $FILE_PATH $FILE_PATH_TMP 
quit
EOF
else
$FTP -in $FTP_IP <<EOF > $LOGFILE1_PATH_TMP
user $FTP_LOGIN $FTP_PASSWORD
ascii
get $FILE_PATH $FILE_PATH_TMP 
quit
EOF
fi

    IFS=$'\n'

    FAIL='';
    FAIL=( $($GREP 'fail' $LOGFILE1_PATH_TMP) );
    $RM $LOGFILE1_PATH_TMP;

    if [ "$FAIL" != "" ]; then
        if [ $VERBOSE -gt 0 ]; then
	    echo "[ERROR]";
	fi
        echo "";
	echo "The following errors occured:";
        for this_fail in ${FAIL[@]}
	do
	    echo $this_fail
	done
        echo "";
        exit 1;
    else
        if [ $VERBOSE -gt 0 ]; then
            echo "[OK]";
	fi
    fi

    if [ $VERBOSE -gt 0 ]; then
        if [ $VERBOSE -eq 2 ]; then
            echo "";
	fi
        if [ $DEBUG -eq 1 ]; then
            echo -n "o Writing snippet to $FILE [$FILE_PATH_TMP] ... ";
        else
            echo -n "o Writing snippet to $FILE ... ";
        fi
    fi

    $CP $FILE_PATH_TMP $FILE_BACKUP_PATH_TMP;

    echo $SNIPPET >> $FILE_PATH_TMP;
    echo -en "\n" >> $FILE_PATH_TMP;
    if [ $VERBOSE -gt 0 ]; then
        echo "[OK]";
    fi 

    if [ $VERBOSE -gt 0 ]; then
        if [ $DEBUG -eq 1 ]; then
            echo -n "o Attempting to uploading $FILE [$FILE_PATH_TMP] to $FTP_IP:/$FILE_PATH ... ";
	else
            echo -n "o Attempting to uploading $FILE to ftp://$FTP_IP/$FILE_PATH ... ";
	fi
    fi

if [ $VERBOSE -eq 2 ]; then
echo "";
echo "";
$FTP -inv $FTP_IP <<EOF | tee $LOGFILE2_PATH_TMP 2>&1
user $FTP_LOGIN $FTP_PASSWORD
ascii
put $FILE_BACKUP_PATH_TMP $FILE_BACKUP_PATH
put $FILE_PATH_TMP $FILE_PATH
quit
EOF
else
$FTP -in $FTP_IP <<EOF > $LOGFILE2_PATH_TMP
user $FTP_LOGIN $FTP_PASSWORD
ascii
put $FILE_BACKUP_PATH_TMP $FILE_BACKUP_PATH
put $FILE_PATH_TMP $FILE_PATH
quit
EOF
fi

    FAIL='';
    FAIL=$($GREP 'fail' $LOGFILE2_PATH_TMP);
    $RM $LOGFILE2_PATH_TMP;
    if [ "$FAIL" != "" ]; then
	echo "[ERROR]";
        echo "";
        echo "";
	echo "The following errors occured:";
        for this_fail in ${FAIL[@]}
        do  
            echo $this_fail
        done
        echo "";
        exit 1;
    else
        if [ $VERBOSE -gt 0 ]; then
            echo "[OK]";
	fi
    fi

    echo "";
    echo "Backup file ftp://$FTP_IP/$FILE_BACKUP_PATH has been uploaded successfully."
    echo "Log file ftp://$FTP_IP/$FILE_PATH has been updated and uploaded successfully."
    echo "";

fi

exit 0;
