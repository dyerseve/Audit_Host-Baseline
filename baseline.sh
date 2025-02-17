#!/bin/sh

# Updated and modified by Phil Ellis <dyerseve@gmail.com>

# Written by Ismael Valenzuela, McAfee Foundstone
# ismael.valenzuela@foundstone.com
# version 1.0 - August 2012
# 
# This script allows you to repeatably collect baseline audit data from a Linux system. 
# Based on David Hoelzer's original idea - www.cyber-defense.org

EXCEPTIONLIMIT=24

function Separator ()
{
            echo +----------------------------------------------------------------------------
}

function RunTest ()
{
            TEST=$2
            TESTNAME=$1
            if [ -z "$TEST" ] ; then
                        echo Empty test called in RunTest.  Exiting.
                        exit 50;
            fi
            if [ -z "$TESTNAME" ] ; then
                        echo Empty test name called in RunTest for $TEST.  Exiting.
                        exit 51;
            fi
            Separator >> $OutputFile
            echo "|  $TESTNAME" >> $OutputFile
            Separator >> $OutputFile

        echo -e "\nRunning $TESTNAME"
        Separator
            echo
            
            echo $TEST > __trunme
            { /bin/sh __trunme;  } >> $OutputFile
            rm -f __trunme
            if [ $? -ne 0 ] ; then
                        echo "Error running $TESTNAME: $TEST"
                        echo "Bailing out."
                        exit 5
            fi
}

function Header ()
{
            Separator > $OutputFile
            echo "  `basename $0` test for `hostname` by `whoami` on `date`" >> $OutputFile
            Separator >> $OutputFile
}

function GetOutputFile ()
{
            OutputFile=`hostname`-`date +%m%d%y_%H%M%S`.`basename $0`
}

function GetRunlevel ()
{
        #inittab replaced with systemd
        #RunLevel=`awk -F: '/^id/ {print $2;}' /etc/inittab`
        
}

if [ ! -z $1 ] ; then
            if [ ! -s $1 ] ; then
                        echo "You requested a comparison but did not provide a valid filename."
                        exit 3
            fi
            BASELINE=$1
fi

echo -e "\nRunning automatic baseline script for `hostname` as `whoami`."
echo -e "\nIf you are attempting to validate a system, please rerun this script"
echo -e "with the name of a baseline file as a command line argument.\n"

GetOutputFile
GetRunlevel
Header

RunTest "Kernel Type/Machine Information" "uname -a"

RunTest "Physical Memory" "free | awk '/Mem/ {print \$2;}'"

RunTest "Mounted Partitions" "mount"

RunTest "Physical Partition Tables" "/sbin/fdisk -l /dev/?d?"

        # Recursively list all interesting directories 
        # But leave out directory (and parent) entries themselves 

RunTest "Critical Directory Inventory" "ls -alR /etc /bin /lib /sbin /usr/lib /usr/bin /usr/sbin /usr/local/bin /usr/local/lib /usr/local/sbin /lib64 /usr/lib64 /usr/local/lib64 | sed s/^d.*[\.]$//"

        # Compute the MD5hash of every binary in the critical directories listed below

RunTest "Critical Binaries Integrity" "find /bin /sbin /usr/bin /usr/sbin -type f -exec md5sum {} \;"

        # Compute the MD5hash of every system configuration file in the sysconfig directory
        
RunTest "System Configuration Files Integrity" "find /etc/sysconfig -type f -exec md5sum {} \;"

RunTest "Network interfaces" "/sbin/ifconfig -a | awk '/^[a-zA-Z]+/ { print \$1\" - \"\$5; }'"

            # List Listening Ports:
            # A listening TCP port will have the word "LISTEN" on the line.  A listening UDP port will
            # begin with the letters UDP

RunTest "Inventory Listening Ports" "netstat -an | awk '/(^udp)|LISTEN/ {print \$1\" \"\$4;}'"

RunTest "Current Runlevel" "who -r | awk '{ print \$1\" \"\$2;}'"

RunTest "Init Default Runlevel" "awk -F: '/^id/ {print \$2;}' /etc/inittab"

RunTest "Find Services Started During Startup" "ps eaxl | awk '/^[0-9][ \t]+[0-9]+[ \t]+[0-9]+[ \t]+1[ \t]+/ {print \$13;}'"

            # List SUID and SGID files:
            # -perm with the + option will identify all objects where any of the listed permissions
            # are set.  04000 is SUID, 02000 is SGID.  '-type f' restricts the list to files only

RunTest "Find SGID Files" "find / -perm -6000 -type f -ls"
RunTest "Find SUID Files" "find / -perm -4000 -user root -type f -ls"

        # List Orphaned files, which could be a sign of an attacker's temporary account that has been deleted"

RunTest "Find Orphaned files" "find / -nouser -print"

        # Look for unusual large files (greater than 10 Megabytes)

RunTest "Find unusual large files" "find / -size +10000k -print"

        # List arp entries

RunTest "Arp Entries" "/sbin/arp -a"

        # List DNS settings and hosts file

RunTest "DNS Settings and hosts file" "cat /etc/resolv.conf; /etc/hosts"

        # List cron jobs scheduled by root and any other UID accounts as well as any other system-wide cron jobs

