// Macro to organize calibration curve

/*function listImageFiles(dir) {  //rewrote this iteratively because the recursion doesnt seem to work well
	//Finds paths for all images in folder with calibration curve images. No need to take images out of subfolders!
   allFilesList = getFileList(dir);
   finalList = newArray();
   dirList = newArray();
   for (i=0; i<allFilesList.length; i++) {
      if (endsWith(allFilesList[i], "/")) { //check if file is a directory
        listImageFiles(""+dir+allFilesList[i]);
      }
      else {
         if (endsWith(allFilesList[i], ".tif")) {
         	if (allFilesList[i] == "UnevenIllumination.tif") {
         		fullFilePath = dir + allFilesList[i];
         		finalList = Array.concat(fullFilePath,finalList); //Puts uneven illumination image first
         	}
         	else {
         		fullFilePath = dir + allFilesList[i];
         		finalList = Array.concat(finalList,fullFilePath);
         	}
         }
      }
   }
   /*for(i=0;i<finalList.length;i++) {
   		print(finalList[i]);
   }
   print(finalList.length);
   return finalList;
}
*/

Dialog.create("Calibration curve settings")
Dialog.addMessage("Choose the parts of the calibration curve program you want to run. \nAfter you click OK, select the folder containing your calibration curve images.");
Dialog.addCheckbox("Split stacks, correct background noise and uneven illumination", true);
Dialog.addNumber("Number of Z-slices to sum (0=all)",0);
//Dialog.addCheckbox("Use separate background image",useExternalBackground);
Dialog.addCheckbox("Segment images with MAARS", true);
Dialog.addCheckbox("Sum fluorescence and plot curve",true); 
Dialog.addCheckbox("Find total fluorescence for additional images",false);
//Dialog.addCheckbox("Correct photobleaching", false);
Dialog.addString("Filename path separating character","/"); //may depend on operating system
Dialog.addString("Wild type name","FY528");
Dialog.addRadioButtonGroup("Error type",newArray("StDev","StErr"),1,2,"StDev");
Dialog.addRadioButtonGroup("Calibration image type",newArray("16-bit","32-bit"),1,2,"32-bit");
Dialog.addRadioButtonGroup("Target image type",newArray("16-bit","32-bit"),1,2,"32-bit");
Dialog.addNumber("Calibration curve exposure time (ms)",100);
Dialog.addNumber("Target exposure time (ms)",1000);
Dialog.show();
correctNoiseUneven = Dialog.getCheckbox;
//useExternalBackground = Dialog.getCheckbox; //has to be left in to optimize code
segmentImages = Dialog.getCheckbox;
plotCurve = Dialog.getCheckbox;
zSlicesToSum = Dialog.getNumber;
extraImages = Dialog.getCheckbox;
//correctPhotobleaching = Dialog.getCheckbox;
//operatingSystem = Dialog.getRadioButton;
slashType = Dialog.getString;
wtName = Dialog.getString;
stErrButton = Dialog.getRadioButton;
calibrationImageType = Dialog.getRadioButton;
targetImageType = Dialog.getRadioButton;
calibrationExposureTimeMs = Dialog.getNumber;
targetExposureTimeMs = Dialog.getNumber;

bitConversionConstant = 6.554; // 214,747.3647/32,767: the ratio between 32 bit max and 16 bit max

exposureConstant = targetExposureTimeMs/calibrationExposureTimeMs;
bitDepthConstant = 1;
if(calibrationImageType == "32-bit") {
	if(targetImageType == "16-bit") {
		bitDepthConstant = 1/bitConversionConstant;
	}
}
else {
	if(targetImageType == "32-bit") {
		bitDepthConstant = bitConversionConstant;
	}
}
differenceConstant = exposureConstant*bitDepthConstant;


//Checking whether to use StDev or StErr
if(stErrButton == "StDev") {
	useStErr = false;
}
else {
	useStErr = true;
}

imageDir = getDirectory("Select folder containing calibration curve images");
MAARSDir = imageDir + slashType + "MAARS Images" + slashType;
CurveDir = imageDir + slashType + "Curve Images" + slashType;
//Loading images
allFolders = getFileList(imageDir);
allImagePaths = newArray();
unevenPath = "NA"; //placeholder; if not changed, throws an error
backgroundPath = "NA";
for(i=0;i<allFolders.length;i++) {
	folderPath = imageDir + allFolders[i];
	if (endsWith(allFolders[i], slashType)) {
		if(allFolders[i] != "Curve Images" + slashType && allFolders[i] != "MAARS Images" + slashType) {
			allFilesInFolder = getFileList(folderPath);
			for(j=0;j<allFilesInFolder.length;j++) {
				if(endsWith(allFilesInFolder[j],".tif")) {
					fullFilePath = folderPath + allFilesInFolder[j];
					allImagePaths = Array.concat(allImagePaths,fullFilePath);
				}
			}
		}
	}
	else {
		if(allFolders[i]=="UnevenIllumination.tif") {
			unevenPath = folderPath;
		}
		else if(allFolders[i]=="CameraNoise.tif") {
			backgroundPath = folderPath;
		}
		else { //it's not a folder, it's an image
			fullFilePath = folderPath;
			allImagePaths = Array.concat(allImagePaths,fullFilePath);
		}
	}
}

