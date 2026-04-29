# Refund Decision Engine - Guide de Test Manuel

## Méthode 1: Test via Node.js (CLI)

### Exécuter tous les tests automatiques
```bash
cd Back
node tests/refundDecisionEngine.test.js
```

### Mode interactif (tester vos propres scénarios)
```bash
cd Back
node tests/refundDecisionEngine.test.js interactive
```

Le mode interactif vous demandera de saisir:
- user_role (tourist/organizer/admin)
- action (cancel/delete_activity/auto_approve_timeout/activity_started)
- time_before_activity_hours (nombre)
- activity_status (pending/approved/cancelled/started/completed)
- payment_status (paid/pending/failed/refunded)

---

## Méthode 2: Test via API (Postman/curl)

### Endpoint: POST /api/refund/decide

**Headers:**
```
Authorization: Bearer <your_jwt_token>
Content-Type: application/json
```

### Cas de Test 1: Touriste annule 48h avant (80% remboursement)
```bash
curl -X POST http://localhost:5000/api/refund/decide \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_role": "tourist",
    "action": "cancel",
    "time_before_activity_hours": 48,
    "activity_status": "approved",
    "payment_status": "paid"
  }'
```

**Résultat attendu:**
```json
{
  "refund_type": "partial",
  "refund_percentage": 80,
  "reason": "Tourist cancelled more than 24 hours before activity - partial refund (80%)",
  "stripe_action": "refund"
}
```

### Cas de Test 2: Touriste annule 12h avant (50% remboursement)
```bash
curl -X POST http://localhost:5000/api/refund/decide \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_role": "tourist",
    "action": "cancel",
    "time_before_activity_hours": 12,
    "activity_status": "approved",
    "payment_status": "paid"
  }'
```

**Résultat attendu:**
```json
{
  "refund_type": "partial",
  "refund_percentage": 50,
  "reason": "Tourist cancelled less than 24 hours before activity - partial refund (50%)",
  "stripe_action": "refund"
}
```

### Cas de Test 3: Organisateur supprime l'activité (100% remboursement)
```bash
curl -X POST http://localhost:5000/api/refund/decide \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_role": "organizer",
    "action": "delete_activity",
    "time_before_activity_hours": 48,
    "activity_status": "approved",
    "payment_status": "paid"
  }'
```

**Résultat attendu:**
```json
{
  "refund_type": "full",
  "refund_percentage": 100,
  "reason": "Organizer deleted activity or approval timeout - full refund",
  "stripe_action": "refund"
}
```

### Cas de Test 4: Activité déjà commencée (0% remboursement)
```bash
curl -X POST http://localhost:5000/api/refund/decide \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_role": "tourist",
    "action": "cancel",
    "time_before_activity_hours": -1,
    "activity_status": "started",
    "payment_status": "paid"
  }'
```

**Résultat attendu:**
```json
{
  "refund_type": "none",
  "refund_percentage": 0,
  "reason": "Activity already started or tourist participated - no refund",
  "stripe_action": "no_refund"
}
```

### Cas de Test 5: Paiement non effectué (0% remboursement)
```bash
curl -X POST http://localhost:5000/api/refund/decide \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_role": "tourist",
    "action": "cancel",
    "time_before_activity_hours": 48,
    "activity_status": "approved",
    "payment_status": "pending"
  }'
```

**Résultat attendu:**
```json
{
  "refund_type": "none",
  "refund_percentage": 0,
  "reason": "Payment not completed - no refund applicable",
  "stripe_action": "no_refund"
}
```

---

## Méthode 3: Test direct dans le code (Node.js)

Créer un fichier temporaire `test-refund-manual.js`:

```javascript
const RefundDecisionEngine = require('./services/refundDecisionEngine');

// Test 1: Tourist cancels 48h before
const test1 = {
  user_role: 'tourist',
  action: 'cancel',
  time_before_activity_hours: 48,
  activity_status: 'approved',
  payment_status: 'paid'
};

console.log('Test 1 - Tourist cancels 48h before:');
console.log(JSON.stringify(RefundDecisionEngine.decideRefund(test1), null, 2));
console.log('\n');

// Test 2: Tourist cancels 12h before
const test2 = {
  user_role: 'tourist',
  action: 'cancel',
  time_before_activity_hours: 12,
  activity_status: 'approved',
  payment_status: 'paid'
};

console.log('Test 2 - Tourist cancels 12h before:');
console.log(JSON.stringify(RefundDecisionEngine.decideRefund(test2), null, 2));
console.log('\n');

// Test 3: Organizer deletes activity
const test3 = {
  user_role: 'organizer',
  action: 'delete_activity',
  time_before_activity_hours: 48,
  activity_status: 'approved',
  payment_status: 'paid'
};

console.log('Test 3 - Organizer deletes activity:');
console.log(JSON.stringify(RefundDecisionEngine.decideRefund(test3), null, 2));
console.log('\n');

// Test 4: Activity already started
const test4 = {
  user_role: 'tourist',
  action: 'cancel',
  time_before_activity_hours: -1,
  activity_status: 'started',
  payment_status: 'paid'
};

console.log('Test 4 - Activity already started:');
console.log(JSON.stringify(RefundDecisionEngine.decideRefund(test4), null, 2));
console.log('\n');

// Test 5: Payment not paid
const test5 = {
  user_role: 'tourist',
  action: 'cancel',
  time_before_activity_hours: 48,
  activity_status: 'approved',
  payment_status: 'pending'
};

console.log('Test 5 - Payment not paid:');
console.log(JSON.stringify(RefundDecisionEngine.decideRefund(test5), null, 2));
```

