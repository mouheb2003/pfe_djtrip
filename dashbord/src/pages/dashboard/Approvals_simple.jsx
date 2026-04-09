import React from 'react';
import { Card, Typography } from 'antd';

const { Title } = Typography;

const Approvals = () => {
  return (
    <div className="p-6">
      <Card>
        <Title level={2}>Organizer Approvals</Title>
        <p>Approvals page is loading...</p>
        <p>This is a simplified version to test if the page loads without errors.</p>
      </Card>
    </div>
  );
};

export default Approvals;
