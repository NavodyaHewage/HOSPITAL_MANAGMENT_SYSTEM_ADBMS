import axiosClient from '../../../api/axiosClient';
import { ENDPOINTS } from '../../../api/endpoints';

const authApi = {
  login: (credentials) => axiosClient.post(ENDPOINTS.auth.login, credentials).then((r) => r.data),
  me: () => axiosClient.get(ENDPOINTS.auth.me).then((r) => r.data),
};

export default authApi;
