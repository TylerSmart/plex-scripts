import { Season } from './season.model';

export interface Episode {
	id: number;
	seriesId: number;
	name: string;
	aired: string;
	runtime: number;
	nameTranslations: string[];
	overview: string;
	overviewTranslations: string[];
	image: string;
	imageType: number;
	isMovie: number;
	seasons: Season[];
	number: number;
	absoluteNumber: number;
	seasonNumber: number;
	lastUpdated: string;
	finaleType: any;
	year: string;
}
