import { RemoteId } from './remote-id.model';

export interface SearchResult {
	objectID: string;
	aliases?: string[];
	country: string;
	id: string;
	image_url: string;
	name: string;
	first_air_time?: string;
	overview?: string;
	primary_language: string;
	primary_type: string;
	status: string;
	type: string;
	tvdb_id: string;
	year?: string;
	slug: string;
	overviews: {
		[key: string]: string;
	};
	translations: {
		[key: string]: string;
	};
	network?: string;
	remote_ids?: RemoteId[];
	thumbnail?: string;
	director?: string;
	extended_title?: string;
	genres?: string[];
	studios?: string[];
}
