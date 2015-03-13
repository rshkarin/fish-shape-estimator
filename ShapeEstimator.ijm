// Shape esimator
// Roman Shkarin

macro "Estimate shape of fishes" {
	requires("1.49h")
	
	var inputPath = "D:\\Roman\\XRegio\\Segmentations";
	var outputPath = "D:\\Roman\\XRegio\\Results";

	var methodPrefix = "segmented";
	var fishPrefix = "fish";
	var fileExt = ".tif";
	var fishNumbers = newArray("202");

	var sliceStep = 10; //in percentage
	var runObjectCounter = true;
	
	//setBatchMode(true);
	process(inputPath, outputPath, sliceStep, fishPrefix, fileExt, fishNumbers);
	//setBatchMode(false);
}

function process(inputPath, outputPath, sliceStep, fishPrefix, fileExt, fishNumbers) {
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
		imageDepth = bitDepth();

/*
		//Histo bins
		numBins = pow(2, imageDepth);

		//Get border slices
		volumeZBoundaries = getMinMaxBorderValueToArray(stackSlices, stackId, numBins);

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

		if (runObjectCounter) {
			//Estimate shape parameters with 3D Object Counter
			run("3D OC Options", "volume surface nb_of_obj._voxels nb_of_surf._voxels integrated_density mean_gray_value std_dev_gray_value median_gray_value minimum_gray_value maximum_gray_value centroid mean_distance_to_surface std_dev_distance_to_surface median_distance_to_surface centre_of_mass bounding_box dots_size=5 font_size=10 store_results_within_a_table_named_after_the_image_(macro_friendly) redirect_to=none");
			run("3D Objects Counter", "threshold=25 slice=928 min.=1000 max.=376042500 objects surfaces centroids centres_of_masses statistics summary");
			/////SAVE
		}

		//Estimate crossections with specified step
		effectiveNumSlices = volumeZBoundaries[1] - volumeZBoundaries[0];
		currentSliceStep = floor(effectiveNumSlices * (sliceStep / 100));
		numOfSteps = floor(effectiveNumSlices / currentSliceStep);

		//Estimate shape parameters of each step-slice
		for (step = 0; step < numOfSteps; step++) {
			sliceIdx = volumeZBoundaries[0] + step * currentSliceStep;
		 	setSlice(sliceIdx);
			//ESTIMATE!
		}
*/
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
