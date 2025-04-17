/**
 * Calculates the Levenshtein distance between two strings.
 * This distance is the minimum number of single-character edits (insertions,
 * deletions, or substitutions) required to change one string into the other.
 * This implementation uses dynamic programming with space optimization (2 rows).
 *
 * @param s1 The first string.
 * @param s2 The second string.
 * @returns The Levenshtein distance between s1 and s2.
 */
export function calculateLevenshteinDistance(s1: string, s2: string): number {
	const m = s1.length;
	const n = s2.length;

	// Optimization: If the difference in lengths is already >= maxDistance,
	// we don't need the full calculation in the context of the main function.
	// However, this function calculates the exact distance.

	// If one string is empty, the distance is the length of the other string
	if (m === 0) return n;
	if (n === 0) return m;

	// Use two arrays (rows) to store distances, optimizing space
	let prevRow: number[] = new Array(n + 1);
	let currentRow: number[] = new Array(n + 1);

	// Initialize the 'previous' row (cost of transforming "" to s2[0...j])
	for (let j = 0; j <= n; j++) {
		prevRow[j] = j;
	}

	// Iterate through rows (characters of s1)
	for (let i = 1; i <= m; i++) {
		// First element of the current row is distance from s1[0...i] to ""
		currentRow[0] = i;

		// Iterate through columns (characters of s2)
		for (let j = 1; j <= n; j++) {
			const cost = s1[i - 1] === s2[j - 1] ? 0 : 1; // Cost is 1 if chars differ, 0 if same

			// Calculate the minimum cost from three operations:
			currentRow[j] = Math.min(
				currentRow[j - 1] + 1, // Insertion into s1 to match s2[j-1]
				prevRow[j] + 1, // Deletion from s1 to match "" from s2[j-1]
				prevRow[j - 1] + cost, // Substitution/match s1[i-1] with s2[j-1]
			);
		}

		// Swap rows for the next iteration: current becomes previous
		// Using array destructuring for a concise swap
		[prevRow, currentRow] = [currentRow, prevRow];
		// You could also manually copy: for (let k=0; k<=n; k++) prevRow[k] = currentRow[k];
		// Resetting currentRow is technically not needed as it will be overwritten,
		// but swapping references (like above) or copying is clearer.
	}

	// The final distance is in the last element of the 'previous' row after the loop
	// (because we swapped at the end of the last iteration)
	return prevRow[n];
}

/**
 * Checks if the Levenshtein distance between two strings is less than a given maximum.
 *
 * @param str1 The first string.
 * @param str2 The second string.
 * @param maxDistance The exclusive maximum distance allowed. The function returns true
 * if the calculated distance is strictly less than this value.
 * @returns True if the distance is less than maxDistance, false otherwise.
 */
export function isDistanceLessThan(
	str1: string,
	str2: string,
	maxDistance: number,
): boolean {
	// Basic checks
	if (maxDistance <= 0) {
		// If maxDistance is 0 or negative, only identical strings have a distance < maxDistance (distance 0)
		// But since the check is strictly '<', even identical strings (dist 0) return false.
		return false;
	}
	// If strings are identical, distance is 0, which is less than any positive maxDistance.
	if (str1 === str2) {
		return true;
	}

	// Optimization: If the absolute difference in lengths is already greater than
	// or equal to maxDistance, the Levenshtein distance cannot be less than maxDistance.
	// Because you need at least `abs(len1 - len2)` insertions or deletions.
	if (Math.abs(str1.length - str2.length) >= maxDistance) {
		return false;
	}

	// Calculate the actual Levenshtein distance
	const distance = calculateLevenshteinDistance(str1, str2);

	// Return true if the calculated distance is strictly less than the max allowed distance
	return distance < maxDistance;
}
