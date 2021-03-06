#!/bin/sh
#================================================================================
# MaMper 1.0.0
#
# Apache virtual Host manager for MacOS
#
# For usage help and available commands run `mamper.sh`.
#================================================================================
# Don't change this!
version="1.4"
#

# Test run...
if [ `whoami` != 'root' -a "$1" -a "$1" != "--list" ]; then
  read -d '' prompt <<- EOT
mamper.sh requires super-user privileges to work only if you run Apache default installation on MacOS.
Enter your password to continue...
Password:
EOT

  sudo -E -p "$prompt" "$0" $* || exit 1
  exit 0
fi

if [ "$SUDO_USER" = "root" -a "$1" -a "$1" != "--list" ]; then
  /bin/echo "You must start this under your regular user account (not root) using sudo."
  /bin/echo "Rerun using: sudo $0 $*"
  exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If you are using this script on a production machine with a static IP address,
# and you wish to set up a "live" virtualhost, you can change the following IP
# address to the IP address of your machine.
#
: ${IP_ADDRESS:="127.0.0.1"}
: ${IPV6_ADDRESS:="::1"}

# By default, this script places files in /Users/[you]/Sites. If you would like
# to change this, like to how Apple does things by default, uncomment the
# following line:
#
#DOC_ROOT_PREFIX="/Library/WebServer/Documents"

# Configure the apache-related paths, these one are for Homembrew httpd installation
#
: ${APACHE_CONFIG:="/opt/homebrew/etc/httpd/"}
: ${APACHECTL:="/opt/homebrew/bin/apachectl"}

# If you wish to change the default application that gets launched after the
# virtual host is created, define it here:
: ${OPEN_COMMAND:="/usr/bin/open"}

# If you want to use a different browser than Safari, define it here:
#BROWSER="Firefox"
#BROWSER="WebKit"
#BROWSER="Google Chrome"

# If defined, a ServerAlias os $1.$WILDCARD_ZONE will be added to the virtual
# host file. This is useful if you, for example, have set up a wildcard domain
# either on your own DNS server or using a server like dyndns.org. For example,
# if my local IP of 10.0.42.42 is static (which can still be achieved using a
# well-configured DHCP server or an Apple Airport Extreme 802.11n base station)
# and I create a host on dyndns.org of patrickdev.dyndns.org with wildcard
# hostnames turned on, then defining my WILDCARD_ZONE to "patrickdev.dyndns.org"
# will enable access to my virtual host from any machine on the network. Note
# that this would also work with a public IP too, and the virtual hosts on your
# machine would be accessible to anyone on the internets.
#WILDCARD_ZONE="my.wildcard.host.address"

# A feature to specify a custom log location within your site's document root
# was requested, and so you will be prompted about this when you create a new
# virtual host. If you do not want to be prompted, set the following to "no":
: ${PROMPT_FOR_LOGS:="no"}

# If you do not want to be prompted, but you do always want to have the site-
# specific logs folder, set PROMPT_FOR_LOGS="no" and enable this:
: ${ALWAYS_CREATE_LOGS:="yes"}

# By default, log files will be created in DOCUMENT_ROOT/logs. If you wish to
# override this to a static location, you can do so here.
#LOG_FOLDER="/var/log/httpd"
# If you want your logs in your document root, uncomment the following
#LOG_FOLDER="__DOCUMENT_ROOT__/logs"

# If you have an atypical setup, and you don't need or want entries in your
# /etc/hosts file, you can set the following option to "yes".
: ${SKIP_ETC_HOSTS:="no"}

# If you are running this script on a platform other than Mac OS X, your home
# partition is going to be different. If so, change it here.
: ${HOME_PARTITION:="/Users"}

# If your environment has a different default DocumentRoot, and you don't want
# to be nagged about "fixing" your DocumentRoot, set this to "yes".
: ${SKIP_DOCUMENT_ROOT_CHECK:="no"}

# If Apache works on a different port than the default 80, set it here
: ${APACHE_PORT:="80"}

# Batch mode (all prompting will assume Yes). Any value will activate this. Can
# be set here, in ~/.mamper.sh.conf, or on the command line, like:
# BATCH_MODE=yes mamper.sh mysite
#BATCH_MODE="yes"

