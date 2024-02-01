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

GFP_CHANNEL = 3;
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
	//waitForUser("before keep_largest_region_in_each_frame");
	current_image_name = getTitle();
	print("current_image_name " + current_image_name);
	Stack.getDimensions(width, height, channels, slices, frames)
	print("frames: " + frames);
	run("Stack to Images");
//	waitForUser("after stack to images " + getTitle());
	for (frame_i=0; frame_i<frames; frame_i++) {
		selectImage(current_image_name+"-000"+frame_i+1);
		run("Keep Largest Region");
		close(current_image_name+"-000"+frame_i+1);
		rename(current_image_name+"-000"+frame_i+1);
	}
//	waitForUser("after for " + getTitle());
//	wait(100);
	run("Images to Stack", "title=mask ");
	selectImage("Stack");
//	waitForUser("after images to stack " + getTitle());
//	waitForUser("aaaa: " + getTitle());
//	if (getTitle() != "Stack") {
//		waitForUser("bbbb: " + getTitle());
//	}
	title = getTitle();
//	if (title != "Stack") {
//		waitForUser("cur image is not Stack: " + title);
//	}
	if (title == "Stack") {
		rename(current_image_name+"-largest");
	} 
	else {
		waitForUser("Erorr: cur image is not Stack: " + title);
	}
	
//	getTitle();
	selectImage(current_image_name+"-largest");
	//waitForUser("after  keep_largest_region_in_each_frame");
}

function min_threshold_in_frames() {
	//waitForUser("before min_threshold_3d");
	min_threshold = 65536;
	Stack.getDimensions(width, height, channels, slices, frames)
	print("frames: " + frames);
	for (frame_i=0; frame_i<frames; frame_i++) {
		Stack.setFrame(frame_i);
		Stack.setFrame(0);
		setAutoThreshold("Otsu dark no-reset");
		getThreshold(lower, upper);
		//waitForUser("lower = " + lower);
		min_threshold = minOf(lower, min_threshold);
	}
	//waitForUser("min_threshold = " + min_threshold);
	return min_threshold;
}


function save_mask_montage(filename) {
	selectImage("mask-largest");
	run("Make Montage...", "columns=5 rows=1 scale=1");
	save(filename);
	if (debug_flag) {
		run("Tile");
		waitForUser("Verify the blob shapes in the montage.");
	}
	close("Montage");
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
		
		run("Duplicate...", "duplicate channels=" + GFP_CHANNEL);
		rename("C" + GFP_CHANNEL + "-" + filename);
		run("Z Project...", "projection=[Max Intensity] all");
		projected = "projected_" + filename;
		rename(projected);
		print(folder + "results/"+ projected);
		File.makeDirectory(folder + "results/");
		save(folder + "results/"+ projected);
		run("Duplicate...", "title=smooth duplicate");
		run("Smooth", "stack");
		min_threshold = min_threshold_in_frames();
		setThreshold(min_threshold, 65535, "raw");
		run("Convert to Mask", "background=Dark create");
		close("smooth");
		rename("mask");
		
		keep_largest_region_in_each_frame(); // returns a mask-largest
		
		
		selectImage("mask-largest");
		save(folder + "results/"+ projected + "_mask.tif");
		save_mask_montage(folder + "results/"+ projected + "_masks.png");
		
		// Find regions to measure
		selectImage("mask-largest");
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
		
 		close(filename);
 		close("C" + GFP_CHANNEL + "-" + filename);
 		close(projected);
 		close("mask");
 		close("mask-largest");

	}
}
selectWindow("all_images");
saveAs("Table", folder + "results/all_images_" + folder_basename + ".csv");