// Separating image stacks into the three channels, correcting uneven illumination and noise, etc.

if(correctNoiseUneven) {
	print("Correcting noise and uneven illumination...");
	if(unevenPath == "NA") { //Creates uneven illumination image
		Dialog.create("Attention");
		Dialog.addMessage("Press OK and then select uneven illumination image");
		Dialog.show;
		rawUnevenPath=File.openDialog("Select uneven illumination image");
		open(rawUnevenPath);
		unevenID = getImageID;
		if(nSlices>1) {
			run("Z Project...","projection=[Average Intensity]");
		}
		unevenID = getImageID;
		if(backgroundPath == "NA") { //Creates background noise image
			Dialog.create("Attention");
			Dialog.addMessage("Press OK and then select camera noise image");
			Dialog.show;
			rawBackgroundPath=File.openDialog("Select camera noise image image");
			open(rawBackgroundPath);
			backgroundID = getImageID;
			if(nSlices>1) {
				run("Z Project...", "projection=[Average Intensity]");
			}
			backgroundID = getImageID;
			backgroundPath = imageDir + "CameraNoise.tif";
			saveAs("Tiff",backgroundPath);
		}
		else {
			open(backgroundPath);
			backgroundID = getImageID;
		}
		imageCalculator("Subtract create 32-bit", unevenID, backgroundID); //if you don't make it 32 bit, the division wont work later
		run("Set Measurements...", "min redirect=None decimal=5");
		run("Select All");
		List.clear();
		List.setMeasurements;
		unevenMax = List.getValue("Max");
		run("Divide...","value=unevenMax");
		unevenPath = imageDir + "UnevenIllumination.tif";
		saveAs("Tiff",unevenPath);
		run("Close All");
	}

	//Creating folders to save modified images
	File.makeDirectory(MAARSDir);
	File.makeDirectory(CurveDir);
	//Loading, correcting and saving images
	for(ii = 0; ii < allImagePaths.length; ii++) {
		unevenName = File.getName(unevenPath);
		open(unevenPath); //opens it every time so I can just close all images with close all
		filePath = allImagePaths[ii];
		open(filePath);
		fileName = File.getName(filePath);
		print("Correcting ",fileName);
		//run("Stack to Hyperstack...", "order=xyzct channels=3 slices=["+zSlices+"] frames=["+numFrames+"] display=Color");
		getDimensions(width,height,numChannels,zSlices,numFrames); //gets dimensions of current image
		
		if(numChannels > 1) {
			run("Split Channels");
			CurveID = getImageID; //this one is chosen because the curve is the third channel, so it opens last.
			MAARSID = CurveID + 1; //plus because it's a negative number
			selectImage(MAARSID);
			MAARSSaveFilePath = MAARSDir + "MAARS_" + fileName;
			saveAs("Tiff",MAARSSaveFilePath);
			
			if(numChannels==2) { //Curve and MAARS but no background
				//Creating background image if it's missing
				if(backgroundPath=="NA") { 
					Dialog.create("Attention");
					Dialog.addMessage("Press OK and then select camera noise image");
					Dialog.show;
					rawBackgroundPath=File.openDialog("Select camera noise image");
					open(rawBackgroundPath);
					backgroundID = getImageID;
					if(nSlices>1) {
						run("Z Project...", "projection=[Average Intensity]");
					}
					backgroundID = getImageID;
					backgroundPath = imageDir + "CameraNoise.tif";
					saveAs("Tiff",backgroundPath);
					run("Close All");		
				}

				//Opening background image and multiplying it to subtract from the curve
				open(backgroundPath);
				run("Multiply...","value=zSlices"); //multiplies background by number of z-slices. May vary by image, that's fine
				sumBackgroundID = getImageID;

			}
			else { //numChannels == 3 
				backgroundID = CurveID + 2;
				selectImage(backgroundID);
				run("Z Project...", "projection=[Sum Slices]");
				sumBackgroundID = getImageID;
			}
		}
		else { //no MAARS segmentation or background

			//Creating background image if it's missing
			if(backgroundPath=="NA") { 
				if(operatingSystem == "Mac") {
					Dialog.create("Attention");
					Dialog.addMessage("Press OK and then select camera noise image");
					Dialog.show;
				}
				rawBackgroundPath=File.openDialog("Select camera noise image");
				open(rawBackgroundPath);
				backgroundID = getImageID;
				if(nSlices>1) {
					run("Z Project...", "projection=[Average Intensity]");
				}
				backgroundID = getImageID;
				backgroundPath = imageDir + "CameraNoise.tif";
				saveAs("Tiff",backgroundPath);
				run("Close All");		
			}
				
			//Opening background image and multiplying it to subtract from the curve
			open(backgroundPath);
			run("Multiply...","value=zSlices"); //multiplies background by number of z-slices. May vary by image, that's fine
			sumBackgroundID = getImageID;
		}

		//Curve image processing (always happens)
		extraSlices = 0;
		if(zSlicesToSum>0) {
			extraSlices = zSlices-zSlicesToSum;
		}
		startSlice = floor(extraSlices/2);
		endSlice = round(zSlices-extraSlices/2);
		selectImage(CurveID);
		String.resetBuffer;
		String.append("start=");
		String.append(startSlice);
		String.append(" stop=");
		String.append(endSlice);
		String.append(" projection=[Sum Slices]");
		zProjectString = String.buffer;
		run("Z Project...",zProjectString);
		sumCurveID = getImageID;
		imageCalculator("Subtract create 32-bit", sumCurveID, sumBackgroundID);
		CurveBackgroundCorrectedID = getImageID;
		imageCalculator("Divide create 32-bit", CurveBackgroundCorrectedID,unevenName);
		CurveFullyCorrectedID = getImageID;
		CurveSaveFilePath = CurveDir + fileName;
		saveAs("Tiff",CurveSaveFilePath);

		run("Close All");
	}
}

