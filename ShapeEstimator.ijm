// Shape esimator
// Roman Shkarin

macro "Estimate shape of fishes" {
	requires("1.49h")
	
	//var inputPath = "D:\\Roman\\XRegio\\Segmentations";
	//var outputPath = "D:\\Roman\\XRegio\\Results";
	var inputPath = "/Users/Roman/Documents/test_segmentations";
	var outputPath = "/Users/Roman/Documents/test_results";

	var methodPrefix = "segmented";
	var fishPrefix = "fish";
	var fileExt = ".tif";
	var statisticsOutputExt = ".xls";
	var fishNumbers = newArray("200");

	var sliceStep = 10; //in percentage
	var sliceNeighbours = 7; //odd number, othgerwise will be corrected by -1
	var runObjectCounter = true;
	
	//setBatchMode(true);
	process(inputPath, outputPath, sliceStep, fishPrefix, fileExt, statisticsOutputExt, fishNumbers, sliceNeighbours);
	//setBatchMode(false);
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

		//Histo bins
		numBins = pow(2, colorDepth);

		//Get border slices
		volumeZBoundaries = getMinMaxBorderValueToArray(stackSlices, stackId, numBins);
		Array.print(volumeZBoundaries);

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
		scaledVolDepth = nSlices;
		
		scaledVolSize = newArray(scaledVolWidth, scaledVolHeight, scaledVolDepth);
		
		if (runObjectCounter) {
			//Estimate shape parameters with 3D Object Counter
			//run("3D OC Options", "volume surface nb_of_obj._voxels nb_of_surf._voxels integrated_density mean_gray_value std_dev_gray_value median_gray_value minimum_gray_value maximum_gray_value centroid mean_distance_to_surface std_dev_distance_to_surface median_distance_to_surface centre_of_mass bounding_box dots_size=5 font_size=10 store_results_within_a_table_named_after_the_image_(macro_friendly) redirect_to=none");
			//run("3D Objects Counter", "threshold=25 slice=928 min.=10 max.=376042500 statistics summary");
			//saveStatistics(outputPath, fishPrefix, fishNumbers[i], scaledVolSize, colorDepth, fishPrefix, statisticsOutputExt);
		}

		//Estimate crossections with specified step
		effectiveNumSlices = volumeZBoundaries[1] - volumeZBoundaries[0] + 1;
		currentSliceStep = floor(effectiveNumSlices * (sliceStep / 100));
		numOfSteps = floor(effectiveNumSlices / currentSliceStep);

		//print("effectiveNumSlices=" + toString(effectiveNumSlices));
		//print("currentSliceStep=" + toString(currentSliceStep));
		//print("numOfSteps=" + toString(numOfSteps));

		newImage("averaged_" + currentFileNameNoExt, toString(colorDepth) + "-bit grayscale-mode", stackWidth, stackHeight, 1, numOfSteps + 1, 1);
		newStackId = getImageID();

		outputCrossectionStatisticResults = "cross_section_statistic_" + currentFileNameNoExt + "_" + toString(stackWidth) + "x" + toString(stackHeight) + "x" + toString(stackSlices);
		run("Table...", "name=" + outputCrossectionStatisticResults);
		outputStatisticId = getImageID();

		//Estimate shape parameters of each step-slice
		for (step = 0; step <= numOfSteps; step++) {
			sliceIdx = step * currentSliceStep + volumeZBoundaries[0];
			neighboursIndices = getNeighboursIndices(sliceIdx, stackSlices, sliceNeighbours);

			selectImage(stackId);
			
			run("Duplicate...", "duplicate range=" + toString(neighboursIndices[0]) + "-" + toString(neighboursIndices[neighboursIndices.length - 1]));
			dupStackId = getImageID();
			run("Particles8 ", "white morphology show=Particles minimum=0 maximum=9999999 redirect=None");
			//run("Summarize");
			interStatisticId = getImageID();
			averageResults(interStatisticId, outputStatisticId, step);

			selectImage(interStatisticId);
			IJ.deleteRows(0, neighboursIndices.length - 1);

			selectImage(dupStackId);
			close();
			
/*
			selectImage(stackId);
			setSlice(sliceIdx);
			
			run("Select All");
			run("Copy");
			
			selectImage(newStackId);
			setSlice(step + 1);
			run("Paste");
			*/
		}

		selectImage(outputStatisticId);
		saveStatistics("coross_sections", outputPath, fishPrefix, fishNumbers[i], volSize, colorDepth, fishPrefix, statisticsOutputExt);
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

function saveStatistics(method_name, outputPath, fishPrefix, fishNumber, scaledVolSize, colorDepth, fishPrefix, outputExt) {
	savePath = outputPath + File.separator + fishPrefix + fishNumber;
	
	if (!File.exists(savePath)) {
		File.makeDirectory(savePath);
	}

	saveAs("Results", outputPath + File.separator + "statistics_ " + method_name + "_" + fishPrefix + fishNumber + "_" + 
			  toString(colorDepth) + "bit_" + toString(scaledVolSize[0]) + "x" + 
			  				  toString(scaledVolSize[1]) + "x" + 
			  				  toString(scaledVolSize[2]));
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

function averageResults(interStatisticId, outputStatisticId, rowIndex) {
	selectImage(interStatisticId);

	sum_val = 0;
	headings = split(String.getResultsHeadings);

	for (col = 0; col < headings.length; col++) {
		selectImage(interStatisticId);

		currentColumnTitle = headings[col];

		for (row = 0; row < nResults; row++) {
			sum_val += parseFloat(getResult(currentColumnTitle, row));
		}

		sum_val /= nResults;
		
		selectImage(outputStatisticId);

		setResult(currentColumnTitle, rowIndex, sum_val);
	}
}
