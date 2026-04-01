import axios from 'axios';

import { API_BASE_URL } from './endPoint';

const apiClient = axios.create({
	baseURL: API_BASE_URL,
});

export async function Get(endpoint, config = {}) {
	const response = await apiClient.get(endpoint, config);
	return response.data;
}

export async function Post(endpoint, payload = {}, config = {}) {
	const response = await apiClient.post(endpoint, payload, config);
	return response.data;
}

export async function Put(endpoint, payload = {}, config = {}) {
	const response = await apiClient.put(endpoint, payload, config);
	return response.data;
}

export async function Delete(endpoint, config = {}) {
	const response = await apiClient.delete(endpoint, config);
	return response.data;
}

