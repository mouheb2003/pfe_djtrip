import React, { useEffect, useMemo, useState } from 'react';
import {
  Badge,
  Button,
  Card,
  ConfigProvider,
  Descriptions,
  Empty,
  Form,
  Input,
  message,
  Modal,
  Select,
  Space,
  Table,
  Tag,
  Tooltip,
  Typography,
  Avatar,
  theme,
} from 'antd';
import {
  CheckOutlined,
  CloseOutlined,
  EyeOutlined,
  GoogleOutlined,
  MailOutlined,
  ReloadOutlined,
  SearchOutlined,
  UserOutlined,
  PhoneOutlined,
  EnvironmentOutlined,
  GlobalOutlined,
  ClockCircleOutlined,
  FileTextOutlined,
  IdcardOutlined,
} from '@ant-design/icons';

import { onboardingService } from 'src/services/onboardingService';
import { useSettingsContext } from 'src/components/settings';

const { Title, Text } = Typography;
const { Option } = Select;
const { TextArea } = Input;

const Approvals = () => {
  const settings = useSettingsContext();
  const isDarkMode = settings.state.colorScheme === 'dark';
  const { defaultAlgorithm, darkAlgorithm } = theme;

  const [organizers, setOrganizers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [statsLoading, setStatsLoading] = useState(false);
  const [stats, setStats] = useState({
    pending_approvals: 0,
    onboarded_users: 0,
    onboarding_completion_rate: 0,
    total_users: 0,
  });

  const [filters, setFilters] = useState({ search: '', signup_method: undefined });
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [total, setTotal] = useState(0);

  const [selectedOrganizer, setSelectedOrganizer] = useState(null);
  const [detailsVisible, setDetailsVisible] = useState(false);
  const [approveVisible, setApproveVisible] = useState(false);
  const [rejectVisible, setRejectVisible] = useState(false);
  const [rejectForm] = Form.useForm();

  const loadApprovals = async (nextPage = page, nextFilters = filters) => {
    setLoading(true);
    try {
      const apiFilters = {};
      if (nextFilters.search) apiFilters.search = nextFilters.search;
      if (nextFilters.signup_method) apiFilters.signup_method = nextFilters.signup_method;

      const res = await onboardingService.getPendingApprovals(nextPage, pageSize, apiFilters);
      const list = res?.organizers ?? [];
      const totalItems = res?.pagination?.total_items ?? list.length;

      setOrganizers(Array.isArray(list) ? list : []);
      setTotal(Number.isFinite(totalItems) ? totalItems : 0);
      setPage(nextPage);
    } catch (e) {
      console.error('Failed to load pending approvals:', e);
      setOrganizers([]);
      setTotal(0);
      message.error('Failed to load pending approvals');
    } finally {
      setLoading(false);
    }
  };

  const loadStats = async () => {
    setStatsLoading(true);
    try {
      const res = await onboardingService.getOnboardingStats();
      setStats({
        pending_approvals: res?.pending_approvals ?? 0,
        onboarded_users: res?.onboarded_users ?? 0,
        onboarding_completion_rate: Number(res?.onboarding_completion_rate ?? 0),
        total_users: res?.total_users ?? 0,
      });
    } catch (e) {
      console.error('Failed to load onboarding stats:', e);
      setStats({
        pending_approvals: 0,
        onboarded_users: 0,
        onboarding_completion_rate: 0,
        total_users: 0,
      });
    } finally {
      setStatsLoading(false);
    }
  };

  useEffect(() => {
    loadApprovals(1, filters);
    loadStats();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSearch = (value) => {
    const next = { ...filters, search: value };
    setFilters(next);
    loadApprovals(1, next);
  };

  const handleSignupMethod = (value) => {
    const next = { ...filters, signup_method: value };
    setFilters(next);
    loadApprovals(1, next);
  };

  const approve = async () => {
    if (!selectedOrganizer?._id) return;
    try {
      await onboardingService.approveOrganizer(selectedOrganizer._id);
      message.success('Organizer approved');
      setApproveVisible(false);
      setSelectedOrganizer(null);
      await Promise.all([loadApprovals(1, filters), loadStats()]);
    } catch (e) {
      console.error('Approve failed:', e);
      message.error('Failed to approve organizer');
    }
  };

  const reject = async (values) => {
    if (!selectedOrganizer?._id) return;
    try {
      await onboardingService.rejectOrganizer(selectedOrganizer._id, values.reason);
      message.success('Organizer rejected');
      setRejectVisible(false);
      rejectForm.resetFields();
      setSelectedOrganizer(null);
      await Promise.all([loadApprovals(1, filters), loadStats()]);
    } catch (e) {
      console.error('Reject failed:', e);
      message.error('Failed to reject organizer');
    }
  };

  const columns = useMemo(
    () => [
      {
        title: 'Organizer',
        key: 'organizer',
        width: 240,
        render: (_, record) => (
          <Space>
            <UserOutlined />
            <div>
              <div style={{ fontWeight: 700 }}>{record.fullname || 'Unknown'}</div>
              <Text type="secondary" style={{ fontSize: 12 }}>
                {record.email}
              </Text>
            </div>
          </Space>
        ),
      },
      {
        title: 'Method',
        dataIndex: 'signup_method',
        key: 'method',
        width: 140,
        render: (m) => (
          <Tag color="blue" style={{ fontWeight: 700 }}>
            {m === 'google' ? <GoogleOutlined /> : <MailOutlined />} {String(m || 'email')}
          </Tag>
        ),
      },
      {
        title: 'Country',
        key: 'country',
        width: 160,
        render: (_, r) => r.onboarding_data?.pays_origine || r.onboarding_data?.country || 'N/A',
      },
      {
        title: 'Submitted',
        dataIndex: 'submitted_for_approval',
        key: 'submitted',
        width: 200,
        render: (v) => (v ? new Date(v).toLocaleString() : '—'),
      },
      {
        title: 'Wait',
        key: 'wait',
        width: 100,
        render: (_, r) => {
          const ts = r.submitted_for_approval ? new Date(r.submitted_for_approval).getTime() : 0;
          const d = ts ? Math.floor((Date.now() - ts) / 86400000) : 0;
          return <Badge color={d > 2 ? '#ef4444' : '#10b981'} text={`${d}d`} />;
        },
      },
      {
        title: 'Actions',
        key: 'actions',
        width: 160,
        fixed: 'right',
        render: (_, r) => (
          <Space>
            <Tooltip title="View details">
              <Button
                type="text"
                icon={<EyeOutlined />}
                onClick={() => {
                  setSelectedOrganizer(r);
                  setDetailsVisible(true);
                }}
              />
            </Tooltip>
            <Tooltip title="Approve">
              <Button
                type="text"
                icon={<CheckOutlined />}
                onClick={() => {
                  setSelectedOrganizer(r);
                  setApproveVisible(true);
                }}
              />
            </Tooltip>
            <Tooltip title="Reject">
              <Button
                danger
                type="text"
                icon={<CloseOutlined />}
                onClick={() => {
                  setSelectedOrganizer(r);
                  setRejectVisible(true);
                }}
              />
            </Tooltip>
          </Space>
        ),
      },
    ],
    [rejectForm]
  );

  return (
    <ConfigProvider
      theme={{
        algorithm: isDarkMode ? darkAlgorithm : defaultAlgorithm,
        token: {
          fontFamily: "'Public Sans', sans-serif",
          borderRadius: 12,
          colorPrimary: '#f97316',
          colorSuccess: '#10b981',
          colorWarning: '#f59e0b',
          colorError: '#ef4444',
          colorInfo: '#3b82f6',
        },
        components: {
          Typography: {
            fontWeightStrong: 800,
          },
          Card: {
            borderRadiusLG: 16,
          },
          Input: {
            controlHeightLG: 48,
            borderRadiusLG: 12,
          },
          Select: {
            controlHeightLG: 48,
            borderRadiusLG: 12,
          },
          Modal: {
            borderRadiusLG: 12,
          },
          Table: {
            borderRadiusLG: 12,
          },
        },
      }}
    >
      <div className="mx-auto max-w-7xl p-6 space-y-8" style={{ color: isDarkMode ? '#fff' : 'inherit' }}>
        {/* Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-8 gap-4">
          <div>
            <Title level={2} className="mb-2 flex items-center" style={{ fontWeight: 800 }}>
              <div className="w-10 h-10 bg-gradient-to-r from-orange-500 to-red-600 rounded-lg flex items-center justify-center mr-3">
                <CheckOutlined className="text-white text-lg" />
              </div>
              Organizer Approvals
            </Title>
            <Text type="secondary" className="text-sm">
              Review onboarding submissions and approve organizer accounts
            </Text>
          </div>
          <Button
            icon={<ReloadOutlined />}
            onClick={() => {
              loadApprovals(1, filters);
              loadStats();
            }}
            className="border-gray-300 hover:border-orange-500 hover:text-orange-500"
            style={{ borderRadius: '10px', height: '40px' }}
          >
            Refresh
          </Button>
        </div>

        {/* Statistics Cards - Enhanced */}
        <Space size={20} style={{ display: 'flex', overflowX: 'auto', paddingBottom: 12, marginBottom: 32 }}>
          <Card
            style={{
              width: 280,
              flex: '0 0 auto',
              background: isDarkMode ? '#1e1e1e' : '#fff',
              border: isDarkMode ? '1px solid #2c2c2c' : '1px solid #e5e7eb',
              borderRadius: 20,
              boxShadow: isDarkMode ? '0 4px 20px rgba(0, 0, 0, 0.3)' : '0 4px 20px rgba(0, 0, 0, 0.08)',
            }}
            className="hover:scale-105 transition-all duration-300 cursor-pointer"
            bodyStyle={{ padding: '28px' }}
            loading={statsLoading}
          >
            <div className="flex justify-between items-start">
              <div>
                <Text type="secondary" className="text-xs font-bold uppercase tracking-wider" style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.5)' : '#6b7280', letterSpacing: '0.05em' }}>Pending</Text>
                <Title level={2} className="mb-0 mt-2" style={{ fontWeight: 900, color: '#f97316', fontSize: '36px', lineHeight: 1 }}>{stats.pending_approvals}</Title>
                <div className="mt-2 flex items-center gap-1">
                  <span style={{ fontSize: '12px', color: '#f97316', fontWeight: 600, background: isDarkMode ? 'rgba(249, 115, 22, 0.15)' : '#fff7ed', padding: '4px 8px', borderRadius: '6px' }}>
                    +{Math.round(stats.pending_approvals * 0.1)} this week
                  </span>
                </div>
              </div>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center" style={{
                background: 'linear-gradient(135deg, #f97316 0%, #ea580c 100%)',
                boxShadow: '0 8px 16px rgba(249, 115, 22, 0.3)'
              }}>
                <ClockCircleOutlined style={{ fontSize: 28, color: '#fff' }} />
              </div>
            </div>
            <div className="mt-5 pt-4" style={{ borderTop: isDarkMode ? '1px solid #2c2c2c' : '1px solid #f3f4f6' }}>
              <Text style={{ fontSize: '13px', color: isDarkMode ? 'rgba(255, 255, 255, 0.6)' : '#6b7280', fontWeight: 500 }}>
                Awaiting review
              </Text>
            </div>
          </Card>

          <Card
            style={{
              width: 280,
              flex: '0 0 auto',
              background: isDarkMode ? '#1e1e1e' : '#fff',
              border: isDarkMode ? '1px solid #2c2c2c' : '1px solid #e5e7eb',
              borderRadius: 20,
              boxShadow: isDarkMode ? '0 4px 20px rgba(0, 0, 0, 0.3)' : '0 4px 20px rgba(0, 0, 0, 0.08)',
            }}
            className="hover:scale-105 transition-all duration-300 cursor-pointer"
            bodyStyle={{ padding: '28px' }}
            loading={statsLoading}
          >
            <div className="flex justify-between items-start">
              <div>
                <Text type="secondary" className="text-xs font-bold uppercase tracking-wider" style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.5)' : '#6b7280', letterSpacing: '0.05em' }}>Onboarded</Text>
                <Title level={2} className="mb-0 mt-2" style={{ fontWeight: 900, color: '#3b82f6', fontSize: '36px', lineHeight: 1 }}>{stats.onboarded_users}</Title>
                <div className="mt-2 flex items-center gap-1">
                  <span style={{ fontSize: '12px', color: '#10b981', fontWeight: 600, background: isDarkMode ? 'rgba(16, 185, 129, 0.15)' : '#ecfdf5', padding: '4px 8px', borderRadius: '6px' }}>
                    ↑ 12% from last month
                  </span>
                </div>
              </div>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center" style={{
                background: 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)',
                boxShadow: '0 8px 16px rgba(59, 130, 246, 0.3)'
              }}>
                <CheckOutlined style={{ fontSize: 28, color: '#fff' }} />
              </div>
            </div>
            <div className="mt-5 pt-4" style={{ borderTop: isDarkMode ? '1px solid #2c2c2c' : '1px solid #f3f4f6' }}>
              <Text style={{ fontSize: '13px', color: isDarkMode ? 'rgba(255, 255, 255, 0.6)' : '#6b7280', fontWeight: 500 }}>
                Approved organizers
              </Text>
            </div>
          </Card>

          <Card
            style={{
              width: 280,
              flex: '0 0 auto',
              background: isDarkMode ? '#1e1e1e' : '#fff',
              border: isDarkMode ? '1px solid #2c2c2c' : '1px solid #e5e7eb',
              borderRadius: 20,
              boxShadow: isDarkMode ? '0 4px 20px rgba(0, 0, 0, 0.3)' : '0 4px 20px rgba(0, 0, 0, 0.08)',
            }}
            className="hover:scale-105 transition-all duration-300 cursor-pointer"
            bodyStyle={{ padding: '28px' }}
            loading={statsLoading}
          >
            <div className="flex justify-between items-start">
              <div>
                <Text type="secondary" className="text-xs font-bold uppercase tracking-wider" style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.5)' : '#6b7280', letterSpacing: '0.05em' }}>Completion Rate</Text>
                <Title level={2} className="mb-0 mt-2" style={{ fontWeight: 900, color: '#10b981', fontSize: '36px', lineHeight: 1 }}>{stats.onboarding_completion_rate}%</Title>
                <div className="mt-2 flex items-center gap-1">
                  <span style={{ fontSize: '12px', color: '#10b981', fontWeight: 600, background: isDarkMode ? 'rgba(16, 185, 129, 0.15)' : '#ecfdf5', padding: '4px 8px', borderRadius: '6px' }}>
                    ↑ 5% improvement
                  </span>
                </div>
              </div>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center" style={{
                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                boxShadow: '0 8px 16px rgba(16, 185, 129, 0.3)'
              }}>
                <FileTextOutlined style={{ fontSize: 28, color: '#fff' }} />
              </div>
            </div>
            <div className="mt-5 pt-4" style={{ borderTop: isDarkMode ? '1px solid #2c2c2c' : '1px solid #f3f4f6' }}>
              <Text style={{ fontSize: '13px', color: isDarkMode ? 'rgba(255, 255, 255, 0.6)' : '#6b7280', fontWeight: 500 }}>
                Profile completion
              </Text>
            </div>
          </Card>

          <Card
            style={{
              width: 280,
              flex: '0 0 auto',
              background: isDarkMode ? '#1e1e1e' : '#fff',
              border: isDarkMode ? '1px solid #2c2c2c' : '1px solid #e5e7eb',
              borderRadius: 20,
              boxShadow: isDarkMode ? '0 4px 20px rgba(0, 0, 0, 0.3)' : '0 4px 20px rgba(0, 0, 0, 0.08)',
            }}
            className="hover:scale-105 transition-all duration-300 cursor-pointer"
            bodyStyle={{ padding: '28px' }}
            loading={statsLoading}
          >
            <div className="flex justify-between items-start">
              <div>
                <Text type="secondary" className="text-xs font-bold uppercase tracking-wider" style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.5)' : '#6b7280', letterSpacing: '0.05em' }}>Total Users</Text>
                <Title level={2} className="mb-0 mt-2" style={{ fontWeight: 900, color: '#8b5cf6', fontSize: '36px', lineHeight: 1 }}>{stats.total_users}</Title>
                <div className="mt-2 flex items-center gap-1">
                  <span style={{ fontSize: '12px', color: '#10b981', fontWeight: 600, background: isDarkMode ? 'rgba(16, 185, 129, 0.15)' : '#ecfdf5', padding: '4px 8px', borderRadius: '6px' }}>
                    ↑ 8% growth
                  </span>
                </div>
              </div>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center" style={{
                background: 'linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%)',
                boxShadow: '0 8px 16px rgba(139, 92, 246, 0.3)'
              }}>
                <UserOutlined style={{ fontSize: 28, color: '#fff' }} />
              </div>
            </div>
            <div className="mt-5 pt-4" style={{ borderTop: isDarkMode ? '1px solid #2c2c2c' : '1px solid #f3f4f6' }}>
              <Text style={{ fontSize: '13px', color: isDarkMode ? 'rgba(255, 255, 255, 0.6)' : '#6b7280', fontWeight: 500 }}>
                Registered users
              </Text>
            </div>
          </Card>
        </Space>

        {/* Filters */}
        <Card
          style={{ background: isDarkMode ? '#1e1e1e' : '#fff' }}
          className="border-0 rounded-2xl shadow-md mb-8"
        >
          <div className="flex flex-col lg:flex-row gap-4 items-start lg:items-center">
            <div className="flex-1">
              <Input
                placeholder="Search by name or email..."
                prefix={<SearchOutlined className="text-gray-400" />}
                className="h-12 border-gray-300 focus:border-orange-500"
                style={{ borderRadius: '12px', background: isDarkMode ? '#2c2c2c' : '#fff', border: isDarkMode ? 'none' : '1px solid #d9d9d9', color: isDarkMode ? '#fff' : 'inherit' }}
                onChange={(e) => handleSearch(e.target.value)}
              />
            </div>
            <div className="flex gap-3 flex-wrap">
              <Select
                placeholder="Signup method"
                className="min-w-[150px]"
                style={{ height: '48px' }}
                allowClear
                onChange={handleSignupMethod}
              >
                <Option value="email">
                  <div className="flex items-center">
                    <MailOutlined className="mr-2 text-blue-500" />
                    Email
                  </div>
                </Option>
                <Option value="google">
                  <div className="flex items-center">
                    <GoogleOutlined className="mr-2 text-red-500" />
                    Google
                  </div>
                </Option>
                <Option value="facebook">
                  <div className="flex items-center">
                    <UserOutlined className="mr-2 text-blue-600" />
                    Facebook
                  </div>
                </Option>
              </Select>
            </div>
          </div>
        </Card>

        {/* Table */}
        <Card
          style={{ background: isDarkMode ? '#1e1e1e' : '#fff' }}
          className="border-0 rounded-2xl shadow-md"
          bodyStyle={{ paddingTop: 16 }}
        >
          <div className="mb-6">
            <Title level={4} className="mb-0" style={{ color: isDarkMode ? '#fff' : 'inherit', fontWeight: 700 }}>Pending Approvals</Title>
            <Text type="secondary" className="text-sm" style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.45)' : 'inherit' }}>
              Review and approve organizer onboarding requests
            </Text>
          </div>
          <Table
            columns={columns}
            dataSource={organizers}
            rowKey="_id"
            loading={loading}
            bordered
            size="middle"
            sticky={{ offsetHeader: 64 }}
            locale={{ emptyText: <Empty description="No pending approvals" /> }}
            pagination={{
              current: page,
              pageSize,
              total,
              showSizeChanger: true,
              showQuickJumper: true,
              showTotal: (t, range) => (
                <span className="text-gray-600" style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.45)' : 'inherit' }}>Showing {range[0]} to {range[1]} of {t} approvals</span>
              ),
            }}
            onChange={(pagination) => {
              const nextPage = pagination.current || 1;
              const nextSize = pagination.pageSize || pageSize;
              setPageSize(nextSize);
              loadApprovals(nextPage, filters);
            }}
            scroll={{ x: 1000 }}
          />
        </Card>

        {/* Details Modal - Enhanced with all user info */}
        <Modal
          title={<span style={{ fontWeight: 700 }}>Organizer Details</span>}
          open={detailsVisible}
          onCancel={() => setDetailsVisible(false)}
          footer={[
            <Button key="close" onClick={() => setDetailsVisible(false)} style={{ borderRadius: '8px' }}>
              Close
            </Button>,
          ]}
          width={900}
        >
          {selectedOrganizer && (
            <div className="space-y-6 pt-4">
              {/* Profile Header */}
              <div className="flex items-center gap-4 p-4 rounded-xl" style={{ background: isDarkMode ? '#2c2c2c' : '#f8fafc', border: isDarkMode ? '1px solid #3c3c3c' : '1px solid #e2e8f0' }}>
                <Avatar size={64} style={{ backgroundColor: '#f97316' }} icon={<UserOutlined />} />
                <div className="flex-1">
                  <Title level={4} className="mb-1" style={{ fontWeight: 700, color: isDarkMode ? '#fff' : 'inherit' }}>
                    {selectedOrganizer.fullname}
                  </Title>
                  <Text type="secondary" style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.45)' : 'inherit' }}>
                    {selectedOrganizer.email}
                  </Text>
                </div>
                <Tag color="blue" style={{ fontWeight: 600, fontSize: 14 }}>
                  {selectedOrganizer.signup_method === 'google' ? <GoogleOutlined className="mr-1" /> : <MailOutlined className="mr-1" />}
                  {selectedOrganizer.signup_method?.toUpperCase()}
                </Tag>
              </div>

              {/* Detailed Information */}
              <Descriptions bordered column={2} labelStyle={{ fontWeight: 600, background: isDarkMode ? '#2c2c2c' : '#fafafa', color: isDarkMode ? '#fff' : 'inherit' }} contentStyle={{ background: isDarkMode ? '#1e1e1e' : '#fff', color: isDarkMode ? '#fff' : 'inherit' }}>
                <Descriptions.Item label="User ID">
                  <Text copyable style={{ color: isDarkMode ? '#fff' : 'inherit' }}>{selectedOrganizer._id}</Text>
                </Descriptions.Item>
                <Descriptions.Item label="Submitted">
                  <Space>
                    <ClockCircleOutlined />
                    <span style={{ fontSize: '13px' }}>
                      {selectedOrganizer.submitted_for_approval
                        ? new Date(selectedOrganizer.submitted_for_approval).toLocaleString()
                        : '—'}
                    </span>
                  </Space>
                </Descriptions.Item>
                <Descriptions.Item label="Phone">
                  <Space>
                    <PhoneOutlined />
                    <span>
                      {selectedOrganizer.phone ||
                       selectedOrganizer.num_tel ||
                       selectedOrganizer.onboarding_data?.phone ||
                       selectedOrganizer.onboarding_data?.num_tel ||
                       selectedOrganizer.onboarding_data?.phoneNumber ||
                       '—'}
                    </span>
                  </Space>
                </Descriptions.Item>
                <Descriptions.Item label="Country">
                  <Space>
                    <EnvironmentOutlined />
                    <span>
                      {selectedOrganizer.country ||
                       selectedOrganizer.pays_origine ||
                       selectedOrganizer.onboarding_data?.country ||
                       selectedOrganizer.onboarding_data?.pays_origine ||
                       selectedOrganizer.onboarding_data?.nationality ||
                       '—'}
                    </span>
                  </Space>
                </Descriptions.Item>
                <Descriptions.Item label="Preferred Language">
                  <Space>
                    <GlobalOutlined />
                    <span>
                      {selectedOrganizer.language ||
                       selectedOrganizer.langue_preferee ||
                       selectedOrganizer.preferred_language ||
                       selectedOrganizer.onboarding_data?.language ||
                       selectedOrganizer.onboarding_data?.langue_preferee ||
                       selectedOrganizer.onboarding_data?.preferred_language ||
                       '—'}
                    </span>
                  </Space>
                </Descriptions.Item>
                <Descriptions.Item label="Account Status">
                  <Tag color="orange" style={{ fontWeight: 600 }}>PENDING APPROVAL</Tag>
                </Descriptions.Item>
                <Descriptions.Item label="Specialities" span={2}>
                  <div className="flex flex-wrap gap-2">
                    {Array.isArray(selectedOrganizer.specialites_activites) && selectedOrganizer.specialites_activites.length > 0
                      ? selectedOrganizer.specialites_activites.map((spec, idx) => (
                          <Tag key={idx} color="blue" style={{ fontWeight: 500 }}>{spec}</Tag>
                        ))
                      : Array.isArray(selectedOrganizer.onboarding_data?.specialites_activites) && selectedOrganizer.onboarding_data.specialites_activites.length > 0
                      ? selectedOrganizer.onboarding_data.specialites_activites.map((spec, idx) => (
                          <Tag key={idx} color="blue" style={{ fontWeight: 500 }}>{spec}</Tag>
                        ))
                      : selectedOrganizer.specialities || selectedOrganizer.onboarding_data?.specialities
                      ? <Tag color="blue" style={{ fontWeight: 500 }}>{selectedOrganizer.specialities || selectedOrganizer.onboarding_data?.specialities}</Tag>
                      : <Text type="secondary">—</Text>
                    }
                  </div>
                </Descriptions.Item>
                <Descriptions.Item label="Languages Offered" span={2}>
                  <div className="flex flex-wrap gap-2">
                    {Array.isArray(selectedOrganizer.langues_proposees) && selectedOrganizer.langues_proposees.length > 0
                      ? selectedOrganizer.langues_proposees.map((lang, idx) => (
                          <Tag key={idx} color="green" style={{ fontWeight: 500 }}>{lang}</Tag>
                        ))
                      : Array.isArray(selectedOrganizer.onboarding_data?.langues_proposees) && selectedOrganizer.onboarding_data.langues_proposees.length > 0
                      ? selectedOrganizer.onboarding_data.langues_proposees.map((lang, idx) => (
                          <Tag key={idx} color="green" style={{ fontWeight: 500 }}>{lang}</Tag>
                        ))
                      : selectedOrganizer.languages_offered || selectedOrganizer.onboarding_data?.languages_offered
                      ? <Tag color="green" style={{ fontWeight: 500 }}>{selectedOrganizer.languages_offered || selectedOrganizer.onboarding_data?.languages_offered}</Tag>
                      : <Text type="secondary">—</Text>
                    }
                  </div>
                </Descriptions.Item>
                {selectedOrganizer.description || selectedOrganizer.onboarding_data?.description && (
                  <Descriptions.Item label="Description" span={2}>
                    <div className="p-4 rounded-xl" style={{ background: isDarkMode ? '#2c2c2c' : '#f8fafc', border: isDarkMode ? '1px solid #3c3c3c' : '1px solid #e2e8f0' }}>
                      {selectedOrganizer.description || selectedOrganizer.onboarding_data?.description}
                    </div>
                  </Descriptions.Item>
                )}
                {selectedOrganizer.experience || selectedOrganizer.onboarding_data?.experience && (
                  <Descriptions.Item label="Experience" span={2}>
                    <div className="p-4 rounded-xl" style={{ background: isDarkMode ? '#2c2c2c' : '#f8fafc', border: isDarkMode ? '1px solid #3c3c3c' : '1px solid #e2e8f0' }}>
                      {selectedOrganizer.experience || selectedOrganizer.onboarding_data?.experience}
                    </div>
                  </Descriptions.Item>
                )}
                {selectedOrganizer.certifications || selectedOrganizer.onboarding_data?.certifications && (
                  <Descriptions.Item label="Certifications" span={2}>
                    <div className="p-4 rounded-xl" style={{ background: isDarkMode ? 'rgba(16, 185, 129, 0.1)' : '#ecfdf5', border: isDarkMode ? '1px solid rgba(16, 185, 129, 0.2)' : '1px solid #d1fae5' }}>
                      {selectedOrganizer.certifications || selectedOrganizer.onboarding_data?.certifications}
                    </div>
                  </Descriptions.Item>
                )}
                {selectedOrganizer.website || selectedOrganizer.onboarding_data?.website && (
                  <Descriptions.Item label="Website" span={2}>
                    <a href={selectedOrganizer.website || selectedOrganizer.onboarding_data?.website} target="_blank" rel="noopener noreferrer" style={{ color: '#3b82f6' }}>
                      {selectedOrganizer.website || selectedOrganizer.onboarding_data?.website}
                    </a>
                  </Descriptions.Item>
                )}
                {/* Debug: Show available data */}
                <Descriptions.Item label="Available Data" span={2}>
                  <div className="p-4 rounded-xl" style={{ background: isDarkMode ? '#2c2c2c' : '#f8fafc', border: isDarkMode ? '1px solid #3c3c3c' : '1px solid #e2e8f0', maxHeight: '300px', overflow: 'auto' }}>
                    <pre style={{ fontSize: '11px', margin: 0 }}>
                      {JSON.stringify(selectedOrganizer, null, 2)}
                    </pre>
                  </div>
                </Descriptions.Item>
              </Descriptions>
            </div>
          )}
        </Modal>

        <Modal
          open={approveVisible}
          onOk={approve}
          onCancel={() => setApproveVisible(false)}
          okText="Approve"
          okButtonProps={{ style: { borderRadius: 8 } }}
          cancelButtonProps={{ style: { borderRadius: 8 } }}
        >
          Approve <b>{selectedOrganizer?.fullname}</b> ?
        </Modal>

        <Modal open={rejectVisible} onCancel={() => setRejectVisible(false)} footer={null} title="Reject organizer">
          <Form form={rejectForm} onFinish={reject} layout="vertical">
            <Form.Item name="reason" label="Reason" rules={[{ required: true, message: 'Please enter a reason' }]}>
              <TextArea rows={4} placeholder="Write the rejection reason..." style={{ borderRadius: '12px' }} />
            </Form.Item>
            <Space>
              <Button onClick={() => setRejectVisible(false)} style={{ borderRadius: 8 }}>
                Cancel
              </Button>
              <Button danger type="primary" htmlType="submit" style={{ borderRadius: 8 }}>
                Reject
              </Button>
            </Space>
          </Form>
        </Modal>
      </div>
    </ConfigProvider>
  );
};

export default Approvals;
