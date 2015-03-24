// Shape esimator
// Roman Shkarin

macro "Estimate shape of fishes" {
	requires("1.49h")
	
	//var inputPath = "D:\\Roman\\XRegio\\Segmentations2";
	var inputPath = "D:\\Roman\\XRegio\\Segmentations_Median";

	var outputPath = "D:\\Roman\\XRegio\\Results";
	//var inputPath = "/Users/Roman/Documents/test_segmentations";
	//var outputPath = "/Users/Roman/Documents/test_results";

	var methodPrefix = "segmented_median";
	var fishPrefix = "fish";
	var fileExt = ".tif";
	var statisticsOutputExt = ".xls";
	var fishNumbers = newArray("223");
	//var fishNumbers = newArray("3000");
	//var fishNumbers = newArray("200", "202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245");

	var sliceStep = 10; //in percentage
	var sliceNeighbours = 31; //odd number, othgerwise will be corrected by -1
	var collectCrossSectionStatistics = true;
	var collectObjectCounterStatistics = false;

	
	setBatchMode(true);
	process(inputPath, outputPath, sliceStep, fishPrefix, fileExt, statisticsOutputExt, fishNumbers, sliceNeighbours);
	setBatchMode(false);
}

function process(inputPath, outputPath, sliceStep, fishPrefix, fileExt, statisticsOutputExt, fishNumbers, sliceNeighbours) {
	for (i = 0; i < fishNumbers.length; i++) {
		currentPath = inputPath + File.separator + fishPrefix + fishNumbers[i];
		fileList = getFileList(currentPath);
		currentFileName = "";
	
		for (j = 0; j < fileList.length; j++) {
			fileName = fileList[j];
			
			if (startsWith(fileName, methodPrefix + "_" + fishPrefix + fishNumbers[i]) &&  endsWith(fileName, fileExt)) {
				currentFileName = fileName;
				break;
			}
		}

		printLogMessage("Statistical analysis started", currentPath + File.separator + currentFileName);

		//Open data as a tiff stack
		open(currentPath + File.separator + currentFileName);
		stackId = getImageID();

		//Get stack info
		currentFileNameNoExt = replace(currentFileName, fileExt, "");
		stackWidth = getWidth();
		stackHeight = getHeight();
		stackSlices = nSlices;
		volSize = newArray(stackWidth, stackHeight, stackSlices);
		colorDepth = bitDepth();
		
		getVoxelSize(voxWidth, voxHeight, voxDepth, voxUnit);
		voxelSize = newArray(voxWidth, voxHeight, voxDepth);

		//Histo bins
		numBins = pow(2, colorDepth);

		//Get border slices
		volumeZBoundaries = getMinMaxBorderValueToArray(stackSlices, stackId, numBins);

		//Create the stack of the biggest particle
		newImage("particles_segmented_" + currentFileNameNoExt, toString(colorDepth) + "-bit grayscale-mode", volSize[0], volSize[1], 1, volSize[2], 1);
		particlesStackId = getImageID();

		totalVolumeSize = 0;
		
		for (sliceIdx = 1; sliceIdx <= volSize[2]; sliceIdx++) {
			showProgress(sliceIdx / volSize[2]);
			
			selectImage(stackId);
			setSlice(sliceIdx);
			
			run("Duplicate...", " ");
			dupSlice = getImageID();

			//Analyze slice
			sliceResults = getSliceRemoveSmallParticles();

			//Get area and masked image
			sliceRemovedSmallParticlesId = sliceResults[0];
			totalVolumeSize += sliceResults[1] / (voxelSize[0] * voxelSize[1]);
			
			selectImage(sliceRemovedSmallParticlesId);
				
			run("Select All");
			run("Copy");
				
			selectImage(particlesStackId);
			setSlice(sliceIdx);
			run("Paste");

			selectImage(sliceRemovedSmallParticlesId);
			close();

			selectImage(dupSlice);
			close();
		}

		//print("totalVolumeSize = " + toString(totalVolumeSize));
		//saveDataAsTiffStack(outputPath, "particles", fishPrefix, fishNumbers[i], volSize, colorDepth);

		if (collectCrossSectionStatistics) {
			//Estimate crossections with specified step
			effectiveNumSlices = volumeZBoundaries[1] - volumeZBoundaries[0] + 1;
			currentSliceStep = floor(effectiveNumSlices * (sliceStep / 100));
			numOfSteps = floor(effectiveNumSlices / currentSliceStep);

			print("effectiveNumSlices = " + toString(effectiveNumSlices));
			print("currentSliceStep = " + toString(currentSliceStep));
			print("numOfSteps = " + toString(numOfSteps));
	
			//Name of resulting table
			actualName = "Cross-Section Summary";
	
			//Create table and fill the headers
			openAndFillTableHeaders(actualName);
	
			//Estimate shape parameters of each step-slice
			for (step = 0; step <= numOfSteps; step++) {
				showProgress(step / numOfSteps);
				
				sliceIdx = step * currentSliceStep + volumeZBoundaries[0];
				neighboursIndices = getNeighboursIndices(sliceIdx, stackSlices, sliceNeighbours);
				
				selectImage(particlesStackId);
				
				run("Duplicate...", "duplicate range=" + toString(neighboursIndices[0]) + "-" + toString(neighboursIndices[neighboursIndices.length - 1]) + " title=[duplicate_step_" + toString(step) + "]");
				duplicatedStack = getImageID();
				
				run("Particles8 ", "white morphology show=Particles filter minimum=25 maximum=9999999 display overwrite redirect=None");
				numResultsBeforeSumm = nResults();
				run("Summarize");
	
				newItem = createNewItem(3, numResultsBeforeSumm, totalVolumeSize);
				
				addItemToTable(actualName, newItem);
	
				selectImage(duplicatedStack);
				close();
			}
	
			saveStatistics(actualName, "cross_sections", outputPath, fishPrefix, fishNumbers[i], volSize, colorDepth, fishPrefix, statisticsOutputExt);
		}

		if (collectObjectCounterStatistics) {
			//Scale the stack in twice
			scaleVal = 0.5;
			run("Scale...", 
				"x=" + toString(scaleVal) + 
				" y=" + toString(scaleVal) +
				" z=" + toString(scaleVal) + 
				" width=" + toString(floor(stackWidth * 0.5)) +
				" height=" + toString(floor(stackHeight * 0.5)) + 
				" depth=" + toString(floor(stackSlices * 0.5)) + 
				" interpolation=Bicubic average process create title=scaled_" + currentFileNameNoExt);
				
			scaledStackId = getImageID();
			selectImage(scaledStackId);
			
			scaledVolWidth = getWidth();
			scaledVolHeight = getHeight();
			scaledVolSlices = nSlices;
			
			scaledVolSize = newArray(scaledVolWidth, scaledVolHeight, scaledVolSlices);
		
			//Estimate shape parameters with 3D Object Counter
			run("3D OC Options", "volume surface nb_of_obj._voxels nb_of_surf._voxels integrated_density mean_gray_value std_dev_gray_value median_gray_value minimum_gray_value maximum_gray_value centroid mean_distance_to_surface std_dev_distance_to_surface median_distance_to_surface centre_of_mass bounding_box dots_size=5 font_size=10 store_results_within_a_table_named_after_the_image_(macro_friendly) redirect_to=none");
			run("3D Objects Counter", "threshold=25 slice=928 min.=10 max.=376042500 statistics summary");
			
			saveStatistics("Results", "object_counter", outputPath, fishPrefix, fishNumbers[i], volSize, colorDepth, fishPrefix, statisticsOutputExt);

			selectImage(scaledStackId);
			close();
		}

		printLogMessage("Statistical analysis finished", currentPath + File.separator + currentFileName);

		closeAll();
	}
}

