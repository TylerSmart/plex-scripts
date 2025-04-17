import { Alias } from './alias.model';
import { Status } from './status.model';

export interface Series {
	id: number;
	name: string;
	slug: string;
	image: string;
	nameTranslations: string[];
	overviewTranslations: string[];
	aliases: Alias[];
	firstAired: string;
	lastAired: string;
	nextAired: string;
	score: number;
	status: Status;
	originalCountry: string;
	originalLanguage: string;
	defaultSeasonType: number;
	isOrderRandomized: boolean;
	lastUpdated: string;
	averageRuntime: number;
	episodes: any;
	overview: string;
	year: string;
}
