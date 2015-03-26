from ij import IJ, ImagePlus, ImageStack
from ij.io import TiffDecoder, FileSaver
from ij.plugin.frame import RoiManager
from ij.process import ImageStatistics, ByteProcessor, ImageConverter
from ij.plugin.filter import ParticleAnalyzer
import ij.plugin.filter.PlugInFilter;
from ij.measure import ResultsTable, Measurements
from java.lang import Double
import os
import sys
import datetime
import math
import collections
import csv

inputPath = "D:\\Roman\\XRegio\\Segmentations2"
outputPath = "D:\\Roman\\XRegio\\Results"

#inputPath = "/Users/Roman/Documents/test_segmentations";
#outputPath = "/Users/Roman/Documents/test_results";

methodPrefix = "segmented_median"
fishPrefix = "fish"
fileExt = ".tif"
statisticsOutputExt = ".csv"
#fishNumbers = ["200"]
fishNumbers = ["3000"];
#fishNumbers = ["200", "202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245"];

sliceStep = 10 #in percentage
sliceNeighbours = 31 #odd number, othgerwise will be corrected by -1
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


def getMaximumAreaStack(imp, voxelSize):
	paOptions = ParticleAnalyzer.SHOW_ROI_MASKS + ParticleAnalyzer.SHOW_PROGRESS + ParticleAnalyzer.CLEAR_WORKSHEET
	paMeasurements = Measurements.AREA
	rt = ResultsTable()

	pa = ParticleAnalyzer(paOptions, paMeasurements, rt, 0, Double.POSITIVE_INFINITY, 0.0, 1.0)
	pa.setHideOutputImage(True)

	maxAreaStack = ImageStack(imp.getWidth(), imp.getHeight())
	totalVolumeArea = 0

	for i in range(imp.getStackSize()):
		IJ.showProgress(i, imp.getStackSize() + 1)
		
		imp.setSliceWithoutUpdate(i + 1)
		pa.analyze(imp)
		countMask = pa.getOutputImage()

		area = rt.getColumn(ResultsTable.AREA)
		if area:
			maxArea = max(area)
			maxAreaId = area.index(maxArea) + 1
			filteredPixels = map(lambda x: 0 if x != maxAreaId else x, countMask.getProcessor().getPixels())
			impFiltered = ByteProcessor(imp.getWidth(), imp.getHeight(), filteredPixels)
			maxAreaStack.addSlice(impFiltered)
			totalVolumeArea += maxArea / (voxelSize[0] * voxelSize[1])

		rt.reset()

	IJ.showProgress(1)

	return totalVolumeArea, ImagePlus("max_area_stack_" + imp.getTitle(), maxAreaStack)

def getNeighboursIndices(currentIndex, numOfSlices, sliceNeighbours):
	halfSliceNeighbours = math.floor(sliceNeighbours / 2);

	if sliceNeighbours % 2 == 0:
		sliceNeighbours -= 1

	return filter(lambda x: x >= 1 and x <= numOfSlices, range(currentIndex - halfSliceNeighbours, currentIndex + halfSliceNeighbours + 1))

def collectCrossSectionStatistic(imp, lowZbound, highZbound, sliceStep, sliceNeighbours):
	effectiveNumSlices = highZbound - lowZbound + 1
	currentSliceStep = effectiveNumSlices * (sliceStep / 100.)
	numOfSteps = int(effectiveNumSlices / currentSliceStep)

	paOptions = ParticleAnalyzer.SHOW_PROGRESS + ParticleAnalyzer.CLEAR_WORKSHEET
	paMeasurements = Measurements.AREA + Measurements.CENTROID + Measurements.CENTER_OF_MASS + Measurements.PERIMETER + Measurements.RECT + Measurements.ELLIPSE + Measurements.CIRCULARITY + Measurements.SHAPE_DESCRIPTORS + Measurements.FERET + Measurements.SKEWNESS + Measurements.KURTOSIS + Measurements.AREA_FRACTION
	rt = ResultsTable()

	pa = ParticleAnalyzer(paOptions, paMeasurements, rt, 0, Double.POSITIVE_INFINITY, 0.0, 1.0)
	pa.setHideOutputImage(True)

	statisticDict = {}

	for step in range(numOfSteps + 1):
		sliceIdx = step * currentSliceStep + lowZbound
		neighboursIndices = getNeighboursIndices(sliceIdx, imp.getStackSize(), sliceNeighbours)

		for localSliceIdx in neighboursIndices:
			imp.setSliceWithoutUpdate(localSliceIdx)
			pa.analyze(imp)

		#if not len(statisticDict.keys()):
		#	statisticDict = collections.defaultdict(list(rt.getHeadings()))
		for header in list(rt.getHeadings()):
			if header not in statisticDict:
				statisticDict[header] = []

		for header in list(rt.getHeadings()):
			colData = rt.getColumn(rt.getColumnIndex(header))
			statisticDict[header].append(float(sum(colData)) / len(colData) if len(colData) > 0 else float(0))
			
		rt.reset()

	return statisticDict

def writeStatistics(outputPath, fileName, fileExt, statDict):
	with open(os.path.join(outputPath, fileName + fileExt),'w') as fout:
	writer = csv.writer(fout)
	writer.writerows([statDict.keys()])
	
	for row in zip(*statDict.values()):
		row = [s.encode('utf-8') for s in row]
		writer.writerows([row])

def estimateShape(inputPath, outputPath, sliceStep, fishPrefix, fileExt, methodPrefix, statisticsOutputExt, fishNumbers, sliceNeighbours):
	for fishNumber in fishNumbers:
		currentPath = os.path.join(inputPath, fishPrefix + fishNumber)
		files = [f for f in os.listdir(currentPath) if os.path.isfile(os.path.join(currentPath,f)) and f.startswith(methodPrefix + "_" + fishPrefix + fishNumber) and f.endswith(fileExt)]

		currentFileName = ''
		if files:
			currentFileName = files[0]

		pathToVolume = os.path.join(currentPath, currentFileName)
		printLog("Statistical analysis started", pathToVolume)

		print 'Opening: ' + currentFileName
		imp = IJ.openImage(pathToVolume)  

		if imp is None:  
			print "Could not open image from file:", currentFileName  
			continue

		td = TiffDecoder(currentPath, currentFileName)

		stackSize = imp.getStackSize()
		stackDims = imp.getDimensions()

		stackInfo = td.getTiffInfo()
		voxelSize = [stackInfo[0].pixelWidth, stackInfo[0].pixelHeight, stackInfo[0].pixelDepth]

		lowZbound, highZbound = getStackBoundaries(imp)

		print "%d %d" % (lowZbound, highZbound) 

		
		#totalVolumeArea, impMaxAreaStack = getMaximumAreaStack(imp, voxelSize)
		#print "totalVolumeArea = %d" % totalVolumeArea
		
		
		statisticsDict = collectCrossSectionStatistic(imp, lowZbound, highZbound, sliceStep, sliceNeighbours)

		writeStatistics(outputPath, fishPrefix + fishNumber, statisticsOutputExt, statisticsDict)

		
		#fs = FileSaver(impMaxAreaStack)
		#fs.saveAsTiffStack(os.path.join(outputPath, "max_area_stack_" + currentFileName))
		

		
estimateShape(inputPath, outputPath, sliceStep, fishPrefix, fileExt, methodPrefix, statisticsOutputExt, fishNumbers, sliceNeighbours)