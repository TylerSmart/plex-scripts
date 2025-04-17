import { SeasonType } from './season-type.model';
import { Companies } from './companies.model';

export interface Season {
	id: number;
	seriesId: number;
	type: SeasonType;
	number: number;
	nameTranslations: any;
	overviewTranslations: any;
	image?: string;
	imageType?: number;
	companies: Companies;
	lastUpdated: string;
}
