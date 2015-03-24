from ij import IJ, ImagePlus
from ij.process import ImageStatistics as IS 
import os
import datetime

inputPath = "D:\\Roman\\XRegio\\Segmentations_Median"
outputPath = "D:\\Roman\\XRegio\\Results"

#inputPath = "/Users/Roman/Documents/test_segmentations";
#outputPath = "/Users/Roman/Documents/test_results";

methodPrefix = "segmented_median"
fishPrefix = "fish"
fileExt = ".tif"
statisticsOutputExt = ".xls"
fishNumbers = ["223"]
#fishNumbers = ["3000"];
#fishNumbers = ["200", "202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245"];

sliceStep = 10 #in percentage
sliceNeighbours = 31 #odd number, othgerwise will be corrected by -1
collectCrossSectionStatistics = True
collectObjectCounterStatistics = False
voxelSize = [1, 1, 1]

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
		stack = imp.getImageStack() 

		if imp is None:  
			print "Could not open image from file:", currentFileName  
			continue

		stackSize = imp.getStackSize()
		stackDims = imp.getDimensions()

		volumeZBoundaries = 

		

def getStackBoundaries(imp):
	fisrtSlice, lastSlice = 0, 0
	
	for i in range(imp.getStackSize()):
		curSlice = imp.getStack().getProcessor(i + 1)
		if sum(ref.getPixels()) > 0:
			fisrtSlice = i + 1
			break

	for i in reversed(range(imp.getStackSize())):
		curSlice = imp.getStack().getProcessor(i + 1)
		if sum(ref.getPixels()) > 0:
			lastSlice = i + 1
			break
			
	return fisrtSlice, lastSlice
			
def saveStatistics():


def getNeighboursIndices():


def getMaximumAreaStack():

def printLog(title, message):
	st = datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
	print "%s - %s (%s)" % st, title, message