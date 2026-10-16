import React, { useState } from 'react';
import {
  View, Text, ScrollView, TouchableOpacity, TextInput, StyleSheet, Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { useApp } from '../storage/AppContext';
import { COLORS, BANKS } from '../constants';
import { fmt, fmtDateFull, daysUntil, AmountInput, Label, DaysBadge, BackBtn, todayStr, DatePickerModal } from '../components';

export default function BankScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { deposits, addDeposit, delDeposit, editDepositAmount } = useApp();
  const [showForm,   setShowForm]   = useState(false);
  const [amount,     setAmount]     = useState('');
  const [bank,       setBank]       = useState('MB');
  const [dueDate,    setDueDate]    = useState(new Date());
  const [showPicker, setShowPicker] = useState(false);
  const [note,       setNote]       = useState('');
  const [editId,     setEditId]     = useState(null);
  const [editAmt,    setEditAmt]    = useState('');

  const totalDeposited = deposits.reduce((s, d) => s + d.amount, 0);

  const handleAdd = () => {
    if (!amount || isNaN(amount)) return;
    addDeposit({
      id: Date.now(),
      amount: +amount,
      bank,
      dueDate: dueDate.toISOString().split('T')[0],
      note: note || '',
      date: todayStr(),
    });
    setAmount(''); setNote(''); setShowForm(false);
  };

  const handleEditSave = (id) => {
    const v = parseInt(editAmt, 10);
    if (!isNaN(v) && v > 0) editDepositAmount(id, v);
    setEditId(null); setEditAmt('');
  };

  const sorted = [...deposits].sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate));

  return (
    <ScrollView style={styles.container} contentContainerStyle={{ paddingBottom: 100 }} showsVerticalScrollIndicator={false}>
      <LinearGradient colors={['#1A1A2E', '#0f1a2e']} style={[styles.header, { paddingTop: insets.top + 20 }]}>
        <BackBtn onPress={() => navigation.goBack()} />
        <View style={styles.headerRow}>
          <View>
            <Text style={styles.pageLabel}>TIỀN GỬI NGÂN HÀNG</Text>
            <Text style={styles.totalAmt}>{fmt(totalDeposited).replace('₫', '')}
              <Text style={{ fontSize: 18, color: COLORS.purple }}> ₫</Text>
            </Text>
            <Text style={styles.sub}>🏦 {deposits.length} khoản đang gửi</Text>
          </View>
          <TouchableOpacity onPress={() => setShowForm(v => !v)} style={styles.addBtn}>
            <Text style={{ color: COLORS.purple, fontSize: 26 }}>+</Text>
          </TouchableOpacity>
        </View>

        {/* Bank breakdown */}
        <View style={styles.bankRow}>
          {BANKS.map(b => {
            const total = deposits.filter(d => d.bank === b.id).reduce((s, d) => s + d.amount, 0);
            return (
              <View key={b.id} style={[styles.bankChip, { backgroundColor: b.bg, borderColor: b.color + '44' }]}>
                <Text style={[styles.bankId, { color: b.color }]}>{b.id}</Text>
                <Text style={styles.bankTotal}>{total > 0 ? (total/1_000_000).toFixed(1)+'tr' : '—'}</Text>
              </View>
            );
          })}
        </View>
      </LinearGradient>

      {/* Add form */}
      {showForm && (
        <View style={styles.form}>
          <Text style={styles.formTitle}>Thêm khoản gửi</Text>

          <View style={styles.inputCard}>
            <Label>Số tiền gửi</Label>
            <View style={styles.amtRow}>
              <Text style={[styles.currency, { color: COLORS.purple }]}>₫</Text>
              <AmountInput value={amount} onChange={setAmount} color={COLORS.purple} />
            </View>
          </View>

          <Label>Ngân hàng</Label>
          <View style={styles.bankSelect}>
            {BANKS.map(b => (
              <TouchableOpacity key={b.id} onPress={() => setBank(b.id)}
                style={[styles.bankSelectBtn, {
                  backgroundColor: bank === b.id ? b.bg : COLORS.card,
                  borderColor:     bank === b.id ? b.color : 'rgba(255,255,255,0.05)',
                }]}>
                <Text style={[styles.bankSelectId, { color: bank === b.id ? b.color : COLORS.subtext }]}>{b.id}</Text>
                <Text style={[{ fontSize: 10, fontWeight: '600', color: bank === b.id ? COLORS.subtext : '#4B5563' }]}>{b.label}</Text>
              </TouchableOpacity>
            ))}
          </View>

          <TouchableOpacity onPress={() => setShowPicker(true)} style={styles.inputCard}>
            <Label>Ngày đến hạn</Label>
            <Text style={{ color: COLORS.text, fontSize: 17, fontWeight: '700' }}>
              {dueDate.toLocaleDateString('vi-VN')}
            </Text>
          </TouchableOpacity>

          <DatePickerModal
            visible={showPicker}
            date={dueDate}
            onConfirm={(d) => { setDueDate(d); setShowPicker(false); }}
            onCancel={() => setShowPicker(false)}
          />

          <View style={styles.inputCard}>
            <Label>Ghi chú (tuỳ chọn)</Label>
            <TextInput value={note} onChangeText={setNote}
              placeholder="Kỳ hạn 6 tháng, lãi 7%..."
              placeholderTextColor={COLORS.subtext}
              style={{ color: COLORS.text, fontSize: 15 }}
            />
          </View>

          <TouchableOpacity onPress={handleAdd}
            style={[styles.saveBtn, { backgroundColor: amount ? COLORS.purple : COLORS.card }]}>
            <Text style={[styles.saveBtnText, { color: amount ? '#fff' : COLORS.subtext }]}>LƯU KHOẢN GỬI</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* List */}
      <View style={{ padding: 24 }}>
        {deposits.length === 0 && !showForm && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <Text style={{ fontSize: 36, marginBottom: 10 }}>🏛️</Text>
            <Text style={{ color: COLORS.subtext, fontSize: 14 }}>Chưa có khoản gửi nào</Text>
          </View>
        )}
        {sorted.map(d => {
          const b    = BANKS.find(x => x.id === d.bank) || BANKS[0];
          const days = daysUntil(d.dueDate);
          const over = days < 0; const urgent = !over && days <= 7;
          return (
            <View key={d.id} style={[styles.depCard, {
              borderColor: over ? 'rgba(255,107,107,0.22)' : urgent ? 'rgba(255,179,71,0.22)' : COLORS.border,
            }]}>
              <View style={styles.depTop}>
                <View style={[styles.bankTag, { backgroundColor: b.bg, borderColor: b.color + '55' }]}>
                  <Text style={[styles.bankTagText, { color: b.color }]}>{b.id}</Text>
                </View>
                <View style={{ flex: 1, marginLeft: 10 }}>
                  {editId === d.id ? (
                    <View style={styles.editRow}>
                      <Text style={{ color: COLORS.purple, fontSize: 16, fontWeight: '700' }}>₫</Text>
                      <AmountInput value={editAmt} onChange={setEditAmt} color={COLORS.purple}
                        style={{ fontSize: 20, flex: 1, marginLeft: 6 }} />
                      <TouchableOpacity onPress={() => handleEditSave(d.id)} style={styles.editConfirm}>
                        <Text style={{ color: '#0F0F14', fontWeight: '800', fontSize: 13 }}>✓</Text>
                      </TouchableOpacity>
                      <TouchableOpacity onPress={() => setEditId(null)} style={styles.editCancel}>
                        <Text style={{ color: COLORS.subtext, fontSize: 13 }}>✕</Text>
                      </TouchableOpacity>
                    </View>
                  ) : (
                    <TouchableOpacity onPress={() => { setEditId(d.id); setEditAmt(String(d.amount)); }}>
                      <Text style={styles.depAmt}>{fmt(d.amount)}</Text>
                      <Text style={{ color: COLORS.subtext, fontSize: 11, marginTop: 2 }}>✏️ Chạm để sửa</Text>
                    </TouchableOpacity>
                  )}
                  {d.note ? <Text style={{ color: COLORS.subtext, fontSize: 12, marginTop: 2 }}>{d.note}</Text> : null}
                </View>
                <TouchableOpacity onPress={() =>
                  Alert.alert('Xoá', 'Xoá khoản gửi này?', [
                    { text: 'Huỷ' },
                    { text: 'Xoá', style: 'destructive', onPress: () => delDeposit(d.id) },
                  ])
                } style={styles.delBtn}>
                  <Text style={{ color: COLORS.red, fontSize: 13 }}>✕</Text>
                </TouchableOpacity>
              </View>
              <View style={styles.depBottom}>
                <View>
                  <Text style={styles.dueLabel}>ĐẾN HẠN</Text>
                  <Text style={styles.dueValue}>{fmtDateFull(d.dueDate)}</Text>
                </View>
                <DaysBadge days={days} />
              </View>
            </View>
          );
        })}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:     { flex: 1, backgroundColor: COLORS.bg },
  header:        { padding: 24 },
  headerRow:     { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  pageLabel:     { color: COLORS.subtext, fontSize: 11, fontWeight: '700', letterSpacing: 1 },
  totalAmt:      { color: COLORS.text, fontSize: 32, fontWeight: '800', marginTop: 4 },
  sub:           { color: COLORS.subtext, fontSize: 13, marginTop: 5 },
  addBtn:        { backgroundColor: 'rgba(195,166,255,0.12)', borderWidth: 1, borderColor: 'rgba(195,166,255,0.28)', borderRadius: 16, width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  bankRow:       { flexDirection: 'row', gap: 10, marginTop: 18 },
  bankChip:      { flex: 1, borderRadius: 14, padding: 12, borderWidth: 1 },
  bankId:        { fontSize: 12, fontWeight: '800' },
  bankTotal:     { color: COLORS.text, fontSize: 14, fontWeight: '700', marginTop: 6 },
  form:          { margin: 24, backgroundColor: COLORS.card, borderRadius: 20, padding: 18, borderWidth: 1, borderColor: COLORS.border },
  formTitle:     { color: COLORS.text, fontSize: 18, fontWeight: '800', marginBottom: 16 },
  inputCard:     { backgroundColor: '#252540', borderRadius: 16, padding: 14, marginBottom: 12, borderWidth: 1, borderColor: COLORS.border },
  amtRow:        { flexDirection: 'row', alignItems: 'center', gap: 8 },
  currency:      { fontSize: 22, fontWeight: '700' },
  bankSelect:    { flexDirection: 'row', gap: 10, marginBottom: 12 },
  bankSelectBtn: { flex: 1, borderRadius: 14, padding: 12, alignItems: 'center', borderWidth: 2 },
  bankSelectId:  { fontSize: 14, fontWeight: '800' },
  saveBtn:       { borderRadius: 16, padding: 15, alignItems: 'center', marginTop: 4 },
  saveBtnText:   { fontSize: 14, fontWeight: '800', letterSpacing: 1 },
  depCard:       { backgroundColor: COLORS.card, borderRadius: 18, padding: 16, marginBottom: 12, borderWidth: 1 },
  depTop:        { flexDirection: 'row', alignItems: 'flex-start' },
  bankTag:       { borderWidth: 1, borderRadius: 12, paddingHorizontal: 10, paddingVertical: 6 },
  bankTagText:   { fontSize: 13, fontWeight: '800' },
  depAmt:        { color: COLORS.text, fontSize: 17, fontWeight: '800' },
  depBottom:     { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 12, paddingTop: 12, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' },
  dueLabel:      { color: COLORS.subtext, fontSize: 10, fontWeight: '700', letterSpacing: 1 },
  dueValue:      { color: COLORS.text, fontSize: 13, fontWeight: '700', marginTop: 3 },
  delBtn:        { backgroundColor: 'rgba(255,107,107,0.08)', borderRadius: 8, padding: 6, marginLeft: 8 },
  editRow:       { flexDirection: 'row', alignItems: 'center', gap: 6 },
  editConfirm:   { backgroundColor: COLORS.green, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 5 },
  editCancel:    { backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 8, paddingHorizontal: 8, paddingVertical: 5 },
});
