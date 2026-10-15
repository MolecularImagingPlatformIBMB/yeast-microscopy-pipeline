// E. Rebollo (Molecular Imaging Platform, IBMB-CSIC)
// IMAGEJ 1.54P
// THIS MACRO COMBINES THREE CHANNELS (GFP, RFP, AND BRIGHTFIELD) INTO A SINGLE COMPOSITE IMAGE OPTIMIZED FOR CELLPOSE SEGMENTATION.

// 1. Select input and output directories
inputDir = getDirectory("Select the folder containing the original TIF hyperstacks");
outputDir = getDirectory("Select the folder where combined images will be saved");

setBatchMode(true); // Hides image windows during processing for maximum execution speed[cite: 21]
list = getFileList(inputDir);

for (i = 0; i < list.length; i++) {
    // Process only files ending with .tif
    if (endsWith(list[i], ".tif")) {
        open(inputDir + list[i]);
        
        // Clean up the original filename to use later for saving
        rawName = getTitle();
        rawName = replace(rawName, ".tif", ""); 
        rename("image");

        // Step 2A: Split and prepare color channels (GFP, RFP, BF)
        prepareImages("image");

        // Step 2B: Preprocess and combine fluorescence channels (GFP + RFP)
        preprocessStackFluo("gfp");
        preprocessStackFluo("rfp");
        imageCalculator("Add", "MAX_gfp", "MAX_rfp"); // Sum GFP and RFP maximum projections[cite: 21]
        rename("fluo");
        selectWindow("MAX_rfp");
        close();

        // Step 2C: Preprocess Brightfield (BF) and combine with fluorescence
        preprocessStackBF("BF");
        imageCalculator("Max", "fluo", "MED_BF"); // Fuse fluorescence with edge-enhanced BF using maximum operator[cite: 21]
        rename(rawName + "_combined");
        selectWindow("MED_BF");
        close();

        // Step 2D: Save the final combined image and clear memory
        saveAs("Tiff", outputDir + rawName + "_combined.tif");
        run("Close All"); // Closes all open windows to free up RAM before the next image[cite: 21]
        
        print("Processed successfully: " + rawName + "_combined.tif");
    }
}
setBatchMode(false);
print("Batch processing completed successfully!");

// --- CUSTOM FUNCTIONS ---

// Function: Splits composite image into individual channels and converts them to 8-bit grayscale
function prepareImages(image){
    selectWindow(image);
    run("Split Channels");
    
    selectWindow("C3-" + image);
    resetMinAndMax;
    run("8-bit");
    rename("BF");
    
    selectWindow("C2-" + image);
    resetMinAndMax;
    run("8-bit");
    rename("rfp");
    
    selectWindow("C1-" + image);
    resetMinAndMax;
    run("8-bit");
    rename("gfp");
}

// Function: Preprocesses fluorescence stacks (Background subtraction, median filter, and max intensity projection)
function preprocessStackFluo(image){
    selectWindow(image);
    run("Subtract Background...", "rolling=50 stack"); // Removes uneven illumination[cite: 21]
    run("Median...", "radius=2 stack"); // Reduces high-frequency noise[cite: 21]
    run("Z Project...", "projection=[Max Intensity]"); // Collapses Z-stack into a single max projection[cite: 21]
    selectWindow(image);
    run("Close");
}

// Function: Preprocesses brightfield stacks (Median Z-projection, smoothing, and edge enhancement)
function preprocessStackBF(image){
    selectWindow(image);
    run("Z Project...", "projection=Median"); // Flattens Z-stack using median[cite: 21]
    run("Median...", "radius=2"); // Smooths noise[cite: 21]
    run("Find Edges"); // Highlights yeast cell walls and boundaries for Cellpose[cite: 21]
    selectWindow(image);
    run("Close");
}