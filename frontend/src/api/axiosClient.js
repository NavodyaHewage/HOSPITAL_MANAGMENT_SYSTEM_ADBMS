import axios from 'axios';

const axiosClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? '/api',
  headers: { 'Content-Type': 'application/json' },
});

axiosClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('hms_access_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

axiosClient.interceptors.response.use(
  (response) => response.data,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('hms_access_token');
      window.location.href = '/login';
    }
    // Backend surfaces SQLSTATE 45000 rule messages as 409 with { message }.
    return Promise.reject(error.response?.data ?? { message: 'Network error' });
  }
);

export default axiosClient;
