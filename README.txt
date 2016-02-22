****************************************************
INCBACKUP
****************************************************

#     Copyright (C) 2016 Javier Martínez Baena
#     Email: jbaena@ugr.es
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

****************************************************

1.- Description
2.- Included files in package
3.- Installation
4.- Use
5.- Configuration files (samples)

****************************************************
1.- DESCRIPTION

This is a Bash script to automate the incremental backup process using rsync. The backups are made on a host using as source and destination local folders. Is is possible to make backup of remote filesystems or in remote filesystems by mounting them as local folders (this is automated by the script). Incremental backups are kept in different folders numbered 1, 2, 3, ... (1 is the oldest copy)

The number of incremental backups may or may not be limited. If a limit is set, when it is reached, the older copy will be deleted and backup folders (1, 2, 3, ...) will be renumbered from 1 (folder 1 will be always the older one). In addition, there will always be a link called "last" that points to the newest backup.

The script always repairs, in a transparent manner, the numbering of backup folders if needed (missing numbers, etc). If the maximum backup limit changes, and is set a lower number than existing copies, then the script deletes the older ones and makes renumeration as expected.

In general, it is possible to change the configuration file yet existing older backups. Changes will affect future backups, remaining unchanged the older ones (until they could be deleted when the backup limit is reached).

Incremental backups are maded with hard links, saving space.

The use is very simple: the parameter of the script is a single bash file with some configuration aspects. In this way, you can have different backup configurations simultaneously.

In the explanations that follow, it is assumed that the package files are in /home/usuario/bin/incbackup

****************************************************
2.- Package files

LICENSE                  License terms GNU GPL 3.0
LEEME.txt                Spanish documentation
README.txt               English documentation
incbackup.sh             Main Bash script
incbackup_profile.sh     Edit: to add incbackup in the execution PATH
incbackup_crondaily      Edit: sample to include automated backups in /etc/cron.daily
incbackup_configXXX.sh   Edit: configuration samples
incbackup_excludeXXX.sh  Edit: exclusion files samples

****************************************************
3.- INSTALL

This package can be used without any specific installation. Neverthless, it would be useful to put it accesible to the whole system and automatice backups. This requires to do this steps:

1.- Include the folder that contains the package to the system PATH:
    - Edit incbackup_profile.sh and change the path
    - Copy incbackup_profile.sh in /etc/profile.d
    For this to take effect to root user, you must modify the system PATH in /etc/bashrc

2.- Modify the cron system to automatice backups (see examples below):
    - Option 1: modify crontab
        For a diary backup at 13:30
          30 13 * * * root nice -n 19 incbackup.sh incbackup_config1.sh
        If the system PATH has not been modified, then do this:
          30 13 * * * root nice -n 19 /home/usuario/bin/incbackup/incbackup.sh /home/usuario/bin/incbackup/incbackup_config1.sh
    - Option 2: add execution script to cron.daily
        Edit incbackup_crondaily and change the path/name of files
        Give execution permission:
          chmod a+x incbackup_daily
        Copy incbackup_daily to /etc/cron.daily/
    
    In the first case, if at the time when it should be done the backup the computer is off, the backup will not be made. In the second case, if computer is off during several days, the backup will be made at the first boot.

****************************************************
4.- USE

To use the script you must set only one parameter: a configuration file. The format of this file is described below:

1.- Target of the backup (only one)
    This will be a folder mounted on the host computer. You must set two variables:
      DESTINO_FS   Name of the folder in which the filesystem is mounted (to make backup inside)
      DESTINO_DIR  Folder, inside DESTINO_FS, in which the backup will be done
    That is, once the silesystem is mounted, the backup will be done into DESTINO_FS/DESTINO_DIR
    DESTINO_FS can be a local drive or a network drive. The script will check if it is mounted and, if it isn't mounted then it will mount it.
    To mount the target folder, it can be configured if the mounting process should be done by the /etc/fstab configuration or, conversely, the target can be named by his volume name. The value of DESTINO_ETQ will be FSTAB if mounting is done through /etc/fstab configuration. In the case the value is not FSTAB, then it will be assumed that it is the volume name.
    In some cases, rsync can't keep the owner/group of files (i.e. if the target filesystem is SSHFS mounted and the remote user is not the root user, etc). In this case you must set DESTINO_OWNER=NO. Otherwise set DESTINO_OWNER=YES. Both options should work in the same way but rsync warning messages about the impossibility to make chown over files will be skipped.

