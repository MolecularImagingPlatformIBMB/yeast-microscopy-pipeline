/* E. REBOLLO (MOLECULAR IMAGING PLATFORM IBMB-CSIC) - MEASURING ACCUMULATED FOCI vs CYTOPLASM RATIO 
 *
 * THE MACRO: 
 * 1. EXTRACTS ROIs FROM CELLPOSE AND SPLITS CHANNELS.
 * 2. MEASURES GLOBAL BACKGROUND (Inverting the dilated total mask to avoid halos).
 * 3. FILTERS DEBRIS AND POORLY SEGMENTED CELLS.
 * 4. PREPARES VERIFICATIOMeasure_Foci_vs_Cytoplasm_Ratio_Background_Corrected.ijmMeasure_Foci_vs_Cytoplasm_Ratio_Background_Corrected.ijmN IMAGE AND DRAWS CELLS IN CYAN.
 * 5. CREATES GLOBAL FOCI/COMPARTMENT MASK AND DRAWS IT IN YELLOW.
 * 6. INTERSECTS (AND) CELL WITH MASK TO EXTRACT LOCAL FOCI SIGNAL.
 * 7. SUBTRACTS (XOR) FOCI FROM CELL TO EXTRACT PURE DIFFUSE CYTOPLASM.
 * 8. MEASURES INTENSITIES, SUBTRACTS BACKGROUND, CALCULATES RATIOS (RAW AND CORRECTED) AND SAVES (NaN on segmentation failure).
 */

// --- 1. DIRECTORY CONFIGURATION ---
dirOriginales = getDirectory("1. Select folder with ORIGINAL images (.tif)");
dirMascaras = getDirectory("2. Select folder with Cellpose MASKS");
dirResultados = getDirectory("3. Select folder to save CSV and VERIFICATION images");

setBatchMode(true); 
list = getFileList(dirOriginales);

// Prepare results table
run("Clear Results"); 
roiManager("reset");
roiManager("Show None"); 
run("Set Measurements...", "area mean integrated min shape redirect=None decimal=3");

