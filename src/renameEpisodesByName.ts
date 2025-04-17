import * as fs from 'fs';
import path from 'node:path';
import inquirer from 'inquirer';

import collectMKVFiles from './util/collect-mkv-files.function';
import { isDistanceLessThan } from './util/levenshtein';
import prompt from './util/prompt.function';

import { TVDBController } from './controllers/tvdb.controller';

import { SearchResult } from './models/search-result.model';
import { Series } from './models/series.model';
import { Episode } from './models/episode.model';

const config = require('../config.json');

const isTestRun = process.argv.includes('--test-run');

if (isTestRun) {
	console.warn('\nRunning in test mode. No files will be renamed.');
}

async function main() {
	const tvdb = new TVDBController(config.TVDB_API_KEY, config.TVDB_PIN);

	console.log();
	const directory: string | null =
		config.DIRECTORY ??
		(await prompt('Please enter the TV series directory: '));

	if (!directory) {
		throw new Error('No directory provided');
	}
	if (!fs.existsSync(directory)) {
		throw new Error(`Directory does not exist: ${directory}`);
	}

	console.log();
	const seriesName: string | null =
		config.SERIES_NAME ??
		(await prompt('Please enter the name of the series: '));

	if (!seriesName) {
		throw new Error('No series name provided');
	}

	const seriesSearchResults: SearchResult[] = await tvdb
		.search({
			query: seriesName,
			type: 'series',
			limit: 10,
		})
		.then((res) => res.data);

	console.log();
	const { selectedSearchResult }: { selectedSearchResult: SearchResult } =
		await inquirer.prompt([
			{
				type: 'list',
				name: 'selectedSearchResult',
				message: `Select the series you want to query:`,
				choices: seriesSearchResults.map((s) => ({
					name: `${s.name} (${s.year})`,
					value: s,
				})),
			},
		]);

	const series: Series = await tvdb.getSeries(selectedSearchResult.tvdb_id);

	let filePaths: string[] = collectMKVFiles(directory, series.name);

	const episodes: Episode[] = await tvdb.getSeriesEpisodes(series.id);

	const episodesWithNoMatches: string[] = [];

	for (const episode of episodes) {
		if (!episode.name) {
			console.warn(
				`\nEpisode ${series.name} S${episode.seasonNumber.toLocaleString(
					undefined,
					{
						minimumIntegerDigits: 2,
					},
				)}E${episode.number.toLocaleString(undefined, {
					minimumIntegerDigits: 2,
				})} ${episode.id} has no name`,
			);
			continue;
		}

		const properEpisodeName = `${
			series.name
		} S${episode.seasonNumber.toLocaleString(undefined, {
			minimumIntegerDigits: 2,
		})}E${episode.number.toLocaleString(undefined, {
			minimumIntegerDigits: 2,
		})} ${episode.name}`;

		let selectedFilePath: string | null = null;

		const episodeNameSimplified = episode.name
			.replace(/[^a-zA-Z0-9]/g, '')
			.toLowerCase();

		const exactMatches = filePaths.filter((file) => {
			const fileNameWithoutExtension = path.basename(file, '.mkv');
			const fileNameSimplified = fileNameWithoutExtension
				.replace(/[^a-zA-Z0-9]/g, '')
				.toLowerCase();

			return fileNameSimplified == episodeNameSimplified;
		});

		if (exactMatches.length == 1) selectedFilePath = exactMatches[0];
		else if (exactMatches.length > 1) {
			console.log();
			selectedFilePath = await inquirer
				.prompt([
					{
						type: 'list',
						name: 'selectedFile',
						message: `Multiple files found for episode ${properEpisodeName}. Please select one:`,
						choices: [
							...exactMatches.map((f) => ({
								name: f,
								value: f,
							})),
							{ name: 'None of the above', value: null },
						],
					},
				])
				.then((res) => res.selectedFile);
		}

		if (!selectedFilePath) {
			const similarMatches = filePaths.filter((file) => {
				const fileNameWithoutExtension = path.basename(file, '.mkv');
				const fileNameSimplified = fileNameWithoutExtension
					.replace(/[^a-zA-Z0-9]/g, '')
					.toLowerCase();

				return (
					isDistanceLessThan(
						episodeNameSimplified,
						fileNameSimplified,
						3,
					) ||
					episodeNameSimplified.includes(fileNameSimplified) ||
					fileNameSimplified.includes(episodeNameSimplified)
				);
			});

			if (similarMatches.length > 0) {
				console.log();
				selectedFilePath = await inquirer
					.prompt([
						{
							type: 'list',
							name: 'selectedFile',
							message: `Similar files found for episode ${properEpisodeName}. Please select one:`,
							choices: [
								...similarMatches.map((f) => ({
									name: f,
									value: f,
								})),
								{ name: 'None of the above', value: null },
							],
						},
					])
					.then((res) => res.selectedFile);
			}
		}

		if (!selectedFilePath) {
			console.warn(
				`\nNo file found or selected for episode ${properEpisodeName}.`,
			);

			episodesWithNoMatches.push(properEpisodeName);
			continue;
		}

		const newFileName = `${properEpisodeName.replace(
			/[^a-zA-Z0-9\s-]/g,
			'',
		)}.mkv`;
		const newFilePath = path.join(
			path.dirname(selectedFilePath),
			newFileName,
		);

		if (!isTestRun) fs.renameSync(selectedFilePath, newFilePath);

		filePaths = filePaths.filter((f) => f !== selectedFilePath);
	}

	if (episodesWithNoMatches.length > 0) {
		console.warn(`\nThe following episodes were not matched to any files:`);
		episodesWithNoMatches.forEach((episode) => {
			console.warn(`- ${episode}`);
		});
	}

	if (filePaths.length > 0) {
		console.warn(`\nThe following files were not matched to any episodes:`);
		filePaths.forEach((file) => {
			console.warn(`- ${file}`);
		});
	}
}

main()
	.then(() => {
		console.log('\nDone');
	})
	.catch((err) => {
		console.log();
		console.error(err);
		process.exit(1);
	});
