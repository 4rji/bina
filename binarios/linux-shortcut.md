Para crear un acceso en favoritos (como acceso directo en el menú o dock) en Debian para `/opt/4rji/bin/promox.AppImage`, crea un archivo `.desktop`:


sudo mv dist/Proxmox-App-1.0.0.AppImage /opt/4rji/bin/promox.AppImage 
sudo cp build/icon.png /usr/share/icons/promox.png 

/usr/share/icons/cursor.png

```bash
nano ~/.local/share/applications/promox.desktop
```

Contenido:

```ini
[Desktop Entry]
Name=Promox
Exec=/opt/4rji/bin/promox.AppImage
Icon=promox
Type=Application
Categories=Utility;
Terminal=false
```

**Notas rápidas:**

* Asegúrate de que el AppImage tenga permisos de ejecución: `chmod +x /opt/4rji/bin/promox.AppImage`
* El ícono `promox` debe estar en `/usr/share/icons` o usa una ruta absoluta si tienes un PNG o SVG, por ejemplo: `Icon=/opt/4rji/bin/promox.png`
* Luego puedes buscarlo en el menú y anclarlo.
