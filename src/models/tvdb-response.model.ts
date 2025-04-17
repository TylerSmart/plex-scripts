export interface TVDBResponse<T> {
	status: string;
	message?: string;
	data: T;
}
