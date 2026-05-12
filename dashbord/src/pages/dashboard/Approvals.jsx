import { useState, useEffect, useCallback, useMemo } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Button from '@mui/material/Button';
import Dialog from '@mui/material/Dialog';
import Tooltip from '@mui/material/Tooltip';
import MenuItem from '@mui/material/MenuItem';
import TableRow from '@mui/material/TableRow';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TextField from '@mui/material/TextField';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import DialogTitle from '@mui/material/DialogTitle';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import TableContainer from '@mui/material/TableContainer';

import { DashboardContent } from 'src/layouts/dashboard';
import { onboardingService } from 'src/services/onboardingService';

import { Label } from 'src/components/label';
import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';
import { Scrollbar } from 'src/components/scrollbar';
import {
  useTable,
  emptyRows,
  rowInPage,
  getComparator,
  TableEmptyRows,
  TableHeadCustom,
  TablePaginationCustom,
} from 'src/components/table';

const TABLE_HEAD = [
  { id: 'fullname', label: 'Nom complet' },
  { id: 'email', label: 'Email' },
  { id: 'signup_method', label: "Méthode d'inscription" },
  { id: 'country', label: 'Pays' },
  { id: 'submitted_for_approval', label: 'Soumis le' },
  { id: 'wait_days', label: "Jours d'attente" },
  { id: 'actions', label: 'Actions', align: 'right' },
];

function normalizeApproval(org) {
  return {
    id: org?._id || org?.id,
    fullname: org?.fullname || '-',
    email: org?.email || '-',
    signup_method: org?.signup_method || 'email',
    country: org?.country || '-',
    submitted_for_approval: org?.onboarding_status?.submitted_at || org?.createdAt || null,
    wait_days: org?.onboarding_status?.wait_days || 0,
    details: org?.details || {},
  };
}

function statusColor(waitDays) {
  if (waitDays > 7) return 'error';
  if (waitDays > 3) return 'warning';
  return 'info';
}