// --- 2. MAIN IMAGE PROCESSING LOOP ---
for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".tif")) {
        
        open(dirOriginales + list[i]);
        rawName = getTitle();
        baseName = replace(rawName, ".tif", "");
        rename("image");

        prepareChannels("image");

        maskName = baseName + "_combined_cp_masks.tif"; 
        
        if (File.exists(dirMascaras + maskName)) {
            open(dirMascaras + maskName);
            rename("mask");

            // --- 2.5 MEASURE GLOBAL BACKGROUND ---
            selectWindow("mask");
            getStatistics(areaMask, meanMask, minMask, maxMask);
            setThreshold(1, maxMask); // Select everything that is a cell
            run("Create Selection");
            if (selectionType() != -1) {
                run("Enlarge...", "enlarge=6"); // Generous dilation (6 px) to avoid halos
                run("Make Inverse"); // Select pure dark background
                
                selectWindow("GFP");
                run("Restore Selection");
                getStatistics(areaBg, meanBg);
                
                // Remove selection
                run("Select None"); 
                
            } else {
                meanBg = 0; // Fallback in case the whole image is a cell (unlikely)
            }
            selectWindow("mask");
            resetThreshold();
            run("Select None"); // Ensure mask is deselected
            // -----------------------------------------------------------------------------
            
            extractROIsFromLabelMask("mask");
            filterSmallIsolatedROIs(800); 
            filterPacmanROIs(0.88); 
            
            numCelulas = roiManager("count");
            
            if (numCelulas > 0) {
                
                // --- 3. PREPARE VERIFICATION IMAGE & DRAW CELLS (CYAN) ---
                selectWindow("GFP");
                run("Duplicate...", "title=Composite_Verificacion");
                run("Green");
                resetMinAndMax();
                run("Enhance Contrast", "saturated=0.01");
                run("RGB Color");
                
                setForegroundColor(0, 255, 255); // Cyan color
                run("Line Width...", "line=1");
                roiManager("Deselect");
                roiManager("Draw"); 
                
                // --- 4. CREATE GLOBAL FOCI MASK (GREEN SIGNAL ACCUMULATION) ---
                selectWindow("GFP");
                run("Duplicate...", "title=Mascara_Foci_Temp");
                
                run("Gaussian Blur...", "sigma=1");
                run("Subtract Background...", "rolling=15");
                run("Gamma...", "value=1.20");
                run("Tubeness", "sigma=0.3 use");
                
                run("Bandpass Filter...", "filter_large=5 filter_small=2 suppress=None tolerance=5 autoscale saturate");
                
                selectWindow("Mascara_Foci_Temp");
                close();
                selectWindow("tubeness of Mascara_Foci_Temp");
                rename("Mascara_Foci");
                
                resetMinAndMax();
                run("8-bit");
                
                setAutoThreshold("Moments dark");
                setOption("BlackBackground", true);
                run("Convert to Mask");
                
                run("Create Selection");
                if (selectionType() != -1) {
                    roiManager("Add");
                    globalFociIndex = roiManager("count") - 1;
                    roiManager("select", globalFociIndex); 
                    roiManager("Rename", "FOCI_GLOBAL");
                    
                    // DRAW GLOBAL FOCI ON VERIFICATION IMAGE (YELLOW)
                    selectWindow("Composite_Verificacion");
                    setForegroundColor(255, 255, 0); // Yellow color
                    roiManager("select", globalFociIndex);
                    run("Draw", "slice"); 
                    
                } else {
                    globalFociIndex = -1; 
                }

                // --- 5. CELL-BY-CELL LOOP (MEASUREMENTS & RATIOS) ---
                for (celula = 0; celula < numCelulas; celula++) {
                    
                    filaActual = nResults;
                    setResult("Image_Name", filaActual, baseName);
                    setResult("Cell_ID", filaActual, celula + 1);
                    setResult("Background_Mean", filaActual, meanBg); // STORE BACKGROUND

                    selectWindow("GFP");
                    roiManager("select", celula);
                    getStatistics(areaCell, meanCell); 
                    intCell = areaCell * meanCell;
                    
                    setResult("Cell_Total_Area", filaActual, areaCell);
                    setResult("Cell_Total_Mean", filaActual, meanCell);
                    setResult("Cell_Total_IntDen", filaActual, intCell);

                    // A. ISOLATE FOCI (AND intersection with global foci mask)
                    if (globalFociIndex != -1) {
                        roiManager("Select", newArray(celula, globalFociIndex));
                        roiManager("AND");
                    } else {
                        run("Select None");
                    }
                    
                    if (selectionType() != -1) { 
                        roiManager("Add"); 
                        indiceFoci = roiManager("count") - 1; 
                        roiManager("select", indiceFoci); 
                        roiManager("Rename", "Foci_Cel_" + (celula+1));

                        selectWindow("GFP");
                        roiManager("select", indiceFoci); 
                        getStatistics(areaFoci, meanFoci);
                        intFoci = areaFoci * meanFoci;

                        // B. ISOLATE DIFFUSE CYTOPLASM (XOR subtraction: Total Cell minus Foci)
                        roiManager("Select", newArray(celula, indiceFoci));
                        roiManager("XOR");
                        
                        if (selectionType() != -1) {
                            roiManager("Add");
                            indiceCyto = roiManager("count") - 1;

                            selectWindow("GFP");
                            roiManager("select", indiceCyto);
                            getStatistics(areaCyto, meanCyto);
                            intCyto = areaCyto * meanCyto;
                            
                            setResult("Foci_Area", filaActual, areaFoci);
                            setResult("Foci_Mean_Int", filaActual, meanFoci);
                            setResult("Foci_IntDen", filaActual, intFoci);
                            setResult("Cyto_Area", filaActual, areaCyto);
                            setResult("Cyto_Mean_Int", filaActual, meanCyto);
                            setResult("Cyto_IntDen", filaActual, intCyto);
                            
                            // C. RATIO CALCULATIONS (RAW AND CORRECTED WITH NaN ON FAILURE)
                            if (meanCyto > 0) {
                                setResult("Ratio_Foci_vs_Cyto_RAW", filaActual, meanFoci / meanCyto);
                            } else {
                                setResult("Ratio_Foci_vs_Cyto_RAW", filaActual, NaN); 
                            }

                            realFoci = meanFoci - meanBg;
                            realCyto = meanCyto - meanBg;

                            if (realCyto > 0 && realFoci > 0) {
                                setResult("Ratio_Foci_vs_Cyto_CORRECTED", filaActual, realFoci / realCyto);
                            } else {
                                setResult("Ratio_Foci_vs_Cyto_CORRECTED", filaActual, NaN); // Artifact or high noise -> NaN
                            }
                            
                            roiManager("select", indiceCyto);
                            roiManager("Delete");
                            
                        } else {
                            // XOR failed (Foci occupy the entire cell) 
                            setResult("Foci_Area", filaActual, areaFoci);
                            setResult("Foci_Mean_Int", filaActual, meanFoci);
                            setResult("Foci_IntDen", filaActual, intFoci);
                            setResult("Cyto_Area", filaActual, 0);
                            setResult("Cyto_Mean_Int", filaActual, meanFoci); 
                            setResult("Cyto_IntDen", filaActual, 0);
                            setResult("Ratio_Foci_vs_Cyto_RAW", filaActual, NaN); 
                            setResult("Ratio_Foci_vs_Cyto_CORRECTED", filaActual, NaN); 
                        }
                        
                    } else {
                        // AND failed (No focal accumulation detected, whole cell is diffuse cytoplasm)
                        setResult("Foci_Area", filaActual, 0);
                        setResult("Foci_Mean_Int", filaActual, meanCell); 
                        setResult("Foci_IntDen", filaActual, 0);
                        setResult("Cyto_Area", filaActual, areaCell);
                        setResult("Cyto_Mean_Int", filaActual, meanCell);
                        setResult("Cyto_IntDen", filaActual, intCell);
                        setResult("Ratio_Foci_vs_Cyto_RAW", filaActual, NaN); 
                        setResult("Ratio_Foci_vs_Cyto_CORRECTED", filaActual, NaN); 
                    }
                }
                updateResults();
                
                selectWindow("Mascara_Foci");
                close();
                
                if (globalFociIndex != -1) {
                    roiManager("select", globalFociIndex);
                    roiManager("Delete");
                }

                // --- 6. SAVE VERIFICATION IMAGE ---
                selectWindow("Composite_Verificacion");
                saveAs("Jpeg", dirResultados + baseName + "_verificacion.jpg");
                close();
                
            } else {
                print("No cells found in: " + baseName);
            }
            roiManager("reset"); 
            
        } else {
            print("MISSING MASK: " + maskName);
        }
        run("Close All"); 
    }
}

