#!/bin/bash
#
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
#
# **********************************************************************

# Carga del fichero de configuracion con variables de entorno
if [ $# -ne 1 ]; then
  echo "Debe indicar el fichero de configuración de backup"
  exit 10
elif [ -f "$1" ]; then
  source $1
else
  echo "No existe fichero de configuración"
  exit 11
fi

# En bash solo se pueden devolver valores en rango 0-255 por lo que en lugar de usar return
# se almacenará el valor devuelto en esta variable global
__returnvalue=0


# **********************************************************************
# Crea el enlace simbólico last a la última copia de seguridad
#
# Argumento: última copia realizada
# Devolución: nada
#
# Warning: En el caso de trabajar sobre un sistema de ficheros remoto sshfs con la opción follow_symlinks, 
#          los enlaces simbólicos se ven como directorios por lo que no se borra/crea el enlace last
function crearEnlaceSimbolicoLast() {
  __ultima=$1
  
  if [[ -L $DESTINO/last ]]; then
    rm $DESTINO/last |& tee -a $LOGFILE
  fi
  pushd $DESTINO >> /dev/null
  ln -s $__ultima last |& tee -a $LOGFILE
  popd >> /dev/null
}
# **********************************************************************


# **********************************************************************
# Compacta huecos en copias de seguridad y empieza numeración en 1
#
# Argumento: Listado de directorios ordenado
# Devolución: última copia existente
function compactaDirectorios() {
  # Parámetro de la función
  __directorios=$1

  #echo "Realizando compactación de huecos y comenzando numeración en 1" |& tee -a $LOGFILE
  __nuevodir=1
  for __dir in $__directorios; do
    if [[ $__dir =~ ^[0-9]+$ ]]; then   # Si es un número de backup
      if [[ $__dir -ne $__nuevodir ]]; then
        echo "   Numeración incorrecta detectada ... moviendo $__dir a $__nuevodir" |& tee -a $LOGFILE
        mv $DESTINO/$__dir $DESTINO/$__nuevodir |& tee -a $LOGFILE
      fi
      (( __nuevodir ++ ))
    fi
  done
  (( __numcopias = __nuevodir - 1 ))
  #echo "   Detectadas $__numcopias copias de seguridad" |& tee -a $LOGFILE
  
  # Borrar/crear enlace simbólico last
  # crearEnlaceSimbolicoLast $__numcopias       <<< se hará al finalizar el proceso completo de backup
  
  __returnvalue=$__numcopias
}
# **********************************************************************


# **********************************************************************
# Reduce el número de copias de seguridad si hay más de MAXCOPIAS
# Deja las más recientes
# Precondición: Los backups han de estar compactados previamente
#
# Argumento: última copia existente
# Devolución: Copias eliminadas
function eliminarCopiasSobrantes() {
  __ultima=$1
  (( __cont = 0 ))
  if [[ $__ultima != -1 && $MAXCOPIAS != 0 ]]; then
    (( __dif = $__ultima - $MAXCOPIAS ))
    if [[ $__dif -gt 0 && $MAXCOPIAS != 0 ]]; then
      echo "Eliminando copias de seguridad que exceden al máximo de copias configurado" |& tee -a $LOGFILE
      (( __cont = 1 ))
      while [[ $__cont -le $__dif ]]; do
        echo "   ... borrando copia $__cont" |& tee -a $LOGFILE
        \rm -rf $DESTINO/$__cont
        (( __cont ++ ))
      done
    fi
  fi
  
  __returnvalue=$__cont
}
# **********************************************************************


# **********************************************************************
# Comprueba si existen huecos en las copias de seguridad
#
# Argumento: Listado de directorios ordenado
# Devolución: 0 si no hay huecos y 1 si los hay
function buscarHuecos() {
  # Parámetro de la función
  __directorios=$1
  #echo " ...... $__directorios"
  
  # Comprobar si hay huecos en la secuencia de backups
  # Variables locales
  __primernum=-1
  __ultimonum=-1
  __lastnumber=-1
  __cont=1
  __compactar=0
  for __dir in $__directorios; do
    #echo " .... voy por $__dir"
    if [[ $__primernum -eq -1 ]]; then
      #echo "   1"
      # Buscamos el primer backup
      if [[ $__dir =~ ^[0-9]+$ ]]; then
        #echo "   2"
        __primernum=$__dir
        # Si es distinto de 1 no hace falta buscar huecos: hay que compactar
        if [[ $__primernum -ne 1 ]]; then
          #echo "   3"
          echo "No existe el primer backup" |& tee -a $LOGFILE
          __compactar=1
          break
        fi
      fi
    elif [[ $__ultimonum -eq -1 ]]; then
      #echo "   4"
      # Comprobamos que los que van a continuación son consecutivos
      if [[ $__dir =~ ^[0-9]+$ ]]; then
        if [[ $__dir-1 -ne $__lastnumber ]]; then
          echo "Encontrados backups no consecutivos $__lastnumber a $__dir" |& tee -a $LOGFILE
          __compactar=1
          break
        fi
      else
         __ultimonum=$__lastnumber
      fi
    fi
    __lastnumber=$__dir  
    ((__cont++))
  done
  if [[ $__ultimonum -eq -1 ]]; then
    __ultimonum=$__lastnumber
  fi
  
  __returnvalue=$__compactar
}
# **********************************************************************


# **********************************************************************
# Localiza la última copia de seguridad existente
#
# Argumento: Listado de directorios
# Devolución: -1 si no hay ninguno o el número del último si hay alguno
function buscarUltimo() {
  # Parámetro de la función
  __directorios=$1

  # Buscar el número del último backup
  __ultimonum=-1
  __directoriosinvert=`echo $__directorios | fmt -1 | sort -nr`
  for __dir in $__directoriosinvert; do
    if [[ $__dir =~ ^[0-9]+$ ]]; then
      __ultimonum=$__dir
      break
    fi
  done
  __returnvalue=$__ultimonum
}
# **********************************************************************


# **********************************************************************
# Rotación de directorios de backup (si hace falta)
#
# Argumento: Última copia existente
# Devolución: Última copia que ha quedado (sería el argumento de entrada menos uno)
function rotarDirectorios() {
  __ultima=$1

  if [[ $MAXCOPIAS -ne 0 && $MAXCOPIAS -ne 1 && $__ultima -eq $MAXCOPIAS ]]; then
    echo "Rotando copias incrementales y borrando la más antigua"  |& tee -a $LOGFILE
    \rm -rf $DESTINO/1 |& tee -a $LOGFILE
    __actual=2
    while [[ $__actual -le $__ultima ]]; do
      (( __anterior = __actual - 1 ))
      mv $DESTINO/$__actual $DESTINO/$__anterior |& tee -a $LOGFILE
      ((__actual++))
    done
    ((__ultima--))
  fi

  __returnvalue=$__ultima
}
# **********************************************************************


# **********************************************************************
# Monta un sistema de ficheros a partir de /etc/fstab o de una etiqueta
#
# Parámetros: FS  : Sistema de ficheros
#             ETQ : FSTAB si se monta desde /etc/fstab o el nombre de una etiqueta de volumen si no se quiere usar /etc/fstab
# Devolución: 0 si ya estaba montada
#             1 si no estaba montada pero la ha montado con éxito
#             2 si hay error en el montaje
function montarFS() {
  __destinofs=$1
  __destinoetq=$2
  __error=2
  if grep -qs "$__destinofs" /proc/mounts; then
    echo "El sistema de ficheros $__destinofs está montado"
    __error=0
  else
    echo "El sistema de ficheros $__destinofs no está montado ... montando"
    __error=2
    if [[ $__destinoetq == "FSTAB" ]]; then
      mount $__destinofs
      if [[ "$?" == 0 ]]; then
        __error=1
      fi
    else
      mount -L $__destinoetq $__destinofs
      if [[ "$?" == 0 ]]; then
        __error=1
      fi
    fi
  fi

  __returnvalue=$__error
}
# **********************************************************************


# **********************************************************************
# **  Comienzo de algoritmo principal
# **********************************************************************

# Montar sistema de ficheros destino del backup
montarFS "$DESTINO_FS" "$DESTINO_ETQ"
MONTAJE=$__returnvalue
if [[ $MONTAJE == 2 ]]; then
  echo "ERROR FATAL: no está disponible el sistema de ficheros de destino $DESTINO"
  echo "Abortando proceso de backup"
  exit
fi

# Crear variable con ruta de DESTINO y verificar que existe
DESTINO=$DESTINO_FS/$DESTINO_DIR
if [[ ! -d $DESTINO ]]; then
  echo "No existe la carpeta de destino para el backup"
  echo "Abortando proceso de backup"
  exit
fi

echo "********* CREANDO BACKUP INCREMENTAL ("`date`") *********" |& tee -a $LOGFILE

# Obtener listado de directorios
DIRLISTADO=`ls $DESTINO`

# Ordenar listado
DIRLISTADOORD=`echo $DIRLISTADO | fmt -1 | sort -n`

# Comprobar si al menos hay un backup
buscarUltimo "$DIRLISTADO"
ULTIMOBACKUP=$__returnvalue

# Si hay alguno reparar, si es necesario, la estructura de directorios
if [[ $ULTIMOBACKUP != -1 ]]; then
  echo "Último backup detectado: $ULTIMOBACKUP" |& tee -a $LOGFILE
  # Buscar huecos (esta etapa no es estrictamente necesaria pero deja mensajes en LOG)
  buscarHuecos "$DIRLISTADOORD"
  hayhuecos=$__returnvalue
  
  # Eliminar huecos (si hubiere)
  if [[ $hayhuecos == 1 ]]; then
    compactaDirectorios "$DIRLISTADOORD"
    ULTIMOBACKUP=$__returnvalue
  fi

  # Si hay más copias de las máximas configuradas: eliminar sobrantes
  if [[ $MAXCOPIAS != 0 ]]; then
    echo "Límite de copias incrementales: $MAXCOPIAS" |& tee -a $LOGFILE
    eliminarCopiasSobrantes $ULTIMOBACKUP
    (( ULTIMOBACKUP = ULTIMOBACKUP - __returnvalue ))
    DIRLISTADO=`ls $DESTINO`
    DIRLISTADOORD=`echo $DIRLISTADO | fmt -1 | sort -n`
    compactaDirectorios "$DIRLISTADOORD"
    ULTIMOBACKUP=$__returnvalue
    # Borrar/crear enlace simbólico last
    # crearEnlaceSimbolicoLast $ULTIMOBACKUP      <<< ... se crea despues del rsync >>>
  else
    echo "Sin límite de copias incrementales" |& tee -a $LOGFILE
  fi

  # Rotación de backups (si es necesario)
  rotarDirectorios $ULTIMOBACKUP
  ULTIMOBACKUP=$__returnvalue
else
  echo "No se ha detectado existencia de ningún backup hasta el momento" |& tee -a $LOGFILE
fi

# Si el FS destino no permite conservar owner/group pasarle las opciones a rsync
if [[ $DESTINO_OWNER == "YES" ]]; then
    OPTS_RSYNC1=""
else
    OPTS_RSYNC1="--no-o --no-g"
fi

# Determinar si el backup es el primero o no
if [[ $ULTIMOBACKUP -eq -1 || $MAXCOPIAS -eq 1 ]]; then
  (( NUEVO = 1 ))
else
  (( NUEVO = $ULTIMOBACKUP + 1 ))
fi

# Realizar backup para cada fuente
echo "Creando backup : $NUEVO" |& tee -a $LOGFILE
for ((i=0;i<${#ORIGEN[@]};i+=3)); do
  # Determinar carpeta de origen de datos
  __fuente=${ORIGEN[$i]}

  (( j=$i+1 ))
  __montaje=${ORIGEN[$j]}
  
  # Añadir fichero con exclusiones al backup (si lo hay)
  (( j=$i+2 ))
  __exclusion=${ORIGEN[$j]}
  if [[ -f $__exclusion ]]; then
    OPTS_RSYNC3="--exclude-from $__exclusion"
  else
    OPTS_RSYNC3=""
  fi

  echo "*** ORIGEN de los datos: $__fuente" |& tee -a $LOGFILE

  # Montar el FS de origen de datos si es necesario
  MONTAJEORIG=0
  if [[ $__montaje == "MOUNT" ]]; then
    montarFS "$__fuente" "FSTAB"
    MONTAJEORIG=$__returnvalue
    if [[ $MONTAJEORIG == 2 ]]; then
      echo "ERROR : no está disponible el sistema de ficheros de origen $__fuente" |& tee -a $LOGFILE
      echo "        saltando backup para ese origen de datos" |& tee -a $LOGFILE
      continue
    elif [[ $MONTAJEORIG == 1 ]]; then
      echo "El sistema de ficheros $__fuente se ha montado para hacer backup" |& tee -a $LOGFILE
    fi
  fi
  
  nombre=${__fuente//[\/]/_}
  if [[ $NUEVO != 1 ]]; then
    OPTS_RSYNC2="--link-dest=$DESTINO/$ULTIMOBACKUP/$nombre"
  else
    OPTS_RSYNC2=""
  fi
  mkdir -p $DESTINO/$NUEVO/$nombre
  echo "    Opciones de rsync: $OPTS_RSYNC1 $OPTS_RSYNC2 $OPTS_RSYNC3" |& tee -a $LOGFILE
  rsync -avl $OPTS_RSYNC1 $OPTS_RSYNC3 --delete $__fuente/ $OPTS_RSYNC2 $DESTINO/$NUEVO/$nombre/ |& tee -a $LOGFILE

  # Si el FS de origen fue montado para hacerle backup: desmontarlo
  if [[ $MONTAJEORIG == 1 ]]; then
    umount $__fuente
  fi
done

# Borrar/crear enlace simbólico last
crearEnlaceSimbolicoLast $NUEVO

echo "********* FINALIZANDO BACKUP ("`date`") *********" |& tee -a $LOGFILE
echo |& tee -a $LOGFILE

# Desmontar FS si se montó para el backup
if [[ $MONTAJE == 1 ]]; then
  umount $DESTINO_FS
fi
