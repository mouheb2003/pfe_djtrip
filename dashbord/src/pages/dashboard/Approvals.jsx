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
      }}
    >
      <div className="mx-auto max-w-7xl p-6 space-y-8" style={{ color: isDarkMode ? '#fff' : 'inherit' }}>
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <Title level={2} className="mb-2" style={{ fontWeight: 800 }}>
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
            style={{ borderRadius: 10, height: 40 }}
          >
            Refresh
          </Button>
        </div>

        <Space size={16} style={{ display: 'flex', overflowX: 'auto', paddingBottom: 12 }}>
          <Card style={{ width: 260, flex: '0 0 auto', background: isDarkMode ? '#1e1e1e' : '#fff' }} loading={statsLoading}>
            <Text type="secondary" className="text-xs font-bold uppercase tracking-wider">
              Pending
            </Text>
            <Title level={2} className="mb-0" style={{ fontWeight: 900, color: '#f97316' }}>
              {stats.pending_approvals}
            </Title>
          </Card>
          <Card style={{ width: 260, flex: '0 0 auto', background: isDarkMode ? '#1e1e1e' : '#fff' }} loading={statsLoading}>
            <Text type="secondary" className="text-xs font-bold uppercase tracking-wider">
              Onboarded
            </Text>
            <Title level={2} className="mb-0" style={{ fontWeight: 900, color: '#3b82f6' }}>
              {stats.onboarded_users}
            </Title>
          </Card>
          <Card style={{ width: 260, flex: '0 0 auto', background: isDarkMode ? '#1e1e1e' : '#fff' }} loading={statsLoading}>
            <Text type="secondary" className="text-xs font-bold uppercase tracking-wider">
              Completion rate
            </Text>
            <Title level={2} className="mb-0" style={{ fontWeight: 900, color: '#10b981' }}>
              {stats.onboarding_completion_rate}%
            </Title>
          </Card>
        </Space>

        <Card style={{ background: isDarkMode ? '#1e1e1e' : '#fff' }}>
          <div className="flex flex-col lg:flex-row gap-4 items-start lg:items-center">
            <div className="flex-1">
              <Input
                placeholder="Search by name or email..."
                prefix={<SearchOutlined />}
                allowClear
                onChange={(e) => handleSearch(e.target.value)}
                style={{
                  height: 44,
                  borderRadius: 12,
                  background: isDarkMode ? '#2c2c2c' : '#fff',
                  border: isDarkMode ? 'none' : '1px solid #d9d9d9',
                  color: isDarkMode ? '#fff' : 'inherit',
                }}
              />
            </div>
            <Select
              placeholder="Signup method"
              allowClear
              onChange={handleSignupMethod}
              style={{ minWidth: 180, height: 44 }}
            >
              <Option value="email">Email</Option>
              <Option value="google">Google</Option>
              <Option value="facebook">Facebook</Option>
            </Select>
          </div>
        </Card>

        <Card style={{ background: isDarkMode ? '#1e1e1e' : '#fff' }}>
          <Table
            columns={columns}
            dataSource={organizers}
            rowKey="_id"
            loading={loading}
            bordered
            sticky={{ offsetHeader: 64 }}
            locale={{ emptyText: <Empty description="No pending approvals" /> }}
            pagination={{
              current: page,
              pageSize,
              total,
              showSizeChanger: true,
              showQuickJumper: true,
              showTotal: (t, range) => (
                <span style={{ color: isDarkMode ? 'rgba(255, 255, 255, 0.45)' : 'inherit' }}>
                  Showing {range[0]} to {range[1]} of {t}
                </span>
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

        <Modal
          title={<span style={{ fontWeight: 800 }}>Organizer details</span>}
          open={detailsVisible}
          onCancel={() => setDetailsVisible(false)}
          footer={[
            <Button key="close" onClick={() => setDetailsVisible(false)} style={{ borderRadius: 8 }}>
              Close
            </Button>,
          ]}
          width={860}
        >
          {selectedOrganizer && (
            <Descriptions bordered column={2}>
              <Descriptions.Item label="Name">{selectedOrganizer.fullname}</Descriptions.Item>
              <Descriptions.Item label="Email">{selectedOrganizer.email}</Descriptions.Item>
              <Descriptions.Item label="Signup method">{selectedOrganizer.signup_method}</Descriptions.Item>
              <Descriptions.Item label="Submitted">
                {selectedOrganizer.submitted_for_approval
                  ? new Date(selectedOrganizer.submitted_for_approval).toLocaleString()
                  : '—'}
              </Descriptions.Item>
              <Descriptions.Item label="Phone" span={2}>
                {selectedOrganizer.onboarding_data?.num_tel || selectedOrganizer.onboarding_data?.phone || '—'}
              </Descriptions.Item>
              <Descriptions.Item label="Country">
                {selectedOrganizer.onboarding_data?.pays_origine || selectedOrganizer.onboarding_data?.country || '—'}
              </Descriptions.Item>
              <Descriptions.Item label="Preferred language">
                {selectedOrganizer.onboarding_data?.langue_preferee || selectedOrganizer.onboarding_data?.language || '—'}
              </Descriptions.Item>
              <Descriptions.Item label="Specialities" span={2}>
                {Array.isArray(selectedOrganizer.onboarding_data?.specialites_activites)
                  ? selectedOrganizer.onboarding_data.specialites_activites.join(', ')
                  : '—'}
              </Descriptions.Item>
              <Descriptions.Item label="Languages offered" span={2}>
                {Array.isArray(selectedOrganizer.onboarding_data?.langues_proposees)
                  ? selectedOrganizer.onboarding_data.langues_proposees.join(', ')
                  : '—'}
              </Descriptions.Item>
            </Descriptions>
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
              <TextArea rows={4} placeholder="Write the rejection reason..." />
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