//Performing image segmentations and saving them on the calibration curve file
if(segmentImages) {
	print("Segmenting images...");
	curveFiles = getFileList(CurveDir); //note that I will rely on the MAARS files having the same name
	run("Close All");
	if(roiManager("count")>0) {
		roiManager("deselect");
		roiManager("delete"); //clears all ROIs
	}
	overWriteSegmentation = false; //0: unknown 1: yes 2: no
	overWriteAsked = false;
	for(ii=0;ii<curveFiles.length;ii++) {
		
		curvePath = CurveDir + curveFiles[ii];
		open(curvePath);

		//Check if image has already been segmented
		segmentImage = true;
		if(Overlay.size>0) {
			if(overWriteAsked==false) {
				overWriteSegmentation = getBoolean("Clear and redo all existing segmentations?");
				overWriteAsked = true;
			}
			if(overWriteSegmentation==false) {
				segmentImage=false;
			}
			else {
				Overlay.clear; //clears existing overlay for replacement
			}
		}

		//Segment image
		if(segmentImage) {	
			print("Segmenting ",curveFiles[ii]);
			curvePath = CurveDir + curveFiles[ii];
			MAARSPath = MAARSDir + "MAARS_" + curveFiles[ii];
			print(MAARSPath);
			open(MAARSPath);
			run("SegmentPombe");
			notDone = true;
			while(notDone) {
				if(roiManager("count") > 0) {
					notDone = false;
				}
				wait(250); //checks every 0.25 seconds to see if the user has completed segmentation
			}
			run("Close All");
			open(curvePath);	
			run("From ROI Manager");
			saveAs("Tiff",curvePath);
			run("Close All");
			//winList = getList("window.titles"); //closing ALL non-image windows, including the ROI manager, which it clears
			//print(winList[0]);
			//for(i=0;i<winList.length;i++) {
			//	selectWindow(winList[i]);
			//	run("Close");
			//}
			//print('Im here');
			roiManager("delete"); //clears all ROIs
		}
		else {
			run("Close"); //close image, don't segment it
		}
		//roiManager("deselect");
		//roiManager("delete"); //clears all ROIs
	}
}