# If you're satisfied with the version you have and do not wish to be reminded
# of a new version, add the following line to your ~/.mamper.sh.conf file.
#SKIP_VERSION_CHECK="yes"

# We now will search your $DOC_ROOT_PREFIX for a matching subfolder using find.
# By default, we will go two levels deep so that it doesn't take too long. If
# you have a really complex structure, you may need to increase this.
: ${MAX_SEARCH_DEPTH:="2"}

# Set to "yes" if you don't have a browser (headless) or don't want the site
# to be launched in your browser after the virtualhost is set up.
#SKIP_BROWSER="yes"

# By default, we'll write out an index.html file in the DOCUMENT_ROOT if one
# is not already present.
: ${CREATE_INDEX:="yes"}

# You can now store your configuration directions in a ~/.mamper.sh.conf
# file so that you can download new versions of the script without having to
# redo your own settings.
if [ -e ~/.mamper.sh.conf ]; then
  . ~/.mamper.sh.conf
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

host_exists()
{
  if grep -q -e "^$IP_ADDRESS  $VIRTUALHOST$" /etc/hosts ; then
    return 0
  else
    return 1
  fi
}

open_command()
{
  if [ ! -z "$BROWSER" ]; then
    $OPEN_COMMAND -a "$BROWSER" "$@"
  else
    $OPEN_COMMAND "$@"
  fi
}

create_virtualhost()
{
  if [ ! -z $WILDCARD_ZONE ]; then
    SERVER_ALIAS="ServerAlias $VIRTUALHOST.$WILDCARD_ZONE"
  else
    SERVER_ALIAS="#ServerAlias your.alias.here"
  fi
  date=`/bin/date`
  if [ -z $3 ]; then
    log="#"
  else
    log=""
    if [ -n "$LOG_FOLDER" ]; then
      # would love a pure shell way to do this, but sed makes it oh so hard
      LOG_FOLDER=`ruby -e "puts File.expand_path('$LOG_FOLDER'.gsub(/__DOCUMENT_ROOT__/, '$2'))"`
      log_folder_path=$LOG_FOLDER
      access_log="${log_folder_path}/access_log-$VIRTUALHOST"
      error_log="${log_folder_path}/error_log-$VIRTUALHOST"
    else
      log_folder_path=$FOLDER/logs
      access_log="${log_folder_path}/access_log"
      error_log="${log_folder_path}/error_log"
    fi
    if [ ! -d "${log_folder_path}" ]; then
      mkdir -p "${log_folder_path}"
      chown $USER "${log_folder_path}"
    fi
    touch $access_log $error_log
    chown $USER $access_log $error_log
  fi

  cat << __EOF >$APACHE_CONFIG/virtualhosts/$VIRTUALHOST
# Created $date
<VirtualHost *:$APACHE_PORT>
  DocumentRoot "$2"
  ServerName $VIRTUALHOST
  $SERVER_ALIAS

  ScriptAlias /cgi-bin "$2/cgi-bin"

  <Directory "$2">
    Options All
    AllowOverride All
    <IfModule mod_authz_core.c>
      Require all granted
    </IfModule>
    <IfModule !mod_authz_core.c>
      Order allow,deny
      Allow from all
    </IfModule>
  </Directory>

  ${log}CustomLog "${access_log}" combined
  ${log}ErrorLog "${error_log}"

</VirtualHost>
__EOF
}

edit_virtualhost()
{
  if [ -e $APACHE_CONFIG/virtualhosts/$VIRTUALHOST ]; then
    $EDITOR $APACHE_CONFIG/virtualhosts/$VIRTUALHOST
    restart_apache
  else
    /bin/echo "VirtualHost $VIRTUALHOST not found."
  fi
}

cleanup()
{
  /bin/echo
  /bin/echo "Cleaning up..."
  exit
}

restart_apache()
{
  /bin/echo -n "+ Restarting Apache... "
  $APACHECTL graceful 1>/dev/null 2>/dev/null
  /bin/echo "done"
}

# Based on FreeBSD's /etc/rc.subr
checkyesno()
{
  case $1 in
    #       "yes", "true", "on", or "1"
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|[Yy]|1)
    return 0
    ;;

    #       "no", "false", "off", or "0"
    [Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|[Nn]|0)
    return 1
    ;;

    *)
    return 1
    ;;
  esac
}

