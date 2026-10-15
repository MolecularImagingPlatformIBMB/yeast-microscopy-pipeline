import os
import tkinter as tk
from tkinter import filedialog
from cellpose import models, io

# Ocultar la ventana principal de tkinter
root = tk.Tk()
root.withdraw()

print("Abriendo selector de carpetas...")

# 1 Ventana para elegir la carpeta de imágenes
image_dir = filedialog.askdirectory(title="1. Selecciona la carpeta con las imágenes '_combined.tif'")
if not image_dir:
    print("Operación cancelada. No se seleccionó ninguna carpeta de origen.")
    exit()

# 2 Ventana para elegir el modelo
print("Abriendo selector de modelo...")
model_path = filedialog.askopenfilename(title="2. Selecciona tu modelo de Cellpose entrenado")
if not model_path:
    print("Operación cancelada. No se seleccionó ningún modelo.")
    exit()

# 3 Ventana para elegir la carpeta de destino de las máscaras
print("Abriendo selector de destino...")
output_dir = filedialog.askdirectory(title="3. Selecciona la carpeta donde GUARDAR las máscaras")
if not output_dir:
    print("Operación cancelada. No se seleccionó carpeta de destino.")
    exit()

print("\n--- Iniciando Segmentación ---")
print(f"Carpeta origen: {image_dir}")
print(f"Modelo: {model_path}")
print(f"Carpeta destino: {output_dir}")
print("Por favor, espera. Esto puede tardar dependiendo del número de imágenes...\n")

# 4 Leer las imágenes
files = io.get_image_files(image_dir, '_masks')
imgs = [io.imread(f) for f in files]

# Modificación: Crear nuevas rutas base apuntando a la carpeta de destino elegida
output_files = [os.path.join(output_dir, os.path.basename(f)) for f in files]

# 5 Cargar modelo (gpu=True usará la gráfica M3 si la hay, si no, usará CPU)
model = models.CellposeModel(gpu=True, pretrained_model=model_path)

# 6 Evaluar (channels=[0,0] porque tus imágenes combinadas son de 1 solo canal/escala de grises)
masks, flows, styles = model.eval(imgs, diameter=None, channels=[0,0])

# 7 Guardar máscaras TIF usando las rutas de la nueva carpeta
io.save_masks(imgs, masks, flows, output_files, png=False, tif=True, save_txt=False)

print(f"\n¡PROCESO COMPLETADO! Las máscaras TIF se han guardado limpiamente en: {output_dir}")