export default function ApprovalsPage() {
  const table = useTable();
  const [organizers, setOrganizers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [signupMethodFilter, setSignupMethodFilter] = useState('all');

  const [selectedOrg, setSelectedOrg] = useState(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [confirmApproveOpen, setConfirmApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');

  const loadApprovals = useCallback(async () => {
    try {
      setLoading(true);
      const data = await onboardingService.getPendingApprovals();
      const rows = Array.isArray(data) ? data : (data.organizers || []);
      setOrganizers(rows.map(normalizeApproval));
    } catch (err) {
      toast.error('Erreur lors du chargement des approbations');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadApprovals();
  }, [loadApprovals]);

  const handleApprove = useCallback(async () => {
    try {
      if (!selectedOrg) return;
      await onboardingService.approveOrganizer(selectedOrg.id);
      toast.success('Organisateur approuvé');
      setConfirmApproveOpen(false);
      loadApprovals();
    } catch (err) {
      toast.error("Erreur lors de l'approbation");
    }
  }, [selectedOrg, loadApprovals]);

  const handleReject = useCallback(async () => {
    try {
      if (!selectedOrg) return;
      if (!rejectionReason.trim()) {
        toast.warning('Veuillez saisir une raison de rejet');
        return;
      }
      await onboardingService.rejectOrganizer(selectedOrg.id, rejectionReason);
      toast.success('Organisateur rejeté');
      setRejectOpen(false);
      setRejectionReason('');
      loadApprovals();
    } catch (err) {
      toast.error('Erreur lors du rejet');
    }
  }, [selectedOrg, rejectionReason, loadApprovals]);

  const handleFilterSearch = (event) => {
    setSearchQuery(event.target.value);
  };

  const handleFilterMethod = (event) => {
    setSignupMethodFilter(event.target.value);
  };

  const dataFiltered = useMemo(() => {
    const comparator = getComparator(table.order, table.orderBy);
    const stabilized = organizers.map((el, idx) => [el, idx]);
    stabilized.sort((a, b) => {
      const order = comparator(a[0], b[0]);
      if (order !== 0) return order;
      return a[1] - b[1];
    });
    let data = stabilized.map((el) => el[0]);

    if (searchQuery) {
      data = data.filter((row) =>
        row.fullname.toLowerCase().includes(searchQuery.toLowerCase()) ||
        row.email.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }
    if (signupMethodFilter !== 'all') {
      data = data.filter((row) => row.signup_method === signupMethodFilter);
    }
    return data;
  }, [organizers, searchQuery, signupMethodFilter, table.order, table.orderBy]);

  return (
    <DashboardContent maxWidth="xl">
      <Typography variant="h4" sx={{ mb: { xs: 3, md: 5 } }}>
        Approbations en attente
      </Typography>

      <Stack spacing={3}>
        <Card sx={{ p: 2.5 }}>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2}>
            <TextField
              fullWidth
              value={searchQuery}
              onChange={handleFilterSearch}
              placeholder="Rechercher par nom ou email..."
              InputProps={{
                startAdornment: <Iconify icon="eva:search-fill" sx={{ color: 'text.disabled', mr: 1 }} />,
              }}
            />
            <TextField
              select
              label="Méthode d'inscription"
              value={signupMethodFilter}
              onChange={handleFilterMethod}
              sx={{ minWidth: 200 }}
            >
              <MenuItem value="all">Toutes</MenuItem>
              <MenuItem value="email">Email</MenuItem>
              <MenuItem value="google">Google</MenuItem>
              <MenuItem value="facebook">Facebook</MenuItem>
            </TextField>
          </Stack>
        </Card>

        <Card>
          <Scrollbar>
            <TableContainer component={Paper}>
              <Table size={table.dense ? 'small' : 'medium'}>
                <TableHeadCustom
                  order={table.order}
                  orderBy={table.orderBy}
                  onSort={table.onSort}
                  headCells={TABLE_HEAD}
                  rowCount={dataFiltered.length}
                />

                <TableBody>
                  {rowInPage(dataFiltered, table.page, table.rowsPerPage).map((row) => (
                    <TableRow key={row.id}>
                      <TableCell>{row.fullname}</TableCell>
                      <TableCell>{row.email}</TableCell>
                      <TableCell>
                        <Label color="default">{row.signup_method}</Label>
                      </TableCell>
                      <TableCell>{row.country}</TableCell>
                      <TableCell>{row.submitted_for_approval ? new Date(row.submitted_for_approval).toLocaleDateString() : '-'}</TableCell>
                      <TableCell>
                        <Label color={statusColor(row.wait_days)}>
                          {row.wait_days} jours
                        </Label>
                      </TableCell>
                      <TableCell align="right">
                        <Tooltip title="Voir détails">
                          <IconButton onClick={() => { setSelectedOrg(row); setDetailsOpen(true); }}>
                            <Iconify icon="eva:eye-fill" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Approuver">
                          <IconButton color="success" onClick={() => { setSelectedOrg(row); setConfirmApproveOpen(true); }}>
                            <Iconify icon="eva:checkmark-circle-2-fill" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Rejeter">
                          <IconButton color="error" onClick={() => { setSelectedOrg(row); setRejectOpen(true); }}>
                            <Iconify icon="eva:close-circle-fill" />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                    </TableRow>
                  ))}

                  <TableEmptyRows height={table.dense ? 56 : 76} emptyRows={emptyRows(table.page, table.rowsPerPage, dataFiltered.length)} />
                </TableBody>
              </Table>
            </TableContainer>
          </Scrollbar>

          <Box sx={{ p: 2 }}>
            <TablePaginationCustom
              page={table.page}
              dense={table.dense}
              count={dataFiltered.length}
              rowsPerPage={table.rowsPerPage}
              onPageChange={table.onChangePage}
              onChangeDense={table.onChangeDense}
              onRowsPerPageChange={table.onChangeRowsPerPage}
            />
          </Box>
        </Card>
      </Stack>

      <Dialog open={detailsOpen} onClose={() => setDetailsOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>Détails de l'organisateur</DialogTitle>
        <DialogContent dividers>
          <Stack spacing={2}>
            <Typography variant="subtitle2">Nom: <Typography variant="body2" component="span">{selectedOrg?.fullname}</Typography></Typography>
            <Typography variant="subtitle2">Email: <Typography variant="body2" component="span">{selectedOrg?.email}</Typography></Typography>
            <Typography variant="subtitle2">Pays: <Typography variant="body2" component="span">{selectedOrg?.country}</Typography></Typography>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDetailsOpen(false)}>Fermer</Button>
        </DialogActions>
      </Dialog>

      <Dialog open={confirmApproveOpen} onClose={() => setConfirmApproveOpen(false)}>
        <DialogTitle>Confirmer l'approbation</DialogTitle>
        <DialogContent>
          Êtes-vous sûr de vouloir approuver <b>{selectedOrg?.fullname}</b> ?
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmApproveOpen(false)}>Annuler</Button>
          <Button variant="contained" color="success" onClick={handleApprove}>Approuver</Button>
        </DialogActions>
      </Dialog>

      <Dialog open={rejectOpen} onClose={() => setRejectOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Rejeter l'organisateur</DialogTitle>
        <DialogContent>
          <Typography sx={{ mb: 2 }}>Veuillez indiquer la raison du rejet pour <b>{selectedOrg?.fullname}</b> :</Typography>
          <TextField
            fullWidth
            multiline
            rows={3}
            value={rejectionReason}
            onChange={(e) => setRejectionReason(e.target.value)}
            placeholder="Ex: Documents incomplets, informations invalides..."
          />
<<<<<<< HEAD
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
                {/* Reason for Joining */}
                {selectedOrganizer.onboarding_data?.reasonToJoin && (
                  <Descriptions.Item label="Reason to Join" span={2}>
                    <div className="p-4 rounded-xl" style={{ 
                      background: isDarkMode ? 'rgba(16, 185, 129, 0.1)' : '#ecfdf5', 
                      border: isDarkMode ? '1px solid rgba(16, 185, 129, 0.2)' : '1px solid #d1fae5',
                      borderRadius: '12px'
                    }}>
                      <div style={{ marginBottom: '8px', fontSize: '13px', fontWeight: '600', color: isDarkMode ? '#10b981' : '#059669' }}>
                        Why they want to join DJTrip:
                      </div>
                      <div style={{ 
                        fontSize: '14px', 
                        lineHeight: '1.5',
                        color: isDarkMode ? 'rgba(255, 255, 255, 0.8)' : '#374151',
                        whiteSpace: 'pre-wrap',
                        wordBreak: 'break-word'
                      }}>
                        {selectedOrganizer.onboarding_data.reasonToJoin || 'No reason provided'}
                      </div>
                    </div>
                  </Descriptions.Item>
                )}

                {/* Enhanced Available Data */}
                <Descriptions.Item label="Available Data" span={2}>
                  <div style={{ 
                    background: '#ffffff', 
                    border: '1px solid #e5e7eb', 
                    borderRadius: '12px',
                    padding: '16px',
                    boxShadow: '0 4px 12px rgba(0, 0, 0, 0.1)'
                  }}>
                    {/* Header */}
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      justifyContent: 'space-between',
                      marginBottom: '16px',
                      padding: '12px 16px',
                      background: '#f8fafc',
                      borderRadius: '10px',
                      border: '1px solid #e2e8f0'
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{
                          width: '40px',
                          height: '40px',
                          borderRadius: '10px',
                          background: '#3b82f6',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          <FileTextOutlined style={{ fontSize: '20px', color: '#ffffff' }} />
                        </div>
                        <div>
                          <div style={{ 
                            fontSize: '16px', 
                            fontWeight: '700', 
                            color: '#1f2937',
                            marginBottom: '2px'
                          }}>
                            Complete Data Structure
                          </div>
                          <div style={{ 
                            fontSize: '12px', 
                            color: '#6b7280',
                            opacity: 0.8
                          }}>
                            Full organizer data object
                          </div>
                        </div>
                      </div>
                      <div style={{
                        padding: '4px 8px',
                        background: '#eff6ff',
                        borderRadius: '6px',
                        fontSize: '11px',
                        fontWeight: '600',
                        color: '#1d4ed8'
                      }}>
                        JSON
                      </div>
                    </div>

                    {/* Code Container */}
                    <div style={{ 
                      background: '#f9fafb',
                      borderRadius: '10px',
                      padding: '20px',
                      border: '1px solid #e5e7eb',
                      position: 'relative',
                      overflow: 'hidden'
                    }}>
                      {/* Copy indicator */}
                      <div style={{
                        position: 'absolute',
                        top: '8px',
                        right: '8px',
                        padding: '4px 8px',
                        background: '#f3f4f6',
                        borderRadius: '6px',
                        fontSize: '10px',
                        color: '#6b7280',
                        fontFamily: 'monospace'
                      }}>
                        {Object.keys(selectedOrganizer || {}).length} keys
                      </div>
                      
                      <pre style={{ 
                        fontSize: '13px', 
                        margin: 0, 
                        fontFamily: "'Fira Code', 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', 'Source Code Pro', monospace",
                        color: '#111827',
                        lineHeight: '1.6',
                        whiteSpace: 'pre-wrap',
                        wordBreak: 'break-word',
                        tabSize: 2
                      }}>
                        {JSON.stringify(selectedOrganizer, null, 2)}
                      </pre>
                    </div>

                    {/* Footer info */}
                    <div style={{
                      marginTop: '12px',
                      padding: '8px 12px',
                      background: '#f0f9ff',
                      borderRadius: '8px',
                      border: '1px solid #bae6fd'
                    }}>
                      <div style={{
                        fontSize: '12px',
                        color: '#1890ff',
                        fontWeight: '500',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px'
                      }}>
                        <div style={{
                          width: '6px',
                          height: '6px',
                          borderRadius: '50%',
                          background: '#1890ff'
                        }} />
                        All available organizer data including onboarding information
                      </div>
                    </div>
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
=======
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRejectOpen(false)}>Annuler</Button>
          <Button variant="contained" color="error" onClick={handleReject}>Rejeter</Button>
        </DialogActions>
      </Dialog>
    </DashboardContent>
>>>>>>> djtrip/DJTripx1
  );
}
