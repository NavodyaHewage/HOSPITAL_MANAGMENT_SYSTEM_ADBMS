import axiosClient from '../../../api/axiosClient';
import { ENDPOINTS } from '../../../api/endpoints';

const patientApi = {
  search: (params) => axiosClient.get(ENDPOINTS.patients, { params }).then((r) => r.data),
  getById: (id) => axiosClient.get(`${ENDPOINTS.patients}/${id}`).then((r) => r.data),
  save: (payload) => axiosClient.post(ENDPOINTS.patients, payload).then((r) => r.data),
  deactivate: (id) => axiosClient.delete(`${ENDPOINTS.patients}/${id}`),
};

export default patientApi;