//Finding and plotting brightnesses
if(plotCurve) {

	//Clearing results window
	run("Clear Results");
	
	curveFiles = getFileList(CurveDir); //note that I will rely on the MAARS files having the same name but with MAARS added
	run("Set Measurements...", "area mean integrated redirect=None decimal=5");
	run("Close All");	
	print("Measuring WT brightness...");
	//Finding wild-type images and measuring wild-type brightness
	wtMeanBrightnesses = newArray();
	wtAreas = newArray();
	wtTotalBrightnesses = newArray();
	wtnumCells = 0;
	for(ii=0;ii<curveFiles.length;ii++) {
		if(indexOf(curveFiles[ii],wtName) > -1) {
			curvePath = CurveDir + curveFiles[ii];
			open(curvePath);
			run("To ROI Manager");
			wtnumCells = wtnumCells + roiManager("count");	
			run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); //done because I want everything in pixels
			for(i=0;i<roiManager("count");i++) {
				roiManager("select",i);
				List.clear();
				List.setMeasurements;
				wtMeanBrightnesses = Array.concat(wtMeanBrightnesses,List.getValue("Mean"));
				wtAreas = Array.concat(wtAreas,List.getValue("Area"));
				wtTotalBrightnesses = Array.concat(wtTotalBrightnesses,List.getValue("RawIntDen"));
			}
			run("Close All");
			/*
			winList = getList("window.titles"); //closing ALL non-image windows, including the ROI manager, which it clears
			for(i=0;i<winList.length;i++) {
				selectWindow(winList[i]);
				run("Close");
			}
			*/
			//roiManager("deselect");
			//roiManager("delete"); //clears all ROIs
		}
	}
	if(wtMeanBrightnesses.length == 0) {
		exit("Wild type image not found");
	}
	//wtBrightness = wtBrightness/wtArea;
	//wtCellArea = wtArea/wtnumCells;
	run("Close All");
	/*winList = getList("window.titles"); //closing ALL non-image windows, including the ROI manager, which it clears
	for(i=0;i<winList.length;i++) {
		selectWindow(winList[i]);
		run("Close");
	}*/
	Array.getStatistics(wtMeanBrightnesses,min,max,wtBrightness,wtStDev);
	Array.getStatistics(wtAreas,min,max,wtArea,wtAreaStDev);
	Array.getStatistics(wtTotalBrightnesses,min,max,wtTotalBrightness,wtTotalStDev);
	//Multiplying mean brightness by area to get integrated density, with error propagation
	wtStErr = wtStDev/sqrt(wtnumCells);
	wtAreaStErr = wtAreaStDev/sqrt(wtnumCells);
	if(useStErr) {
		wtTotalBrightness = wtBrightness*wtArea;
		wtTotalStErr = wtTotalBrightness*sqrt(pow(wtStErr/wtBrightness,2) + pow(wtAreaStErr/wtArea,2)); //error propagation for multiplication
		print("WT brightness per cell: " + wtTotalBrightness + " +/- " + wtTotalStErr);
	}
	else {
		print("WT brightness per cell: " + wtTotalBrightness + " +/- " + wtTotalStDev);
	}
	setResult("Strain", 0,"WT"); // +1 is to account for wild-type
	setResult("Intensity",0, wtTotalBrightness); 
	setResult("Stdev",0, wtTotalStDev); 
	if(useStErr) {
		setResult("Sterr",0, wtTotalStErr); 
	}
	setResult("# cells",0,wtnumCells);
	
	//Measuring other strains

	possibleStrains = newArray("Ain1","Myo2","Acp2","ArpC5","Arp2","Arp3","Fim1");
	numberOfMolecules = newArray(3600,7300,19200,30500,46600,66700,86500); //Source: Wu and Pollard, 2005
	numberOfMoleculesErr = newArray(500,1400,2600,2300,5700,7300,9100); //Source: Wu and Pollard, 2005
	brightArray = newArray(0,0,0,0,0,0,0);
	stDevArray = newArray(0,0,0,0,0,0,0);
	stErrArray = newArray(0,0,0,0,0,0,0);
	for(strain=0;strain<possibleStrains.length;strain++) {
		strainAreas = newArray();
		strainMeanBrightnesses = newArray();
		strainTotalBrightnesses = newArray();
		strainNumCells = 0;
		print("Measuring " + possibleStrains[strain] + " brightness...");
		for(ii=0;ii<curveFiles.length;ii++) {
			if(indexOf(curveFiles[ii],possibleStrains[strain]) > -1) {
				curvePath = CurveDir + curveFiles[ii];
				open(curvePath);
				run("To ROI Manager");
				strainNumCells = strainNumCells + roiManager("count");	
				run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); //done because I want everything in pixels
				for(i=0;i<roiManager("count");i++) {
					roiManager("select",i);
					//showMessageWithCancel("Right image?");
					List.clear();
					List.setMeasurements;
					strainAreas = Array.concat(strainAreas,List.getValue("Area"));
					strainMeanBrightnesses = Array.concat(strainMeanBrightnesses,List.getValue("Mean"));
					strainTotalBrightnesses = Array.concat(strainTotalBrightnesses,List.getValue("RawIntDen"));
				}
				run("Close All");
				/*
				winList = getList("window.titles"); //closing ALL non-image windows, including the ROI manager, which it clears
				for(i=0;i<winList.length;i++) {
					selectWindow(winList[i]);
					run("Close");
				}
				*/
				//roiManager("deselect");
				//roiManager("delete"); //clears all ROIs
			}
		}
		Array.getStatistics(strainMeanBrightnesses,min,max,strainBrightness,strainStDev);
		Array.getStatistics(strainAreas,min,max,strainArea,strainAreaStDev);
		Array.getStatistics(strainTotalBrightnesses,min,max,strainTotalBrightness,strainTotalStDev);
		
		//Multiplying mean brightness by area to get integrated density, with error propagation
		if(useStErr) {
			strainStErr = strainStDev/sqrt(strainNumCells);
			strainAreaStErr = strainAreaStDev/sqrt(strainNumCells);
			strainTotalBrightness = strainBrightness*strainArea;
			strainTotalStDev = strainStDev*strainArea; //no error prop. because this is not error - it's standard deviation
			strainTotalStErr = strainTotalBrightness*sqrt(pow(strainStErr/strainBrightness,2) + pow(strainAreaStErr/strainArea,2));//error propagation for multiplication
		}
		
		//Subtracting wild-type, with error propagation
		strainTotalBrightness = strainTotalBrightness - wtTotalBrightness;
		brightArray[strain] = strainTotalBrightness;

		if(useStErr) {
			strainTotalStErr = strainTotalStErr + wtTotalStErr;
			stErrArray[strain] = strainTotalStErr;
			print(possibleStrains[strain] + " brightness per cell: " + strainTotalBrightness + " +/- " + strainTotalStErr);
		}
		else {
			stDevArray[strain] = strainTotalStDev;
			print(possibleStrains[strain] + " brightness per cell: " + strainTotalBrightness + " +/- " + strainTotalStDev);
		}

		//Creating and saving results table (Thanks Matt!)
		setResult("Strain", strain+1, possibleStrains[strain]); // +1 is to account for wild-type
		setResult("Intensity", strain+1, strainTotalBrightness); 
		setResult("Stdev", strain+1, strainTotalStDev); 
		if(useStErr) {
			setResult("Sterr", strain+1, strainTotalStErr); 
		}
		setResult("# cells",strain+1,strainNumCells);
		
		//showMessageWithCancel(brightArray[strain]);
		
		run("Close All");
	}
	saveAs("Results",  imageDir+"Calibration_intensities.txt"); 

	//Accounting for differences in bit depth and exposure time

	for(ii=0;ii<brightArray.length;ii++) {
		brightArray[ii] = brightArray[ii]*differenceConstant;
		stErrArray[ii] = stErrArray[ii]*differenceConstant;
		stDevArray[ii] = stDevArray[ii]*differenceConstant;
	}
	
	//Plotting the curve
	xArray = newArray();
	yArray = newArray();
	errorBars = newArray();
	xerrorBars = newArray();
	for(i=0;i<brightArray.length;i++) {
		if(brightArray[i] > 0) {
			xArray = Array.concat(xArray,numberOfMolecules[i]);
			yArray = Array.concat(yArray,brightArray[i]);
			if(useStErr) {
				errorBars = Array.concat(errorBars,stErrArray[i]);
			}
			else {
				errorBars = Array.concat(errorBars,stDevArray[i]);
			}
			xerrorBars = Array.concat(xerrorBars,numberOfMoleculesErr[i]);
		}
	}
	Fit.doFit("y=a*x",xArray,yArray);
	//Fit.plot();
	xMax = xArray[xArray.length-1];
	yMax = yArray[yArray.length-1];
	fitX = newArray(0,xMax*1.1);
	fitY = newArray(0,Fit.f(xMax*1.1)); //I can get away with this because I forced the fit through the origin
	Plot.create("Calibration curve","Number of molecules","Total fluorescence (AU)");
	Plot.setColor("red");
	Plot.add("circles",xArray,yArray);
	Plot.add("error bars",errorBars);
	Plot.add("xerror bars",xerrorBars);
	Plot.setColor("blue");
	Plot.add("line",fitX,fitY);
	Plot.setFontSize(20);
	curveSlope = Fit.p(0);
	Plot.addText("Best fit: y = " + curveSlope + "*x",0.05,0.2);
		
	//Plot.setXYLabels("Number of molecules","Cell integrated density (AU)");
	Plot.setLimits(0,1.1*xMax,0,1.1*yMax); //sets limits to 1.1 times max values
	Plot.show();
	Plot.makeHighResolution("",4.0);
	graphPath = imageDir + "CalibrationCurveFinal.tif";
	saveAs("Tiff",graphPath);
}

