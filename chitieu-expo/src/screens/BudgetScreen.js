import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../storage/AppContext';
import { COLORS } from '../constants';
import { AmountInput, Card, Label, BigButton, BackBtn } from '../components';

export default function BudgetScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { budget, setBudget } = useApp();
  const [input, setInput] = useState(budget ? String(budget) : '');

  const handleSave = () => {
    const v = parseInt(input, 10);
    if (!isNaN(v) && v > 0) {
      setBudget(v);
      navigation.goBack();
    }
  };

  return (
    <ScrollView style={[styles.container, { paddingTop: insets.top + 16 }]}
      contentContainerStyle={{ padding: 24, paddingBottom: 60 }}
      keyboardShouldPersistTaps="handled">
      <BackBtn onPress={() => navigation.goBack()} />
      <Text style={styles.title}>Ngân sách tháng</Text>
      <Text style={styles.sub}>Đặt giới hạn chi tiêu của bạn</Text>

      <Card borderColor="rgba(232,255,71,0.18)" style={{ marginTop: 24 }}>
        <Label>Ngân sách (₫)</Label>
        <View style={styles.amtRow}>
          <Text style={[styles.currency, { color: COLORS.accent }]}>₫</Text>
          <AmountInput value={input} onChange={setInput} color={COLORS.accent} />
        </View>
      </Card>

      <View style={styles.presets}>
        {[3_000_000, 5_000_000, 10_000_000].map(v => (
          <TouchableOpacity key={v} onPress={() => setInput(String(v))}
            style={[styles.preset, {
              backgroundColor: input === String(v) ? 'rgba(232,255,71,0.15)' : COLORS.card,
              borderColor:     input === String(v) ? COLORS.accent : 'rgba(255,255,255,0.05)',
            }]}>
            <Text style={[styles.presetText, { color: input === String(v) ? COLORS.accent : COLORS.subtext }]}>
              {v / 1_000_000}tr
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <BigButton label="LƯU NGÂN SÁCH" onPress={handleSave} active={!!input} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.bg },
  title:     { color: COLORS.text, fontSize: 24, fontWeight: '800' },
  sub:       { color: COLORS.subtext, fontSize: 14, marginTop: 6 },
  amtRow:    { flexDirection: 'row', alignItems: 'center', gap: 8 },
  currency:  { fontSize: 22, fontWeight: '700' },
  presets:   { flexDirection: 'row', gap: 10, marginBottom: 24 },
  preset:    { flex: 1, borderRadius: 14, padding: 14, alignItems: 'center', borderWidth: 2 },
  presetText:{ fontSize: 15, fontWeight: '700' },
});
