import { useState } from 'react';
import { usePatients } from '../hooks/usePatients';

export default function PatientListPage() {
  const [term, setTerm] = useState('');
  const { data, isLoading, error } = usePatients({ term });

  if (isLoading) return <p>Loading patients...</p>;
  if (error) return <p className="error">{error.message}</p>;

  return (
    <section>
      <h2>Patients</h2>
      <input value={term} onChange={(e) => setTerm(e.target.value)} placeholder="Name, phone or NIC" />
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Age</th>
            <th>Gender</th>
            <th>Phone</th>
          </tr>
        </thead>
        <tbody>
          {data?.content?.map((p) => (
            <tr key={p.patientId}>
              <td>{p.patientId}</td>
              <td>{p.fullName}</td>
              <td>{p.age}</td>
              <td>{p.gender}</td>
              <td>{p.phone}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