//Finding total fluorescence in extra images
if(extraImages) {
	
	//Clearing results window to clear any existing results
	run("Clear Results");
	resultRowNumber = 0;
	
	Dialog.create("Enter any custom strain names")
	Dialog.addString("Strain 1","N/A");
	Dialog.addString("Strain 2","N/A");
	Dialog.addString("Strain 3","N/A");
	Dialog.addString("Strain 4","N/A");
	Dialog.show();

	strain1 = Dialog.getString();
	strain2 = Dialog.getString();
	strain3 = Dialog.getString();
	strain4 = Dialog.getString();
	possibleStrains = newArray(strain1,strain2,strain3,strain4);
	curveFiles = getFileList(CurveDir);
	if(plotCurve==false) { //If they haven't plotted the curve, then they will have to enter the slope manually
		Dialog.create("Enter calibration curve slope")
		Dialog.addNumber("Calibration curve slope", 1);
		Dialog.show();
		curveSlope = Dialog.getNumber;

		
		//obtaining wild-type brightness if it exists
		wtMeanBrightnesses = newArray();
		wtAreas = newArray();
		wtnumCells = 0;
		run("Set Measurements...", "area mean integrated redirect=None decimal=5");
		for(ii=0;ii<curveFiles.length;ii++) {
			if(indexOf(curveFiles[ii],wtName) > -1) {
				curvePath = CurveDir + curveFiles[ii];
				open(curvePath);
				run("To ROI Manager");
				wtnumCells = wtnumCells + roiManager("count");	
				run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); //done because I want everything in pixels
				for(i=0;i<roiManager("count");i++) {
					roiManager("select",i);
					List.clear();
					List.setMeasurements;
					wtMeanBrightnesses = Array.concat(wtMeanBrightnesses,List.getValue("Mean"));
					wtAreas = Array.concat(wtAreas,List.getValue("Area"));
					wtTotalBrightnesses = Array.concat(wtMeanBrightnesses,List.getValue("RawIntDen"));
				}
				run("Close All");
			}
		}
		run("Close All");
		if(wtMeanBrightnesses.length == 0) { //if there are no wild-type images
			wtStErr = 0;
			wtTotalBrightness = 0;
			print("WT brightness not found; will not be subtracted.");
		}
		else {
			Array.getStatistics(wtMeanBrightnesses,min,max,wtBrightness,wtStDev);
			Array.getStatistics(wtAreas,min,max,wtArea,wtAreaStDev);
			Array.getStatistics(wtTotalBrightnesses,min,max,wtTotalBrightness,wtTotalStDev);
			//Multiplying mean brightness by area to get integrated density, with error propagation
			if(useStErr) {
				wtStErr = wtStDev/sqrt(wtnumCells);
				wtAreaStErr = wtAreaStDev/sqrt(wtnumCells);
				wtTotalBrightness = wtBrightness*wtArea;
				wtTotalStErr = wtTotalBrightness*sqrt(pow(wtStErr/wtBrightness,2) + pow(wtAreaStErr/wtArea,2)); //error propagation for multiplication
			}
			
			// Converting to number of molecules, and accounting for bit depth/exposure time
			wtNumMolecules = wtTotalBrightness*differenceConstant/curveSlope;
			if(useStErr) {
				wtMoleculesStErr = wtTotalStErr*differenceConstant/curveSlope;
			}
			wtMoleculesStDev = wtTotalStDev*differenceConstant/curveSlope;
			if(useStErr) {
				print("WT number of molecules: " + wtNumMolecules + " +/- " + wtMoleculesStErr);
			}
			else {
				print("WT number of molecules: " + wtNumMolecules + " +/- " + wtMoleculesStDev);
			}

			//Adding WT to results table
			setResult("Movie", resultRowNumber, "WT compiled"); 
			setResult("# Molecules", resultRowNumber, wtNumMolecules); 
			setResult("Stdev", resultRowNumber, wtMoleculesStDev); 
			if(useStErr) {
				setResult("Sterr", resultRowNumber, wtMoleculesStErr); 
			}
			setResult("# cells",resultRowNumber,wtnumCells);

			resultRowNumber = resultRowNumber + 1;
		}
	}
	else {
		wtNumMolecules = wtTotalBrightness*differenceConstant/curveSlope;
		if(useStErr) {
			wtMoleculesStErr = wtTotalStErr*differenceConstant/curveSlope;
		}
		wtMoleculesStDev = wtTotalStDev*differenceConstant/curveSlope;
		if(useStErr) {
			print("WT number of molecules: " + wtNumMolecules + " +/- " + wtMoleculesStErr);
		}
		else {
			print("WT number of molecules: " + wtNumMolecules + " +/- " + wtMoleculesStDev);
		}

		//Adding WT to results table
		setResult("Strain/Movie", resultRowNumber, "WT compiled"); 
		setResult("# Molecules", resultRowNumber, wtNumMolecules); 
		setResult("Stdev", resultRowNumber, wtMoleculesStDev); 
		if(useStErr) {
			setResult("Sterr", resultRowNumber, wtMoleculesStErr); 
		}
		setResult("# cells",resultRowNumber,wtnumCells);
		resultRowNumber = resultRowNumber + 1;
	}

	//Measuring number of molecules for custom strains
	numStrains = 0;
	for(strain=0;strain<possibleStrains.length;strain++) {
		if(possibleStrains[strain] != "N/A") {
			numStrains = numStrains + 1;
		}
	}

	for(strain=0;strain<numStrains;strain++) {
		strainAreas = newArray();
		strainMeanBrightnesses = newArray();
		strainTotalBrightnesses = newArray();
		strainNumCells = 0;
		print("Measuring " + possibleStrains[strain] + " brightness...");
		for(ii=0;ii<curveFiles.length;ii++) {
			if(indexOf(curveFiles[ii],possibleStrains[strain]) > -1) {
				curvePath = CurveDir + curveFiles[ii];
				open(curvePath);
				run("To ROI Manager");
				strainNumCells = strainNumCells + roiManager("count");	
				run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); //done because I want everything in pixels
				for(i=0;i<roiManager("count");i++) {
					roiManager("select",i);
					//showMessageWithCancel("Right image?");
					List.clear();
					List.setMeasurements;
					strainAreas = Array.concat(strainAreas,List.getValue("Area"));
					strainMeanBrightnesses = Array.concat(strainMeanBrightnesses,List.getValue("Mean"));
					strainTotalBrightnesses = Array.concat(strainTotalBrightnesses,List.getValue("RawIntDen"));
				}
				run("Close All");
				/*
				winList = getList("window.titles"); //closing ALL non-image windows, including the ROI manager, which it clears
				for(i=0;i<winList.length;i++) {
					selectWindow(winList[i]);
					run("Close");
				}
				*/
				//roiManager("deselect");
				//roiManager("delete"); //clears all ROIs
			}
		}
		Array.getStatistics(strainMeanBrightnesses,min,max,strainBrightness,strainStDev);
		Array.getStatistics(strainAreas,min,max,strainArea,strainAreaStDev);
		Array.getStatistics(strainTotalBrightnesses,min,max,strainTotalBrightness,strainTotalStDev);
		
		//Multiplying mean brightness by area to get integrated density, with error propagation
		if(useStErr) {
			strainStErr = strainStDev/sqrt(strainNumCells);
			strainAreaStErr = strainAreaStDev/sqrt(strainNumCells);
			strainTotalBrightness = strainBrightness*strainArea;
			strainTotalStDev = strainStDev*strainArea; //no error prop. because this is not error - it's standard deviation
			strainTotalStErr = strainTotalBrightness*sqrt(pow(strainStErr/strainBrightness,2) + pow(strainAreaStErr/strainArea,2));//error propagation for multiplication
		}
		
		//Subtracting wild-type, with error propagation
		strainTotalBrightness = strainTotalBrightness - wtTotalBrightness;

		//Converting to number of molecules, accounting for differences in exposure time/bit depth
		strainNumMolecules = strainTotalBrightness*differenceConstant/curveSlope; //curveSlope = brightness/number of molecules
		if(useStErr) {
			strainTotalStErr = strainTotalStErr + wtTotalStErr;
			strainNumMoleculesStErr = strainTotalStErr*differenceConstant/curveSlope;
		}
		strainNumMoleculesStDev = strainTotalStDev*differenceConstant/curveSlope;

		//Printing results
		if(useStErr) {
			print(possibleStrains[strain] + " number of molecules per cell: " + strainNumMolecules + " +/- " + strainNumMoleculesStErr);
		}
		else {
			print(possibleStrains[strain] + " number of molecules per cell: " + strainNumMolecules + " +/- " + strainNumMoleculesStDev);
		}

	

		//Creating and saving results table (Thanks Matt!)
		setResult("Strain/Movie", resultRowNumber, possibleStrains[strain] + " compiled");
		setResult("# Molecules", resultRowNumber, strainNumMolecules); 
		setResult("Stdev", resultRowNumber, strainNumMoleculesStDev); 
		if(useStErr) {
			setResult("Sterr", resultRowNumber, strainNumMoleculesStErr); 
		}
		setResult("# cells",resultRowNumber,strainNumCells);
		
		//showMessageWithCancel(brightArray[strain]);
		resultRowNumber = resultRowNumber + 1;
		run("Close All");
	}
	//Measuring number of molecules in each image that is WT or part of a custom strain
	print(curveFiles.length);
	for(ii=0;ii<curveFiles.length;ii++) {
		measureFile = true;
		if(indexOf(curveFiles[ii],wtName) > -1) { //if it's the wild type, don't measure it
			measureFile = false;
		}
		else {
			for(strain=0;strain<possibleStrains.length;strain++) { //if it's any of the specified custom strains, don't measure it.
				if(indexOf(curveFiles[ii],possibleStrains[strain]) > -1) {
					measureFile = false;
				}
			}
		}
		if(measureFile) { //if it's not wild-type--calibration strains are now measured, because why not
			curvePath = CurveDir + curveFiles[ii];
			open(curvePath);
			run("To ROI Manager");
			run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); //done because I want everything in pixels
			print("Measuring " + curveFiles[ii] + " brightness...");
			strainAreas = newArray();
			strainMeanBrightnesses = newArray();
			strainTotalBrightnesses = newArray();
			strainNumCells = roiManager("count");	
			for(i=0;i<roiManager("count");i++) {
				roiManager("select",i);
				//showMessageWithCancel("Right image?");
				List.clear();
				List.setMeasurements;
				strainAreas = Array.concat(strainAreas,List.getValue("Area"));
				strainMeanBrightnesses = Array.concat(strainMeanBrightnesses,List.getValue("Mean"));
				strainTotalBrightnesses = Array.concat(strainTotalBrightnesses,List.getValue("RawIntDen"));
			}
			run("Close All");
			
			Array.getStatistics(strainMeanBrightnesses,min,max,strainBrightness,strainStDev);
			Array.getStatistics(strainAreas,min,max,strainArea,strainAreaStDev);
			Array.getStatistics(strainTotalBrightnesses,min,max,strainTotalBrightness,strainTotalStDev);
			
			//Multiplying mean brightness by area to get integrated density, with error propagation
			if(useStErr) {
				strainStErr = strainStDev/sqrt(strainNumCells);
				strainAreaStErr = strainAreaStDev/sqrt(strainNumCells);
				strainTotalBrightness = strainBrightness*strainArea;
				strainTotalStDev = strainStDev*strainArea; //no error prop. because this is not error - it's standard deviation
				strainTotalStErr = strainTotalBrightness*sqrt(pow(strainStErr/strainBrightness,2) + pow(strainAreaStErr/strainArea,2));//error propagation for multiplication
				strainTotalStErr = strainTotalStErr + wtTotalStErr;
			}
			strainTotalBrightness = strainTotalBrightness - wtTotalBrightness;			
			//Calculating number of molecules from total brightness, accounting for differences in exposure time/bit depth
			strainNumMolecules = strainTotalBrightness*differenceConstant/curveSlope; //curveSlope = brightness/number of molecules
			if(useStErr) {
				strainNumMoleculesStErr = strainTotalStErr*differenceConstant/curveSlope;
			}
			strainNumMoleculesStDev = strainTotalStDev*differenceConstant/curveSlope;

			//Printing results (later replace with text file)
			if(useStErr) {
				print("Number of molecules for " + curveFiles[ii] + ": " + strainNumMolecules + " +/- " + strainNumMoleculesStErr);
			}
			else {
				print("Number of molecules for " + curveFiles[ii] + ": " + strainNumMolecules + " +/- " + strainNumMoleculesStDev);
			}

			//Printing stuff to results table
			setResult("Strain/Movie", resultRowNumber, curveFiles[ii]); 
			setResult("# Molecules", resultRowNumber, strainNumMolecules); 
			setResult("Stdev", resultRowNumber, strainNumMoleculesStDev); 
			if(useStErr) {
				setResult("Sterr", resultRowNumber, strainNumMoleculesStErr); 
			}
			setResult("# cells",resultRowNumber,strainNumCells);

			resultRowNumber = resultRowNumber + 1;

			/*
			winList = getList("window.titles"); //closing ALL non-image windows, including the ROI manager, which it clears
			for(i=0;i<winList.length;i++) {
				selectWindow(winList[i]);
				run("Close");
			}
			*/
			//roiManager("deselect");
			//roiManager("delete"); //clears all ROIs
		}
	}
	saveAs("Results",  imageDir+"Calibration_intensities_all_movies.txt"); 

}