2.- Sources of the copy (one or more)
      ORIGEN   List of folders to backup
    Each entry in the list must contain:
      - the path to backup
      - MOUNT/LOCAL. If MOUNT is used, then the source filesystem will be mounted through his /etc/fstab entry. If LOCAL is used, it is assumed that the filesystem doesn't need to be mounted. This facilitates the backup of remote drives through the host computer.
      - filename used by the --exclude-from option of rsync to exclude files/folders from backup. It's mandatory to put something here but you can set a foo filename (a file that doesn't exists) if you don't want to exclude any file.
 
3.- Maximum number of incremental backups 
      MAXCOPIAS
    If its value is zero then there is no limit.
    When this number of backups is reached (except for zero) the "1" folder (the older one) is deleted to keep the maximum number of backups. Then, 2 is moved to 1, 3 is moved to 2, ... so that the resulting set of backups starts again in 1. The newest backups are preserved and the oldest is deleted.
    
4.- File with logs of the backup process
      LOGFILE
    It is recomended to use this value to keep the log file into the same folder that the backup:
      LOGFILE=$DESTINO_FS/$DESTINO_DIR/log.txt

****************************************************
Configuration sample 1      

#!/bin/bash

# Backup will be made in drive /backup and, inside, in the folder incbackup/ (that is, the backup will be made in /backup/incbackup)
DESTINO_FS=/backup
DESTINO_DIR=incbackup

# The backup folder must be mounted using the /etc/fstab configuration
# in this case it is an Ext4, so rsync can do chown
DESTINO_ETQ=FSTAB   # Mounting point in /etc/fstab
DESTINO_OWNER=YES

# Folders to backup
#   /etc and /root (both mounted)
#   /home excluding some files/folders
#   Several network drives that must be mounted before the backup
ORIGEN=(
          /etc                     LOCAL   SINEXCLUSION
          /root                    LOCAL   SINEXCLUSION
          /home                    LOCAL   /home/usuario/bin/incbackup/incbackup_excludehome.txt
          /mnt/remoteserver1       MOUNT   SINEXCLUSION
          /mnt/webserver           MOUNT   SINEXCLUSION
       )

# No limit of backups
MAXCOPIAS=0

# Log file
LOGFILE=$DESTINO_FS/$DESTINO_DIR/log.txt

****************************************************
Configuration sample 2

#!/bin/bash

# Backup will be made in drive /mnt/wd4tb and in folder incbackup   (/mnt/wd4tb/incbackup)
DESTINO_FS=/mnt/wd4tb
DESTINO_DIR=incbackup

# Target folder must be mounted by his volume name
DESTINO_ETQ=WD4TB   
DESTINO_OWNER=YES 

# Backup folders
ORIGEN=(
          /etc                     LOCAL   SINEXCLUSION
          /root                    LOCAL   SINEXCLUSION
          /home                    LOCAL   /home/usuario/bin/incbackup/incbackup_excludehome.txt
          /mnt/remoteserver1       MOUNT   SINEXCLUSION
          /mnt/webserver           MOUNT   SINEXCLUSION
       )

# No limit of backups
MAXCOPIAS=0

# Log file
LOGFILE=$DESTINO_FS/$DESTINO_DIR/log.txt

****************************************************
Configuration sample 3

#!/bin/bash

# Backup will be made in a network drive mounted in /mnt/backupserver and in folder incbackup   (/mnt/backupserver/incbackup)
DESTINO_FS=/mnt/backupserver
DESTINO_DIR=incbackup

# Target drive is mounted through /etc/fstab
DESTINO_ETQ=FSTAB   
DESTINO_OWNER=NO    # Filesystem is SSHFS so chown can't be done by rsync

ORIGEN=(
          /etc                     LOCAL   SINEXCLUSION
          /root                    LOCAL   SINEXCLUSION
          /home                    LOCAL   /home/usuario/bin/incbackup/incbackup_excludehome.txt
          /mnt/remoteserver1       MOUNT   SINEXCLUSION
          /mnt/webserver           MOUNT   SINEXCLUSION
       )

# Maximum number of copies: 10
MAXCOPIAS=10

LOGFILE=$DESTINO_FS/$DESTINO_DIR/log.txt
