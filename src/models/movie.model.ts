import { Status } from './status.model';

export interface Movie {
	id: number;
	name: string;
	slug: string;
	image: string;
	nameTranslations: string[];
	overviewTranslations: string[];
	aliases: any[];
	score: number;
	runtime: number;
	status: Status;
	lastUpdated: string;
	year: string;
}
