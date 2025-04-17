import { TVDBResponse } from './tvdb-response.model';
import { Links } from './links.model';

export interface TVDBPaginatedResponse<T> extends TVDBResponse<T> {
	links: Links;
}
