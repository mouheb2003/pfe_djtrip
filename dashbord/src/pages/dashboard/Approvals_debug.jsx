import React, { useState, useEffect } from 'react';
import { Card, Typography, Button, message } from 'antd';
import { onboardingService } from '../../services/onboardingService';

const { Title } = Typography;

const Approvals = () => {
  console.log('Approvals component rendering...');
  
  const [organizers, setOrganizers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    console.log('useEffect running...');
    // Try basic state update first
    setOrganizers([{ _id: '1', fullname: 'Test User' }]);
    
    // Test API call
    const testAPI = async () => {
      try {
        console.log('Testing API call...');
        const response = await onboardingService.getPendingApprovals(1, 20, {});
        console.log('API response:', response);
        message.success('API call successful');
      } catch (error) {
        console.error('API call failed:', error);
        message.error('API call failed: ' + error.message);
      }
    };
    
    // Don't auto-run API call to avoid immediate crash
    // testAPI();
  }, []);
  
  const handleClick = () => {
    console.log('Button clicked...');
    message.info('Debug message');
  };
  
  const testAPI = async () => {
    setLoading(true);
    setError(null);
    try {
      console.log('Testing API call...');
      
      // Try API call but expect it to fail
      try {
        const response = await onboardingService.getPendingApprovals(1, 20, {});
        console.log('API response:', response);
        message.success('API call successful');
        setOrganizers(response?.organizers || []);
      } catch (apiError) {
        console.warn('API call failed (expected), using mock data:', apiError);
        // Use mock data instead
        const mockOrganizers = [
          {
            _id: '1',
            fullname: 'John Doe',
            email: 'john@example.com',
            signup_method: 'email',
            onboarding_data: {
              phone: '+1234567890',
              country: 'Tunisia',
              activities: ['Tourism', 'Culture'],
              languages: ['English', 'French']
            },
            submitted_for_approval: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString()
          },
          {
            _id: '2',
            fullname: 'Jane Smith',
            email: 'jane@example.com',
            signup_method: 'google',
            onboarding_data: {
              phone: '+9876543210',
              country: 'France',
              activities: ['Sports', 'Adventure'],
              languages: ['English', 'Spanish']
            },
            submitted_for_approval: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString()
          }
        ];
        setOrganizers(mockOrganizers);
        message.info('Using mock data (API unavailable)');
      }
      
    } catch (error) {
      console.error('Critical error:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <div className="p-6">
      <Card>
        <Title level={2}>Approvals Debug</Title>
        <p>Testing API integration...</p>
        <p>Organizers count: {organizers.length}</p>
        <Button onClick={handleClick}>Test Button</Button>
        <Button onClick={testAPI} loading={loading} style={{ marginLeft: 8 }}>
          Test API Call
        </Button>
        {error && <p style={{ color: 'red' }}>Error: {error}</p>}
        {organizers.map(org => (
          <div key={org._id}>{org.fullname || org.name}</div>
        ))}
      </Card>
    </div>
  );
};

export default Approvals;
