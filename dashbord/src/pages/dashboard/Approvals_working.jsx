import React, { useState, useEffect } from 'react';
import { Card, Typography, Button, Table, Tag, Space, message, Modal, Form, Input, Select } from 'antd';
import { UserOutlined, ReloadOutlined, EyeOutlined, CheckOutlined, CloseOutlined, SearchOutlined, FilterOutlined } from '@ant-design/icons';

const { Title, Text } = Typography;
const { Option } = Select;

const Approvals = () => {
  const [organizers, setOrganizers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedOrganizer, setSelectedOrganizer] = useState(null);
  const [detailsModalVisible, setDetailsModalVisible] = useState(false);
  const [searchText, setSearchText] = useState('');

  // Mock data
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

  useEffect(() => {
    // Load mock data
    setOrganizers(mockOrganizers);
  }, []);

  const handleApprove = (organizer) => {
    setSelectedOrganizer(organizer);
    message.success(`${organizer.fullname} approved (demo)`);
    setOrganizers(prev => prev.filter(org => org._id !== organizer._id));
  };

  const handleReject = (organizer) => {
    setSelectedOrganizer(organizer);
    message.success(`${organizer.fullname} rejected (demo)`);
    setOrganizers(prev => prev.filter(org => org._id !== organizer._id));
  };

  const viewDetails = (organizer) => {
    setSelectedOrganizer(organizer);
    setDetailsModalVisible(true);
  };

  const columns = [
    {
      title: 'Name',
      dataIndex: 'fullname',
      key: 'fullname',
      render: (text) => <strong>{text}</strong>,
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email',
    },
    {
      title: 'Signup Method',
      dataIndex: 'signup_method',
      key: 'signup_method',
      render: (method) => (
        <Tag color={method === 'google' ? 'blue' : method === 'email' ? 'green' : 'default'}>
          {method?.toUpperCase()}
        </Tag>
      ),
    },
    {
      title: 'Country',
      key: 'country',
      render: (_, record) => record.onboarding_data?.country || 'N/A',
    },
    {
      title: 'Submitted',
      dataIndex: 'submitted_for_approval',
      key: 'submitted_for_approval',
      render: (date) => new Date(date).toLocaleDateString(),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_, record) => (
        <Space>
          <Button icon={<EyeOutlined />} onClick={() => viewDetails(record)} />
          <Button 
            type="primary" 
            icon={<CheckOutlined />} 
            onClick={() => handleApprove(record)}
            style={{ backgroundColor: '#52c41a', borderColor: '#52c41a' }}
          />
          <Button 
            danger 
            icon={<CloseOutlined />} 
            onClick={() => handleReject(record)}
          />
        </Space>
      ),
    },
  ];

  const filteredOrganizers = organizers.filter(org =>
    org.fullname.toLowerCase().includes(searchText.toLowerCase()) ||
    org.email.toLowerCase().includes(searchText.toLowerCase())
  );

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-8 gap-4">
        <div>
          <Title level={2} className="mb-2 flex items-center">
            <div className="w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg flex items-center justify-center mr-3">
              <UserOutlined className="text-white text-lg" />
            </div>
            Organizer Approvals
          </Title>
          <Text type="secondary" className="text-sm">
            Manage and review organizer onboarding requests
          </Text>
        </div>
        <Button
          icon={<ReloadOutlined />}
          onClick={() => setOrganizers(mockOrganizers)}
          className="border-gray-300 hover:border-blue-500 hover:text-blue-500"
        >
          Refresh
        </Button>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card className="border-0 shadow-lg hover:shadow-xl transition-shadow duration-300">
          <div className="flex justify-between items-center">
            <div>
              <Text type="secondary" className="text-sm font-medium">Pending Approvals</Text>
              <Title level={3} className="mb-0 text-orange-500 font-bold">{organizers.length}</Title>
              <Text type="secondary" className="text-xs">Need review</Text>
            </div>
            <div className="w-12 h-12 bg-orange-100 rounded-full flex items-center justify-center">
              <UserOutlined style={{ fontSize: 24, color: '#FFA502' }} />
            </div>
          </div>
        </Card>
        <Card className="border-0 shadow-lg hover:shadow-xl transition-shadow duration-300">
          <div className="flex justify-between items-center">
            <div>
              <Text type="secondary" className="text-sm font-medium">Onboarded Users</Text>
              <Title level={3} className="mb-0 text-green-500 font-bold">15</Title>
              <Text type="secondary" className="text-xs">Approved</Text>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
              <CheckOutlined style={{ fontSize: 24, color: '#00B894' }} />
            </div>
          </div>
        </Card>
        <Card className="border-0 shadow-lg hover:shadow-xl transition-shadow duration-300">
          <div className="flex justify-between items-center">
            <div>
              <Text type="secondary" className="text-sm font-medium">Completion Rate</Text>
              <Title level={3} className="mb-0 text-blue-500 font-bold">85%</Title>
              <Text type="secondary" className="text-xs">Success rate</Text>
            </div>
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
              <div style={{ fontSize: 24, color: '#4B63FF' }}>%</div>
            </div>
          </div>
        </Card>
        <Card className="border-0 shadow-lg hover:shadow-xl transition-shadow duration-300">
          <div className="flex justify-between items-center">
            <div>
              <Text type="secondary" className="text-sm font-medium">Total Users</Text>
              <Title level={3} className="mb-0 text-purple-500 font-bold">20</Title>
              <Text type="secondary" className="text-xs">All time</Text>
            </div>
            <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
              <div style={{ fontSize: 24, color: '#9B59B6' }}>#</div>
            </div>
          </div>
        </Card>
      </div>

      {/* Search */}
      <Card className="border-0 shadow-lg mb-8">
        <Input
          placeholder="Search organizers by name or email..."
          prefix={<SearchOutlined className="text-gray-400" />}
          className="h-12 border-gray-300 focus:border-blue-500"
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
        />
      </Card>

      {/* Table */}
      <Card className="border-0 shadow-lg">
        <div className="mb-4">
          <Title level={4} className="mb-0">Pending Organizers</Title>
          <Text type="secondary" className="text-sm">
            Review and approve organizer applications
          </Text>
        </div>
        <Table
          columns={columns}
          dataSource={filteredOrganizers}
          rowKey="_id"
          loading={loading}
          pagination={{
            showSizeChanger: true,
            showQuickJumper: true,
            showTotal: (total, range) => (
              <span className="text-gray-600">
                Showing {range[0]} to {range[1]} of {total} organizers
              </span>
            ),
          }}
          scroll={{ x: 1200 }}
        />
      </Card>

      {/* Details Modal */}
      <Modal
        title="Organizer Details"
        open={detailsModalVisible}
        onCancel={() => setDetailsModalVisible(false)}
        footer={[
          <Button key="close" onClick={() => setDetailsModalVisible(false)}>
            Close
          </Button>,
        ]}
        width={800}
      >
        {selectedOrganizer && (
          <div>
            <p><strong>Name:</strong> {selectedOrganizer.fullname}</p>
            <p><strong>Email:</strong> {selectedOrganizer.email}</p>
            <p><strong>Signup Method:</strong> {selectedOrganizer.signup_method}</p>
            <p><strong>Country:</strong> {selectedOrganizer.onboarding_data?.country}</p>
            <p><strong>Phone:</strong> {selectedOrganizer.onboarding_data?.phone}</p>
            <p><strong>Activities:</strong> {selectedOrganizer.onboarding_data?.activities?.join(', ')}</p>
            <p><strong>Languages:</strong> {selectedOrganizer.onboarding_data?.languages?.join(', ')}</p>
          </div>
        )}
      </Modal>
    </div>
  );
};

export default Approvals;
