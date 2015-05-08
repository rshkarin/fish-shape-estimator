from ij import IJ, ImagePlus, ImageStack
from ij.io import TiffDecoder, FileSaver
from ij.plugin.frame import RoiManager
from ij.process import ImageStatistics, ByteProcessor, FloatProcessor, ShortProcessor, ImageConverter
from ij.plugin.filter import ParticleAnalyzer
import ij.plugin.filter.PlugInFilter;
from ij.measure import ResultsTable, Measurements
from java.lang import Double
from java.lang import Character
import os, sys, datetime, math, csv, codecs, cStringIO
from ij import Prefs

Prefs.blackBackground = True

#inputPath = "D:\\Roman\\XRegio\\Segmentations2"
#outputPath = "D:\\Roman\\XRegio\\Results"

#inputPath = "/Users/Roman/Documents/test_segmentations";
#outputPath = "/Users/Roman/Documents/test_results";

inputPath = "/home/rshkarin/ANKA_Work/Segmentations_Median"
outputPath = "/home/rshkarin/ANKA_Work/Results"

methodPrefix = "segmented_median"
fishPrefix = "fish"
fileExt = ".tif"
statisticsOutputExt = ".csv"
#fishNumbers = ["007"]
#fishNumbers = ["200", "202", "204"]
#fishNumbers = ["200", "202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245"];
#fishNumbers = ["202", "214", "233", "243"]
fishNumbers = ["200","202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245"];
#fishNumbers = ["200"]

sliceStep = 0.5 #in percentage
sliceNeighbours = 15 #odd number, othgerwise will be corrected by -1
collectCrossSectionStatistics = True
collectObjectCounterStatistics = False
voxelSize = [1, 1, 1]

def printLog(title, message):
	print "%s - %s (%s)" % (datetime.datetime.now(), title, message)

def getStackBoundaries(imp):
	fisrtSlice, lastSlice = 0, 0

	for i in range(imp.getStackSize()):
		if sum(imp.getImageStack().getProcessor(i + 1).convertToShort(False).getPixels()) > 0:
			fisrtSlice = i + 1
			break

	for i in reversed(range(imp.getStackSize())):
		if sum(imp.getImageStack().getProcessor(i + 1).convertToShort(False).getPixels()) > 0:
			lastSlice = i + 1
			break
			
	return fisrtSlice, lastSlice

def filterPixels(pixels, maxAreaId):
	for i in range(len(pixels)):
		pixels[i] = (0 if pixels[i] != maxAreaId else 255)

	return pixels

def getMaximumAreaStack(imp, voxelSize):
	paOptions = ParticleAnalyzer.SHOW_ROI_MASKS + ParticleAnalyzer.SHOW_PROGRESS + ParticleAnalyzer.CLEAR_WORKSHEET
	paMeasurements = Measurements.AREA + Measurements.PERIMETER
	rt = ResultsTable()

	pa = ParticleAnalyzer(paOptions, paMeasurements, rt, 0, Double.POSITIVE_INFINITY, 0.0, 1.0)
	pa.setHideOutputImage(True)

	maxAreaStack = ImageStack(imp.getWidth(), imp.getHeight())
	totalVolumeArea = 0
	totalVolumeSurface = 0

	for i in range(imp.getStackSize()):
		IJ.showProgress(i, imp.getStackSize() + 1)
		
		imp.setSliceWithoutUpdate(i + 1)
		imp.getProcessor().threshold(125)
		pa.analyze(imp)
		countMask = pa.getOutputImage()

		area = rt.getColumn(ResultsTable.AREA)
		perim = rt.getColumn(ResultsTable.PERIMETER)

		print "Slice %d" % (i + 1)
		impFiltered = None
		
		if area:
			maxPerim = max(perim)
			maxArea = max(area)
			maxAreaId = area.index(maxArea) + 1
			filteredPixels = map(lambda x: 0.0 if x != maxAreaId else 255.0, countMask.getProcessor().convertToFloat().getPixels())
			#filteredPixels = filterPixels(countMask.getProcessor().convertToFloat().getPixels(), maxAreaId)
			totalVolumeArea += maxArea / (voxelSize[0] * voxelSize[1])
			totalVolumeSurface += maxPerim / (voxelSize[0] * voxelSize[1])
			impFiltered = FloatProcessor(imp.getWidth(), imp.getHeight(), filteredPixels, None)
		else:
			impFiltered = FloatProcessor(imp.getWidth(), imp.getHeight())
		
		maxAreaStack.addSlice(impFiltered)

		rt.reset()

	IJ.showProgress(1)

	outImage = ImagePlus("max_area_stack_" + imp.getTitle(), maxAreaStack)
	ImageConverter(outImage).convertToGray8()

	return totalVolumeArea, totalVolumeSurface, outImage

def getNeighboursIndices(currentIndex, numOfSlices, sliceNeighbours):
	halfSliceNeighbours = math.floor(sliceNeighbours / 2)

	if sliceNeighbours % 2 == 0:
		sliceNeighbours -= 1

	minIdx = currentIndex - halfSliceNeighbours
	if minIdx < 1:
		minIdx = 1

	if minIdx > numOfSlices:
		minIdx = numOfSlices

	maxIdx = currentIndex + halfSliceNeighbours + 1
	if maxIdx < 1:
		maxIdx = 1

	if maxIdx > numOfSlices:
		maxIdx = numOfSlices

	return range(minIdx, maxIdx)
	#return filter(lambda x: x >= 1 and x <= numOfSlices, range(currentIndex - halfSliceNeighbours, currentIndex + halfSliceNeighbours + 1))

