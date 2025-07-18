import * as fs from 'fs'; // Standard Node.js file system module
import path from 'node:path';

/**
 * Recursively collects all video files from a directory and its subdirectories.
 *
 * @param directory The directory to search.
 * @param showName The name of the show to exclude from the results.
 * @returns An array of file paths for all video files found.
 */
export default function collectVideoFiles(
	directory: string,
	showName: string,
	extension: string,
): string[] {
	const entries = fs.readdirSync(directory, { withFileTypes: true });
	const videoFiles: string[] = [];

	for (const entry of entries) {
		const fullPath = path.join(directory, entry.name);

		if (entry.isDirectory()) {
			// Recursively collect video files from subdirectories
			videoFiles.push(...collectVideoFiles(fullPath, showName, extension));
		} else if (entry.isFile() && entry.name.endsWith(`.${extension}`)) {
			videoFiles.push(fullPath);
		}
	}

	return videoFiles;
}