RunTest "Cron Jobs scheduled" "crontab -u root -l; cat /etc/crontab; ls /etc/cron.*"

RunTest "Kernel IP routing table" "netstat -rn"

        # Look for unusual network configuration (IP forwarding, broadcasts, etc.)

RunTest "Unusual network configuration" "cat /etc/sysctl.conf"

        # Look for files named with dots and spaces used to camouflage files

RunTest "Files named with dots and spaces" "find / -name " " -print; find / -name ".. " -print; find / -name ". " -print"

        # List unlinked files (files can still be accessible via /proc/<PID>/fd)

RunTest "Unlinked Files" "lsof +L1"

        # List all services enabled at various runlevels using chkconfig

RunTest "Services enabled using chkconfig" "/sbin/chkconfig --list"

            # Ensure that there is only one tcpd binary and that it's not altered (an attacker could add his or replace it)

RunTest "Unique Tcpd Binary" "find / -name tcpd"

RunTest "Current Users" "cat /etc/passwd"

            # List Root Users:
            # Root users in the passwd file will contain a username followed by colon followed by at
            # least one zero followed by a colon

RunTest "Root Users" "awk \"/^[^:]+:[^:]+:0+:/ {print;}\" /etc/passwd"

            # List Blank Passwords:
            # A blank password in the shadow file will be a line that has a username followed
            # by a colon followed by a colon

RunTest "Inventory Blank Passwords" "awk -F: '/^[^:]+::/ {print \$1;}' /etc/shadow"

            # List Active Accounts:  
            # Inactive accounts in shadow file will contain a line with a username
            # followed by a colon followed by more than one character other than a colon
            # NOTE: Most awks don't understand {2,} so we require [^:][^:]+.

RunTest "Inventory Active Accounts" "awk -F: '/^[^:]+:([^:][^:]+|:)/ {print \$1;}' /etc/shadow"

RunTest "Groups and Membership" "cat /etc/group"

            # Rhosts is just a really bad idea these days.  We look for and inventory
            # any .rhost files and hosts.equiv

RunTest "Find Unencrypted Remote Trusts" "find / -name .rhost -name hosts.equiv -ls"

# The following tests are potentially VERY NOISY. Disable if needed

RunTest "List all running processes" "ps -eo pid,user,cmd"

RunTest "List all logged in users" "last"

# systemd startup services
RunTest "All systemd services" "systemctl list-units --type=service"


#
# Below are conditional tests, depending on the function of the server involved
# The tests check for existence of certain files and act upon them if they exist
#

# Checking Apache configuration files for changes
# Use symlink in /opt dir to avoid version dependencies

RunTest "Checking Apache httpd.conf" "if [ -f /opt/httpd/conf/httpd.conf ]; then cat /opt/httpd/conf/httpd.conf; fi;"

# Checking Postgresql DB configuration files for any changes

RunTest "Checking Postgresql pg_hba.conf" "if [ -f /var/lib/pgsql/data/pg_hba.conf ]; then cat /var/lib/pgsql/data/pg_hba.conf; fi;"
RunTest "Checking Postgresql pg_ident.conf" "if [ -f /var/lib/pgsql/data/pg_ident.conf ]; then cat /var/lib/pgsql/data/pg_ident.conf; fi;"
RunTest "Checking Postgresql postgres.conf" "if [ -f /var/lib/pgsql/data/postgres.conf ]; then cat /var/lib/pgsql/data/postgres.conf; fi;"

# Checking Tomcat configuration files for any changes. PLEASE REPLACE 6.0.x WITH THE CORRECT PATH IN USE.
# Use symlink in /opt dir to avoid version dependencies

RunTest "Checking Tomcat catalina.policy" "if [ -f /opt/tomcat/conf/catalina.policy ]; then cat /opt/tomcat/conf/catalina.policy; fi;"
RunTest "Checking Tomcat tomcat-users.xml" "if [ -f /opt/tomcat/conf/tomcat-users.xml ]; then cat /opt/tomcat/conf/tomcat-users.xml; fi;"


# Checking GoPhish configuration files for any changes.

RunTest "Checking goPhish config.json" "if [ -f /opt/gophish/config.json ]; then cat /opt/gophish/config.json; fi;"


# If the script was invoked with a baseline filename, check for changes.

if [ ! -z $BASELINE ] ; then
        echo "SECURITY EXCEPTION ALERT on `hostname`" > Exceptions
        echo "***********************************************" >> Exceptions
            diff $BASELINE $OutputFile >> Exceptions
            NUMEXCEPTIONS=`wc -l Exceptions | awk '{print \$1;}'`
            echo "Exception limit set to: ${EXCEPTIONLIMIT}"
            echo "Exceptions found: ${NUMEXCEPTIONS}"
            if [ $NUMEXCEPTIONS -ne "$EXCEPTIONLIMIT" ] ; then
                        echo -e "\nExceptions detected:"
                        diff --color $BASELINE $OutputFile
                        echo -e "\nSending Exceptions to Syslog"
                        logger -f Exceptions
                        else
                                    rm -f Exceptions
            fi
        else
            echo -e "\nSending $OutputFile to Syslog"
            logger -f $OutputFile
fi