function getMinMaxBorderValueToArray(stackSlices, stackId, numBins) {
	selectImage(stackId);

	array = newArray();
	
	//Get min slice index with data
	for (sliceIdx = 1; sliceIdx <= stackSlices; sliceIdx++) {
	 	setSlice(sliceIdx);
		getHistogram(values, binCounts, numBins);
		Array.getStatistics(values, min, max, mean, std);
		if (binCounts[max] > 0) {
			array = Array.concat(array, sliceIdx);
			break;
		}
	}

	//Get max slice index with data
	for (sliceIdx = stackSlices; sliceIdx >= 1; sliceIdx--) {
	 	setSlice(sliceIdx);
		getHistogram(values, binCounts, numBins);
		Array.getStatistics(values, min, max, mean, std);
		if (binCounts[max] > 0) {
			array = Array.concat(array, sliceIdx);
			break;
		}
	}

	return array;
}

function saveStatistics(table_name, method_name, outputPath, fishPrefix, fishNumber, volSize, colorDepth, fishPrefix, outputExt) {
	savePath = outputPath + File.separator + fishPrefix + fishNumber;
	
	if (!File.exists(savePath)) {
		File.makeDirectory(savePath);
	}

	saveAs("Results", savePath + File.separator + "statistics_" + method_name + "_" + fishPrefix + fishNumber + "_" + 
			  toString(colorDepth) + "bit_" + toString(volSize[0]) + "x" + 
			  				  toString(volSize[1]) + "x" + 
			  				  toString(volSize[2]) + outputExt);

}