// --- 7. SAVE MASTER TABLE & FINISH ---
saveAs("Results", dirResultados + "Resultados_Ratio_Foci_Ceramida_Corregidos.csv");
setBatchMode(false);
print("Ceramide Foci Ratio analysis completed! CSV and verification images saved.");

// ================= HELPER FUNCTIONS ================= //

function prepareChannels(image){
    selectWindow(image);
    run("Split Channels");
    
    selectWindow("C2-"+image);
    close();
    
    selectWindow("C1-"+image);
    run("Z Project...", "projection=[Max Intensity]");
    rename("GFP"); 
    
    selectWindow("C1-"+image);
    close();
}

function extractROIsFromLabelMask(maskImage) {
    selectWindow(maskImage);
    getStatistics(area, mean, min, max); 
    
    if (max > 2000) { max = 2000; }
    
    for (label = 1; label <= max; label++) {
        setThreshold(label, label);
        run("Create Selection");
        if (selectionType() != -1) { roiManager("Add"); }
    }
    resetThreshold();
}

function filterSmallIsolatedROIs(minArea) {
    width = getWidth(); height = getHeight(); n = roiManager("count");
    if (n == 0) return;
    newImage("TouchMap", "8-bit black", width, height, 1);
    setColor(255);
    for (i = 0; i < n; i++) { roiManager("select", i); fill(); }
    for (i = n - 1; i >= 0; i--) {
        roiManager("select", i); getStatistics(area);
        if (area < minArea) {
            setColor(0); fill(); run("Enlarge...", "enlarge=2");
            getStatistics(areaE, meanE, minE, maxE);
            if (maxE == 0) { roiManager("select", i); roiManager("delete"); } 
            else { roiManager("select", i); setColor(255); fill(); }
        }
    }
    selectWindow("TouchMap"); close();
}

function filterPacmanROIs(minSolidity) {
    n = roiManager("count");
    for (i = n - 1; i >= 0; i--) {
        roiManager("select", i); solidity = getValue("Solidity");
        if (solidity < minSolidity) { roiManager("delete"); }
    }
}