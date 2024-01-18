// Quantify the mean pixel intensity of a single cell through time
//
// This ImageJ script quantifies the mean GFP intensity of the a single cell over time.
// Input: a folder with .tif images. Each must contain a single cell. 
//        Image dimensions: 
//        - Channels: 1: ?, 2: GFP, 3: ?
//        - Z-slices:
//        - Frames: time frames
// Output: One directory per input image with these files: 
//         - Cell mask
//         - Excel file with the cell's mean intensity over time
//         
// Required plugins: https://imagej.net/plugins/morpholibj#installation

debug_flag = false;

// Choose folder
if (!debug_flag) {
	folder = getDirectory("Choose a folder");
}
else {
	folder = "";
}

// Function similar to MorphoLibJ's Keep Largest Region, but it only keeps the largest region in each time-frame of the image with dims W*H*C*T.
// This function is used to solve the problem when an image has dims W*H*1*T and "Keep Largest Region" keeps a 3D region instead of a series of 2D components.
function keep_largest_region_in_each_frame() {
	current_image_name = getTitle();
	print("current_image_name " + current_image_name);
	Stack.getDimensions(width, height, channels, slices, frames)
	print("frames: " + frames);
	run("Stack to Images");
	for (frame_i=0; frame_i<frames; frame_i++) {
		selectImage(current_image_name+"-000"+frame_i+1);
		run("Keep Largest Region");
		close(current_image_name+"-000"+frame_i+1);
		rename(current_image_name+"-000"+frame_i+1);
	}
	run("Images to Stack", "title=mask ");
	rename(current_image_name+"-largest");
	selectImage(current_image_name+"-largest");
}

// Initialize ImageJ
run("Clear Results");
close("*");
print("Start");

// Create folder table
Table.create("all_images");
Table.setColumn("image");
split_folder_array = split(folder,"/\\");
folder_basename = split_folder_array[split_folder_array.length-1];

filenames = getFileList(folder);
filenames = Array.sort(filenames);
for (filename_i = 0; filename_i < filenames.length; filename_i++) {
	roiManager("reset");
	filename = filenames[filename_i];
	
	if(endsWith(filename, ".tif")) {
		open(folder + filename);
		
		run("Duplicate...", "duplicate channels=2");
		rename("C2-" + filename);
		run("Z Project...", "projection=[Max Intensity] all");
		projected = "projected_" + filename;
		rename(projected);
		print(folder + "results/"+ projected);
		File.makeDirectory(folder + "results/");
		save(folder + "results/"+ projected);
		run("Duplicate...", "title=smooth duplicate");
		run("Smooth", "stack");
		setThreshold(200, 65535, "raw");
		run("Convert to Mask", "background=Dark create");
		close("smooth");
		rename("mask");
		
		keep_largest_region_in_each_frame(); // returns a mask-largest
		
		selectImage("mask-largest");
		save(folder + "results/"+ projected + "_mask.tif");
		// Find regions to measure
		run("Analyze Particles...", "size=1-Infinity include add stack");
		// Measure mean intensity
		run("Clear Results");
		selectImage(projected);
		run("Set Measurements...", "mean display redirect=None decimal=3");
		roiManager("Measure");
		Stack.getDimensions(width, height, channels, slices, frames)
		saveAs("Results", folder + "results/" + filename + ".csv");
		
		selectWindow("all_images");
		// Create a new row
		Table.set("image", Table.size, filename); 
		// populate mean values
		for (row=1; row<=nResults; row++) {
			Table.set("T_"+row, Table.size-1, getResult("Mean", row-1));
		}
		Table.update();
		
		if (debug_flag) {
			run("Tile");
			selectImage("mask-largest");
			roiManager("Show None");
			doCommand("Start Animation [\\]");
			waitForUser("Verify the animated blob. The largest blob is kept in each time-frame.");
			doCommand("Start Animation [\\]");
		}
 		close(filename);
 		close("C2-" + filename);
 		close(projected);
 		close("mask");
 		close("mask-largest");

	}
}
selectWindow("all_images");
saveAs("Table", folder + "results/all_images_" + folder_basename + ".csv");