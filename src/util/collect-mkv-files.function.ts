import * as fs from 'fs'; // Standard Node.js file system module
import path from 'node:path';

/**
 * Recursively collects all .mkv files from a directory and its subdirectories.
 *
 * @param directory The directory to search.
 * @param showName The name of the show to exclude from the results.
 * @returns An array of file paths for all .mkv files found.
 */
export default function collectMkvFiles(
	directory: string,
	showName: string,
): string[] {
	const entries = fs.readdirSync(directory, { withFileTypes: true });
	const mkvFiles: string[] = [];

	for (const entry of entries) {
		const fullPath = path.join(directory, entry.name);

		if (entry.isDirectory()) {
			// Recursively collect .mkv files from subdirectories
			mkvFiles.push(...collectMkvFiles(fullPath, showName));
		} else if (
			entry.isFile() &&
			entry.name.endsWith('.mkv') &&
			!entry.name.startsWith(showName)
		) {
			mkvFiles.push(fullPath);
		}
	}

	return mkvFiles;
}