version_check()
{
  # Only check for a new version once every day.
  current_time=`date +%s`
  last_update_check_directory="${HOME_PARTITION}/$USER/.mamper.sh"
  last_update_check_file="${last_update_check_directory}/last_update_check"
  if [ -e "$last_update_check_file" ]; then
    last_checked=`cat "$last_update_check_file"`
    due_for_a_check=`/bin/echo "$last_checked < ($current_time - 86400)" | /usr/bin/bc`
    if [ $due_for_a_check -eq 0 ]; then
      return 0
    fi
  elif [ ! -d "$last_update_check_directory" ]; then
    # Set up the last update check directory if it's not there yet.
    mkdir "$last_update_check_directory"
  fi

  /bin/echo -n "Checking for updates... "
  current_version=`curl --silent https://api.github.com/repos/liucoj/Mamper/releases | grep tag_name -m 1 | awk '{print $2}' | sed -e 's/[^0-9.]//g'`
  /bin/echo $current_time > "$last_update_check_file"
  chown $USER "$last_update_check_directory" "$last_update_check_file"

  # See if we have the latest version
  if [ -n "$current_version" ]; then
    testes=`/bin/echo "$version < $current_version" | /usr/bin/bc`

    if [ $testes -eq 1 ]; then
      /bin/echo "done"
      if [ -z $BATCH_MODE ]; then
        /bin/echo "A newer version ($current_version) of mamper.sh is available."
        /bin/echo -n "Do you want to get it now? [Y/n] "
        read resp
      else
        /bin/echo "A newer version ($current_version) of mamper.sh is available."
        /bin/echo "Visit https://github.com/liucoj/Mamper to go get it."
        resp="n"
      fi

      case $resp in
      y*|Y*)
        open_command https://github.com/liucoj/Mamper
        exit
      ;;

      *)
        /bin/echo "Okay. At your convenience, visit: https://github.com/liucoj/Mamper"
        /bin/echo
      ;;
      esac
    else
      /bin/echo "Mamper is updated!"
    fi
  else
    /bin/echo "failed. Are you online?"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Get the Apache version number to check compatibility.
APACHE_VERSION=$(${APACHECTL} -v | perl -ne 'print $1 if /Apache\/([0-9.]+)/')

# Extract the major, minor, and patch numbers from the Apache version for
# easier version comparisons.
IFS='.'
read APACHE_MAJOR_VERSION APACHE_MINOR_VERSION APACHE_PATCH_VERSION <<< "$APACHE_VERSION"
unset IFS

# Check for Apache 2.x.
if (( $APACHE_MAJOR_VERSION < 2 )); then
  /bin/echo "Could not find ${APACHE_CONFIG}"
  /bin/echo "Sorry, this version of mamper.sh does not support Apache 1.x.x"
  /bin/echo

  exit 1
fi

# catch Ctrl-C
#trap 'cleanup' 2

# restore it
#trap '' 2

if [ -z $USER -o $USER = "root" ]; then
  if [ ! -z $SUDO_USER ]; then
    USER=$SUDO_USER
  else
    USER=""

    /bin/echo "ALERT! Your root shell did not provide your username."

    while : ; do
      if [ -z $USER ]; then
        while : ; do
          /bin/echo -n "Please enter *your* username: "
          read USER
          if [ -d $HOME_PARTITION/$USER ]; then
            break
          else
            /bin/echo "$USER is not a valid username."
          fi
        done
      else
        break
      fi
    done
  fi
fi

if [ -z $DOC_ROOT_PREFIX ]; then
  DOC_ROOT_PREFIX="${HOME_PARTITION}/$USER/Sites"
fi

if [ -z $SKIP_VERSION_CHECK ]; then
  version_check
fi

usage()
{
  cat << __EOT
Usage: sudo mamper.sh <name> [<optional path>]
       sudo mamper.sh --list
       sudo mamper.sh --edit <name>
       sudo mamper.sh --delete <name>
   where <name> is the one-word name you'd like to use. (e.g. mysite)

   Note that if "mamper.sh" is not in your PATH, you will have to write
   out the full path to it: eg. /Users/$USER/Desktop/mamper.sh <name>
   
Version: $version
__EOT
  exit 1
}

