import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../storage/AppContext';
import { COLORS, INCOME_SOURCES } from '../constants';
import { AmountInput, Card, Label, BigButton, BackBtn, todayStr } from '../components';

export default function AddIncomeScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { addIncome } = useApp();
  const [amount, setAmount] = useState('');
  const [source, setSource] = useState('salary');
  const [note,   setNote]   = useState('');

  const handleSave = () => {
    if (!amount || isNaN(amount)) return;
    addIncome({
      id: Date.now(), amount: +amount, source, note: note || 'Không có ghi chú', date: todayStr(),
    });
    setAmount('');
    setNote('');
    setSource('salary');
  };

  return (
    <ScrollView style={[styles.container, { paddingTop: insets.top + 16 }]}
      contentContainerStyle={{ padding: 24, paddingBottom: 60 }}
      keyboardShouldPersistTaps="handled">
      <BackBtn onPress={() => navigation.goBack()} />
      <Text style={styles.title}>Nhập tiền</Text>

      <Card borderColor="rgba(168,230,207,0.2)">
        <Label>Số tiền nhận</Label>
        <View style={styles.amountRow}>
          <Text style={[styles.currency, { color: COLORS.green }]}>₫</Text>
          <AmountInput value={amount} onChange={setAmount} color={COLORS.green} />
        </View>
      </Card>

      <Card>
        <Label>Ghi chú</Label>
        <TextInput
          value={note} onChangeText={setNote}
          placeholder="Từ đâu vậy?"
          placeholderTextColor={COLORS.subtext}
          style={styles.textInput}
        />
      </Card>

      <Label>Nguồn tiền</Label>
      <View style={styles.grid}>
        {INCOME_SOURCES.map(s => (
          <TouchableOpacity key={s.id} onPress={() => setSource(s.id)}
            style={[styles.srcBtn, {
              backgroundColor: source === s.id ? s.color + '28' : COLORS.card,
              borderColor:     source === s.id ? s.color : 'rgba(255,255,255,0.05)',
            }]}>
            <Text style={{ fontSize: 24 }}>{s.icon}</Text>
            <Text style={[styles.srcLabel, { color: source === s.id ? COLORS.text : COLORS.subtext }]}>
              {s.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <BigButton label="LƯU THU NHẬP" onPress={handleSave} active={!!amount} gradient={['#A8E6CF', '#4ECDC4']} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:  { flex: 1, backgroundColor: COLORS.bg },
  title:      { color: COLORS.text, fontSize: 24, fontWeight: '800', marginBottom: 24 },
  amountRow:  { flexDirection: 'row', alignItems: 'center', gap: 8 },
  currency:   { fontSize: 22, fontWeight: '700' },
  textInput:  { color: COLORS.text, fontSize: 16, fontWeight: '500' },
  grid:       { flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginBottom: 16 },
  srcBtn:     { width: '30%', borderRadius: 16, padding: 11, alignItems: 'center', borderWidth: 2 },
  srcLabel:   { fontSize: 10, marginTop: 5, fontWeight: '600', textAlign: 'center' },
});