function getNeighboursIndices(currentIndex, numOfSlices, sliceNeighbours) {
	halfSliceNeighbours = floor(sliceNeighbours / 2);

	outputIndices = newArray();
	
	if (sliceNeighbours % 2 == 0) {
		sliceNeighbours -= 1;
	}

	for (i = currentIndex - halfSliceNeighbours; i <= currentIndex + halfSliceNeighbours; i++) {
		if (i >= 1 || i <= numOfSlices) {
			outputIndices = Array.concat(outputIndices, i);
		}
	}

	return outputIndices;
}


function openAndFillTableHeaders(actualName) {
		crossSectionSummaryTableName = "[" + actualName + "]";

		run("Particles8 ", "white morphology show=Particles minimum=0 maximum=9999999 overwrite redirect=None");
		headings = split(String.getResultsHeadings);
		headersStr = "\\Headings: CSIndex ";
		for (h = 3; h < headings.length; h++) {
			headersStr += "\t " + headings[h] + " ";
		}
	   
		if (!isOpen(actualName)) {
			run("New... ", "name=" + crossSectionSummaryTableName + " type=Table");
			print(crossSectionSummaryTableName, headersStr);
		}
}

function addItemToTable(tableName, item) {
	crossSectionSummaryTableName = "[" + tableName + "]";
	print(crossSectionSummaryTableName, item);
}

function createNewItem(startHeaderIndex, numResults, totalVolumeSize) {
		selectWindow("Results");
		
		headings = split(String.getResultsHeadings);

		rowItem = toString(step) + "\t";

		for (col = startHeaderIndex; col < headings.length; col++) {
			currentColumnTitle = headings[col];

			if (numResults > 0 && numResults <= 1) {
				rowItem += toString(parseFloat(getResult(currentColumnTitle, numResults - 1)) / parseFloat(totalVolumeSize));
			}
			else {
				rowItem += toString(parseFloat(getResult(currentColumnTitle, numResults)) / parseFloat(totalVolumeSize));
			}
				
			if (col > startHeaderIndex || col < headings.length - 1) {
					 rowItem += "\t";
			}
		}

		run("Clear Results");
		run("Close");
		
		return rowItem;
}

function getSliceRemoveSmallParticles() {
	run("Analyze Particles...", "  show=[Count Masks] clear");
	objectCountmaskId = getImageID();
	
	numResults = nResults;
	maxVal = 0;
	idxMaxVal = -1;
	
	for (row = 0; row < numResults; row++) {
		currVal = parseFloat(getResult("Area", row));
		
		if (maxVal < currVal) {
			maxVal = currVal;
			idxMaxVal = row + 1;
		}
	}

	run("Macro...", "code=[if (v==" + toString(idxMaxVal) + ") v=255; else v=0;]");

	return newArray(objectCountmaskId, maxVal);
}


function saveDataAsTiffStack(outputPath, method_name, fishPrefix, fishNumber, volSize, colorDepth) {
	savePath = outputPath + File.separator + fishPrefix + fishNumber;
	
	if (!File.exists(savePath)) {
		File.makeDirectory(savePath);
	} 

	saveAs("Tiff", savePath + File.separator + method_name + "_" + fishPrefix + fishNumber + "_" + 
				   toString(colorDepth) + "bit_" + toString(volSize[0]) + "x" + toString(volSize[1]) + "x" + toString(volSize[2]) + ".tif");
}


function closeAll() {
	list = getList("window.titles");
	
   	for (i = 0; i < list.length; i++) {
    	winame = list[i];
    	
    	if (winame != "Log") {
	      	selectWindow(winame);
	     	run("Close");
    	}
    } 

    while (nImages > 0) { 
    	selectImage(nImages); 
        close(); 
    } 
}

function printLogMessage(title, message) {
	getDateAndTime(year, month, week, day, hour, min, sec, msec);
    print(hour+":"+min+":"+sec+" -- " + title + ": ", message);	
}