if [ -z $1 ]; then
  usage
else
  if [ "$1" = "--delete" ]; then
    if [ -z $2 ]; then
      usage
    else
      VIRTUALHOST=`echo $2|sed -e 's/\///g'`
      DELETE=0
    fi
  elif [ "$1" = "--list" ]; then
    if [ -d $APACHE_CONFIG/virtualhosts ]; then
      echo "Listing virtualhosts found in $APACHE_CONFIG/virtualhosts"
      echo
      for i in $APACHE_CONFIG/virtualhosts/*; do
        server_name=`grep -m1 "^\s*ServerName" $i | awk '{print $2}'`
        doc_root=`grep -m1 "^\s*DocumentRoot" $i | awk '{print $2}' | sed -e 's/"//g'`
        echo "http://${server_name}/ -> ${doc_root}"
      done
    else
      echo "No virtualhosts have been set up yet."
    fi

    exit
  elif [ "$1" = "--edit" ]; then
    if [ -z $2 ]; then
      usage
    else
      VIRTUALHOST=`echo $2|sed -e 's/\///g'`
      edit_virtualhost

      exit
    fi
  else
    VIRTUALHOST=`echo $1|sed -e 's/\///g'`
    FOLDER=`echo $2 | sed -e 's/\/*$//'`
  fi
fi

# Test that the virtualhost name is valid (starts with a number or letter)
if ! /bin/echo $VIRTUALHOST | grep -q -E '^[A-Za-z0-9]+[A-Za-z0-9.-]+$' ; then
  /bin/echo "Sorry, '$VIRTUALHOST' is not a valid host name to use. It must start with a letter or number."
  exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Delete the virtualhost if that's the requested action
#
if [ ! -z $DELETE ]; then
  /bin/echo -n "- Deleting virtualhost, $VIRTUALHOST... Continue? [Y/n]: "

  if [ -z "$BATCH_MODE" ]; then
    read continue
  else
    continue="Y"
    /bin/echo $continue
  fi

  case $continue in
  n*|N*) exit
  esac

  if ! checkyesno ${SKIP_ETC_HOSTS}; then
    /bin/echo -n "  - Removing $VIRTUALHOST from /etc/hosts... "

    cat /etc/hosts | grep -v $VIRTUALHOST > /tmp/hosts.tmp

    if [ -s /tmp/hosts.tmp ]; then
      mv /tmp/hosts.tmp /etc/hosts
    fi
    /bin/echo "done"
  fi

  if [ -e $APACHE_CONFIG/virtualhosts/$VIRTUALHOST ]; then
    DOCUMENT_ROOT=`grep DocumentRoot $APACHE_CONFIG/virtualhosts/$VIRTUALHOST | awk '{print $2}' | tr -d '"'`

    if [ -d $DOCUMENT_ROOT ]; then
      /bin/echo -n "  + Found DocumentRoot $DOCUMENT_ROOT. Delete this folder? [y/N]: "

      if [ -z $BATCH_MODE ]; then
        read resp
      else
        resp="n"
        echo $resp
      fi

      case $resp in
      y*|Y*)
        /bin/echo -n "  - Deleting folder... "
        if rm -rf "${DOCUMENT_ROOT}" ; then
          /bin/echo "done"
        else
          /bin/echo "Could not delete $DOCUMENT_ROOT"
        fi
      ;;
      esac
    fi

    LOG_FILES=`grep "CustomLog\|ErrorLog" $APACHE_CONFIG/virtualhosts/$VIRTUALHOST | awk '{print $2}' | tr -d '"'`
    if [ ! -z "$LOG_FILES" ]; then
      /bin/echo -n "  + Delete logs? [y/N]: "

      if [ -z BATCH_MODE ]; then
        read resp
      else
        resp="n"
        echo $resp
      fi

      case $resp in
      y*|Y*)
        /bin/echo -n "  - Deleting logs... "
        if rm -f ${LOG_FILES} ; then
          /bin/echo "done"
        else
          /bin/echo "Could not delete $LOG_FILES"
        fi
      ;;
      esac
    fi

    /bin/echo -n "  - Deleting virtualhost file, $APACHE_CONFIG/virtualhosts/$VIRTUALHOST... "
    rm $APACHE_CONFIG/virtualhosts/$VIRTUALHOST
    /bin/echo "done"

    restart_apache
  else
    /bin/echo "- Virtualhost $VIRTUALHOST does not currently exist. Aborting..."
    exit 1
  fi

  exit
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make sure $APACHE_CONFIG/httpd.conf is ready for virtual hosting...
#
# If it's not, we will:
#
# a) Backup the original to $APACHE_CONFIG/httpd.conf.original
# b) Add a NameVirtualHost 127.0.0.1 line
# c) Create $APACHE_CONFIG/virtualhosts/ (virtualhost definition files reside here)
# d) Add a line to include all files in $APACHE_CONFIG/virtualhosts/
# e) Create a _localhost file for the default "localhost" virtualhost
#

if ! checkyesno ${SKIP_DOCUMENT_ROOT_CHECK} ; then
  if ! grep -q -e "^DocumentRoot \"$DOC_ROOT_PREFIX\"" $APACHE_CONFIG/httpd.conf ; then
    /bin/echo "httpd.conf's DocumentRoot does not point where it should."
    /bin/echo -n "Do you wish to set it to $DOC_ROOT_PREFIX? [Y/n]: "
    if [ -z $BATCH_MODE ]; then
      read response
    else
      response="n"
    fi
    case $response in
    n*|N*)
      /bin/echo "Okay, just re-run this script if you change your mind."
    ;;
    *)
      cat << __EOT | ed $APACHE_CONFIG/httpd.conf 1>/dev/null 2>/dev/null
/^DocumentRoot
i
#
.
j
+
i
DocumentRoot "$DOC_ROOT_PREFIX"
.
w
q
__EOT
    ;;
    esac
  fi
fi

if ! grep -q -E "^NameVirtualHost \*:$APACHE_PORT" $APACHE_CONFIG/httpd.conf ; then

  /bin/echo "httpd.conf not ready for virtual hosting. Fixing..."
  cp $APACHE_CONFIG/httpd.conf $APACHE_CONFIG/httpd.conf.original
  /bin/echo "NameVirtualHost *:$APACHE_PORT" >> $APACHE_CONFIG/httpd.conf

  if [ ! -d $APACHE_CONFIG/virtualhosts ]; then
    mkdir $APACHE_CONFIG/virtualhosts
    create_virtualhost localhost $DOC_ROOT_PREFIX
  fi

  /bin/echo "Include $APACHE_CONFIG/virtualhosts"  >> $APACHE_CONFIG/httpd.conf

fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Look for hosts created in Tiger
#
if [ -d /etc/httpd/virtualhosts ]; then

  /bin/echo -n "Do you want to port the hosts you previously created in Tiger to the new system? [Y/n]: "
  read PORT_HOSTS
  case $PORT_HOSTS in
  n*|N*)
    /bin/echo "Okay, just re-run this script if you change your mind."
  ;;

  *)
    for host in `ls -1 /etc/httpd/virtualhosts | grep -v _localhost`; do
      /bin/echo -n "  + Creating $host... "
      if ! checkyesno ${SKIP_ETC_HOSTS}; then
        if ! host_exists $host ; then
          /bin/echo "$IP_ADDRESS  $host" >> /etc/hosts
          /bin/echo "$IPV6_ADDRESS  $host" >> /etc/hosts
          /bin/echo "" >> /etc/hosts
        fi
      fi
      docroot=`grep DocumentRoot /etc/httpd/virtualhosts/$host | awk '{print $2}'`
      create_virtualhost $host $docroot
      /bin/echo "done"
    done

    mv /etc/httpd/virtualhosts /etc/httpd/virtualhosts-ported
  ;;
  esac


fi

if [ -z $WILDCARD_ZONE ]; then
  /bin/echo -n "Create http://${VIRTUALHOST}:${APACHE_PORT}/? [Y/n]: "
else
  /bin/echo -n "Create http://${VIRTUALHOST}.${WILDCARD_ZONE}:${APACHE_PORT}/? [Y/n]: "
fi

if [ -z "$BATCH_MODE" ]; then
  read continue
else
  continue="Y"
  /bin/echo $continue
fi

case $continue in
n*|N*) exit
esac


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If the host is not already defined in /etc/hosts, define it...
#

if ! checkyesno ${SKIP_ETC_HOSTS}; then
  if ! host_exists $VIRTUALHOST ; then

    /bin/echo "Creating a virtualhost for $VIRTUALHOST..."
    /bin/echo -n "+ Adding $VIRTUALHOST to /etc/hosts... "
    /bin/echo "$IP_ADDRESS  $VIRTUALHOST" >> /etc/hosts
    /bin/echo "$IPV6_ADDRESS  $VIRTUALHOST" >> /etc/hosts
    /bin/echo "" >> /etc/hosts
    /bin/echo "done"
  fi
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Ask the user where they would like to put the files for this virtual host
# if a document root hasn't been specified as a second argument.
#
if [ -z "$FOLDER" ]; then
  /bin/echo "+ Looking in $DOC_ROOT_PREFIX for an existing document root to use..."

  # See if we can find an appropriate folder
  if ls -1 $DOC_ROOT_PREFIX | grep -q -e "^$VIRTUALHOST"; then
    DOC_ROOT_FOLDER_MATCH=`ls -1 $DOC_ROOT_PREFIX | grep -e ^$VIRTUALHOST | head -n 1`
    DOC_ROOT_FOLDER_MATCH="${DOC_ROOT_PREFIX}/${DOC_ROOT_FOLDER_MATCH}"
  else
    if [ -d $DOC_ROOT_PREFIX/$VIRTUALHOST ]; then
      DOC_ROOT_FOLDER_MATCH="$DOC_ROOT_PREFIX/$VIRTUALHOST"
    else
      if [ $MAX_SEARCH_DEPTH -eq 0 ]; then
        /bin/echo "  searching with no maximum depth. This could take a really long time..."
      else
        /bin/echo "  searching to a maximum directory depth of $MAX_SEARCH_DEPTH. This could take some time..."
      fi
      nested_match=`find $DOC_ROOT_PREFIX -maxdepth $MAX_SEARCH_DEPTH -type d -name $VIRTUALHOST 2>/dev/null`

      if [ -n "$nested_match" ]; then
        if [ -d $nested_match ]; then
          DOC_ROOT_FOLDER_MATCH=$nested_match
        fi
      else
        DOC_ROOT_FOLDER_MATCH="$DOC_ROOT_PREFIX/$VIRTUALHOST"
      fi
    fi
  fi

/bin/echo -n "  - Use $DOC_ROOT_FOLDER_MATCH as the virtualhost folder? [Y/n] "

  if [ -z "$BATCH_MODE" ]; then
    read resp
  else
    resp="Y"
    echo $resp
  fi

  case $resp in

    n*|N*)
      while : ; do
        if [ -z "$FOLDER" ]; then
          /bin/echo -n "  - Enter new folder name (located in $DOC_ROOT_PREFIX): "
          read response
          FOLDER=$DOC_ROOT_PREFIX/$response
        else
          break
        fi
      done
    ;;

    *)
      if [ -d $DOC_ROOT_FOLDER_MATCH/public ]; then
        /bin/echo -n "  - Found a public folder suggesting a Rails/Rack project. Use as DocumentRoot? [Y/n] "
        if [ -z "$BATCH_MODE" ]; then
          read response
        else
          response="Y"
          echo $response
        fi
        if checkyesno ${response} ; then
          FOLDER=$DOC_ROOT_FOLDER_MATCH/public
        else
          FOLDER=$DOC_ROOT_FOLDER_MATCH
        fi
      elif [ -d $DOC_ROOT_FOLDER_MATCH/web ]; then
        /bin/echo -n "  - Found a web folder suggesting a Symfony project. Use as DocumentRoot? [Y/n] "
        if [ -z "$BATCH_MODE" ]; then
          read response
        else
          response="Y"
          echo $response
        fi
        if checkyesno ${response} ; then
          FOLDER=$DOC_ROOT_FOLDER_MATCH/web
        else
          FOLDER=$DOC_ROOT_FOLDER_MATCH
        fi
      else
        FOLDER=$DOC_ROOT_FOLDER_MATCH
      fi
    ;;
  esac
fi

# Create the folder if we need to...
if [ ! -d "${FOLDER}" ]; then
  /bin/echo -n "  + Creating folder ${FOLDER}... "
  su $USER -c "mkdir -p $FOLDER"

  # Error out if the folder was not created.
  if [ ! -d "${FOLDER}" ]; then
    /bin/echo "  # Fatal: could not create ${FOLDER}"
    exit 1
  fi
  /bin/echo "done"
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# See if a custom log should be used (requested by david.kerns, Issue #7)
#
if checkyesno ${PROMPT_FOR_LOGS}; then

  /bin/echo -n "  - Enable custom server access and error logs in $VIRTUALHOST/logs? [y/N] "

  if [ -z "$BATCH_MODE" ]; then
    read resp
  else
    resp="Y"
  fi

  case $resp in

    y*|Y*)
      log="1"
      LOG_FOLDER="$FOLDER/logs"
    ;;

    *)
      log=""
    ;;
  esac

elif checkyesno ${ALWAYS_CREATE_LOGS}; then

  log="1"

fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create a default index.html if there isn't already one there
#
if checkyesno ${CREATE_INDEX}; then
  if [ ! -e "${FOLDER}/index.html" -a ! -e "${FOLDER}/index.php" ]; then
    /bin/echo -n "+ Creating 'index.html'... "
    cat << __EOF >"${FOLDER}/index.html"
<html>
<head>
<title>Welcome to $VIRTUALHOST</title>
<style type="text/css">
 body, div, td { font-family: "Lucida Grande"; font-size: 12px; color: #666666; }
 b { color: #333333; }
 .indent { margin-left: 10px; }
</style>
</head>
<body link="#993300" vlink="#771100" alink="#ff6600">

<table border="0" width="100%" height="95%"><tr><td align="center" valign="middle">
<div style="width: 500px; background-color: #eeeeee; border: 1px dotted #cccccc; padding: 20px; padding-top: 15px;">
 <div align="center" style="font-size: 14px; font-weight: bold;">
  Congratulations!
 </div>

 <div align="left">
  <p>If you are reading this in your web browser, then the only logical conclusion is that the <b><a href="http://$VIRTUALHOST:$APACHE_PORT/">http://$VIRTUALHOST:$APACHE_PORT/</a></b> virtualhost was set up correctly. :)</p>

  <p>You can find the configuration file for this virtual host in:<br>
  <table class="indent" border="0" cellspacing="3">
   <tr>
    <td><b>$APACHE_CONFIG/virtualhosts/$VIRTUALHOST</b></td>
   </tr>
  </table>
  </p>

  <p>You will need to place all of your website files in:<br>
  <table class="indent" border="0" cellspacing="3">
   <tr>
    <td><b><a href="file://$FOLDER">$FOLDER</b></a></td>
   </tr>
  </table>
  </p>

  <p>For the latest version of this script visit:<br>
  <table class="indent" border="0" cellspacing="3">
   <tr>
    <td><svg height="32" aria-hidden="true" viewBox="0 0 16 16" version="1.1" width="32" data-view-component="true" class="octicon octicon-mark-github v-align-middle">
    <path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"></path>
</svg>
</td>
    <td><b><a href="https://github.com/liucoj">Liuc0j</a></b></td>
   </tr>
  </table>
  </p>
 </div>

</div>
</td></tr></table>

</body>
</html>
__EOF
    /bin/echo "done"
    chown $USER "${FOLDER}/index.html"
  fi
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create a default virtualhost file
#
/bin/echo -n "+ Creating virtualhost file... "
create_virtualhost $VIRTUALHOST "${FOLDER}" $log
/bin/echo "done"


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Restart apache for the changes to take effect
#
if [ -x /usr/bin/dscacheutil ]; then
  /bin/echo -n "+ Flushing cache... "
  dscacheutil -flushcache
  /bin/echo "done"

  dscacheutil -q host | grep -q $VIRTUALHOST

  sleep 1
fi

restart_apache

cat << __EOF

http://$VIRTUALHOST:$APACHE_PORT/ is set up and ready for use.

__EOF


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Launch the new URL in the browser
#
if [ -z $SKIP_BROWSER ]; then
  /bin/echo -n "Launching virtualhost... "
  sleep 1
  curl --silent http://$VIRTUALHOST:$APACHE_PORT/ 2>&1 >/dev/null
  open_command "http://$VIRTUALHOST:$APACHE_PORT/"
  /bin/echo "done"
fi