Exécuter:
```bash
cd Back
node test-refund-manual.js
```

---

## Méthode 4: Test via Dashboard React

### Ajouter un composant de test dans le dashboard

Créer `dashbord/src/pages/admin/RefundTest.jsx`:

```jsx
import React, { useState } from 'react';
import { Card, Button, Form, InputNumber, Select, message, Spin } from 'antd';
import axios from 'axios';

const { Option } = Select;

const RefundTest = () => {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [form] = Form.useForm();

  const onFinish = async (values) => {
    setLoading(true);
    try {
      const response = await axios.post('/api/refund/decide', values, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`
        }
      });
      setResult(response.data.decision);
      message.success('Decision retrieved successfully');
    } catch (error) {
      message.error('Error getting decision');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card title="Refund Decision Engine Test" style={{ maxWidth: 800, margin: '0 auto' }}>
      <Form form={form} onFinish={onFinish} layout="vertical">
        <Form.Item
          name="user_role"
          label="User Role"
          rules={[{ required: true }]}
        >
          <Select>
            <Option value="tourist">Tourist</Option>
            <Option value="organizer">Organizer</Option>
            <Option value="admin">Admin</Option>
          </Select>
        </Form.Item>

        <Form.Item
          name="action"
          label="Action"
          rules={[{ required: true }]}
        >
          <Select>
            <Option value="cancel">Cancel</Option>
            <Option value="delete_activity">Delete Activity</Option>
            <Option value="auto_approve_timeout">Auto Approve Timeout</Option>
            <Option value="activity_started">Activity Started</Option>
          </Select>
        </Form.Item>

        <Form.Item
          name="time_before_activity_hours"
          label="Hours Before Activity"
          rules={[{ required: true }]}
        >
          <InputNumber style={{ width: '100%' }} />
        </Form.Item>

        <Form.Item
          name="activity_status"
          label="Activity Status"
          rules={[{ required: true }]}
        >
          <Select>
            <Option value="pending">Pending</Option>
            <Option value="approved">Approved</Option>
            <Option value="cancelled">Cancelled</Option>
            <Option value="started">Started</Option>
            <Option value="completed">Completed</Option>
          </Select>
        </Form.Item>

        <Form.Item
          name="payment_status"
          label="Payment Status"
          rules={[{ required: true }]}
        >
          <Select>
            <Option value="paid">Paid</Option>
            <Option value="pending">Pending</Option>
            <Option value="failed">Failed</Option>
            <Option value="refunded">Refunded</Option>
          </Select>
        </Form.Item>

        <Form.Item>
          <Button type="primary" htmlType="submit" loading={loading}>
            Get Refund Decision
          </Button>
        </Form.Item>
      </Form>

      {result && (
        <Card title="Decision Result" style={{ marginTop: 16, backgroundColor: '#f5f5f5' }}>
          <pre>{JSON.stringify(result, null, 2)}</pre>
        </Card>
      )}
    </Card>
  );
};

export default RefundTest;
```

---

## Scénarios de Test Recommandés

### Scénario A: Annulation normale (24h+ avant)
- user_role: tourist
- action: cancel
- time_before_activity_hours: 48
- activity_status: approved
- payment_status: paid
- **Attendu**: 80% remboursement

### Scénario B: Annulation tardive (<24h avant)
- user_role: tourist
- action: cancel
- time_before_activity_hours: 12
- activity_status: approved
- payment_status: paid
- **Attendu**: 50% remboursement

### Scénario C: Suppression par organisateur
- user_role: organizer
- action: delete_activity
- time_before_activity_hours: 48
- activity_status: approved
- payment_status: paid
- **Attendu**: 100% remboursement

### Scénario D: Activité déjà commencée
- user_role: tourist
- action: cancel
- time_before_activity_hours: -1
- activity_status: started
- payment_status: paid
- **Attendu**: 0% remboursement

### Scénario E: Timeout d'approbation
- user_role: admin
- action: auto_approve_timeout
- time_before_activity_hours: 0
- activity_status: pending
- payment_status: paid
- **Attendu**: 100% remboursement

### Scénario F: Paiement non effectué
- user_role: tourist
- action: cancel
- time_before_activity_hours: 48
- activity_status: approved
- payment_status: pending
- **Attendu**: 0% remboursement

---

## Checklist de Validation

- [ ] Tourist cancel >24h → 80% refund
- [ ] Tourist cancel <24h → 50% refund
- [ ] Organizer delete activity → 100% refund
- [ ] Activity timeout without approval → 100% refund
- [ ] Activity started → 0% refund
- [ ] Payment not paid → 0% refund
- [ ] Validation des champs obligatoires
- [ ] Validation des valeurs valides
- [ ] Gestion des cas limites (exactement 24h, 0h)
