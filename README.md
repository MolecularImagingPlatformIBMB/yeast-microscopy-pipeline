# Yeast Microscopy Image Analysis Pipeline

Automated image analysis pipeline for multi-channel yeast microscopy data (acquired from Leica Thunder systems as `.lif` hyperstacks)[cite: 13]. This repository integrates Bio-Formats extraction, custom Fiji/ImageJ preprocessing, Cellpose deep learning segmentation (`cyto3`), and background-corrected quantitative measurement of focal fluorescence accumulation (*foci*) versus diffuse cytosolic signals[cite: 13].

---

## Repository Structure

* **`001_Open Lif Extract Files with name_entire folder.ijm`**: Fiji macro to automatically extract all individual series from raw `.lif` files into `.tif` hyperstacks[cite: 13].
* **`002_Create Combined GFP RFP BF Images for Yeast Segmentation_Batch.ijm`**: Fiji macro to preprocess and merge fluorescence channels (GFP/RFP max projections) with edge-enhanced brightfield (BF) channels into a single composite image optimized for segmentation[cite: 13].
* **`003_extract_cellpose_masks_batch.py`**: Python batch script with graphical file selectors to run Cellpose segmentation across all combined images[cite: 13].
* **`004_Measure_Foci_vs_Cytoplasm_Ratio.ijm`**: Fiji macro for single-cell background subtraction, local focal signal extraction (AND), pure cytosolic extraction (XOR), and master CSV ratio generation with `NaN` quality control flags[cite: 13].

*(Note: Custom trained Cellpose `.npy` weight files are excluded from this repository due to GitHub file size limits; users can train their own following Step 3 below[cite: 13]).*

---

## Step-by-Step Analysis Protocol

### Step 1: Automatic Extraction of Hyperstacks from `.lif` Files
1. Open Fiji (ImageJ) with the Bio-Formats extension enabled[cite: 13].
2. Run `001_Open Lif Extract Files with name_entire folder.ijm`[cite: 13].
3. Select your input folder containing the raw `.lif` files and your target output folder. The macro will automatically export all series as individual `.tif` hyperstacks[cite: 13].

### Step 2: Channel Splitting, Preprocessing, and Combination
> **Why we combine channels:** In yeast microscopy, relying solely on Brightfield (BF) often fails because cell walls have low contrast and cells grow in tight clusters. Conversely, relying only on fluorescence leaves out cells with weak or absent expression. Fusing sharp cell-wall edges from BF with robust internal fluorescence provides complementary dual information, preventing cells from fusing in dense clusters[cite: 13].

1. Run `002_Create Combined GFP RFP BF Images for Yeast Segmentation_Batch.ijm`[cite: 13].
2. Select your folder of extracted `.tif` hyperstacks and a destination folder[cite: 13].
3. The macro splits channels, background-subtracts and max-projects the fluorescence channels, edge-enhances the brightfield channel, and combines them into `_combined.tif` images[cite: 13].

### Step 3: Model Selection & Training in Cellpose (Using `cyto3`)
1. Launch the Cellpose user interface (GUI)[cite: 13].
2. Load a sample of your newly generated `_combined.tif` images[cite: 13].
3. Select the **`cyto3`** pre-trained model as your starting base[cite: 13].
4. Manually refine or trace cell boundaries on a few sample images[cite: 13].
5. Click **"train"** to fine-tune the model weights on your yeast morphology[cite: 13].
6. Once satisfied, save your trained model weights (e.g., `yeast_model_custom.npy`) to your local directory[cite: 13].

### Step 4: Batch Segmentation via Python
1. Run the script `003_extract_cellpose_masks_batch.py`[cite: 13].
2. Use the interactive file dialogs to select:
   * The folder containing your `_combined.tif` images[cite: 13].
   * Your trained Cellpose model file (`.npy`)[cite: 13].
   * The destination folder for output masks[cite: 13].
3. The script will automatically process the batch and save clean segmentation `.tif` masks[cite: 13].

### Step 5: Quantitative Fluorescence Analysis & Ratio Calculation
1. Run `004_Measure_Foci_vs_Cytoplasm_Ratio.ijm` in Fiji[cite: 13].
2. Select your original images folder, your Cellpose masks folder, and your results output folder[cite: 13].
3. **What the macro calculates:**
   * **Global Background:** Measures pure background intensity by inverting a generous dilation (6 px) of the total cell mask[cite: 13].
   * **Foci Isolation (AND):** Intersects individual cell ROIs with an automatically generated global compartment mask (`FOCI_GLOBAL`)[cite: 13].
   * **Cytoplasm Isolation (XOR):** Subtracts the focal mask from the total cell area to isolate pure diffuse cytosol[cite: 13].
   * **Background Correction & Ratios:** Subtracts background from both compartments and computes RAW and CORRECTED ratios ($\text{Net}_{\text{Foci}} / \text{Net}_{\text{Cyto}}$)[cite: 13].
   * **Quality Control:** Assigns `NaN` values to segmentation failures, artifacts, or negative background-subtracted intensities to protect downstream statistics[cite: 13].
4. **Outputs:** Generates a master `.csv` spreadsheet and visual verification snapshots (`_verificacion.jpg`) outlining cell borders in Cyan and focal compartments in Yellow[cite: 13].

---

## Requirements
* **Fiji (ImageJ)** with Bio-Formats plugin[cite: 13].
* **Python** environment with Cellpose and tkinter installed[cite: 13].
