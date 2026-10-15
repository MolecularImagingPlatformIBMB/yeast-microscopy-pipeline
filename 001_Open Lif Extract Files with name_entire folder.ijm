// Macro Batch: Extraer series de múltiples archivos .lif en una carpeta
setBatchMode(true); 

// 1. Seleccionar carpetas de entrada y salida
inputDir = getDirectory("1. Selecciona la carpeta con los archivos .LIF del Thunder");
dir = getDirectory("2. Selecciona la carpeta donde guardar todos los TIFs");

// Obtener la lista de archivos de la carpeta
list = getFileList(inputDir);

// Cargar extensiones de Bio-Formats
run("Bio-Formats Macro Extensions");

// Bucle principal: iterar sobre cada archivo de la carpeta
for (i = 0; i < list.length; i++) {
    
    // Procesar solo si es un archivo LIF (ignorando mayúsculas/minúsculas)
    if (endsWith(toLowerCase(list[i]), ".lif")) {
        path = inputDir + list[i];
        
        // Extraer el nombre original del archivo y quitarle la extensión
        originalName = list[i];
        originalName = replace(originalName, ".lif", "");
        originalName = replace(originalName, ".LIF", ""); 
        
        print("Abriendo archivo: " + list[i]);
        
        Ext.setId(path);
        Ext.getSeriesCount(seriesCount);
        
        print("Encontradas " + seriesCount + " series en " + originalName);

        // Bucle secundario: extraer las series de este LIF
        for (s=0; s<seriesCount; s++) {
            Ext.setSeries(s);
            
            // Crear el sufijo numérico con formato 00x (001, 002, ..., 010, etc.)
            num = s + 1;
            if (num < 10) {
                seriesNum = "00" + num;
            } else if (num < 100) {
                seriesNum = "0" + num;
            } else {
                seriesNum = "" + num;
            }
            
            // Construir el nombre final
            finalName = originalName + "_series" + seriesNum;
            
            // Importar solo la serie actual
            run("Bio-Formats Importer", "open=["+path+"] color_mode=Default view=Hyperstack stack_order=XYCZT series_"+(s+1));
            
            // Guardar y cerrar
            saveAs("Tiff", dir + finalName + ".tif");
            close("*");
            
            print("  Guardada serie " + num + " de " + seriesCount + ": " + finalName);
        }
        
        // Cerrar el archivo actual en Bio-Formats antes de pasar al siguiente
        Ext.close();
    }
}

setBatchMode(false);
print("¡Extracción de toda la carpeta terminada!");