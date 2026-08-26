import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import patientApi from '../api/patientApi';

export function usePatients({ term = '', page = 0, size = 20 }) {
  return useQuery({
    queryKey: ['patients', term, page, size],
    queryFn: () => patientApi.search({ term, page, size }),
  });
}

export function useSavePatient() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: patientApi.save,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['patients'] }),
  });
}
