import React, { useState } from 'react';
import {
  View, Text, ScrollView, TouchableOpacity, TextInput, StyleSheet, Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { useApp } from '../storage/AppContext';
import { COLORS } from '../constants';
import { fmt, fmtDateFull, fmtDate, daysUntil, AmountInput, Label, DaysBadge, BackBtn, todayStr, DatePickerModal } from '../components';

export default function LoansScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { loans, addLoan, delLoan, markLoanPaid, partialPayLoan } = useApp();

  // Add form
  const [showForm,    setShowForm]    = useState(false);
  const [amount,      setAmount]      = useState('');
  const [borrower,    setBorrower]    = useState('');
  const [loanDate,    setLoanDate]    = useState(new Date());
  const [dueDate,     setDueDate]     = useState(null);
  const [note,        setNote]        = useState('');
  const [pickerFor,   setPickerFor]   = useState(null); // 'loan' | 'due'
  const [partialId,   setPartialId]   = useState(null);
  const [partialAmt,  setPartialAmt]  = useState('');

  const active = loans.filter(l => !l.paid);
  const paid   = loans.filter(l => l.paid);
  const totalLoaned = active.reduce((s, l) => s + l.amount, 0);

  const byBorrower = active.reduce((acc, l) => {
    (acc[l.borrower] = acc[l.borrower] || []).push(l);
    return acc;
  }, {});

  const handleAdd = () => {
    if (!amount || !borrower.trim()) return;
    addLoan({
      id: Date.now(),
      amount: +amount,
      borrower: borrower.trim(),
      loanDate: loanDate.toISOString().split('T')[0],
      dueDate:  dueDate ? dueDate.toISOString().split('T')[0] : null,
      note: note || '',
      paid: false,
      paidDate: null,
      payments: [],
    });
    setAmount(''); setBorrower(''); setNote(''); setDueDate(null);
    setShowForm(false);
  };

  const handlePartial = (id) => {
    const v = parseInt(partialAmt, 10);
    if (!isNaN(v) && v > 0) { partialPayLoan(id, v); setPartialId(null); setPartialAmt(''); }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={{ paddingBottom: 100 }} showsVerticalScrollIndicator={false}>
      <LinearGradient colors={['#1A1A2E', '#1a1500']} style={[styles.header, { paddingTop: insets.top + 20 }]}>
        <BackBtn onPress={() => navigation.goBack()} />
        <View style={styles.headerRow}>
          <View>
            <Text style={styles.pageLabel}>CHO VAY</Text>
            <Text style={styles.totalAmt}>{fmt(totalLoaned).replace('₫', '')}
              <Text style={{ fontSize: 18, color: COLORS.orange }}> ₫</Text>
            </Text>
            <Text style={styles.sub}>🤝 {active.length} chưa thu · {paid.length} đã thu</Text>
          </View>
          <TouchableOpacity onPress={() => setShowForm(v => !v)} style={styles.addBtn}>
            <Text style={{ color: COLORS.orange, fontSize: 26 }}>+</Text>
          </TouchableOpacity>
        </View>

        {/* Borrower chips */}
        {Object.keys(byBorrower).length > 0 && (
          <View style={styles.chipRow}>
            {Object.entries(byBorrower).map(([name, items]) => (
              <View key={name} style={styles.chip}>
                <Text style={styles.chipName}>{name}</Text>
                <Text style={styles.chipAmt}>{(items.reduce((s,l)=>s+l.amount,0)/1_000_000).toFixed(2)}tr</Text>
              </View>
            ))}
          </View>
        )}
      </LinearGradient>

      {/* Add form */}
      {showForm && (
        <View style={styles.form}>
          <Text style={styles.formTitle}>Thêm khoản cho vay</Text>

          <View style={styles.inputCard}>
            <Label>Số tiền cho vay</Label>
            <View style={styles.amtRow}>
              <Text style={[styles.currency, { color: COLORS.orange }]}>₫</Text>
              <AmountInput value={amount} onChange={setAmount} color={COLORS.orange} />
            </View>
          </View>

          <View style={styles.inputCard}>
            <Label>Người vay</Label>
            <TextInput value={borrower} onChangeText={setBorrower}
              placeholder="Tên người vay..." placeholderTextColor={COLORS.subtext}
              style={{ color: COLORS.text, fontSize: 18, fontWeight: '700' }} />
          </View>

          <TouchableOpacity onPress={() => setPickerFor('loan')} style={styles.inputCard}>
            <Label>Ngày vay</Label>
            <Text style={{ color: COLORS.text, fontSize: 16, fontWeight: '600' }}>
              {loanDate.toLocaleDateString('vi-VN')}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={() => setPickerFor('due')} style={styles.inputCard}>
            <Label>Ngày dự định trả (tuỳ chọn)</Label>
            <Text style={{ color: dueDate ? COLORS.text : COLORS.subtext, fontSize: 16, fontWeight: '600' }}>
              {dueDate ? dueDate.toLocaleDateString('vi-VN') : 'Chưa đặt'}
            </Text>
          </TouchableOpacity>

          <DatePickerModal
            visible={!!pickerFor}
            date={pickerFor === 'loan' ? loanDate : (dueDate || new Date())}
            onConfirm={(date) => {
              if (pickerFor === 'loan') setLoanDate(date);
              else setDueDate(date);
              setPickerFor(null);
            }}
            onCancel={() => setPickerFor(null)}
          />

          <View style={styles.inputCard}>
            <Label>Ghi chú (tuỳ chọn)</Label>
            <TextInput value={note} onChangeText={setNote}
              placeholder="Mục đích vay..." placeholderTextColor={COLORS.subtext}
              style={{ color: COLORS.text, fontSize: 15 }} />
          </View>

          <TouchableOpacity onPress={handleAdd}
            style={[styles.saveBtn, { backgroundColor: amount && borrower ? '#FFB347' : COLORS.card }]}>
            <Text style={[styles.saveBtnText, { color: amount && borrower ? '#fff' : COLORS.subtext }]}>
              LƯU KHOẢN CHO VAY
            </Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Active loans */}
      <View style={{ padding: 24 }}>
        {loans.length === 0 && !showForm && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <Text style={{ fontSize: 36, marginBottom: 10 }}>🤝</Text>
            <Text style={{ color: COLORS.subtext, fontSize: 14 }}>Chưa có khoản cho vay nào</Text>
          </View>
        )}

        {Object.entries(byBorrower).map(([name, items]) => (
          <View key={name} style={{ marginBottom: 24 }}>
            <View style={styles.borrowerHeader}>
              <View style={styles.avatar}><Text style={styles.avatarText}>{name.charAt(0).toUpperCase()}</Text></View>
              <Text style={styles.borrowerName}>{name}</Text>
              <Text style={styles.borrowerTotal}>· {fmt(items.reduce((s,l)=>s+l.amount,0))}</Text>
            </View>

            {[...items].sort((a,b) => (a.dueDate||'9999') > (b.dueDate||'9999') ? 1 : -1).map(l => {
              const days   = l.dueDate ? daysUntil(l.dueDate) : null;
              const over   = days !== null && days < 0;
              const urgent = days !== null && !over && days <= 7;
              return (
                <View key={l.id} style={[styles.loanCard, {
                  borderColor: over ? 'rgba(255,107,107,0.2)' : urgent ? 'rgba(255,179,71,0.2)' : COLORS.border,
                }]}>
                  <View style={styles.loanTop}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.loanAmt}>{fmt(l.amount)}</Text>
                      <Text style={styles.loanDate}>Ngày vay: {fmtDateFull(l.loanDate)}</Text>
                      {l.note ? <Text style={styles.loanNote}>{l.note}</Text> : null}
                    </View>
                    <TouchableOpacity onPress={() =>
                      Alert.alert('Xoá', 'Xoá khoản vay này?', [
                        { text: 'Huỷ' },
                        { text: 'Xoá', style: 'destructive', onPress: () => delLoan(l.id) },
                      ])} style={styles.delBtn}>
                      <Text style={{ color: COLORS.red, fontSize: 13 }}>✕</Text>
                    </TouchableOpacity>
                  </View>

                  {/* Payment history */}
                  {l.payments && l.payments.length > 0 && (
                    <View style={styles.payHistory}>
                      {l.payments.map((p, i) => (
                        <View key={i} style={styles.payRow}>
                          <Text style={{ color: COLORS.subtext, fontSize: 11 }}>Trả {fmtDate(p.date)}</Text>
                          <Text style={{ color: COLORS.green, fontSize: 11, fontWeight: '700' }}>+{fmt(p.amount)}</Text>
                        </View>
                      ))}
                    </View>
                  )}

                  {/* Partial pay input */}
                  {partialId === l.id && (
                    <View style={styles.partialBox}>
                      <Label>Số tiền trả một phần</Label>
                      <View style={styles.amtRow}>
                        <Text style={[styles.currency, { color: COLORS.orange }]}>₫</Text>
                        <AmountInput value={partialAmt} onChange={setPartialAmt} color={COLORS.orange} />
                      </View>
                      <View style={styles.partialBtns}>
                        <TouchableOpacity onPress={() => handlePartial(l.id)}
                          style={[styles.partialConfirm, { backgroundColor: partialAmt ? COLORS.orange : COLORS.card }]}>
                          <Text style={{ color: partialAmt ? '#fff' : COLORS.subtext, fontWeight: '800', fontSize: 13 }}>Xác nhận</Text>
                        </TouchableOpacity>
                        <TouchableOpacity onPress={() => { setPartialId(null); setPartialAmt(''); }}
                          style={styles.partialCancel}>
                          <Text style={{ color: COLORS.subtext, fontSize: 13 }}>Huỷ</Text>
                        </TouchableOpacity>
                      </View>
                    </View>
                  )}

                  <View style={styles.loanBottom}>
                    <View>
                      {l.dueDate
                        ? <><Text style={styles.dueLabel}>DỰ KIẾN TRẢ</Text><Text style={styles.dueValue}>{fmtDateFull(l.dueDate)}</Text></>
                        : <Text style={{ color: '#4B5563', fontSize: 12 }}>Chưa đặt ngày</Text>
                      }
                    </View>
                    {partialId !== l.id && (
                      <View style={styles.actionBtns}>
                        {days !== null && <DaysBadge days={days} />}
                        <TouchableOpacity onPress={() => { setPartialId(l.id); setPartialAmt(''); }} style={styles.partialBtn}>
                          <Text style={{ color: COLORS.orange, fontSize: 12, fontWeight: '700' }}>Trả một phần</Text>
                        </TouchableOpacity>
                        <TouchableOpacity onPress={() =>
                          Alert.alert('Xác nhận', 'Đánh dấu đã thu hồi?', [
                            { text: 'Huỷ' },
                            { text: '✓ Đã thu', onPress: () => markLoanPaid(l.id) },
                          ])} style={styles.paidBtn}>
                          <Text style={{ color: '#0F0F14', fontSize: 12, fontWeight: '800' }}>✓ Đã thu</Text>
                        </TouchableOpacity>
                      </View>
                    )}
                  </View>
                </View>
              );
            })}
          </View>
        ))}

        {/* Paid */}
        {paid.length > 0 && (
          <View>
            <Text style={styles.paidHeader}>ĐÃ THU HỒI ({paid.length})</Text>
            {paid.map(l => (
              <View key={l.id} style={[styles.paidRow, { opacity: 0.55 }]}>
                <Text style={{ fontSize: 18 }}>✅</Text>
                <View style={{ flex: 1, marginLeft: 12 }}>
                  <Text style={{ color: COLORS.text, fontSize: 14, fontWeight: '700' }}>{l.borrower} · {fmt(l.amount)}</Text>
                  <Text style={{ color: COLORS.subtext, fontSize: 12, marginTop: 2 }}>Thu ngày {fmtDateFull(l.paidDate)}</Text>
                </View>
                <TouchableOpacity onPress={() => delLoan(l.id)} style={styles.delBtn}>
                  <Text style={{ color: COLORS.red, fontSize: 13 }}>✕</Text>
                </TouchableOpacity>
              </View>
            ))}
          </View>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:      { flex: 1, backgroundColor: COLORS.bg },
  header:         { padding: 24 },
  headerRow:      { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  pageLabel:      { color: COLORS.subtext, fontSize: 11, fontWeight: '700', letterSpacing: 1 },
  totalAmt:       { color: COLORS.text, fontSize: 32, fontWeight: '800', marginTop: 4 },
  sub:            { color: COLORS.subtext, fontSize: 13, marginTop: 5 },
  addBtn:         { backgroundColor: 'rgba(255,179,71,0.12)', borderWidth: 1, borderColor: 'rgba(255,179,71,0.28)', borderRadius: 16, width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  chipRow:        { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 16 },
  chip:           { backgroundColor: 'rgba(255,179,71,0.08)', borderWidth: 1, borderColor: 'rgba(255,179,71,0.18)', borderRadius: 12, padding: 10 },
  chipName:       { color: COLORS.orange, fontSize: 11, fontWeight: '700' },
  chipAmt:        { color: COLORS.text, fontSize: 13, fontWeight: '800', marginTop: 3 },
  form:           { margin: 24, backgroundColor: COLORS.card, borderRadius: 20, padding: 18, borderWidth: 1, borderColor: COLORS.border },
  formTitle:      { color: COLORS.text, fontSize: 18, fontWeight: '800', marginBottom: 16 },
  inputCard:      { backgroundColor: '#252540', borderRadius: 16, padding: 14, marginBottom: 12, borderWidth: 1, borderColor: COLORS.border },
  amtRow:         { flexDirection: 'row', alignItems: 'center', gap: 8 },
  currency:       { fontSize: 22, fontWeight: '700' },
  saveBtn:        { borderRadius: 16, padding: 15, alignItems: 'center', marginTop: 4 },
  saveBtnText:    { fontSize: 14, fontWeight: '800', letterSpacing: 1 },
  borrowerHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 },
  avatar:         { width: 28, height: 28, borderRadius: 14, backgroundColor: 'rgba(255,179,71,0.15)', alignItems: 'center', justifyContent: 'center' },
  avatarText:     { color: COLORS.orange, fontSize: 13, fontWeight: '800' },
  borrowerName:   { color: COLORS.text, fontSize: 14, fontWeight: '700' },
  borrowerTotal:  { color: COLORS.subtext, fontSize: 12 },
  loanCard:       { backgroundColor: COLORS.card, borderRadius: 18, padding: 14, marginBottom: 10, borderWidth: 1 },
  loanTop:        { flexDirection: 'row', alignItems: 'flex-start' },
  loanAmt:        { color: COLORS.text, fontSize: 17, fontWeight: '800' },
  loanDate:       { color: COLORS.subtext, fontSize: 12, marginTop: 3 },
  loanNote:       { color: COLORS.subtext, fontSize: 12, marginTop: 2 },
  delBtn:         { backgroundColor: 'rgba(255,107,107,0.08)', borderRadius: 8, padding: 6 },
  payHistory:     { backgroundColor: 'rgba(168,230,207,0.05)', borderWidth: 1, borderColor: 'rgba(168,230,207,0.1)', borderRadius: 10, padding: 8, marginTop: 10 },
  payRow:         { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 3 },
  partialBox:     { backgroundColor: 'rgba(255,179,71,0.06)', borderWidth: 1, borderColor: 'rgba(255,179,71,0.18)', borderRadius: 12, padding: 12, marginTop: 10 },
  partialBtns:    { flexDirection: 'row', gap: 8, marginTop: 10 },
  partialConfirm: { flex: 1, borderRadius: 10, padding: 9, alignItems: 'center' },
  partialCancel:  { backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 14, paddingVertical: 9 },
  loanBottom:     { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', marginTop: 12, paddingTop: 12, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' },
  dueLabel:       { color: COLORS.subtext, fontSize: 10, fontWeight: '700', letterSpacing: 1 },
  dueValue:       { color: COLORS.text, fontSize: 13, fontWeight: '700', marginTop: 2 },
  actionBtns:     { flexDirection: 'row', alignItems: 'center', gap: 6, flexWrap: 'wrap', justifyContent: 'flex-end' },
  partialBtn:     { backgroundColor: 'rgba(255,179,71,0.12)', borderWidth: 1, borderColor: 'rgba(255,179,71,0.22)', borderRadius: 12, paddingHorizontal: 10, paddingVertical: 7 },
  paidBtn:        { backgroundColor: COLORS.green, borderRadius: 12, paddingHorizontal: 10, paddingVertical: 7 },
  paidHeader:     { color: COLORS.subtext, fontSize: 11, fontWeight: '700', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 12 },
  paidRow:        { flexDirection: 'row', alignItems: 'center', padding: 12, backgroundColor: COLORS.card, borderRadius: 16, marginBottom: 8, borderWidth: 1, borderColor: COLORS.border },
});
