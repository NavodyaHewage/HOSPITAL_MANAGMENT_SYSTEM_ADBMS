export const formatCurrency = (value) =>
  new Intl.NumberFormat('en-LK', { style: 'currency', currency: 'LKR' }).format(value ?? 0);

export const formatDate = (value) => (value ? new Date(value).toLocaleDateString('en-GB') : '-');

export const formatDateTime = (value) => (value ? new Date(value).toLocaleString('en-GB') : '-');
