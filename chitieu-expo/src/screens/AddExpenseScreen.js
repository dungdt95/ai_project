import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../storage/AppContext';
import { COLORS, CATEGORIES } from '../constants';
import { AmountInput, Card, Label, BigButton, BackBtn, todayStr } from '../components';

export default function AddExpenseScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { addExpense } = useApp();
  const [amount,   setAmount]   = useState('');
  const [category, setCategory] = useState('food');
  const [note,     setNote]     = useState('');

  const handleSave = () => {
    if (!amount || isNaN(amount)) return;
    addExpense({
      id: Date.now(), amount: +amount, category, note: note || 'Không có ghi chú', date: todayStr(),
    });
    setAmount('');
    setNote('');
    setCategory('food');
  };

  return (
    <ScrollView style={[styles.container, { paddingTop: insets.top + 16 }]}
      contentContainerStyle={{ padding: 24, paddingBottom: 60 }}
      keyboardShouldPersistTaps="handled">
      <BackBtn onPress={() => navigation.goBack()} />
      <Text style={styles.title}>Thêm chi tiêu</Text>

      <Card borderColor="rgba(255,107,107,0.2)">
        <Label>Số tiền</Label>
        <View style={styles.amountRow}>
          <Text style={[styles.currency, { color: COLORS.redLight }]}>₫</Text>
          <AmountInput value={amount} onChange={setAmount} color={COLORS.redLight} />
        </View>
      </Card>

      <Card>
        <Label>Ghi chú</Label>
        <TextInput
          value={note}
          onChangeText={setNote}
          placeholder="Mua gì vậy?"
          placeholderTextColor={COLORS.subtext}
          style={styles.textInput}
        />
      </Card>

      <Label>Danh mục</Label>
      <View style={styles.grid}>
        {CATEGORIES.map(c => (
          <TouchableOpacity key={c.id} onPress={() => setCategory(c.id)}
            style={[styles.catBtn, {
              backgroundColor: category === c.id ? c.color + '28' : COLORS.card,
              borderColor:     category === c.id ? c.color : 'rgba(255,255,255,0.05)',
            }]}>
            <Text style={{ fontSize: 24 }}>{c.icon}</Text>
            <Text style={[styles.catLabel, { color: category === c.id ? COLORS.text : COLORS.subtext }]}>
              {c.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <BigButton
        label="LƯU CHI TIÊU"
        onPress={handleSave}
        active={!!amount}
        gradient={['#FF6B6B', '#FF8E53']}
      />
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
  catBtn:     { width: '22%', borderRadius: 16, padding: 11, alignItems: 'center', borderWidth: 2 },
  catLabel:   { fontSize: 10, marginTop: 5, fontWeight: '600', textAlign: 'center' },
});
