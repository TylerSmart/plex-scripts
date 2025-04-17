import * as fs from 'fs';
import * as path from 'path';

import { Series } from '../models/series.model';
import { Episode } from '../models/episode.model';
import { Movie } from '../models/movie.model';
import { SearchResult } from '../models/search-result.model';
import { TVDBResponse } from '../models/tvdb-response.model';
import { TVDBPaginatedResponse } from '../models/tvdb-paginated-response.model';

export class TVDBController {
	private _token: string | null = null;

	constructor(
		private readonly apikey: string,
		private readonly pin: string | null = null,
		private readonly baseUrl: string = 'https://api4.thetvdb.com/v4',
	) {}

	private async login(): Promise<string> {
		const url: string = `${this.baseUrl}/login`;

		const loginInfo: { apikey: string; pin?: string } = {
			apikey: this.apikey,
		};
		if (this.pin) {
			loginInfo.pin = this.pin;
		}

		const response = await fetch(url, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Accept: 'application/json',
			},
			body: JSON.stringify(loginInfo),
		});

		const responseBody: TVDBResponse<{
			token: string;
		}> = await response.json();

		if (
			!response.ok ||
			responseBody.status !== 'success' ||
			!responseBody.data?.token
		) {
			throw new Error(
				`Error loggin in: ${response.status} ${response.statusText} - ${
					responseBody.message || 'Unknown error'
				}`,
			);
		}

		return responseBody.data.token;
	}

	private get token(): Promise<string> {
		if (this._token) {
			return Promise.resolve(this._token);
		}

		return this.login().then((token) => {
			this._token = token;
			return token;
		});
	}

	public async getSeries(seriesId: number | string): Promise<Series> {
		const cachePath = `./cache/series.${seriesId}.json`;
		if (fs.existsSync(cachePath)) {
			const cachedData = fs.readFileSync(cachePath, 'utf-8');
			return JSON.parse(cachedData) as Series;
		}

		const url: string = `${this.baseUrl}/series/${seriesId}`;

		const token = await this.token;

		const response = await fetch(url, {
			method: 'GET',
			headers: {
				Authorization: `Bearer ${token}`,
				Accept: 'application/json',
			},
		});

		const responseBody: TVDBResponse<Series> = await response.json();

		if (
			!response.ok ||
			responseBody.status !== 'success' ||
			!responseBody.data
		) {
			throw new Error(
				`Error fetching series: ${response.status} ${
					response.statusText
				} - ${responseBody.message || 'Unknown error'}`,
			);
		}

		fs.mkdirSync(path.dirname(cachePath), { recursive: true });
		fs.writeFileSync(
			cachePath,
			JSON.stringify(responseBody.data, null, 2),
			'utf-8',
		);

		return responseBody.data;
	}

	public async getSeriesEpisodes(
		seriesId: number | string,
	): Promise<Episode[]> {
		const cachePath = `./cache/series.${seriesId}.episodes.json`;
		if (fs.existsSync(cachePath)) {
			const cachedData = fs.readFileSync(cachePath, 'utf-8');
			return JSON.parse(cachedData) as Episode[];
		}

		const episodes: Episode[] = [];

		for (let page = 0; ; page++) {
			const pageEpisodes = await this.getSeriesEpisodesPage(seriesId, page);
			if (pageEpisodes.length === 0) {
				break;
			}
			episodes.push(...pageEpisodes);

			await new Promise((resolve) => setTimeout(resolve, 1000));
		}

		const sortedEpisodes = episodes.sort((a, b) => {
			if (a.seasonNumber === b.seasonNumber) {
				return a.number - b.number;
			}

			if (a.seasonNumber === 0) {
				return 1;
			}
			if (b.seasonNumber === 0) {
				return -1;
			}

			return a.seasonNumber - b.seasonNumber;
		});

		fs.mkdirSync(path.dirname(cachePath), { recursive: true });
		fs.writeFileSync(
			cachePath,
			JSON.stringify(sortedEpisodes, null, 2),
			'utf-8',
		);

		return sortedEpisodes;
	}

	public async getSeriesEpisodesPage(
		seriesId: number | string,
		page: number,
	): Promise<Episode[]> {
		const cachePath = `./cache/series.${seriesId}.page-${page}.episodes.json`;
		if (fs.existsSync(cachePath)) {
			const cachedData = fs.readFileSync(cachePath, 'utf-8');
			return JSON.parse(cachedData).episodes as Episode[];
		}

		const url: string = `${this.baseUrl}/series/${seriesId}/episodes/default?page=${page}`;

		const token = await this.token;

		const response = await fetch(url, {
			method: 'GET',
			headers: {
				Authorization: `Bearer ${token}`,
				Accept: 'application/json',
			},
		});

		const responseBody: TVDBResponse<Series> = await response.json();

		if (
			!response.ok ||
			responseBody.status !== 'success' ||
			!responseBody.data
		) {
			throw new Error(
				`Error fetching series episodes: ${response.status} ${
					response.statusText
				} - ${responseBody.message || 'Unknown error'}`,
			);
		}

		fs.mkdirSync(path.dirname(cachePath), { recursive: true });
		fs.writeFileSync(
			cachePath,
			JSON.stringify(responseBody.data, null, 2),
			'utf-8',
		);

		return responseBody.data.episodes as Episode[];
	}

	public async getEpisode(episodeId: number | string): Promise<Episode> {
		const cachePath = `./cache/episode.${episodeId}.json`;
		if (fs.existsSync(cachePath)) {
			const cachedData = fs.readFileSync(cachePath, 'utf-8');
			return JSON.parse(cachedData) as Episode;
		}

		const url: string = `${this.baseUrl}/episodes/${episodeId}`;

		const token = await this.token;

		const response = await fetch(url, {
			method: 'GET',
			headers: {
				Authorization: `Bearer ${token}`,
				Accept: 'application/json',
			},
		});

		const responseBody: TVDBResponse<Episode> = await response.json();

		if (
			!response.ok ||
			responseBody.status !== 'success' ||
			!responseBody.data
		) {
			throw new Error(
				`Error fetching episode: ${response.status} ${
					response.statusText
				} - ${responseBody.message || 'Unknown error'}`,
			);
		}

		fs.mkdirSync(path.dirname(cachePath), { recursive: true });
		fs.writeFileSync(
			cachePath,
			JSON.stringify(responseBody.data, null, 2),
			'utf-8',
		);

		return responseBody.data;
	}

	public async getMovie(movieId: number | string): Promise<Movie> {
		const cachePath = `./cache/movie.${movieId}.json`;
		if (fs.existsSync(cachePath)) {
			const cachedData = fs.readFileSync(cachePath, 'utf-8');
			return JSON.parse(cachedData) as Movie;
		}

		const url: string = `${this.baseUrl}/movies/${movieId}`;

		const token = await this.token;

		const response = await fetch(url, {
			method: 'GET',
			headers: {
				Authorization: `Bearer ${token}`,
				Accept: 'application/json',
			},
		});

		const responseBody: TVDBResponse<Movie> = await response.json();

		if (
			!response.ok ||
			responseBody.status !== 'success' ||
			!responseBody.data
		) {
			throw new Error(
				`Error fetching movie: ${response.status} ${
					response.statusText
				} - ${responseBody.message || 'Unknown error'}`,
			);
		}

		fs.mkdirSync(path.dirname(cachePath), { recursive: true });
		fs.writeFileSync(
			cachePath,
			JSON.stringify(responseBody.data, null, 2),
			'utf-8',
		);

		return responseBody.data;
	}

	public async search(params: {
		query: string;
		type?:
			| 'series'
			| 'movie'
			| 'person'
			| 'company'
			| 'episode'
			| 'list'
			| null;
		// year?: number | null;
		// company?: string | null;
		// country?: string | null;
		// director?: string | null;
		// language?: string | null;
		// primaryType?: string | null;
		// network?: string | null;
		// remote_id?: string | null;
		offset?: number | null; // Alternative to page
		limit?: number | null; // Default 100
		page?: number | null; // Default 0
		[key: string]: any; // Allow arbitrary key-value pairs
	}): Promise<TVDBPaginatedResponse<SearchResult[]>> {
		const paramsString = new URLSearchParams(params).toString();
		const cachePath = `./cache/search.${paramsString.replace(
			/[^a-zA-Z0-9]/g,
			'',
		)}.json`;
		if (fs.existsSync(cachePath)) {
			const cachedData = fs.readFileSync(cachePath, 'utf-8');
			return JSON.parse(cachedData) as TVDBPaginatedResponse<SearchResult[]>;
		}

		const url: string = `${this.baseUrl}/search?${paramsString}`;

		const token = await this.token;

		const response = await fetch(url, {
			method: 'GET',
			headers: {
				Authorization: `Bearer ${token}`,
				Accept: 'application/json',
			},
		});

		const responseBody: TVDBPaginatedResponse<SearchResult[]> =
			await response.json();

		if (
			!response.ok ||
			responseBody.status !== 'success' ||
			!responseBody.data
		) {
			throw new Error(
				`Error searching: ${response.status} ${response.statusText} - ${
					responseBody.message || 'Unknown error'
				}`,
			);
		}

		fs.mkdirSync(path.dirname(cachePath), { recursive: true });
		fs.writeFileSync(
			cachePath,
			JSON.stringify(responseBody, null, 2),
			'utf-8',
		);

		return responseBody;
	}
}
