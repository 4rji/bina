#!/bin/bash

# Variables para opciones predeterminadas
default_answer="s"
default_port="8880"
port=$default_port

# Directorio de destino para los archivos Apache
destination_dir="/tmp/apache"

# Archivo de lista de nombres de archivos
file_list="/usr/bin/listaapache"

# Pregunta combinada
if $apache_installed || $httpd_installed || $python_http_installed; then
  echo -e "${GREEN}Se detectó Apache/httpd y/o Python en el sistema.${NC}"
  read -n1 -p "¿Deseas iniciar Apache/httpd [S/n] " answer_combined
  echo ""

  # Establecer respuesta predeterminada si se presiona Enter
  answer_combined="${answer_combined:-$default_answer}"

  if [[ $answer_combined =~ ^[Ss]$ ]]; then
    # Iniciar Apache/httpd si está disponible
    if $apache_installed; then
      sudo service apache2 start
      apache_started=true
      echo -e "${GREEN}Apache iniciado.${NC}"
    elif $httpd_installed; then
      sudo service httpd start
      apache_started=true
      echo -e "${GREEN}httpd iniciado.${NC}"
    fi

    # Verificar si se especificó un puerto diferente
    read -p "¿Deseas utilizar un puerto diferente al predeterminado ($default_port)? [s/N] " custom_port
    custom_port="${custom_port:-n}"

    if [[ $custom_port =~ ^[Ss]$ ]]; then
      # Solicitar el puerto personalizado
      read -p "Por favor, introduce el puerto deseado: " port
    fi

    # Copiar archivos de la listaapache a /tmp/apache
    if [ ! -d "$destination_dir" ]; then
      mkdir -p "$destination_dir"
    fi
    while IFS= read -r filename; do
      file_path=$(find /usr/bin/ -name "$filename" 2>/dev/null)
      if [ -n "$file_path" ]; then
        cp "$file_path" "$destination_dir"
      else
        echo -e "${RED}No se encontró el archivo $filename en /usr/bin.${NC}"
      fi
    done < "$file_list"
    echo -e "${BLUE}Archivos de listaapache copiados a $destination_dir.${NC}"

    # Iniciar el servidor HTTP de Python en /tmp/apache
    if [[ $port =~ ^[0-9]+$ ]]; then
      cd "$destination_dir"
      echo -e "${BLUE}Iniciando servidor HTTP de Python en la ruta $destination_dir:${port}${NC}"
      python3 -m http.server $port
    else
      echo -e "${RED}El puerto ingresado no es válido.${NC}"
    fi
  fi
else
  echo -e "${RED}No se encontró un servicio para iniciar.${NC}"
fi

