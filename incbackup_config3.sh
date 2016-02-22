#!/bin/bash

# Directorio en donde se harán las copias de seguridad
DESTINO_FS=/mnt/cvg
DESTINO_DIR=incbackup

# Elegir una de las siguientes opciones sobre el sistema de ficheros DESTINO
DESTINO_ETQ=FSTAB   # El punto de montaje está en fstab
DESTINO_OWNER=NO    # YES=el FS conserva owner/group  (NO=No lo conserva, p.ej. SSHFS)

# Directorios de los que se deseamos hacer copia de seguridad
ORIGEN=(
          /etc                     LOCAL   SINEXCLUSION
          /root                    LOCAL   SINEXCLUSION
          /home                    LOCAL   /home/usuario/bin/incbackup/incbackup_excludehome.txt
          /mnt/remoteserver1       MOUNT   SINEXCLUSION
          /mnt/webserver           MOUNT   SINEXCLUSION
       )

# Máximo de copias incrementales. 0 para no poner límite
MAXCOPIAS=0

# Fichero en el que almacenar logs del proceso
LOGFILE=$DESTINO_FS/$DESTINO_DIR/log.txt