def collectCrossSectionStatistic(imp, lowZbound, highZbound, sliceStep, sliceNeighbours, totalVolumeArea):
	effectiveNumSlices = highZbound - lowZbound + 1
	currentSliceStep = effectiveNumSlices * (sliceStep / 100.)
	numOfSteps = int(effectiveNumSlices / currentSliceStep)

	paOptions = ParticleAnalyzer.SHOW_PROGRESS + ParticleAnalyzer.CLEAR_WORKSHEET
	paMeasurements = Measurements.AREA + Measurements.CENTROID + Measurements.CENTER_OF_MASS + Measurements.PERIMETER + Measurements.RECT + Measurements.ELLIPSE + Measurements.CIRCULARITY + Measurements.SHAPE_DESCRIPTORS + Measurements.FERET + Measurements.SKEWNESS + Measurements.KURTOSIS + Measurements.AREA_FRACTION
	rt = ResultsTable()

	pa = ParticleAnalyzer(paOptions, paMeasurements, rt, 0, Double.POSITIVE_INFINITY, 0.0, 1.0)
	pa.setHideOutputImage(True)

	statisticDict = {}

	totalVolumeArea = 1
	totalVolumeSurface = 1

	for step in range(numOfSteps + 1):
		sliceIdx = int(step * currentSliceStep + lowZbound)
		neighboursIndices = getNeighboursIndices(sliceIdx, imp.getStackSize(), sliceNeighbours)

		for localSliceIdx in neighboursIndices:
			imp.setSliceWithoutUpdate(localSliceIdx)
			imp.getProcessor().threshold(125)
			pa.analyze(imp)

		headers = [u'StepIdx']
		headers.extend(list(rt.getHeadings()))

		for header in headers:
			if header not in statisticDict:
				statisticDict[header] = []

		for header in headers:
			if header != 'StepIdx':
				colData = rt.getColumn(rt.getColumnIndex(header))

				statisticDict[header].append(float(sum(colData)) / len(colData) / totalVolumeArea if len(colData) > 0 else float(0))
			else:
				statisticDict[header].append(step)

		rt.reset()

	return headers, statisticDict

def writeStatistics(outputPath, fileName, fileExt, statDict, headers):
	if not os.path.exists(outputPath):
		os.makedirs(outputPath)

	outFile = open(os.path.join(outputPath, fileName + fileExt), 'w')
	csvWriter = csv.writer(outFile, delimiter=';')
	csvWriter.writerow(headers)

	for row in range(len(statDict[headers[0]])):
		outRow = [statDict[header][row] for header in headers]
		print outRow
		csvWriter.writerow(outRow)

	outFile.close()

def estimateShape(inputPath, outputPath, sliceStep, fishPrefix, fileExt, methodPrefix, statisticsOutputExt, fishNumbers, sliceNeighbours):
	for fishNumber in fishNumbers:
		currentPath = os.path.join(inputPath, fishPrefix + fishNumber)
		files = [f for f in os.listdir(currentPath) if os.path.isfile(os.path.join(currentPath,f)) and f.startswith(methodPrefix + "_" + fishPrefix + fishNumber) and f.endswith(fileExt)]

		currentFileName = ''
		if files:
			currentFileName = files[0]

		pathToVolume = os.path.join(currentPath, currentFileName)
		printLog("Statistical analysis started", pathToVolume)

		printLog("Opening", pathToVolume)
		imp = IJ.openImage(pathToVolume)  

		if imp is None:  
			print "Could not open image from file:", currentFileName  
			continue

		td = TiffDecoder(currentPath, currentFileName)

		stackSize = imp.getStackSize()
		stackDims = imp.getDimensions()

		stackInfo = td.getTiffInfo()
		voxelSize = [stackInfo[0].pixelWidth, stackInfo[0].pixelHeight, stackInfo[0].pixelDepth]

		printLog("Obtaining Z bounds", pathToVolume)
		lowZbound, highZbound = getStackBoundaries(imp)

		printLog("Obtaining max stack area", pathToVolume)
		totalVolumeArea, totalVolumeSurface, impMaxAreaStack = getMaximumAreaStack(imp, voxelSize)

		printLog("Collecting statistics", pathToVolume)
		headers, statisticsDict = collectCrossSectionStatistic(impMaxAreaStack, lowZbound, highZbound, sliceStep, sliceNeighbours, totalVolumeArea)

		csvOutPath = os.path.join(outputPath, fishPrefix + fishNumber)
		printLog("Write statistics", csvOutPath)
		writeStatistics(csvOutPath, "statistics_" + str(totalVolumeArea) + "_" + str(totalVolumeSurface) +"_L" + str(lowZbound) + "_H" + str(highZbound) + "_" + os.path.splitext(currentFileName)[0], statisticsOutputExt, statisticsDict, headers)

		
estimateShape(inputPath, outputPath, sliceStep, fishPrefix, fileExt, methodPrefix, statisticsOutputExt, fishNumbers, sliceNeighbours)
